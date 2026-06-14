import { prisma } from '../db.js';
import { chatCompletion, streamChatCompletion } from '../deepseek.js';
import { APP_KNOWLEDGE } from '../app-knowledge.js';
import { serializeProduct } from './product.js';

const SHOPPING_HINTS = [
  '买',
  '购',
  '下单',
  '订购',
  '入手',
  '推荐',
  '有没有',
  '想要',
  '帮我找',
  '帮我买',
  '帮我下单',
  '帮我购买',
  '带价',
  '多少钱',
  '价格',
  '商品',
  '盲盒',
  '手办',
  '公仔',
  '谷子',
  '徽章',
  '小卡',
  '文具',
  '玩具',
];

function lastUserMessage(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === 'user' && messages[i].content?.trim()) {
      return messages[i].content.trim();
    }
  }
  return '';
}

function quickShoppingHint(text) {
  const value = String(text ?? '').trim();
  if (!value) return false;
  return SHOPPING_HINTS.some((hint) => value.includes(hint));
}

function parseIntentJson(raw) {
  try {
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    const parsed = JSON.parse(raw.slice(start, end + 1));
    return {
      shopping: Boolean(parsed.shopping),
      keywords: String(parsed.keywords ?? '').trim(),
    };
  } catch {
    return null;
  }
}

const MAJOR_CATEGORIES = ['玩具', '文具', '手办', '公仔', '谷子', '小卡'];

function detectMajorCategory(keyword) {
  const value = String(keyword ?? '').trim();
  if (!value) return null;

  for (const category of MAJOR_CATEGORIES) {
    if (value === category) return category;
  }

  for (const category of MAJOR_CATEGORIES) {
    if (value.includes(category)) return category;
  }

  const tokens = value.split(/[\s,，、]+/).map((item) => item.trim()).filter(Boolean);
  for (const token of tokens) {
    if (MAJOR_CATEGORIES.includes(token)) return token;
  }

  return null;
}

export async function analyzeShoppingIntent(messages, config) {
  const latest = lastUserMessage(messages);
  if (!quickShoppingHint(latest)) {
    return { shopping: false, keywords: '' };
  }

  try {
    const raw = await chatCompletion(
      [
        {
          role: 'system',
          content:
            '你是购物意图分析器。根据用户最后一条消息，判断是否想购买/下单/让助手帮忙找商品并购买。' +
            '若是，提取 1～4 个中文搜索关键词（商品名、品类、角色名等），否则 keywords 为空。' +
            '注意：谷子与小卡、手办、公仔、玩具、文具是 App 内不同的大分类，用户说「谷子」时 keywords 应含「谷子」，不要写成小卡。' +
            '只输出 JSON：{"shopping":true/false,"keywords":"关键词"}',
        },
        {
          role: 'user',
          content: `用户消息：${latest}`,
        },
      ],
      { ...config, temperature: 0, maxTokens: 80 },
    );
    const parsed = parseIntentJson(raw);
    if (parsed) return parsed;
  } catch (error) {
    console.warn('[xiaodou-agent] intent analyze failed:', error.message);
  }

  return { shopping: true, keywords: latest.slice(0, 40) };
}

const RECOMMEND_LIMIT = 6;
const KEYWORD_LIMIT = 3;

