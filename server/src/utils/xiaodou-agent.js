import { prisma } from '../db.js';
import { chatCompletion, streamChatCompletion } from '../deepseek.js';
import { APP_KNOWLEDGE } from '../app-knowledge.js';
import { serializeProduct } from './product.js';
import { chatCompletionRaw, streamChatEvents, streamChatText } from './openai-compatible.js';
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

// 合脑（2026-11-22）：关键词分流已删除。以前这里有三组关键词表
// （店内事务 / 短追问 / 购物信号）猜这一轮走导购还是智能模式，
// 一句话里既问店外又问店内时必走偏。现在只有一个大脑
// （runUnifiedAgent），模型自己决定查工具、联网搜还是直接答。
// 上面的 SHOPPING_HINTS / quickShoppingHint 不再参与分流，只给
// DeepSeek 兜底路线当购物意图的粗筛（analyzeShoppingIntent 在用）。

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
// 以前写死「一句画面+一句理由+一句邀请」，逼得每答都写散文，2026-11-20 hx 定规矩后改成分场景。
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

// 合脑后的统一系统提示：导购与智能两份提示词合成一份。
// 与 agentSystemPrompt 的区别：那个只给纯导购保底用（没有联网与思考）；
// 这份多出「三样本事自己判断用哪样」与「查证规矩」——店内事实只信工具、
// 店外事实只信搜索，是这次合并最关键的一条，防的是模型拿搜到的过期
// 价格答店内问题、或拿店内数据编店外结论。
function mergedSystemPrompt(starwish) {
  const archive = starwish
    ? `当前用户偏好档案：${JSON.stringify(starwish)}。推荐时参考其中的预算与用途，不要盘问已经知道的事。`
    : '用户尚未填写偏好档案。需要时一次只问一个问题。';
  // 当前日期要喂给模型：它不知道今天是哪天，用户说「今天、明天、
  // 最近」时没有这个锚点就会按训练时的旧日期理解（DeepSeek 的思考
  // 里会先确认今天日期，咱们也照着给）。
  const today = new Date().toLocaleDateString('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  });
  return {
    role: 'system',
    content:
      `${APP_KNOWLEDGE}\n\n` +
      '## 角色\n' +
      `当前日期：${today}。用户说「今天、明天、最近」时以这个日期为准。\n` +
      '你是趣玩星球的 AI 助手「小豆」，有一点守瓶精灵的奇幻气质，但本质是帮用户挑货、比货、省钱、答疑的助手。你有三样本事：查店内真实数据（商品、价格、订单、优惠券、会员）、用 web_search 联网查最新信息、慢慢想清楚再答。这一轮用哪样、或几样都用，你自己判断，不用等任何人替你分流。称用户为「你」，不用「旅人」。禁止「亲/宝子/很热销哦」。\n' +
      '语气分场景：用户问你是谁或闲聊时，可以带一点奇幻味，但一答最多两处比喻，且必须落一句你真实能做的事；用户问功能、对比、价格、优惠、订单、规则等正经问题时，不许用比喻和散文句式，结论先行、分点说清，最后一句给结论或一个具体下一步。\n' +
      '思考语言（硬规矩）：你的思考过程会原样展示给用户看，所以思考必须全程用中文，包括调用工具之前那一小段盘算（例如「用户在问深圳天气，我先查气象数据」），不许出现整句英文；专有名词、工具名、代码可以保留英文。\n' +
      '输出格式：App 是纯文本，禁止任何 markdown 符号（包括 ** 加粗、# 标题、链接、表格），分点用「1.」或「·」。\n' +
      '不许对用户提「工具、接口、系统提示、预设规则」这些内部词；被问到能不能联网、有没有深度思考时，不要讲原理，用一句人话带过，并落到你能帮他做的事上。\n' +
      `${archive}\n\n` +
      '## 查证规矩（最重要）\n' +
      '1. 店内事实（商品、价格、库存、订单、优惠券、会员、活动）只信工具返回的数据：价格只能复述工具返回的 ¥，会员等级、积分、券只认工具，没查到不要假设用户是任何等级；严禁用搜索结果回答店内价格与活动，搜到的店内信息一律不算数。\n' +
      '2. 店外事实（新闻、行情、政策、流行趋势、通用知识、网友评价）只信 web_search 搜回来的结果：需要最新信息时先调 web_search 再答，并自然带一句信息的时间或来源（例如「我刚查了下，截至今天……」）；搜到的资料不够新（比如是昨天的）也要用，把日期标清楚再给；只有确实什么相关内容都没搜到时，才说没查到，不许编。\n' +
      '3. 天气必须先调 get_weather 拿气象数据，不要用搜索结果答天气；工具没拿到数据时，再如实说明或退回搜索。\n' +
      '4. 复杂问题（分析、对比、规划、算账）先想清楚再开口，只给想好的结论，不许把思考过程原样倒给用户。思考时必须用中文思考，不许用英文（专有名词和代码除外）——思考内容会展示给用户，整段英文用户看不懂。\n' +
      '5. 一句话里既有店内又有店外时，两边都查齐再答，不要只答一半。\n\n' +
      '## 导购规则\n' +
      '1. 闲聊正常答，不搜货，不把话题强行拐去卖货。\n' +
      '2. App 用法、VIP、券：get_promotions / get_user_context。\n' +
      '3. 需求清楚时优先 draw_star_cards（三张星牌），不要一次甩很多热销。\n' +
      '4. 信息不够只问 1 个问题。\n' +
      '5. 谷子≠小卡，手办≠公仔。\n' +
      '6. 引出星牌用 2～3 句，说明可翻开本命/遇见/余韵。\n' +
      '7. 换一批：excludeIds 或 skip。\n' +
      '8. 加购：propose_add_to_cart，禁止声称已经放进背包。\n' +
      '9. 识图：若消息已含视觉结果，再搜同款或同味道；不要假装看见像素。\n' +
      '10. 送礼：点到商品后用一句寄语，不要长篇。\n' +
      '11. 对比商品时必须下结论：先摆数据（价格/券后价、规格、销量评分、优惠适配，缺的数据明说没有），最后一句说清选谁、为什么，不许把判断推回用户。',
  };
}

// 思考文本的语言检查：汉字数不少于英文字母数才算「中文思考」。
// 输入是一整轮攒下来的思考文本，输出 true=可以展示给用户。
// 坑：计数前先抹掉下划线标识符（get_promotions 这类工具名）——
// 一句中文思考点名两三个工具，英文字母能反超汉字，会被误杀。
function isMostlyChinese(text) {
  const cleaned = String(text).replace(/[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+/g, ' ');
  const cjk = (cleaned.match(/[一-鿿]/g) || []).length;
  const latin = (cleaned.match(/[A-Za-z]/g) || []).length;
  return cjk + latin === 0 || cjk >= latin;
}

// 一轮流式事件的转发：思考先攒着、过语言检查才往外给，答案直通，
// 工具调用收进 sink 不往外发。输入是 streamChatEvents 的事件流与
// sink（{ calls, text, started }，就地回填）；输出 thinking / text 事件。
// 为什么思考不逐字直通：qwen4-max 调工具前的短思考总爱用英文，
// 提示词两次实测都压不住；英文思考原样展示用户看不懂，攒整轮过滤
// 比逐字直通稳。代价是思考不再逐字滚动，而是整段出现在答案之前，
// 顺序不变（先思考、后答案）。
// 还有一类不展示：工具轮的短思考多半是「需要调用 X」式的报幕，
// 不是在分析问题（hx 对照 DeepSeek 的思考后定的规矩——人家的思考
// 在分析用户要什么、自己打算怎么答，不念工具名）。这一轮以工具
// 调用收尾、且思考不超过 40 字时，直接不展示；有分量的分析照常给。
async function* streamRoundWithReasoningFilter(events, sink) {
  let buffer = '';
  const flush = (isFinal = false) => {
    const text = buffer;
    buffer = '';
    if (!text || !isMostlyChinese(text)) return null;
    if (isFinal && sink.calls.length > 0 && text.length <= 40) return null;
    return { type: 'thinking', content: text };
  };
  for await (const event of events) {
    if (event.type === 'tool_calls') {
      sink.calls = event.calls;
      continue;
    }
    sink.started = true;
    if (event.type === 'reasoning') {
      buffer += event.text;
      continue;
    }
    if (event.type === 'content') {
      const thinking = flush();
      if (thinking) yield thinking;
      sink.text += event.text;
      yield { type: 'text', content: event.text };
    }
  }
  const thinking = flush(true);
  if (thinking) yield thinking;
}

// 合脑后的统一大脑（2026-11-22 第一步施工）：不再分流。一次对话里
// 模型自己决定下一步：调店内工具、调天气、联网搜索，还是直接开口答。
// 输入：对话消息 + 通义配置（dashscope）+ { userId, starwish }。
// 输出：事件类型与合并前完全一致——status / thinking / text / products /
// fate_cards / gift_note / cart_confirm，App 零改动。
// 模型沿用原智能模式的 XIAODOU_SMART_MODEL（默认 qwen4-max），思考与
// 答案分开透传、思考不落库（与原智能模式一致）。
// 工具循环上限 4 轮（hx 2026-11-22 拍板）：跨界问题常要「搜→查店→比」
// 三步，留一轮余量；4 轮都用来调工具还没结论时，补一轮无工具的流式
// 回答收尾，不把用户晾在半截。
// 降级两档：第一档思考（带预算）+工具全开；若在吐出任何内容、执行
// 任何工具之前就失败，换第二档（只开思考+工具，不带思考预算——
// 第一档若是被某个新参数拒了，第二档保证走得通）；第二档再失败
// 就抛出去，由 streamXiaodouAgent 回落纯导购保底，绝不哑火。
// 联网搜索不在这两档里：它已是 web_search 工具（见 xiaodou-tools.js），
// 与普通工具同进同出，不再用 enable_search 开关与工具抢轮次。
// 停滞处理（实测教训）：搜索+思考+工具同开时，模型流偶尔会半路
// 没动静、把用户晾在半句话上。每轮开 30 秒无数据看门狗：还没吐
// 正文就卡住的，原样重试一次（工具未执行、无副作用）；已经在吐
// 内容的，就此体面收尾（该给的商品卡照给），不让用户干等。
// 天气不再前置注入：原智能模式靠 buildWeatherContext 预塞数据，
// 合脑后改走 get_weather 工具（在 xiaodou-tools.js 里），任何问题里
// 捎带问天气都能查，且不会用一句「直接答天气」的要求带偏复合问题。
async function* runUnifiedAgent(messages, dashscope, { userId, starwish } = {}) {
  const smartModel = String(process.env.XIAODOU_SMART_MODEL || 'qwen4-max').trim() || 'qwen4-max';
  // 思考预算：qwen4-max 默认能想 13 万 token，难题会想个没完。给个
  // 上限（默认 2048，环境变量 XIAODOU_THINKING_BUDGET 可调），想满
  // 就必须开口答；简单问题自己早早想完，不受这个上限影响。
  const budgetRaw = Number.parseInt(process.env.XIAODOU_THINKING_BUDGET ?? '', 10);
  const thinkingBudget = Number.isFinite(budgetRaw) && budgetRaw > 0 ? budgetRaw : 2048;
  // 停滞看门狗阈值：一轮流式响应连续多久没数据算卡死，默认 30 秒；
  // 环境变量 XIAODOU_STREAM_IDLE_MS 可调（网络特别慢时调大）。
  const idleRaw = Number.parseInt(process.env.XIAODOU_STREAM_IDLE_MS ?? '', 10);
  const idleTimeoutMs = Number.isFinite(idleRaw) && idleRaw > 0 ? idleRaw : 30000;

  const byId = new Map();
  const pendingCart = [];
  let offerCards = false;
  let fateRoles = [];
  const history = [mergedSystemPrompt(starwish), ...messages];

  // 先报一句状态：思考与查工具都要时间，第一秒就让用户知道在动。
  // 文案用中性的「思考中…」：这一轮未必会联网搜索（那是模型自己
  // 决定要不要调 web_search），别先把话说满。
  yield { type: 'status', content: '思考中…' };

  // 思考与答案分开往外给：思考是进度、答案是正文，App 分开渲染，
  // index.js 落库时也只收答案，思考不进聊天记录。转发统一走
  // streamRoundWithReasoningFilter（思考先攒后放、英文思考不展示）。
  const base = {
    apiKey: dashscope.apiKey,
    baseUrl: dashscope.baseUrl,
    model: smartModel,
    temperature: 0.6,
    // 输出上限必须大于思考预算：接口硬校验 max_completion_tokens
    // 必须 > thinking_budget，否则直接 400。原智能模式 1500 配 2048
    // 一直在踩这个坑、靠降级档兜着，联网搜索其实从没真正开过；
    // 这里按「预算 + 2048 的答案余量」动态给，改预算也不会再撞。
    maxTokens: thinkingBudget + 2048,
    // 思考模型的答案可以更长，且要给足流式总时长，40 秒默认值不够用。
    timeoutMs: 120000,
  };
  // 注意：这里不再开 enable_search。实测它与工具调用同开会让模型
  // 只预告不调工具、整轮空转；联网搜索已改成 web_search 工具
  // （见 xiaodou-tools.js），主循环只保留「思考 + 工具」这个稳的组合。
  const extraFor = (tier) =>
    tier === 1
      ? { enable_thinking: true, thinking_budget: thinkingBudget }
      : { enable_thinking: true };

  let started = false; // 已吐内容或已执行工具：整轮重试会重复，禁止
  let answered = false; // 出现无工具调用的一轮 = 模型已给出最终回答
  let tier = 1;
  let stallRetryRound = -1; // 已为停滞重试过的轮次号（重试标记必须放循环外，放里面每轮清零会变成无限重试）

  for (let round = 0; round < 4 && !answered; round += 1) {
    let calls = [];
    let roundText = '';
    const sink = { calls: [], text: '', started: false };
    try {
      yield* streamRoundWithReasoningFilter(
        streamChatEvents({
          ...base,
          messages: history,
          tools: XIAODOU_TOOLS,
          extra: extraFor(tier),
          idleTimeoutMs,
        }),
        sink,
      );
      calls = sink.calls;
      roundText = sink.text;
      if (sink.started) started = true;
    } catch (error) {
      const stalled = error?.code === 'STREAM_STALL';
      if (stalled && !sink.text && stallRetryRound !== round) {
        console.warn('[xiaodou-agent] unified round stalled before content, retry once:', error.message);
        stallRetryRound = round;
        round -= 1;
        continue;
      }
      if (stalled && (started || sink.text)) {
        console.warn('[xiaodou-agent] unified round stalled after content, end turn gracefully:', error.message);
        answered = true;
        break;
      }
      if (!started && !sink.started && tier === 1) {
        console.warn('[xiaodou-agent] unified(tier1) failed, retry tier2:', error.message);
        tier = 2;
        round -= 1;
        continue;
      }
      throw error;
    }

    if (calls.length === 0) {
      answered = true;
      break;
    }

    started = true;
    // 工具调用的 id 以模型给的为准；流式碎片万一没带 id，按轮次序号
    // 补一个——assistant 消息与 tool 结果必须用同一个 id 对上。
    const normalized = calls.map((call, i) => ({
      id: call.id || `call_${round}_${i}`,
      name: call.name,
      arguments: call.arguments || '{}',
    }));
    history.push({
      role: 'assistant',
      content: roundText,
      tool_calls: normalized.map((call) => ({
        id: call.id,
        type: 'function',
        function: { name: call.name, arguments: call.arguments },
      })),
    });

    for (const call of normalized) {
      // 单个工具翻车（查库抖动、外部接口超时）不许掀翻整轮对话：
      // 把失败当成一条工具结果喂回模型，让它换个说法或如实告知。
      let result;
      try {
        result = await executeXiaodouTool(call.name, call.arguments, { userId, messages, dashscope, smartModel });
      } catch (error) {
        console.warn('[xiaodou-agent] tool failed:', call.name, error.message);
        result = { ok: false, error: `工具 ${call.name} 执行失败。不要编造数据，如实告诉用户这项暂时查不了。` };
      }
      if (call.name === 'search_products') {
        byId.clear();
        collectProducts(byId, result.fullProducts);
        offerCards = (result.fullProducts?.length ?? 0) > 0;
        fateRoles = [];
      }
      if (call.name === 'draw_star_cards') {
        byId.clear();
        collectProducts(byId, result.fullProducts);
        offerCards = (result.fullProducts?.length ?? 0) > 0;
        fateRoles = Array.isArray(result.roles) ? result.roles : [];
      }
      if (call.name === 'get_product_detail' && result.fullProduct) {
        collectProducts(byId, [result.fullProduct]);
        offerCards = true;
      }
      if (call.name === 'propose_add_to_cart' && result.fullProduct) {
        pendingCart.push(result.fullProduct);
      }
      history.push({
        role: 'tool',
        tool_call_id: call.id,
        name: call.name,
        content: toolResultForModel(call.name, result),
      });
    }
  }

  // 4 轮全花在查工具上、还没开口给结论：补一轮不带工具的流式回答，
  // 把已经查到的数据说成结论再结束。
  if (!answered) {
    const sink = { calls: [], text: '', started: false };
    try {
      yield* streamRoundWithReasoningFilter(
        streamChatEvents({ ...base, messages: history, extra: extraFor(tier), idleTimeoutMs }),
        sink,
      );
    } catch (error) {
      // 收尾轮卡住就直接结束这一轮，别为最后一句把整轮拖垮；
      // 其他错误照常抛出去走保底链。
      if (error?.code !== 'STREAM_STALL') throw error;
      console.warn('[xiaodou-agent] unified final round stalled, end turn:', error.message);
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

function collectProducts(byId, fullList = []) {
  for (const item of fullList) {
    if (item?.id) byId.set(item.id, item);
  }
}

// 纯导购保底：合脑前的主力路线，合脑后降为第二道防线——统一大脑
// 整体失败时由它接住（只查店内工具、走 qwen-plus、不联网不思考）。
// 逻辑与合并前保持一致，不要在这里加新能力，新能力一律进统一大脑。
// （合脑审计时只补了两处防崩：streamChatText 的导入以前漏写、工具
// 执行加了失败兜底，行为口径未动。）
async function* runGuideFallback(messages, dashscope, { userId, starwish } = {}) {
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
      // 与统一大脑同一条规矩：单个工具翻车喂回错误结果，不掀翻整轮。
      let result;
      try {
        result = await executeXiaodouTool(name, args, { userId });
      } catch (error) {
        console.warn('[xiaodou-agent] guide tool failed:', name, error.message);
        result = { ok: false, error: `工具 ${name} 执行失败。不要编造数据，如实告诉用户这项暂时查不了。` };
      }
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

  // 合脑后只有一条主路线：统一大脑（工具 + 联网搜索 + 深度思考，
  // 模型自己判断用哪样）。它整体失败时先回落纯导购保底，再失败
  // 才轮到 DeepSeek 兜底，保证这一轮一定有回复。
  if (dashscope?.apiKey) {
    let unifiedYieldedText = false;
    try {
      for await (const event of runUnifiedAgent(guideMessages, dashscope, { userId, starwish })) {
        if (event.type === 'text') unifiedYieldedText = true;
        yield event;
      }
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] unified failed, fallback guide:', error.message);
      // 已经吐过正文才失败的：答案已在用户眼前，再叠一份保底答案
      // 会变成两段话打架，直接收尾（半截答案也比双份答案强）。
      if (unifiedYieldedText) return;
    }
    let guideYieldedText = false;
    try {
      for await (const event of runGuideFallback(guideMessages, dashscope, { userId, starwish })) {
        if (event.type === 'text') guideYieldedText = true;
        yield event;
      }
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] qwen failed, fallback deepseek:', error.message);
      if (guideYieldedText) return;
    }
  }

  if (deepseek?.apiKey) {
    yield* runDeepseekFallback(guideMessages, deepseek);
    return;
  }

  throw new Error('未配置 DASHSCOPE_API_KEY 或 DEEPSEEK_API_KEY');
}
