import { prisma } from '../db.js';
import { serializeProduct } from './product.js';

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
            enum: ['sales', 'price_asc', 'price_desc'],
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
      name: 'propose_add_to_cart',
      description:
        '用户明确说加入购物车或帮我加购某件商品时调用。不会真正加购，只发起确认，请用户在界面点确认。',
      parameters: {
        type: 'object',
        properties: {
          productId: { type: 'string' },
        },
        required: ['productId'],
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

async function drawStarCards(args) {
  const result = await searchProducts(args, { take: 12 });
  const list = result.fullProducts ?? [];
  if (list.length === 0) {
    return { ...result, cards: [], fate: true };
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
  const cards = picked.map((item, index) => ({
    role: roles[index],
    id: item.id,
    name: item.name,
    majorCategory: item.majorCategory,
    price: item.price,
    tag: item.tag,
    sales: item.sales,
  }));

  return {
    ok: true,
    fate: picked.length >= 2,
    totalCount: result.totalCount,
    cards,
    fullProducts: picked,
    roles: picked.map((_, index) => roles[index]),
    note: picked.length >= 3 ? '三张星牌：本命、遇见、余韵。请用两三句星愿笺引出，不要报库存编造。' : '货架这一层不足三件，按实际张数推荐。',
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

export async function executeXiaodouTool(name, rawArgs, context = {}) {
  const args = parseArgs(rawArgs);
  if (name === 'search_products') return searchProducts(args);
  if (name === 'draw_star_cards') return drawStarCards(args);
  if (name === 'get_product_detail') return getProductDetail(args);
  if (name === 'get_promotions') return getPromotions();
  if (name === 'get_user_context') return getUserContext(context.userId);
  if (name === 'propose_add_to_cart') return proposeAddToCart(args);
  return { ok: false, error: `未知工具 ${name}` };
}

export function toolResultForModel(name, result) {
  if (name === 'search_products' || name === 'draw_star_cards') {
    const { fullProducts, ...rest } = result;
    return JSON.stringify(rest);
  }
  if (name === 'get_product_detail' || name === 'propose_add_to_cart') {
    const { fullProduct, ...rest } = result;
    return JSON.stringify(rest);
  }
  return JSON.stringify(result);
}