export async function searchProductsForAgent(keyword, limit = KEYWORD_LIMIT) {
  const value = String(keyword ?? '').trim();
  if (!value) return { products: [], totalCount: 0, categoryLabel: '' };

  const majorCategory = detectMajorCategory(value);
  if (majorCategory) {
    const where = { majorCategory };
    const [categoryProducts, totalCount] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy: [{ sales: 'desc' }, { id: 'asc' }],
        take: RECOMMEND_LIMIT,
      }),
      prisma.product.count({ where }),
    ]);
    if (categoryProducts.length > 0) {
      return {
        products: categoryProducts.map(serializeProduct),
        totalCount,
        categoryLabel: majorCategory,
      };
    }
  }

  const products = await prisma.product.findMany({
    where: {
      OR: [
        { name: { contains: value } },
        { nameEn: { contains: value, mode: 'insensitive' } },
        { subCategory: { contains: value } },
        { majorCategory: { contains: value } },
        { category: { contains: value } },
      ],
    },
    orderBy: [{ sales: 'desc' }, { id: 'asc' }],
    take: limit,
  });

  if (products.length > 0) {
    return {
      products: products.map(serializeProduct),
      totalCount: products.length,
      categoryLabel: detectMajorCategory(value) ?? '',
    };
  }

  const tokens = value.split(/[\s,，、]+/).map((item) => item.trim()).filter(Boolean);
  for (const token of tokens) {
    const tokenCategory = detectMajorCategory(token);
    if (tokenCategory) {
      const where = { majorCategory: tokenCategory };
      const [categoryProducts, totalCount] = await Promise.all([
        prisma.product.findMany({
          where,
          orderBy: [{ sales: 'desc' }, { id: 'asc' }],
          take: RECOMMEND_LIMIT,
        }),
        prisma.product.count({ where }),
      ]);
      if (categoryProducts.length > 0) {
        return {
          products: categoryProducts.map(serializeProduct),
          totalCount,
          categoryLabel: tokenCategory,
        };
      }
    }

    const partial = await prisma.product.findMany({
      where: {
        OR: [
          { name: { contains: token } },
          { subCategory: { contains: token } },
          { majorCategory: { contains: token } },
          { category: { contains: token } },
        ],
      },
      orderBy: [{ sales: 'desc' }, { id: 'asc' }],
      take: limit,
    });
    if (partial.length > 0) {
      return {
        products: partial.map(serializeProduct),
        totalCount: partial.length,
        categoryLabel: tokenCategory ?? '',
      };
    }
  }

  const fallback = await prisma.product.findMany({
    orderBy: [{ sales: 'desc' }, { id: 'asc' }],
    take: limit,
  });
  return {
    products: fallback.map(serializeProduct),
    totalCount: fallback.length,
    categoryLabel: '',
  };
}

function buildAgentSystemMessage(products, { totalCount = 0, categoryLabel = '' } = {}) {
  if (!products.length) {
    return {
      role: 'system',
      content:
        `${APP_KNOWLEDGE}\n\n` +
        '## 购物助手\n' +
        '用户可能有购买意向，但暂未匹配到合适商品。请礼貌说明，并引导用户补充品类、名称或预算。',
    };
  }

  const catalog = products
    .map((p, index) => `${index + 1}. id=${p.id}｜${p.majorCategory}｜${p.name}｜¥${p.price}`)
    .join('\n');

  const categoryHint =
    categoryLabel && totalCount > products.length
      ? `该「${categoryLabel}」分类在 App 内共有 ${totalCount} 款商品，以下仅为销量最高的 ${products.length} 款推荐（不是全部）。`
      : categoryLabel && totalCount > 0
        ? `该「${categoryLabel}」分类匹配到 ${totalCount} 款商品：`
        : '系统已为用户匹配以下商品：';

  return {
    role: 'system',
    content:
      `${APP_KNOWLEDGE}\n\n` +
      '## 购物助手\n' +
      `${categoryHint}\n` +
      `${catalog}\n\n` +
      '请用 2～4 句亲切中文简要推荐，说明下方会出现商品卡片，可点击「立即购买」或「加入购物车」。' +
      '若推荐款数少于分类总数，必须说明「App 里还有更多，可以去商城对应分类看看」，禁止说「共有 X 款」且 X 小于真实总数。' +
      '严格按上方商品的大分类介绍，谷子与小卡不可混说。不要输出 markdown 链接，不要虚构价格或库存。',
  };
}

export async function* streamXiaodouAgent(messages, config) {
  const intent = await analyzeShoppingIntent(messages, config);
  let products = [];
  let searchMeta = { totalCount: 0, categoryLabel: '' };

  if (intent.shopping) {
    const result = await searchProductsForAgent(intent.keywords);
    products = result.products;
    searchMeta = { totalCount: result.totalCount, categoryLabel: result.categoryLabel };
  }

  const agentMessages = [buildAgentSystemMessage(products, searchMeta), ...messages];

  for await (const chunk of streamChatCompletion(agentMessages, config)) {
    yield { type: 'text', content: chunk };
  }

  if (products.length > 0) {
    yield { type: 'products', products };
  }
}
