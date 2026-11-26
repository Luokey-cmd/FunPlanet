import { prisma } from '../db.js';
import { log } from './log.js';
import { serializeProduct } from './product.js';
import { buildWeatherContext } from './weather.js';
import { streamChatEvents } from './openai-compatible.js';
import { CLAIM_GROUPS } from '../routes/coupons.js';
import { ensureProfileFresh, isMemberCouponClaimedThisMonth } from './daily-tasks.js';
import {
  buildLineItemsFromRequest,
  cancelOrderForUser,
  createAfterSaleForUser,
  resolveAddress,
  resolveDiscount,
} from '../routes/orders.js';
import { generateOrderNo } from './order.js';
import { resolvePromotionDiscount } from './promotions.js';

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
            enum: ['sales', 'price_asc', 'price_desc', 'rating', 'positive_rate', 'reviews'],
            description: '默认按销量；用户看重口碑传 positive_rate（好评率）或 rating，看重省钱传 price_asc',
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
            enum: ['sales', 'price_asc', 'price_desc', 'rating', 'positive_rate', 'reviews'],
            description: '默认按销量；用户看重口碑传 positive_rate（好评率）或 rating，看重省钱传 price_asc',
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
      name: 'list_claimable_coupons',
      description:
        '列出用户现在能领的优惠券：用户说领券、找优惠、有什么券能领时调用。只列清单——结果会做成带「领取」按钮的卡片给用户自己点，你不要替他领，也不要说已经帮他领了。',
      parameters: {
        type: 'object',
        properties: {},
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
  {
    type: 'function',
    function: {
      name: 'get_my_orders',
      description:
        '查用户自己的订单（最近 5 笔：状态、金额、买了什么、快递公司与单号）。用户问「我的订单」「快递到哪了」「买的东西发货没」时调用；订单只信这个工具，不要编。',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'cancel_order',
      description:
        '用户明确说要取消某一笔订单时调用：真的取消（待付款和已付款未发货的能取消，已付款的款会原路退回）。orderId 用 get_my_orders 返回的 id，先查再取消，别猜。取消是大事：用户没明说取消哪一笔时，先问清楚，不要自己挑一笔取消。',
      parameters: {
        type: 'object',
        properties: {
          orderId: { type: 'string', description: '订单 id（get_my_orders 返回的 id）' },
          reason: { type: 'string', description: '取消原因，用户说了才填' },
        },
        required: ['orderId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'apply_after_sale',
      description:
        '用户要给某一笔已付款/已发货/已完成的订单申请售后（退款、退货）时调用：真的提交售后申请等后台处理。orderId 用 get_my_orders 返回的 id；reason 必填，用户没说原因先问一句，别替他编。',
      parameters: {
        type: 'object',
        properties: {
          orderId: { type: 'string', description: '订单 id（get_my_orders 返回的 id）' },
          type: {
            type: 'string',
            description: 'refund 仅退款 / return 退货退款，用户没明说默认 refund',
          },
          reason: { type: 'string', description: '售后原因，用户亲口说的' },
          description: { type: 'string', description: '补充说明，可空' },
        },
        required: ['orderId', 'reason'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'suggest_options',
      description:
        '你这一轮要向用户提问时，同时调用这个工具，把用户最可能点的短回答交出来，界面会把它们挂成按钮给他点选（省得打字）。两种给法：①普通一问：用 options 给 3~4 个短选项，点一个就发送。②分组问法（挑礼物专用，见导购规则）：用 groups 给 2 组带标签的选项，mode=each 表示每组必选一个、都选完点「选好了」才发送（送给谁+预算合并问）；mode=multi 表示两组一共选 1~2 个、每组最多选 1 个（类型+系列那一问），anyOption 给一个可单独提交的兜底项（如「你帮我定」）。规矩：只有提问的那一轮才调用，陈述、亮牌、办事的轮次绝不调用；选项写成用户会说出口的话；结合他刚说的话和档案给，别给万金油选项。例外：问「想要哪个系列/角色」时，用 options 把系统提示里「店内系列清单」中该品类下的系列一次给全（可以超过 4 个，服务端只放行清单里真实存在的系列名，编的会被截掉）。',
      parameters: {
        type: 'object',
        properties: {
          options: {
            type: 'array',
            description: '普通一问的 3~4 个短选项（与 groups 二选一）',
            items: { type: 'string' },
          },
          groups: {
            type: 'array',
            description: '分组问法：2 组选项，每组带一个标签（如「送给谁」「预算」）',
            items: {
              type: 'object',
              properties: {
                label: { type: 'string', description: '组标签，如「送给谁」' },
                options: { type: 'array', items: { type: 'string' } },
              },
              required: ['label', 'options'],
            },
          },
          mode: {
            type: 'string',
            description: '分组问法才用：each=每组必选一个；multi=两组共选 1~2 个、每组最多 1 个',
            enum: ['each', 'multi'],
          },
          anyOption: {
            type: 'string',
            description: '分组问法可选：一个能单独点选直接提交的兜底项，如「你帮我定」',
          },
        },
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
  if (sort === 'positive_rate') return [{ positiveRate: 'desc' }, { rating: 'desc' }, { id: 'asc' }];
  if (sort === 'reviews') return [{ reviewCount: 'desc' }, { sales: 'desc' }, { id: 'asc' }];
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
    // 数据丰富化：口碑与可比参数一起给模型，比对时有据可依，不用现编
    rating: full.rating,
    reviewCount: full.reviewCount,
    positiveRate: full.positiveRate,
    favoriteCount: full.favoriteCount,
    stock: full.stock,
    rarity: full.rarity,
    sellingPoints: full.sellingPoints,
    suitableFor: full.suitableFor,
    attributes: full.attributes,
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
          fullProducts: loose.map((p) => serializeProduct(p)),
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
    fullProducts: rows.map((p) => serializeProduct(p)),
    note: rows.length === 0 ? '没有更多匹配商品，请换关键词或放宽预算，不要编造商品。' : undefined,
  };
}

// 给三张牌各算一个「判断标签」：格式「短标签，证据句」，App 按第一个
// 逗号拆——小卡顶部缎带只挂短标签，翻开的详细卡显示整句。
// 标签只能来自真实数据的同批比对，一共 8 个候选维度：
//   口碑最好（评分，评分同分时评价条数多者胜）／好评率最高／卖得最火（销量）／
//   收藏最多／性价比最高（评分×好评率÷价格）／价格最低／折扣最大（直降比例）／
//   最新上架（编号最大）。
// 分配按「赢的幅度」贪心：每个维度算第一名赢第二名的相对差，幅度大的
// 断言先落位；一张牌只占一个标签、一个标签只给一张牌，保证三张牌的
// 标签互不重复、且都是各自最有说服力的那条。并列第一的维度不发标签
// （不能两张都叫最高）。哪条都没赢的牌退回「小豆精选，事实行」，
// 不硬凑最高级。数字全在这里算死，不许模型自己编（导购硬规矩）。
// 输入：本批商品（通常 3 件）；输出：Map<商品 id, 标签句>。
function computeTraits(picked) {
  const traits = new Map();
  if (picked.length === 0) return traits;
  const num = (v) => Number(v ?? 0) || 0;
  const idNum = (id) => parseInt(String(id).replace(/[^0-9]/g, ''), 10) || 0;
  const prices = picked.map((x) => num(x.price));
  const priceSpread = Math.max(...prices) - Math.min(...prices);
  // 性价比：口碑综合（评分 × 好评率）除以价格，花得少、口碑还硬的胜出；
  // 好评率缺失时按 0.9 中性兜底，不让缺字段的商品直接出局。
  const valueOf = (x) => {
    const price = num(x.price);
    if (price <= 0) return 0;
    const positive = num(x.positiveRate);
    return (num(x.rating) * (positive > 0 ? positive / 100 : 0.9)) / price;
  };
  const discountOf = (x) => {
    const op = num(x.originalPrice);
    const price = num(x.price);
    return op > price && price > 0 ? (op - price) / op : 0;
  };
  const dims = [
    {
      key: 'rating',
      // 评分只有 4.6~4.9 几档、同分常见：同分时评价条数多者胜（样本大更可信）。
      value: (x) => num(x.rating) * 100000 + Math.min(num(x.reviewCount), 99999),
      ok: (best) => best > 0,
      text: (x) => `口碑最好，评分 ${num(x.rating)} · ${num(x.reviewCount)} 条评价`,
    },
    {
      key: 'positive',
      value: (x) => num(x.positiveRate) * 1000 + num(x.rating),
      ok: (best) => best >= 90 * 1000,
      text: (x) => `好评率最高，${num(x.positiveRate)}% 的买家给了好评`,
    },
    {
      key: 'sales',
      value: (x) => num(x.sales),
      ok: (best) => best > 0,
      text: (x) => `卖得最火，已售 ${num(x.sales)} 件`,
    },
    {
      key: 'favorite',
      value: (x) => num(x.favoriteCount),
      ok: (best) => best > 0,
      text: (x) => `收藏最多，${num(x.favoriteCount)} 人收藏`,
    },
    {
      key: 'value',
      value: valueOf,
      ok: () => true,
      text: (x) => `性价比最高，评分 ${num(x.rating)} · 好评率 ${num(x.positiveRate)}%，只要 ¥${num(x.price)}`,
    },
    {
      key: 'price',
      value: (x) => -num(x.price),
      ok: () => priceSpread > 0,
      text: () => `价格最低，比最贵的省 ¥${Math.round(priceSpread)}`,
    },
    {
      key: 'discount',
      value: discountOf,
      ok: (best) => best >= 0.15,
      text: (x) => `折扣最大，直降 ¥${Math.round(num(x.originalPrice) - num(x.price))}`,
    },
    {
      key: 'newest',
      value: (x) => idNum(x.id),
      ok: () => true,
      text: () => '最新上架，本批三件里最新上架',
    },
  ];
  const claims = [];
  dims.forEach((dim, dimIdx) => {
    const vals = picked.map((x) => dim.value(x));
    const best = Math.max(...vals);
    if (!dim.ok(best)) return;
    const winnerIdx = vals.indexOf(best);
    if (vals.filter((v) => v === best).length !== 1) return; // 并列第一不发
    const runnerUp = Math.max(...vals.filter((_, i) => i !== winnerIdx), 0);
    const margin = Math.abs(best) > 0 ? (best - runnerUp) / Math.abs(best) : 0;
    claims.push({ item: picked[winnerIdx], dim, dimIdx, margin });
  });
  // 幅度大的先落位；同幅度按维度顺序（口碑、好评、销量在前）裁决。
  claims.sort((a, b) => b.margin - a.margin || a.dimIdx - b.dimIdx);
  const usedItems = new Set();
  const usedDims = new Set();
  for (const claim of claims) {
    if (usedItems.has(claim.item.id) || usedDims.has(claim.dim.key)) continue;
    usedItems.add(claim.item.id);
    usedDims.add(claim.dim.key);
    traits.set(claim.item.id, claim.dim.text(claim.item));
  }
  for (const item of picked) {
    if (!traits.has(item.id)) {
      traits.set(item.id, `小豆精选，¥${num(item.price)} · 已售 ${num(item.sales)} 件 · 评分 ${num(item.rating)}`);
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
    sort: ['price_asc', 'price_desc', 'rating', 'positive_rate', 'reviews'].includes(args.sort) ? args.sort : 'sales',
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
    note: picked.length >= 3 ? '三张牌已明着亮在用户面前。每张牌的 trait 是系统按真实数据算好的特点句，只活在牌面上：你的正文不要复述商品名、价格和特点句，只写一句引出加一句建议，指代用位置（第一张/中间那张/最后一张）。' : '货架这一层不足三件，按实际张数推荐。',
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

// 列可领券（2026-11-26 hx 定）：小豆只列清单、不代领——把每个领券组
// 的状态（可领/已领/需会员/领完）算好做成卡片下发，App 在每行后面挂
// 「领取」按钮，用户点哪张领哪张。状态口径与领券核心
// claimCouponGroupForUser 保持一致（会员门槛、月券跨月、新人终身
// 一次、中心券看持有），那边改规则时这边要跟着对。
// 输入：context.userId。输出：{ ok, couponChoices, claimableCount, note }。
async function listClaimableCoupons(context) {
  const userId = context.userId;
  if (!userId) {
    return { ok: false, error: '用户未登录，领不了券' };
  }
  const profile = await ensureProfileFresh(userId);
  const groupOrder = ['newcomer', 'center', 'center_200', 'center_300', 'member_monthly'];
  const allIds = groupOrder.flatMap((key) => CLAIM_GROUPS[key] ?? []);
  const [templates, owned] = await Promise.all([
    prisma.couponTemplate.findMany({ where: { id: { in: allIds } } }),
    prisma.userCoupon.findMany({ where: { userId }, select: { templateId: true } }),
  ]);
  const byId = new Map(templates.map((t) => [t.id, t]));
  const ownedSet = new Set(owned.map((r) => r.templateId));
  const now = new Date();
  const expireText = (t) => (t?.expireAt ? t.expireAt.toISOString().slice(0, 10) : '');
  const choices = [];
  for (const group of groupOrder) {
    const ids = CLAIM_GROUPS[group] ?? [];
    const rows = ids.map((id) => byId.get(id)).filter(Boolean);
    if (rows.length !== ids.length || rows.length === 0) continue;
    const first = rows[0];
    let status = 'claimable';
    let statusText = '';
    if (group === 'member_monthly' && (profile?.vipLevel ?? 1) < 2) {
      status = 'member';
      statusText = '开通 VIP2 后可领';
    } else if (
      group === 'member_monthly'
        ? isMemberCouponClaimedThisMonth(profile)
        : group === 'newcomer'
          ? Boolean(profile?.newcomerClaimed)
          : ownedSet.has(ids[0])
    ) {
      status = 'claimed';
      statusText = '已领取';
    } else {
      const blocked = rows.find(
        (t) =>
          (t.claimStartAt && now < t.claimStartAt) ||
          (t.expireAt && now > t.expireAt) ||
          (t.totalQuantity != null && t.issuedCount >= t.totalQuantity),
      );
      if (blocked) {
        status = 'unavailable';
        statusText =
          blocked.claimStartAt && now < blocked.claimStartAt
            ? '尚未开始领取'
            : blocked.expireAt && now > blocked.expireAt
              ? '已过期'
              : '已领完';
      }
    }
    choices.push({
      group,
      title: group === 'newcomer' ? '新人券包' : first.title,
      detail:
        group === 'newcomer'
          ? `${rows.map((t) => t.title).join('、')} · ${expireText(first)} 到期`
          : `${first.condition} · ${expireText(first)} 到期`,
      status,
      statusText,
    });
  }
  // 可领的排最前，其次要开会员的，最后已领/不可领（同档保持领券中心顺序）
  const rank = { claimable: 0, member: 1, claimed: 2, unavailable: 3 };
  choices.sort((a, b) => rank[a.status] - rank[b.status]);
  const claimableCount = choices.filter((c) => c.status === 'claimable').length;
  return {
    ok: true,
    couponChoices: choices,
    claimableCount,
    note: '清单已做成带「领取」按钮的卡片发给用户了。规矩：你只列清单、正文简短点名最值得领的一两张，不要替他领、不要说「已帮你领」，点不点由他自己。',
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
  // 复查：写完回读购物车这一行，清单里的数量以库里真实存下的为准。
  const savedRow = await prisma.cartItem.findFirst({
    where: { userId, productId, spec: product.spec ?? '' },
  });
  const shownQty = savedRow?.quantity ?? finalQty;
  return {
    ok: true,
    fullProduct: serializeProduct(product),
    action: makeAction(context, {
      type: 'cart_add',
      title: '已加入购物车',
      detail: `${product.name} ×${shownQty} · ¥${money(product.price)}`,
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
  // 满减与下单路由同一口径（utils/promotions.js），小豆代下单也享活动
  const promotion = await resolvePromotionDiscount(subtotal);
  // 会员 95 折与下单路由同口径：VIP2 起，券与满减后的商品款再打 95 折
  const buyerProfile = await prisma.userProfile.findUnique({
    where: { userId },
    select: { vipLevel: true },
  });
  const memberBase = Math.max(0, subtotal - discount - promotion.amount);
  const memberDiscount =
    (buyerProfile?.vipLevel ?? 1) >= 2 ? Math.round(memberBase * 0.05 * 100) / 100 : 0;
  const total = Math.max(0, memberBase - memberDiscount + freight);
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
        promotionDiscount: promotion.amount,
        promotionName: promotion.name,
        memberDiscount,
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
  // 复查：订单落库后回读一遍，汇报的金额以数据库里真实存下的为准——
  // 办完不复查是开环；万一对不上，按库里的数改口并留一条警告日志。
  let verifiedTotal = total;
  let verifiedDiscount = discount;
  try {
    const saved = await prisma.order.findUnique({
      where: { id: order.id },
      select: { total: true, discount: true },
    });
    if (saved) {
      verifiedTotal = Number(saved.total);
      verifiedDiscount = Number(saved.discount);
      if (
        Math.abs(verifiedTotal - total) > 0.001 ||
        Math.abs(verifiedDiscount - discount) > 0.001
      ) {
        log.warn(
          '小豆',
          `建单复查金额对不上：订单 ${orderNo} 本地算应付 ¥${total}，库里是 ¥${verifiedTotal}，按库里的汇报`,
        );
      }
    }
  } catch {
    // 复查读不到不挡汇报，用本地算的数（与改造前的行为一致）
  }
  const firstName = lineItems[0]?.name ?? '';
  const summary =
    lineItems.length > 1 ? `${firstName} 等 ${lineItems.length} 件` : firstName;
  const result = {
    ok: true,
    orderId: order.id,
    orderNo,
    total: verifiedTotal,
    action: makeAction(context, {
      type: 'order_create',
      title: '已生成待付款订单',
      detail: `订单 ${orderNo} · ${summary}`,
      status: 'pending',
      saved: discount,
      payment: {
        subtotal,
        discount: verifiedDiscount,
        freight,
        total: verifiedTotal,
        ...(couponRow ? { couponTitle: couponRow.title } : {}),
      },
      target: { page: 'order', id: order.id, orderNo },
    }),
    note: '订单只是待付款，绝不能说已经付款或下单成功；把应付金额告诉用户，付款要他在清单卡里点「确认下单」。金额已回读数据库复核过，照 total 说。',
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
  'get_my_orders',
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
  list_claimable_coupons: '列出可领券',
  add_to_cart: '加入购物车',
  update_cart: '调整购物车',
  add_favorite: '收藏商品',
  set_order_note: '写订单备注',
  create_order: '生成订单',
  get_my_orders: '查我的订单',
  cancel_order: '取消订单',
  apply_after_sale: '申请售后',
  suggest_options: '给出选项',
  get_weather: '查天气',
  web_search: '联网搜索',
};

// 订单状态的人话说法：给模型和清单看，别把 pending 这种内部词漏出去。
const ORDER_STATUS_TEXT = {
  pending: '待付款',
  paid: '待发货',
  shipping: '已发货，运输中',
  completed: '已完成',
  cancelled: '已取消',
};

// 查我的订单：只读工具，不记办事清单。返回最近 5 笔的骨架信息，
// 物流只报库里真有的快递公司和单号，没发货就没单号、如实说。
async function getMyOrders(args, context) {
  const userId = context.userId;
  if (!userId) return { ok: false, error: '用户未登录，查不了订单' };
  const rows = await prisma.order.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    take: 5,
    include: { items: { select: { name: true, quantity: true } } },
  });
  const orders = rows.map((row) => ({
    id: row.id,
    orderNo: row.orderNo,
    status: ORDER_STATUS_TEXT[row.status] ?? row.status,
    total: money(row.total),
    items: row.items.map((item) => `${item.name} ×${item.quantity}`).join('、'),
    createdAt: row.createdAt.toISOString().slice(0, 16).replace('T', ' '),
    ...(row.shippingCompany ? { shippingCompany: row.shippingCompany } : {}),
    ...(row.trackingNo ? { trackingNo: row.trackingNo } : {}),
  }));
  return {
    ok: true,
    orders,
    note: orders.length
      ? '这就是他最近的订单，状态和物流只照这里说；要取消或售后，用对应订单的 id 调工具。'
      : '他还没有任何订单，如实告诉他。',
  };
}

// 取消订单：走订单路由抽出的同一份核心逻辑（cancelOrderForUser），
// 回补库存、退款标记的口径与用户自己在订单页取消完全一致。
async function cancelOrder(args, context) {
  const userId = context.userId;
  const orderId = String(args.orderId ?? '').trim();
  if (!userId) {
    return { ok: false, action: failedAction(context, 'order_cancel', '取消订单', '用户未登录，取消不了') };
  }
  if (!orderId) {
    return { ok: false, action: failedAction(context, 'order_cancel', '取消订单', '没指明要取消哪一笔订单') };
  }
  const result = await cancelOrderForUser(userId, orderId, args.reason);
  if (!result.ok) {
    return {
      ok: false,
      action: failedAction(context, 'order_cancel', '取消订单', result.error, { page: 'order' }),
    };
  }
  const order = result.order;
  return {
    ok: true,
    action: makeAction(context, {
      type: 'order_cancel',
      title: '已取消订单',
      detail: result.wasPaid
        ? `订单 ${order.orderNo} · 已付款，款项已原路退回（模拟支付即时到账）`
        : `订单 ${order.orderNo} · 待付款订单已作废`,
      target: { page: 'order', id: order.id, orderNo: order.orderNo },
    }),
    note: '订单已真实取消，可以在正文里告诉用户。',
  };
}

// 申请售后：同样走订单路由抽出的核心逻辑（createAfterSaleForUser），
// 状态可申请范围、重复申请拦截与订单页里自己申请完全一致。
async function applyAfterSale(args, context) {
  const userId = context.userId;
  const orderId = String(args.orderId ?? '').trim();
  if (!userId) {
    return { ok: false, action: failedAction(context, 'after_sale', '申请售后', '用户未登录，申请不了') };
  }
  if (!orderId) {
    return { ok: false, action: failedAction(context, 'after_sale', '申请售后', '没指明要给哪一笔订单申请售后') };
  }
  const result = await createAfterSaleForUser(userId, orderId, {
    type: args.type,
    reason: args.reason,
    description: args.description,
  });
  if (!result.ok) {
    return {
      ok: false,
      action: failedAction(context, 'after_sale', '申请售后', result.error, { page: 'order' }),
    };
  }
  const order = result.order;
  return {
    ok: true,
    action: makeAction(context, {
      type: 'after_sale',
      title: '已提交售后申请',
      detail: `订单 ${order.orderNo} · ${result.request.type === 'return' ? '退货退款' : '仅退款'} · 等待处理`,
      target: { page: 'order', id: order.id, orderNo: order.orderNo },
    }),
    note: '售后申请已真实提交，可以在正文里告诉用户等后台处理。',
  };
}

// ── 店内系列目录（2026-11-26 hx 选 A 方案）──────────────────
// 病根：小豆被问「想要哪个系列」时没人给它全店清单，只能凭翻到的
// 几件商品临场编，还被单组选项上限 4 个截断——店里光谷子就有 20+
// 个系列/角色，它只给了 4 个、还漏了原创 8 系列（hx 截图抓到）。
// 解法：服务端按商品数据实时汇总一份目录（系列列 → 描述《》→
// 名称前缀 → 英文角色名 → 饼干等关键词，逐级兜底），一式两用：
// ①注入小豆的系统提示，它问系列时照单给全；②suggest_options 清洗
// 时做白名单——超过 4 个的选项，只有名字在目录里才放行（上限 10）。
// 目录带 10 分钟缓存，查库失败就当没有（选项退回上限 4，不许崩）。
const SERIES_DIRECTORY_TTL_MS = 10 * 60 * 1000;
let _seriesDirectoryCache = null;
let _seriesDirectoryBuiltAt = 0;

function seriesGroupOf(product, knownSeries) {
  const fromColumn = String(product.series ?? '').trim();
  if (fromColumn) return fromColumn;
  const fromDesc = String(product.description ?? '').match(/《([^》]{2,14})》/);
  if (fromDesc) return fromDesc[1];
  const name = String(product.name ?? '');
  for (const series of knownSeries) {
    if (series && name.startsWith(series)) return series;
  }
  const english = name.match(/^([A-Za-z]{3,})/);
  if (english) return english[1].toUpperCase();
  if (name.includes('饼干')) return '饼干人系列';
  const stripped = name.replace(/【[^】]*】/g, '');
  const seriesSuffix = stripped.match(/^(.{2,6}?)系列/);
  if (seriesSuffix) return `${seriesSuffix[1]}系列`;
  const formPrefix = stripped.match(/^(.{3,6}?)(徽章|立牌|挂件|色纸|周边|套装|礼盒)/);
  if (formPrefix) return formPrefix[1];
  return null;
}

export async function getSeriesDirectory() {
  if (_seriesDirectoryCache && Date.now() - _seriesDirectoryBuiltAt < SERIES_DIRECTORY_TTL_MS) {
    return _seriesDirectoryCache;
  }
  try {
    const products = await prisma.product.findMany({
      select: { name: true, description: true, series: true, majorCategory: true },
    });
    const knownSeries = new Set();
    for (const product of products) {
      const fromColumn = String(product.series ?? '').trim();
      if (fromColumn) knownSeries.add(fromColumn);
      const fromDesc = String(product.description ?? '').match(/《([^》]{2,14})》/);
      if (fromDesc) knownSeries.add(fromDesc[1]);
    }
    // names：全店系列/角色名集合（白名单用，英文名统一大写比对另存一份）
    const names = new Set();
    const byCategory = new Map();
    for (const product of products) {
      const group = seriesGroupOf(product, knownSeries);
      if (!group) continue;
      names.add(group);
      const category = String(product.majorCategory ?? '').trim() || '其他';
      if (!byCategory.has(category)) byCategory.set(category, new Map());
      const bucket = byCategory.get(category);
      bucket.set(group, (bucket.get(group) ?? 0) + 1);
    }
    // text：给小豆看的紧凑清单，按大类一行、系列按件数从多到少，
    // 每类最多 14 个（再多它也念不完，用户更看不完）。
    const lines = [];
    for (const category of MAJOR_CATEGORIES) {
      const bucket = byCategory.get(category);
      if (!bucket || bucket.size === 0) continue;
      const entries = [...bucket.entries()].sort((a, b) => b[1] - a[1]).slice(0, 14);
      lines.push(`${category}：${entries.map(([name, count]) => `${name}(${count}件)`).join('、')}`);
    }
    _seriesDirectoryCache = { names, text: lines.join('\n') };
    _seriesDirectoryBuiltAt = Date.now();
    return _seriesDirectoryCache;
  } catch (error) {
    log.warn('小豆', '系列目录生成失败，本轮先不带清单', error);
    return { names: new Set(), text: '' };
  }
}

// 给出选项：模型提问时自带短选项，服务端只做清洗（去空、去重、
// 截断、限量），不记办事清单、不算办事。清洗后不足 2 个当没给，
// 外层会走事后补生成的安全网。
// 2026-11-26 分组问法（hx 定挑礼物问法）：groups 给了就走分组清洗——
// mode=each 每组必选一个（送给谁+预算合并问）；mode=multi 两组共选
// 1~2 个、每组最多 1 个（类型+系列）；anyOption 是单独提交的兜底项。
function cleanOptionText(raw, seen) {
  const text = String(raw ?? '').trim().replace(/\s+/g, ' ');
  if (!text || text.length > 12 || seen.has(text)) return null;
  seen.add(text);
  return text;
}

async function suggestOptions(args) {
  if (Array.isArray(args.groups) && args.groups.length > 0) {
    const seen = new Set();
    const groups = [];
    for (const rawGroup of args.groups.slice(0, 3)) {
      const label = String(rawGroup?.label ?? '').trim().slice(0, 6);
      const options = [];
      for (const raw of Array.isArray(rawGroup?.options) ? rawGroup.options : []) {
        const text = cleanOptionText(raw, seen);
        if (text) options.push(text);
        if (options.length >= 10) break;
      }
      if (label && options.length >= 2) groups.push({ label, options });
    }
    const mode = args.mode === 'multi' ? 'multi' : 'each';
    const anyText = args.anyOption ? cleanOptionText(args.anyOption, seen) : null;
    if (groups.length < 2) {
      return { ok: false, quiet: true, error: '分组选项不足两组，已忽略' };
    }
    return {
      ok: true,
      quiet: true,
      suggestedOptionSet: { mode, groups, ...(anyText ? { anyOption: anyText } : {}) },
      note:
        mode === 'each'
          ? '分组选项已收下：每组选一个、都选完他点「选好了」会把两个答案一起发给你；正文里把两个问题都问清楚，不要把选项再念一遍。'
          : '分组选项已收下：他可以选 1~2 个（每组最多一个）再点提交，也可以直接点兜底项；正文里把问题问清楚，不要把选项再念一遍。',
    };
  }
  const seen = new Set();
  const cleaned = [];
  for (const raw of Array.isArray(args.options) ? args.options : []) {
    const text = cleanOptionText(raw, seen);
    if (text) cleaned.push(text);
  }
  // 常规问题仍最多 4 个；超过 4 个的部分只有系列目录里的真系列/角色
  // 名才放行（问系列时一次给全），上限 10——目录外的词照样截断，
  // 防止普通问题被模型塞成长串（2026-11-26 hx 选 A 方案）。
  const options = cleaned.slice(0, 4);
  if (cleaned.length > 4) {
    const { names } = await getSeriesDirectory();
    for (const text of cleaned.slice(4)) {
      if (options.length >= 10) break;
      if (names.has(text) || names.has(text.toUpperCase())) options.push(text);
    }
  }
  if (options.length < 2) {
    return { ok: false, quiet: true, error: '选项不足两个，已忽略' };
  }
  return {
    ok: true,
    quiet: true,
    suggestedOptions: options,
    note: '选项已收下，会挂在你这句问话下面给他点；正文里只管把问题问清楚，不要把选项再念一遍。',
  };
}

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
  } else if (!result?.quiet) {
    // quiet 的工具（如给出选项）不是办事，不打「办了一件事」免得日志误导
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
  if (name === 'list_claimable_coupons') return listClaimableCoupons(context);
  if (name === 'add_to_cart') return addToCart(args, context);
  if (name === 'update_cart') return updateCart(args, context);
  if (name === 'add_favorite') return addFavorite(args, context);
  if (name === 'set_order_note') return setOrderNote(args, context);
  if (name === 'create_order') return createOrder(args, context);
  if (name === 'get_my_orders') return getMyOrders(args, context);
  if (name === 'cancel_order') return cancelOrder(args, context);
  if (name === 'apply_after_sale') return applyAfterSale(args, context);
  if (name === 'suggest_options') return suggestOptions(args);
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
