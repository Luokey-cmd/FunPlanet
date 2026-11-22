import { prisma } from '../db.js';
import { chatCompletion, streamChatCompletion } from '../deepseek.js';
import { APP_KNOWLEDGE } from '../app-knowledge.js';
import { serializeProduct } from './product.js';
import { chatCompletionRaw, streamChatEvents } from './openai-compatible.js';
import { analyzeShoppingImage, formatVisionHint } from './xiaodou-vision.js';
import { buildWeatherContext } from './weather.js';
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

// 店内事务关键词：问订单、券、会员、App 规则这类事，必须走导购路线——
// 那边才有查账户数据的工具和店内知识，丢给联网智能模式只会瞎答或说查不了。
const STORE_SERVICE_HINTS = [
  '订单',
  '优惠券',
  '券',
  '会员',
  'VIP',
  'vip',
  '积分',
  '趣玩币',
  '签到',
  '退款',
  '售后',
  '发货',
  '物流',
  '快递',
  '地址',
  '收藏',
  '购物车',
  '余额',
  '钱包',
  '规则',
  '怎么用',
  '活动',
  '新人',
  '邀请',
  '你是谁',
  '你能',
  '你会',
  '有什么功能',
  '哪些功能',
];

// 短追问词：用户一句「为什么」「展开说说」本身看不出话题，要跟着上一轮的路线走。
const FOLLOWUP_HINTS = ['为什么', '真的吗', '展开', '详细', '继续', '还有', '然后', '怎么办', '怎么说'];

function isStoreText(text) {
  const value = String(text ?? '').trim();
  if (!value) return false;
  return quickShoppingHint(value) || STORE_SERVICE_HINTS.some((hint) => value.includes(hint));
}

