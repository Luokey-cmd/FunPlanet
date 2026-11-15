import { prisma } from '../db.js';
import { chatCompletion, streamChatCompletion } from '../deepseek.js';
import { APP_KNOWLEDGE } from '../app-knowledge.js';
import { serializeProduct } from './product.js';
import { chatCompletionRaw, streamChatText } from './openai-compatible.js';
import { analyzeShoppingImage, formatVisionHint } from './xiaodou-vision.js';
import {
  executeXiaodouTool,
  MAJOR_CATEGORIES,
  toolResultForModel,
  XIAODOU_TOOLS,
} from './xiaodou-tools.js';

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
  '礼物',
  '小夜灯',
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

  return { products: [], totalCount: 0, categoryLabel: '' };
}

function agentSystemPrompt(starwish) {
  const archive = starwish
    ? `当前旅人星签：${JSON.stringify(starwish)}。推荐时要轻轻对上心情与预算，不要盘问已经知道的事。`
    : '旅人尚未点亮星签。需要时一次只问一个槽位。';
  return {
    role: 'system',
    content:
      `${APP_KNOWLEDGE}\n\n` +
      '## 角色\n' +
      '你是趣玩星球的守瓶精灵「小豆」。称用户为「你」或「旅人」。话像短笺：一句画面 + 一句理由 + 一句邀请。禁止「亲/宝子/很热销哦」。\n' +
      `${archive}\n\n` +
      '## 导购规则\n' +
      '1. 闲聊正常答，不搜货，不把话题强行拐去卖货。\n' +
      '2. App 用法、VIP、券：get_promotions / get_user_context。\n' +
      '3. 需求清楚时优先 draw_star_cards（三张星牌），不要一次甩很多热销。\n' +
      '4. 信息不够只问 1 个问题。\n' +
      '5. 价格只能复述工具返回的 ¥。\n' +
      '6. 谷子≠小卡，手办≠公仔。\n' +
      '7. 引出星牌用 2～3 句，说明可翻开本命/遇见/余韵。\n' +
      '8. 换一批：excludeIds 或 skip。\n' +
      '9. 加购：propose_add_to_cart，禁止声称已经放进背包。\n' +
      '10. 识图：若消息已含视觉结果，再搜同款或同味道；不要假装看见像素。\n' +
      '11. 送礼：点到商品后用一句寄语，不要长篇。\n' +
      '12. 不要 markdown 链接。',
  };
}

function collectProducts(byId, fullList = []) {
  for (const item of fullList) {
    if (item?.id) byId.set(item.id, item);
  }
}

async function* runQwenGuide(messages, dashscope, { userId, starwish } = {}) {
  const byId = new Map();
  const pendingCart = [];
  let offerCards = false;
  let fateRoles = [];
  let emittedText = false;
  const history = [agentSystemPrompt(starwish), ...messages];

  for (let round = 0; round < 3; round += 1) {
    const message = await chatCompletionRaw({
      ...dashscope,
      messages: history,
      tools: XIAODOU_TOOLS,
      temperature: 0.5,
      maxTokens: 700,
    });

    const toolCalls = Array.isArray(message.tool_calls) ? message.tool_calls : [];
    if (toolCalls.length === 0) {
      const text = String(message.content ?? '').trim();
      if (text) {
        yield { type: 'text', content: text };
        emittedText = true;
      }
      break;
    }

    history.push({
      role: 'assistant',
      content: message.content ?? '',
      tool_calls: toolCalls,
    });

    for (const call of toolCalls) {
      const name = call.function?.name || call.name;
      const args = call.function?.arguments ?? call.arguments;
      const result = await executeXiaodouTool(name, args, { userId });
      if (name === 'search_products') {
        byId.clear();
        collectProducts(byId, result.fullProducts);
        offerCards = (result.fullProducts?.length ?? 0) > 0;
        fateRoles = [];
      }
      if (name === 'draw_star_cards') {
        byId.clear();
        collectProducts(byId, result.fullProducts);
        offerCards = (result.fullProducts?.length ?? 0) > 0;
        fateRoles = Array.isArray(result.roles) ? result.roles : [];
      }
      if (name === 'get_product_detail' && result.fullProduct) {
        collectProducts(byId, [result.fullProduct]);
        offerCards = true;
      }
      if (name === 'propose_add_to_cart' && result.fullProduct) {
        pendingCart.push(result.fullProduct);
      }
      history.push({
        role: 'tool',
        tool_call_id: call.id,
        name,
        content: toolResultForModel(name, result),
      });
    }
  }

  if (!emittedText) {
    for await (const chunk of streamChatText({
      ...dashscope,
      messages: history,
      temperature: 0.5,
      maxTokens: 700,
    })) {
      yield { type: 'text', content: chunk };
    }
  }

  if (offerCards && byId.size > 0) {
    const products = [...byId.values()].slice(0, 3);
    if (fateRoles.length >= 2) {
      yield { type: 'fate_cards', products, roles: fateRoles.slice(0, products.length) };
    } else {
      yield { type: 'products', products };
    }
    const purpose = String(starwish?.purpose ?? starwish?.giftFeeling ?? '');
    if (/送|礼|gift|被懂|被哄|惊/i.test(purpose) || /送|礼/.test(lastUserMessage(messages))) {
      const feeling = starwish?.giftFeeling || 'default';
      const notes = {
        understood: '托小豆带到你桌上的第一颗星，希望你被准确看见。',
        被懂: '托小豆带到你桌上的第一颗星，希望你被准确看见。',
        comforted: '这是一封不催你坚强的短笺，拆开时先被轻轻接住。',
        被哄: '这是一封不催你坚强的短笺，拆开时先被轻轻接住。',
        surprised: '不许提前拆——里面藏着一颗会眨眼的小意外。',
        被惊到: '不许提前拆——里面藏着一颗会眨眼的小意外。',
        default: '托小豆带到你桌上的第一颗星。',
      };
      yield { type: 'gift_note', content: notes[feeling] || notes.default };
    }
  }
  if (pendingCart.length > 0) {
    yield { type: 'cart_confirm', products: pendingCart.slice(0, 3) };
  }
}

