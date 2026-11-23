import { prisma } from '../db.js';
import { log } from './log.js';
import { serializeProduct } from './product.js';
import { buildWeatherContext } from './weather.js';
import { streamChatEvents } from './openai-compatible.js';
import { CLAIM_GROUPS, claimCouponGroupForUser } from '../routes/coupons.js';
import {
  buildLineItemsFromRequest,
  resolveAddress,
  resolveDiscount,
} from '../routes/orders.js';
import { generateOrderNo } from './order.js';

export const MAJOR_CATEGORIES = ['玩具', '文具', '手办', '公仔', '谷子', '小卡', '实用类周边'];
const SEARCH_LIMIT = 3;

export const XIAODOU_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'search_products',
      description:
        '在趣玩星球商城搜索真实在售商品。品类、关键词、预算至少有一项再调用。价格以返回的 price 为准，禁止自己编价格。',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: '商品名、角色、风格、颜色等关键词' },
          majorCategory: {
            type: 'string',
            enum: MAJOR_CATEGORIES,
            description: '大分类。谷子与小卡不可混用',
          },
          minPrice: { type: 'number', description: '最低价格（元）' },
          maxPrice: { type: 'number', description: '最高价格（元）' },
          sort: {
            type: 'string',
            enum: ['sales', 'price_asc', 'price_desc', 'rating'],
            description: '默认按销量',
          },
          skip: { type: 'number', description: '换一批时跳过前几条，例如 4、8' },
          excludeIds: {
            type: 'array',
            items: { type: 'string' },
            description: '排除已展示过的商品 id',
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'draw_star_cards',
      description:
        '需求已较清楚时调用。从货架揭三张星牌：本命、遇见、余韵。比 search_products 更适合正式推荐。仍不要编造商品。',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
          majorCategory: { type: 'string', enum: MAJOR_CATEGORIES },
          minPrice: { type: 'number' },
          maxPrice: { type: 'number' },
          sort: {
            type: 'string',
            enum: ['sales', 'price_asc', 'price_desc', 'rating'],
            description: '默认按销量；用户看重口碑传 rating，看重省钱传 price_asc',
          },
          excludeIds: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_product_detail',
      description: '按商品 id 读取介绍和购买须知。价格、分类以返回为准。',
      parameters: {
        type: 'object',
        properties: {
          productId: { type: 'string' },
        },
        required: ['productId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_promotions',
      description: '查询当前可介绍的优惠券与会员福利，不要编造不存在的活动。',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_user_context',
      description: '读取当前登录用户的 VIP、积分、未使用优惠券。不要编造等级或券额。',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_to_cart',
      description:
        '用户明确说加入购物车、帮我加购某件商品时调用：直接真的加进购物车，办完会记进办事清单，用户可以自己再去改。不要只是嘴上说加好了。',
      parameters: {
        type: 'object',
        properties: {
          productId: { type: 'string' },
          quantity: { type: 'number', description: '数量，默认 1' },
        },
        required: ['productId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_cart',
      description:
        '用户要改购物车里某件商品的数量时调用（改成几件、去掉这件）。quantity 是改完的目标数量，传 0 表示从购物车移除。只对已经在购物车里的商品有效。',
      parameters: {
        type: 'object',
        properties: {
          productId: { type: 'string' },
          quantity: { type: 'number', description: '改完的数量；0 = 移除' },
        },
        required: ['productId', 'quantity'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'claim_coupon',
      description:
        '帮用户领取一张优惠券：用户说要领券时，或下单前发现有他能领、且对这次购买明显有用的券时调用。templateId 用 get_promotions 返回的券 id。领过的、领完的会如实返回失败，不要假装领到。',
      parameters: {
        type: 'object',
        properties: {
          templateId: { type: 'string', description: '券模板 id，如 c6' },
        },
        required: ['templateId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_favorite',
      description: '用户说收藏、先存着、加心愿单时调用：真的把商品加进他的收藏夹。',
      parameters: {
        type: 'object',
        properties: {
          productId: { type: 'string' },
        },
        required: ['productId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'set_order_note',
      description:
        '用户交代订单备注或贺卡内容时调用（如「备注写生日快乐，帮我包好看点」）：先记下来，本轮稍后生成订单时会自动带上；没生成订单也会记进办事清单。',
      parameters: {
        type: 'object',
        properties: {
          text: { type: 'string', description: '备注原文，最多 200 字' },
        },
        required: ['text'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_order',
      description:
        '用户明确拍板要买（「就它了，帮我下单」「买这个」）时调用：按给定商品生成一张待付款订单。只生成待付款，绝不替用户付款；没指定券时系统会自动挑一张最划算的可用券。地址用他的默认地址，没有地址会如实返回失败。',
      parameters: {
        type: 'object',
        properties: {
          items: {
            type: 'array',
            description: '要买的商品列表',
            items: {
              type: 'object',
              properties: {
                productId: { type: 'string' },
                quantity: { type: 'number', description: '数量，默认 1' },
              },
              required: ['productId'],
            },
          },
          couponTemplateId: {
            type: 'string',
            description: '指定用哪张已领取的券（模板 id）；不传则自动挑最划算的',
          },
          note: { type: 'string', description: '订单备注；不传则用本轮 set_order_note 记下的' },
        },
        required: ['items'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description:
        '查询某个城市的真实天气（今天起三天的温度、降水概率等，来自气象服务）。用户问天气、冷不冷、下不下雨、要不要带伞时调用；天气只信这个工具返回的数据，不要用联网搜索答天气。',
      parameters: {
        type: 'object',
        properties: {
          city: {
            type: 'string',
            description: '城市名，如「深圳」。用户没明说时可省略，系统会从对话历史里提取',
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'web_search',
      description:
        '联网搜索最新信息：新闻、行情、政策、流行趋势、网友评价等店外事实。需要最新或店外信息时调用；结果带时间与来源，回答时自然带一句。店内商品、价格、订单、券不要用这个查，那些只认店内工具。',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: '搜索问题，写成一句完整的话，如「2026 年 11 月最近流行的盲盒系列有什么」',
          },
        },
        required: ['query'],
      },
    },
  },
];

function parseArgs(raw) {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function orderByFor(sort) {
  if (sort === 'price_asc') return [{ price: 'asc' }, { id: 'asc' }];
  if (sort === 'price_desc') return [{ price: 'desc' }, { id: 'asc' }];
  if (sort === 'rating') return [{ rating: 'desc' }, { sales: 'desc' }, { id: 'asc' }];
  return [{ sales: 'desc' }, { id: 'asc' }];
}

function compactProduct(p) {
  const full = serializeProduct(p);
  return {
    id: full.id,
    name: full.name,
    majorCategory: full.majorCategory,
    price: full.price,
    tag: full.tag,
    sales: full.sales,
  };
}

async function searchProducts(args, { take = SEARCH_LIMIT } = {}) {
  const query = String(args.query ?? '').trim();
  const majorCategory = MAJOR_CATEGORIES.includes(args.majorCategory) ? args.majorCategory : null;
  const minPrice = Number.isFinite(Number(args.minPrice)) ? Number(args.minPrice) : null;
  const maxPrice = Number.isFinite(Number(args.maxPrice)) ? Number(args.maxPrice) : null;
  const sort = String(args.sort ?? 'sales');
  const skip = Math.max(0, Number.parseInt(String(args.skip ?? 0), 10) || 0);
  const excludeIds = (Array.isArray(args.excludeIds) ? args.excludeIds : [])
    .map((id) => String(id).trim())
    .filter(Boolean);

  if (!query && !majorCategory && minPrice == null && maxPrice == null) {
    return {
      ok: false,
      needMore: true,
      hint: '请先向用户确认品类、关键词或预算，再搜索。',
      products: [],
      totalCount: 0,
    };
  }

  const and = [];
  if (majorCategory) and.push({ majorCategory });
  if (minPrice != null) and.push({ price: { gte: minPrice } });
  if (maxPrice != null) and.push({ price: { lte: maxPrice } });
  if (excludeIds.length > 0) and.push({ id: { notIn: excludeIds } });
  if (query) {
    and.push({
      OR: [
        { name: { contains: query } },
        { nameEn: { contains: query, mode: 'insensitive' } },
        { subCategory: { contains: query } },
        { tag: { contains: query } },
        { description: { contains: query } },
      ],
    });
  }

  const where = and.length === 1 ? and[0] : { AND: and };
  const [rows, totalCount] = await Promise.all([
    prisma.product.findMany({
      where,
      orderBy: orderByFor(sort),
      skip,
      take,
    }),
    prisma.product.count({ where }),
  ]);

  if (rows.length === 0 && query) {
    const tokens = query.split(/[\s,，、]+/).map((item) => item.trim()).filter((item) => item.length >= 2);
    for (const token of tokens) {
      const looseWhere = {
        AND: [
          ...(majorCategory ? [{ majorCategory }] : []),
          ...(maxPrice != null ? [{ price: { lte: maxPrice } }] : []),
          ...(minPrice != null ? [{ price: { gte: minPrice } }] : []),
          ...(excludeIds.length > 0 ? [{ id: { notIn: excludeIds } }] : []),
          {
            OR: [
              { name: { contains: token } },
              { subCategory: { contains: token } },
            ],
          },
        ],
      };
      const loose = await prisma.product.findMany({
        where: looseWhere,
        orderBy: orderByFor(sort),
        skip,
        take,
      });
      if (loose.length > 0) {
        const looseCount = await prisma.product.count({ where: looseWhere });
        return {
          ok: true,
          totalCount: looseCount,
          skip,
          products: loose.map(compactProduct),
          fullProducts: loose.map(serializeProduct),
          note: `按「${token}」放宽匹配`,
        };
      }
    }
  }

  return {
    ok: true,
    totalCount,
    skip,
    products: rows.map(compactProduct),
    fullProducts: rows.map(serializeProduct),
    note: rows.length === 0 ? '没有更多匹配商品，请换关键词或放宽预算，不要编造商品。' : undefined,
  };
}

// 给三张牌各算一句「特点」：只用真实数据里的最高级——口碑最好（评分）、
// 价格最低、卖得最火（销量），一张牌占一条、互不重复；哪条都没占上
// 就退回「价格 · 销量 · 评分」的事实行。不许模型自己编特点，
// 数字全在这里算死（导购全流程稿拍 4 的硬规矩）。
// 输入：本批三件商品；输出：Map<商品 id, 特点句>。
function computeTraits(picked) {
  const traits = new Map();
  const used = new Set();
  const bestRating = Math.max(...picked.map((x) => Number(x.rating ?? 0)));
  const minPrice = Math.min(...picked.map((x) => Number(x.price ?? 0)));
  const maxPrice = Math.max(...picked.map((x) => Number(x.price ?? 0)));
  const bestSales = Math.max(...picked.map((x) => Number(x.sales ?? 0)));
  for (const item of picked) {
    const rating = Number(item.rating ?? 0);
    const price = Number(item.price ?? 0);
    const sales = Number(item.sales ?? 0);
    if (rating > 0 && rating === bestRating && !used.has('rating')) {
      used.add('rating');
      traits.set(item.id, `口碑最好，评分 ${rating}`);
    } else if (price === minPrice && maxPrice > minPrice && !used.has('price')) {
      used.add('price');
      traits.set(item.id, `价格最低，比最贵的省 ¥${Math.round(maxPrice - minPrice)}`);
    } else if (sales === bestSales && sales > 0 && !used.has('sales')) {
      used.add('sales');
      traits.set(item.id, `卖得最火，已售 ${sales} 件`);
    } else {
      traits.set(item.id, `¥${price} · 已售 ${sales} 件 · 评分 ${rating}`);
    }
  }
  return traits;
}

async function drawStarCards(args) {
  const result = await searchProducts(args, { take: 12 });
  const list = result.fullProducts ?? [];
  // 本次抽牌的有效条件原样回带：App 的「下一批」要拿它接着抽，
  // 批次翻页不能靠模型重新猜条件。
  const drawArgs = {
    ...(String(args.query ?? '').trim() ? { query: String(args.query).trim() } : {}),
    ...(MAJOR_CATEGORIES.includes(args.majorCategory)
      ? { majorCategory: args.majorCategory }
      : {}),
    ...(Number.isFinite(Number(args.minPrice)) && args.minPrice != null
      ? { minPrice: Number(args.minPrice) }
      : {}),
    ...(Number.isFinite(Number(args.maxPrice)) && args.maxPrice != null
      ? { maxPrice: Number(args.maxPrice) }
      : {}),
    sort: ['price_asc', 'price_desc', 'rating'].includes(args.sort) ? args.sort : 'sales',
  };
  if (list.length === 0) {
    return { ...result, cards: [], fate: true, drawArgs, hasMore: false };
  }
  const fate = list[0];
  const rest = list.slice(1);
  const encounter = [...rest].sort((a, b) => (a.sales ?? 0) - (b.sales ?? 0))[0] ?? rest[0] ?? fate;
  const lingerPool = rest.filter((item) => item.id !== encounter.id);
  const linger =
    lingerPool.sort(
      (a, b) => Math.abs(Number(a.price) - Number(fate.price) * 1.15) - Math.abs(Number(b.price) - Number(fate.price) * 1.15),
    )[0] ?? encounter;

  const unique = [];
  const seen = new Set();
  for (const item of [fate, encounter, linger]) {
    if (!item?.id || seen.has(item.id)) continue;
    seen.add(item.id);
    unique.push(item);
  }
  const roles = ['fate', 'encounter', 'linger'];
  const picked = unique.slice(0, 3);

  // 每张牌的真实评价条数：功课段要报「看了 N 条评价」，数字从这来。
  const reviewCounts = await Promise.all(
    picked.map((item) =>
      prisma.productReview.count({ where: { productId: item.id } }).catch(() => 0),
    ),
  );

  const traitMap = computeTraits(picked);
  const cards = picked.map((item, index) => ({
    role: roles[index],
    id: item.id,
    name: item.name,
    majorCategory: item.majorCategory,
    price: item.price,
    tag: item.tag,
    sales: item.sales,
    rating: Number(item.rating ?? 0),
    reviewCount: reviewCounts[index],
    trait: traitMap.get(item.id) ?? '',
  }));

  return {
    ok: true,
    fate: picked.length >= 2,
    totalCount: result.totalCount,
    // totalCount 是「扣掉已展示后还剩多少件匹配」，大于本批张数就是还有下一批
    hasMore: (result.totalCount ?? 0) > picked.length,
    drawArgs,
    reviewTotal: reviewCounts.reduce((sum, n) => sum + n, 0),
    cards,
    fullProducts: picked,
    roles: picked.map((_, index) => roles[index]),
    note: picked.length >= 3 ? '三张星牌：本命、遇见、余韵。每张牌的 trait 是系统按真实数据算好的特点句，讲牌时照它说，不要改数字、不要另编特点。' : '货架这一层不足三件，按实际张数推荐。',
  };
}

// 批次翻页专用（App 点「下一批」时走 /api/chat/draw-batch 直达，不经模型）：
// 输入同一套抽牌条件 + 已展示的 excludeIds，输出下一批三张与批次元数据。
// 坑：excludeIds 必须把之前每一批都算上，漏了就会把看过的牌再端上来。
export async function drawStarCardsBatch(args = {}) {
  const result = await drawStarCards(args);
  const traits = {};
  for (const card of result.cards ?? []) traits[card.id] = card.trait;
  return {
    ok: result.ok !== false,
    products: result.fullProducts ?? [],
    roles: result.roles ?? [],
    traits,
    totalCount: result.totalCount ?? 0,
    hasMore: Boolean(result.hasMore),
    drawArgs: result.drawArgs ?? {},
  };
}

async function getProductDetail(args) {
  const productId = String(args.productId ?? '').trim();
  if (!productId) return { ok: false, error: '缺少 productId' };
  const row = await prisma.product.findUnique({ where: { id: productId } });
  if (!row) return { ok: false, error: '商品不存在' };
  const full = serializeProduct(row);
  return {
    ok: true,
    product: {
      ...compactProduct(row),
      description: String(full.description ?? '').slice(0, 280),
      purchaseNotes: String(full.purchaseNotes ?? '').slice(0, 180),
      originalPrice: full.originalPrice,
    },
    fullProduct: full,
  };
}

async function getPromotions() {
  const templates = await prisma.couponTemplate.findMany({
    orderBy: { id: 'asc' },
    take: 12,
  });
  return {
    ok: true,
    coupons: templates.map((item) => ({
      id: item.id,
      title: item.title,
      discount: Number(item.discount),
      condition: item.condition,
      claimType: item.claimType,
    })),
    member: 'VIP 可享每月赠券、积分加成、专属折扣、生日礼包、优先发货；具体以「我的-会员权益」为准。',
    note: '不要编造未列出的满减或活动。',
  };
}

async function getUserContext(userId) {
  if (!userId) {
    return { ok: false, error: '用户未登录，无法读取会员信息' };
  }
  const [user, profile, coupons] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId }, select: { nickname: true, userId: true } }),
    prisma.userProfile.findUnique({ where: { userId } }),
    prisma.userCoupon.findMany({
      where: { userId, used: false },
      include: { template: true },
      take: 12,
    }),
  ]);
  return {
    ok: true,
    nickname: user?.nickname ?? '',
    publicUserId: user?.userId ?? '',
    vipLevel: profile?.vipLevel ?? 1,
    points: profile?.points ?? 0,
    funCoins: profile?.funCoins ?? 0,
    newcomerClaimed: profile?.newcomerClaimed ?? false,
    memberMonthlyCouponClaimed: profile?.memberMonthlyCouponClaimed ?? false,
    unusedCoupons: coupons.map((row) => ({
      id: row.templateId,
      title: row.template.title,
      discount: Number(row.template.discount),
      condition: row.template.condition,
    })),
    note: '未使用优惠券以 unusedCoupons 为准；未领取的新人券请引导去领券中心，不要假装已经到账。',
  };
}

async function proposeAddToCart(args) {
  const productId = String(args.productId ?? '').trim();
  if (!productId) return { ok: false, pendingConfirm: false, error: '缺少 productId' };
  const row = await prisma.product.findUnique({ where: { id: productId } });
  if (!row) return { ok: false, pendingConfirm: false, error: '商品不存在' };
  const full = serializeProduct(row);
  return {
    ok: true,
    pendingConfirm: true,
    product: compactProduct(row),
    fullProduct: full,
    note: '尚未加入购物车。请告诉用户点击下方「确认加入购物车」。',
  };
}

// 天气工具（合脑新增）：包一层 weather.js 的 buildWeatherContext。
// 输入：模型给的 city（可省略）+ 调用方从 context 递进来的完整对话。
// 输出：{ ok: true, weather: '气象数据…' }，或查不到时 ok: false。
// 坑：城市优先用模型给的；没给时把整段对话交给天气模块提取——
// 用户追问「明天呢」时城市只在上一轮出现过，靠对话才找得到。
async function getWeather(args, context) {
  const city = String(args.city ?? '').trim();
  const messages = city
    ? [{ role: 'user', content: `${city}天气怎么样` }]
    : Array.isArray(context.messages)
      ? context.messages
      : [];
  const brief = await buildWeatherContext(messages);
  if (!brief) {
    return {
      ok: false,
      error: '这次没查到天气数据。不要编造天气；如实告诉用户没查到，或请他确认城市名。',
    };
  }
  return { ok: true, weather: brief.trim() };
}

// 联网搜索工具：为什么不直接用模型的 enable_search 开关——实测它
// 与工具调用同开时，模型会只说「我先帮你查一下」却不真正发出工具
// 调用、整轮空转（2026-11-22 23:40 实锤）。改成普通工具：内部单独
// 发一次开了搜索的请求（不带工具、不带思考预算，避开所有冲突），
// 把整理好的事实清单当工具结果交回主循环，模型再据此回答。
// 输入：query + context 里的 dashscope 配置与 smartModel。
// 输出：{ ok: true, findings }；失败或没搜到时 ok: false 并写明
// 不许编造，让主模型如实告知用户。
async function webSearch(args, context) {
  const query = String(args.query ?? '').trim();
  if (!query) return { ok: false, error: '缺少搜索问题' };
  const dashscope = context.dashscope;
  if (!dashscope?.apiKey) {
    return { ok: false, error: '当前路线用不了联网搜索。不要编造外部信息，如实告诉用户。' };
  }
  let findings = '';
  try {
    for await (const event of streamChatEvents({
      apiKey: dashscope.apiKey,
      baseUrl: dashscope.baseUrl,
      model: context.smartModel || 'qwen4-max',
      messages: [
        {
          role: 'system',
          content:
            '你是检索员，只做一件事：联网搜索与问题相关的最新事实，整理成简明的事实清单。每条事实带上时间或来源；搜不到就直说没搜到，不许编造。只输出事实清单，不要寒暄，不要给建议。',
        },
        { role: 'user', content: query },
      ],
      temperature: 0.3,
      maxTokens: 1200,
      timeoutMs: 60000,
      idleTimeoutMs: 30000,
      extra: { enable_search: true },
    })) {
      if (event.type === 'content') findings += event.text;
    }
  } catch (error) {
    console.warn('[xiaodou-tools] web_search failed:', error.message);
    return { ok: false, error: '这次联网搜索失败了。不要编造外部信息，如实告诉用户没查到。' };
  }
  const text = findings.trim();
  if (!text) {
    return { ok: false, error: '这次没搜到相关信息。不要编造外部信息，如实告诉用户没查到。' };
  }
  return { ok: true, findings: text.slice(0, 3000) };
}


// ================= 办事工具（Agent 第二步「长手」） =================
// 共同规矩：每个办事工具都返回一份 action 记录（办成 done / 没办成
// failed + 人话原因），大脑循环把它发成 actions 事件、App 记进办事
// 清单。没办成不许假装办成——failed 也是清单的一条（设计稿硬规矩）。
// 输入：args 是模型给的参数，context 带 userId 与本轮共享的 turnState。
// 坑：turnState 是「这一轮对话」的暂存（比如先记备注、后生成订单），
// 跨轮不保留，不要拿它当长期记忆用。

function turnStateOf(context) {
  if (!context.turnState) context.turnState = {};
  return context.turnState;
}

// 造一条清单记录：id 在一轮内递增不重复，App 按 id 更新同一条。
function makeAction(context, fields) {
  const turn = turnStateOf(context);
  turn.actionSeq = (turn.actionSeq ?? 0) + 1;
  return {
    id: `a${turn.actionSeq}`,
    status: 'done',
    saved: 0,
    ...fields,
  };
}

function failedAction(context, type, title, failReason, target) {
  return makeAction(context, {
    type,
    title,
    detail: '',
    status: 'failed',
    failReason,
    ...(target ? { target } : {}),
  });
}

function money(value) {
  const n = Number(value ?? 0);
  return Number.isInteger(n) ? String(n) : n.toFixed(2);
}

// 领券：按 templateId 反查它属于哪个领券组，走 coupons 路由同款核心
// 逻辑（claimCouponGroupForUser），已领/领完/未到时间都如实失败。
async function claimCoupon(args, context) {
  const userId = context.userId;
  const templateId = String(args.templateId ?? '').trim();
  if (!userId) {
    return { ok: false, action: failedAction(context, 'coupon', '领取优惠券', '用户未登录，领不了券') };
  }
  const template = templateId
    ? await prisma.couponTemplate.findUnique({ where: { id: templateId } })
    : null;
  if (!template) {
    return { ok: false, action: failedAction(context, 'coupon', '领取优惠券', '这张券不存在') };
  }
  const groupKey = Object.keys(CLAIM_GROUPS).find((key) => CLAIM_GROUPS[key].includes(templateId));
  if (!groupKey) {
    return {
      ok: false,
      action: failedAction(context, 'coupon', `领取${template.title}`, '这张券不能直接领取'),
    };
  }
  const result = await claimCouponGroupForUser(userId, groupKey);
  if (!result.ok) {
    const reason =
      result.status === 409 && result.error === '已领取过'
        ? '这张券你已经领过了'
        : result.error;
    return {
      ok: false,
      action: failedAction(context, 'coupon', `领取${template.title}`, reason, { page: 'coupons' }),
    };
  }
  const first = result.coupons[0];
  const titles = result.coupons.map((c) => c.title).join('、');
  return {
    ok: true,
    action: makeAction(context, {
      type: 'coupon',
      title: `已领取优惠券`,
      detail: `${titles} · ${first?.condition ?? ''} · ${first?.expire ?? ''} 到期`,
      target: { page: 'coupons' },
    }),
    note: '券已真实领取到账，可以在正文里告诉用户。',
  };
}

// 加购：与购物车路由同一套写法（已有就累加数量，没有就新建，
// spec 存商品自身规格文字、没规格存空字符串）。
async function addToCart(args, context) {
  const userId = context.userId;
  const productId = String(args.productId ?? '').trim();
  const quantity = Math.max(1, Number.parseInt(String(args.quantity ?? 1), 10) || 1);
  const product = productId ? await prisma.product.findUnique({ where: { id: productId } }) : null;
  if (!product) {
    return { ok: false, action: failedAction(context, 'cart_add', '加入购物车', '商品不存在') };
  }
  // 找已有行用 findFirst 按（用户、商品、规格）匹配：购物车的唯一
  // 约束是三字段的，findUnique 的复合键名写成 userId_productId 会在
  // 运行时直接报错（购物车路由就踩过这个坑），findFirst 没这问题。
  const existing = await prisma.cartItem.findFirst({
    where: { userId, productId, spec: product.spec ?? '' },
  });
  let finalQty = quantity;
  if (existing) {
    finalQty = existing.quantity + quantity;
    await prisma.cartItem.update({ where: { id: existing.id }, data: { quantity: finalQty } });
  } else {
    await prisma.cartItem.create({
      data: { userId, productId, quantity, spec: product.spec ?? '' },
    });
  }
  return {
    ok: true,
    fullProduct: serializeProduct(product),
    action: makeAction(context, {
      type: 'cart_add',
      title: '已加入购物车',
      detail: `${product.name} ×${finalQty} · ¥${money(product.price)}`,
      target: { page: 'cart', productId },
    }),
  };
}

// 改购物车数量：quantity 是改完的目标值，0 = 移除。同一轮多次改量
// 由大脑循环合并成清单里的一行，这里只管把这一件办对。
async function updateCart(args, context) {
  const userId = context.userId;
  const productId = String(args.productId ?? '').trim();
  const quantity = Number.parseInt(String(args.quantity ?? -1), 10);
  const existing = productId
    ? await prisma.cartItem.findFirst({
        where: { userId, productId },
        include: { product: true },
        orderBy: { updatedAt: 'desc' },
      })
    : null;
  if (!existing) {
    return {
      ok: false,
      action: failedAction(context, 'cart_update', '调整购物车', '购物车里没有这件商品', { page: 'cart' }),
    };
  }
  if (!Number.isFinite(quantity) || quantity < 0) {
    return {
      ok: false,
      action: failedAction(context, 'cart_update', '调整购物车', '数量不对，没改成'),
    };
  }
  if (quantity === 0) {
    await prisma.cartItem.delete({ where: { id: existing.id } });
  } else {
    await prisma.cartItem.update({ where: { id: existing.id }, data: { quantity } });
  }
  return {
    ok: true,
    cartUpdateItem: { productId, name: existing.product.name, quantity },
    action: makeAction(context, {
      type: 'cart_update',
      title: '已调整购物车',
      detail:
        quantity === 0
          ? `${existing.product.name} 已移除`
          : `${existing.product.name} 改为 ${quantity} 件`,
      target: { page: 'cart', productId },
    }),
  };
}

// 收藏：已收藏过不算办成，如实记 failed（清单的信用靠这个）。
async function addFavorite(args, context) {
  const userId = context.userId;
  const productId = String(args.productId ?? '').trim();
  const product = productId ? await prisma.product.findUnique({ where: { id: productId } }) : null;
  if (!product) {
    return { ok: false, action: failedAction(context, 'favorite', '收藏商品', '商品不存在') };
  }
  const existing = await prisma.favorite.findUnique({
    where: { userId_productId: { userId, productId } },
  });
  if (existing) {
    return {
      ok: false,
      action: failedAction(context, 'favorite', `收藏${product.name}`, '这件你已经收藏过了', {
        page: 'favorites',
        productId,
      }),
    };
  }
  await prisma.favorite.create({ data: { userId, productId } });
  return {
    ok: true,
    action: makeAction(context, {
      type: 'favorite',
      title: '已收藏',
      detail: product.name,
      target: { page: 'favorites', productId },
    }),
  };
}

// 写订单备注：先存进本轮 turnState，本轮稍后 create_order 自动带上；
// 这一轮没生成订单，备注本身也是一条办成的事（结算时用户能接着用
// 的说法不要许诺过头——正文只说「记下了，下单时会带上」）。
async function setOrderNote(args, context) {
  const text = String(args.text ?? '').trim().slice(0, 200);
  if (!text) {
    return { ok: false, action: failedAction(context, 'order_note', '写订单备注', '备注是空的，没记上') };
  }
  turnStateOf(context).note = text;
  return {
    ok: true,
    action: makeAction(context, {
      type: 'order_note',
      title: '已写好订单备注',
      detail: `「${text}」`,
      target: { page: 'cart' },
    }),
  };
}

// 生成待付款订单：库存/地址/用券全部复用下单路由导出的同一套函数，
// 与用户自己下单一个口径。只生成到待付款为止，付款留用户在清单里
// 点「确认下单」（付款闸）。积分与趣玩币不在这里发——支付接口在
// 付款成功时会发，这里再发就重复计了。
async function createOrder(args, context) {
  const userId = context.userId;
  // 同一轮里模型重复调 create_order（真发生过：答完一遍又调一遍）：
  // 不许再生成第二笔订单，把第一笔的结果原样返回——action 的
  // id 不变，App 清单也不会多出一行（2026-11-23 全面自查修）。
  const turn = turnStateOf(context);
  if (turn.orderResult) return turn.orderResult;
  const items = Array.isArray(args.items) ? args.items : [];
  const built = await buildLineItemsFromRequest(
    items.map((item) => ({
      productId: String(item?.productId ?? ''),
      quantity: Math.max(1, Number(item?.quantity) || 1),
    })),
  );
  if (built.error) {
    return {
      ok: false,
      action: failedAction(context, 'order_create', '生成订单', built.error.message),
    };
  }
  const lineItems = built.lineItems;
  const subtotal = lineItems.reduce((sum, item) => sum + item.subtotal, 0);

  // 用券：指定了就按指定的验；没指定就把未用的券挨个试一遍，
  // 挑减得最多的一张——挑券的口径只认 resolveDiscount 的判定。
  let discount = 0;
  let usedTemplateId = null;
  const wanted = String(args.couponTemplateId ?? '').trim();
  if (wanted) {
    const resolved = await resolveDiscount(userId, wanted, subtotal, lineItems);
    if (resolved.error) {
      return {
        ok: false,
        action: failedAction(context, 'order_create', '生成订单', resolved.error.message),
      };
    }
    discount = resolved.discount ?? 0;
    usedTemplateId = resolved.templateId ?? null;
  } else {
    const unused = await prisma.userCoupon.findMany({
      where: { userId, used: false },
      include: { template: true },
    });
    for (const row of unused) {
      if (row.template.expireAt && new Date() > row.template.expireAt) continue;
      const resolved = await resolveDiscount(userId, row.templateId, subtotal, lineItems);
      if (!resolved.error && (resolved.discount ?? 0) > discount) {
        discount = resolved.discount ?? 0;
        usedTemplateId = resolved.templateId ?? null;
      }
    }
  }

  const address = await resolveAddress(userId, null);
  if (!address) {
    return {
      ok: false,
      action: failedAction(context, 'order_create', '生成订单', '还没有收货地址，先去加一个地址', {
        page: 'addresses',
      }),
    };
  }

  const freight = 0;
  const total = Math.max(0, subtotal - discount + freight);
  const remark =
    String(args.note ?? '').trim().slice(0, 200) || turnStateOf(context).note || null;
  const orderNo = generateOrderNo();
  const now = new Date();

  const order = await prisma.$transaction(async (tx) => {
    const created = await tx.order.create({
      data: {
        userId,
        orderNo,
        status: 'pending',
        subtotal,
        discount,
        total,
        addressName: address.name,
        addressPhone: address.phone,
        addressDetail: composeAddressDetailForOrder(address),
        couponTemplateId: usedTemplateId,
        paymentMethod: null,
        paymentStatus: 'pending',
        paidAt: null,
        freight,
        remark,
        items: {
          create: lineItems.map((item) => ({
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            spec: item.spec ?? '',
            imagePath: item.imagePath ?? null,
            unitPrice: item.unitPrice,
            subtotal: item.subtotal,
          })),
        },
      },
      include: { items: true },
    });

    // 订单里的商品从购物车里划掉（与下单路由的部分结算口径一致）
    await tx.cartItem.deleteMany({
      where: { userId, productId: { in: lineItems.map((item) => item.productId) } },
    });

    if (usedTemplateId) {
      await tx.userCoupon.update({
        where: { userId_templateId: { userId, templateId: usedTemplateId } },
        data: { used: true, usedAt: now, orderId: created.id },
      });
    }

    await tx.paymentTransaction.create({
      data: {
        orderId: created.id,
        userId,
        method: 'mock',
        transactionNo: `MOCK${now.getTime()}${created.orderNo}`,
        amount: total,
        status: 'pending',
        paidAt: null,
      },
    });

    await tx.notification.create({
      data: {
        userId,
        title: '待付款订单',
        body: `订单 ${orderNo} 待支付，请尽快完成付款`,
        type: 'order',
        targetType: 'order',
        targetId: created.id,
      },
    });

    // 导购推荐回填：买了小豆推荐过的商品就标 ordered（失败不挡下单）
    try {
      await tx.guideRecommendation.updateMany({
        where: {
          userId,
          productId: { in: lineItems.map((item) => item.productId) },
          outcome: { in: ['recommended', 'clicked'] },
        },
        data: { outcome: 'ordered' },
      });
    } catch {
      // 推荐记录是统计用途，写不上不回滚订单
    }

    return created;
  });

  const couponRow = usedTemplateId
    ? await prisma.couponTemplate.findUnique({ where: { id: usedTemplateId } })
    : null;
  const firstName = lineItems[0]?.name ?? '';
  const summary =
    lineItems.length > 1 ? `${firstName} 等 ${lineItems.length} 件` : firstName;
  const result = {
    ok: true,
    orderId: order.id,
    orderNo,
    total,
    action: makeAction(context, {
      type: 'order_create',
      title: '已生成待付款订单',
      detail: `订单 ${orderNo} · ${summary}`,
      status: 'pending',
      saved: discount,
      payment: {
        subtotal,
        discount,
        freight,
        total,
        ...(couponRow ? { couponTitle: couponRow.title } : {}),
      },
      target: { page: 'order', id: order.id, orderNo },
    }),
    note: '订单只是待付款，绝不能说已经付款或下单成功；把应付金额告诉用户，付款要他在清单卡里点「确认下单」。',
  };
  turn.orderResult = result;
  return result;
}

// 拼收货地址展示文字：与下单路由 composeAddressDetail 同口径
// （新地址拆了省市区，订单快照仍存一整段文字）。
function composeAddressDetailForOrder(address) {
  if (!address) return null;
  const parts = [address.province, address.city, address.district].filter(Boolean).join('');
  const detail = address.detail ?? '';
  if (parts && detail && !detail.startsWith(parts)) return parts + detail;
  return detail || parts || null;
}

// 纯导购保底专用的工具子集：只有查和说，没有办事工具。
// 保底路线不发 actions 事件、也没有跨调用共享的 turnState，
// 办事工具在它手里会变成「办了不记账、备注还丢失」，不如
// 压根不给它（2026-11-23 全面自查修）。
const GUIDE_TOOL_NAMES = new Set([
  'search_products',
  'draw_star_cards',
  'get_product_detail',
  'get_promotions',
  'get_user_context',
  'get_weather',
  'web_search',
]);
export const XIAODOU_GUIDE_TOOLS = XIAODOU_TOOLS.filter((tool) =>
  GUIDE_TOOL_NAMES.has(tool.function.name),
);

// 工具名 → 人话标签：日志里打人话，hx 一眼看懂小豆刚办了什么事。
const TOOL_LABELS = {
  search_products: '查商品',
  draw_star_cards: '亮牌抽卡',
  get_product_detail: '看商品详情',
  get_promotions: '查优惠',
  get_user_context: '读用户档案',
  propose_add_to_cart: '提议加购',
  claim_coupon: '领优惠券',
  add_to_cart: '加入购物车',
  update_cart: '调整购物车',
  add_favorite: '收藏商品',
  set_order_note: '写订单备注',
  create_order: '生成订单',
  get_weather: '查天气',
  web_search: '联网搜索',
};

// 工具统一入口：所有工具都从这里过，所以日志也只在这里打一处——
// 小豆每办一件事留一行中文；没办成打警告并带上原因；抛错打报错后
// 原样往上抛（不改变原来的失败处理）。
export async function executeXiaodouTool(name, rawArgs, context = {}) {
  const label = TOOL_LABELS[name] ?? name;
  let result;
  try {
    result = await dispatchXiaodouTool(name, rawArgs, context);
  } catch (error) {
    log.error('小豆', `办事出错：${label}`, error);
    throw error;
  }
  if (result && result.ok === false) {
    log.warn('小豆', `办事没成：${label}——${result.error ?? '未知原因'}`);
  } else {
    log.info('小豆', `办了一件事：${label}`);
  }
  return result;
}

async function dispatchXiaodouTool(name, rawArgs, context = {}) {
  const args = parseArgs(rawArgs);
  if (name === 'search_products') return searchProducts(args);
  if (name === 'draw_star_cards') return drawStarCards(args);
  if (name === 'get_product_detail') return getProductDetail(args);
  if (name === 'get_promotions') return getPromotions();
  if (name === 'get_user_context') return getUserContext(context.userId);
  if (name === 'propose_add_to_cart') return proposeAddToCart(args);
  if (name === 'claim_coupon') return claimCoupon(args, context);
  if (name === 'add_to_cart') return addToCart(args, context);
  if (name === 'update_cart') return updateCart(args, context);
  if (name === 'add_favorite') return addFavorite(args, context);
  if (name === 'set_order_note') return setOrderNote(args, context);
  if (name === 'create_order') return createOrder(args, context);
  if (name === 'get_weather') return getWeather(args, context);
  if (name === 'web_search') return webSearch(args, context);
  return { ok: false, error: `未知工具 ${name}` };
}

export function toolResultForModel(name, result) {
  if (name === 'search_products' || name === 'draw_star_cards') {
    const { fullProducts, ...rest } = result;
    return JSON.stringify(rest);
  }
  if (name === 'get_product_detail' || name === 'propose_add_to_cart' || name === 'add_to_cart') {
    const { fullProduct, ...rest } = result;
    return JSON.stringify(rest);
  }
  return JSON.stringify(result);
}