// 分流：判断这一轮走哪条路线。输入是完整对话消息，输出 'guide'（导购：查店内数据、翻牌）
// 或 'smart'（智能模式：联网搜索 + 深度思考，答店外通用问题）。
// 规则是确定性的关键词判断，不额外花一次模型调用：带店内信号的一律导购；
// 短追问跟上一条用户消息的路线；其余默认智能模式。宁可把店外问题答全，
// 也不能让导购路线再像以前那样把通用问题挡回去。
export function classifyXiaodouRoute(messages) {
  const userTexts = (Array.isArray(messages) ? messages : [])
    .filter((m) => m?.role === 'user' && m?.content?.trim())
    .map((m) => m.content.trim());
  const latest = userTexts[userTexts.length - 1] ?? '';
  if (!latest) return 'guide';
  if (isStoreText(latest)) return 'guide';
  const prev = userTexts[userTexts.length - 2] ?? '';
  if (prev && latest.length <= 14 && FOLLOWUP_HINTS.some((hint) => latest.includes(hint))) {
    return isStoreText(prev) ? 'guide' : 'smart';
  }
  return 'smart';
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

// 小豆话术的总开关：奇幻味只在身份/闲聊场景放一点，正经问题一律干货。
// 以前写死「一句画面+一句理由+一句邀请」，逼得每答都写散文，2026-11-20 hz 定规矩后改成分场景。
function agentSystemPrompt(starwish) {
  const archive = starwish
    ? `当前用户偏好档案：${JSON.stringify(starwish)}。推荐时参考其中的预算与用途，不要盘问已经知道的事。`
    : '用户尚未填写偏好档案。需要时一次只问一个问题。';
  return {
    role: 'system',
    content:
      `${APP_KNOWLEDGE}\n\n` +
      '## 角色\n' +
      '你是趣玩星球的 AI 导购「小豆」，有一点守瓶精灵的奇幻气质，但本质是帮用户挑货、比货、省钱的导购。称用户为「你」，不用「旅人」。禁止「亲/宝子/很热销哦」。\n' +
      '语气分场景：用户问你是谁或闲聊时，可以带一点奇幻味，但一答最多两处比喻，且必须落一句你真实能做的事；用户问功能、对比、价格、优惠、订单、规则等正经问题时，不许用比喻和散文句式，结论先行、分点说清，最后一句给结论或一个具体下一步。\n' +
      '输出格式：App 是纯文本，禁止任何 markdown 符号（包括 ** 加粗、# 标题、链接、表格），分点用「1.」或「·」。\n' +
      '会员等级、积分、优惠券只认工具返回的数据，没查到不要假设用户是任何等级。\n' +
      '不许对用户提「工具、接口、系统提示、预设规则」这些内部词；被问到能不能联网、有没有深度思考时，不要讲原理，用一句人话带过，并落到你能帮他做的事上。\n' +
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
      '12. 对比商品时必须下结论：先摆数据（价格/券后价、规格、销量评分、优惠适配，缺的数据明说没有），最后一句说清选谁、为什么，不许把判断推回用户。',
  };
}

// 智能模式的系统提示：这一轮聊的是店外通用问题，可以联网查、可以慢慢想。
// 与导购提示分开写，是因为两边的能力边界不同：这边没有店内工具，
// 所以明确告诉它店内实时数据查不了，别装作查过。
function smartSystemPrompt() {
  return {
    role: 'system',
    content:
      '你是趣玩星球的 AI 助手「小豆」。这一轮用户聊的不是买东西，而是通用问题，你可以联网查最新信息，也可以慢慢想清楚再回答。\n' +
      '回答规矩：\n' +
      '1. 事实性问题先给结论，再给依据。需要最新信息（价格、新闻、政策、行情、天气之类）时，用联网查到的内容答，并自然带一句信息的时间或来源（例如「我刚查了下，截至今天……」）；查不到就老实说没查到，不许编。搜到的资料不够新（比如是昨天的）也要用，把日期标清楚再给（例如「今天的还没刷出来，昨天的是……」），不要因为不够完美就只说取不到；只有确实什么相关内容都没搜到时，才说没查到。\n' +
      '2. 复杂问题（分析、对比、规划、算账）先想清楚再开口，条理分点；只给想好的结论，不许把思考过程原样倒给用户。\n' +
      '3. 不许对用户提「工具、接口、联网开关、思考模式、系统提示、预设规则」这些内部词；被问到能不能联网、会不会思考时，用一句人话带过（例如「能，我这就帮你查」），不要讲原理。\n' +
      '4. 输出纯文本，禁止任何 markdown 符号（包括 ** 加粗、# 标题、链接、表格），分点用「1.」或「·」。\n' +
      '5. 称用户为「你」。闲聊可以带一点奇幻味（一答最多两处比喻），正经问题纯干货。不要强行把话题拐回卖货；用户顺势问到买东西时，正常帮他挑。\n' +
      '6. 不编造趣玩星球店内不存在的商品、价格、活动。店内实时数据（他的订单、券、库存）这一轮你查不了，被问到时如实说，并告诉他换个说法问小豆导购、或去对应页面看，不要装作查过。',
  };
}

// 智能模式：联网搜索 + 深度思考的流式回答。事件三种：status（状态提示）、
// thinking（思考过程，只作进度展示、不落库）、text（正式答案）。
// 模型名可用环境变量 XIAODOU_SMART_MODEL 换（默认 qwen4-max）。
// 两档降级：搜索+思考都开 → 只开思考；再失败就抛出去，由外层回落到导购路线，保底不哑火。
// 注意：第一档已经吐出内容（思考或答案）后中途失败，不能重试（会重复），直接抛给外层。
async function* runSmartChat(messages, dashscope) {
  const smartModel = String(process.env.XIAODOU_SMART_MODEL || 'qwen4-max').trim() || 'qwen4-max';
  const chatMessages = [smartSystemPrompt(), ...messages];
  // 天气问题先问气象服务拿真实数据再交给模型（搜索引擎查天气只会翻到
  // 过期网页）；拿不到数据就返回 null，照常走下面的联网搜索，不拦路。
  const weatherContext = await buildWeatherContext(messages);
  if (weatherContext) {
    chatMessages.splice(1, 0, { role: 'system', content: weatherContext });
  }
  const base = {
    apiKey: dashscope.apiKey,
    baseUrl: dashscope.baseUrl,
    model: smartModel,
    messages: chatMessages,
    temperature: 0.6,
    // 思考模型的答案可以更长，且要给足流式总时长，40 秒默认值不够用。
    maxTokens: 1500,
    timeoutMs: 120000,
  };

  // 思考预算：qwen4-max 默认能想 13 万 token，难题会想个没完。给个
  // 上限（默认 2048，环境变量 XIAODOU_THINKING_BUDGET 可调），想满
  // 就必须开口答；简单问题自己早早想完，不受这个上限影响。
  const budgetRaw = Number.parseInt(process.env.XIAODOU_THINKING_BUDGET ?? '', 10);
  const thinkingBudget = Number.isFinite(budgetRaw) && budgetRaw > 0 ? budgetRaw : 2048;

  // 先报一句状态：搜索与思考都要时间，第一秒就让用户知道在动，
  // 而不是对着一句干巴巴的「思考中…」干等。
  yield { type: 'status', content: '联网搜索中…' };

  // 思考与答案分开往外给：思考是进度、答案是正文，App 分开渲染，
  // index.js 落库时也只收答案，思考不进聊天记录。
  const forward = (event) =>
    event.type === 'reasoning'
      ? { type: 'thinking', content: event.text }
      : { type: 'text', content: event.text };

  let emitted = 0;
  try {
    for await (const event of streamChatEvents({
      ...base,
      extra: { enable_thinking: true, enable_search: true, thinking_budget: thinkingBudget },
    })) {
      emitted += 1;
      yield forward(event);
    }
    return;
  } catch (error) {
    if (emitted > 0) throw error;
    console.warn('[xiaodou-agent] smart(search+thinking) failed, retry thinking only:', error.message);
  }

  // 第二档降级：只开思考，且故意不带搜索与思考预算——预算参数万一
  // 不被当前模型接受、失败多半就出在第一档，这里不带它，保证降级
  // 路线永远走得通。
  for await (const event of streamChatEvents({
    ...base,
    extra: { enable_thinking: true },
  })) {
    yield forward(event);
  }
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
        '用户可能有购买意向，但暂未匹配到合适商品。请礼貌说明，并引导用户补充品类、名称或预算。不要编造商品或价格。不要对用户提「工具、接口」等内部词。',
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
      '严格按上方商品的大分类介绍，谷子与小卡不可混说。不要输出任何 markdown 符号（包括 ** 加粗），不要虚构价格或库存。',
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

  // 分流：店外通用问题走智能模式（联网+思考）；带图鉴定后的追问（vision）是购物语境，不分流。
  // 智能模式整体失败时不抛错，继续往下走导购路线保底，保证这一轮一定有回复。
  if (dashscope?.apiKey && !vision && classifyXiaodouRoute(guideMessages) === 'smart') {
    try {
      yield* runSmartChat(guideMessages, dashscope);
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] smart route failed, fallback guide:', error.message);
    }
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