function buildLegacySystemMessage(products, { totalCount = 0, categoryLabel = '' } = {}) {
  if (!products.length) {
    return {
      role: 'system',
      content:
        `${APP_KNOWLEDGE}\n\n` +
        '## 购物助手\n' +
        '用户可能有购买意向，但暂未匹配到合适商品。请礼貌说明，并引导用户补充品类、名称或预算。不要编造商品或价格。',
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

async function* runDeepseekFallback(messages, config) {
  const intent = await analyzeShoppingIntent(messages, config);
  let products = [];
  let searchMeta = { totalCount: 0, categoryLabel: '' };

  if (intent.shopping) {
    const result = await searchProductsForAgent(intent.keywords);
    products = result.products;
    searchMeta = { totalCount: result.totalCount, categoryLabel: result.categoryLabel };
  }

  const agentMessages = [buildLegacySystemMessage(products, searchMeta), ...messages];

  for await (const chunk of streamChatCompletion(agentMessages, config)) {
    yield { type: 'text', content: chunk };
  }

  if (products.length > 0) {
    yield { type: 'products', products };
  }
}

export async function* streamXiaodouAgent(
  messages,
  { dashscope, deepseek, userId, imageBase64, mimeType, starwish, vision } = {},
) {
  if (dashscope?.apiKey && imageBase64) {
    try {
      const result = await analyzeShoppingImage({ dashscope, imageBase64, mimeType });
      const notes = result.notes || '瓶子里映出一件轮廓。';
      yield {
        type: 'appraisal',
        content: `${notes} 你要找几乎一样的，还是只要这个味道？`,
        vision: result,
      };
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] vision failed:', error.message);
      yield {
        type: 'appraisal',
        content: '瓶子晃了一下，这张照片我还看不真切。换一张更清楚的，或告诉我品类。',
        vision: null,
      };
      return;
    }
  }

  let guideMessages = messages;
  if (vision && typeof vision === 'object') {
    guideMessages = [
      {
        role: 'user',
        content: `${formatVisionHint(vision)}\n用户选择：${lastUserMessage(messages) || '找同类气味'}`,
      },
      ...messages,
    ];
  }

  if (dashscope?.apiKey) {
    try {
      yield* runQwenGuide(guideMessages, dashscope, { userId, starwish });
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] qwen failed, fallback deepseek:', error.message);
    }
  }

  if (deepseek?.apiKey) {
    yield* runDeepseekFallback(guideMessages, deepseek);
    return;
  }

  throw new Error('未配置 DASHSCOPE_API_KEY 或 DEEPSEEK_API_KEY');
}
