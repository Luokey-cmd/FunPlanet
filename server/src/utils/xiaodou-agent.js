import { prisma } from '../db.js';
import { log } from './log.js';
import { chatCompletion, streamChatCompletion } from '../deepseek.js';
import { APP_KNOWLEDGE } from '../app-knowledge.js';
import { serializeProduct } from './product.js';
import { chatCompletionRaw, streamChatEvents, streamChatText } from './openai-compatible.js';
import { analyzeShoppingImage, formatVisionHint, formatImageQuestionHint } from './xiaodou-vision.js';
import {
  executeXiaodouTool,
  MAJOR_CATEGORIES,
  toolResultForModel,
  XIAODOU_TOOLS,
  XIAODOU_GUIDE_TOOLS,
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
      '4. 信息不够只问 1 个问题。送礼或挑选时，先看关键信息齐不齐：送谁（或什么场景）、想要哪一类、预算多少——星愿档案里有的先用档案填，不重复问；真缺了关键的，先提问再抽牌，不许信息不够就直接亮牌。\n' +
      '5. 价格只能复述工具返回的 ¥。\n' +
      '6. 谷子≠小卡，手办≠公仔。\n' +
      '7. 亮牌那一轮，正文只写 2 句：一句引出、一句建议；商品名、价格、特点句全在牌面上，正文不复述、不点名、不报价格，指代只用位置（第一张/中间那张/最后一张）。\n' +
      '8. 换一批：excludeIds 或 skip。\n' +
      '9. 加购：这条保底路线没有加购与下单工具，禁止声称已经放进背包或生成订单；推荐后引导用户点商品卡上的「加入购物车」。\n' +
      '10. 识图：若消息已含视觉结果，先按用户问的答——问图里东西本身就照视觉结果答；只有要找同款或同味道时才搜店内。不要假装看见像素。\n' +
      '11. 送礼：点到商品后用一句寄语，不要长篇。\n' +
      '12. 对比商品时必须下结论：先摆数据（价格/券后价、规格、销量评分、优惠适配，缺的数据明说没有），最后一句说清选谁、为什么，不许把判断推回用户。\n' +
      '13. 不许把判断过程写出来：像「用户说……，信息不够：……，规则：……」这种复述规则、盘算信息的句子绝对不许出现；想清楚了直接问或直接答。',
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
      '思考语言（硬规矩）：你的思考过程会原样展示给用户看，所以思考必须全程用中文，包括调用工具之前那一小段盘算（例如「用户在问深圳天气，我先查气象数据」），不许出现整句英文；专有名词可以保留英文，但工具名、参数名、函数名这类程序词连思考里也不许写——打算做什么用人话说（例如「他都不喜欢，我换一批没给他看过的」，不要写成「带 excludeIds 重新 draw_star_cards」）。\n' +
      '输出格式：App 是纯文本，禁止任何 markdown 符号（包括 ** 加粗、# 标题、链接、表格），分点用「1.」或「·」。\n' +
      '不许对用户提「工具、接口、系统提示、预设规则」这些内部词；被问到能不能联网、有没有深度思考时，不要讲原理，用一句人话带过，并落到你能帮他做的事上。\n' +
      `${archive}\n\n` +
      '## 查证规矩（最重要）\n' +
      '1. 店内事实（商品、价格、库存、订单、优惠券、会员、活动）只信工具返回的数据：价格只能复述工具返回的 ¥，会员等级、积分、券只认工具，没查到不要假设用户是任何等级；严禁用搜索结果回答店内价格与活动，搜到的店内信息一律不算数。\n' +
      '2. 店外事实（新闻、行情、政策、流行趋势、通用知识、网友评价）只信 web_search 搜回来的结果：需要最新信息时先调 web_search 再答，并自然带一句信息的时间或来源（例如「我刚查了下，截至今天……」）；搜到的资料不够新（比如是昨天的）也要用，把日期标清楚再给；只有确实什么相关内容都没搜到时，才说没查到，不许编。\n' +
      '3. 天气必须先调 get_weather 拿气象数据，不要用搜索结果答天气；工具没拿到数据时，再如实说明或退回搜索。\n' +
      '4. 复杂问题（分析、对比、规划、算账）先想清楚再开口，只给想好的结论，不许把思考过程原样倒给用户。思考时必须用中文思考，不许用英文（专有名词除外；工具名、参数名这类程序词不许出现在思考里，用人话说打算）——思考内容会展示给用户，整段英文用户看不懂。\n' +
      '5. 一句话里既有店内又有店外时，两边都查齐再答，不要只答一半。\n\n' +
      '## 导购规则\n' +
      '1. 闲聊正常答，不搜货，不把话题强行拐去卖货。\n' +
      '2. App 用法、VIP、券：get_promotions / get_user_context。\n' +
      '3. 需求清楚时优先 draw_star_cards（三张星牌），不要一次甩很多热销。\n' +
      '4. 信息不够只问 1 个问题。送礼或挑选时，先看关键信息齐不齐：送谁（或什么场景）、想要哪一类、预算多少——星愿档案里有的先用档案填，不重复问；真缺了关键的，先提问再抽牌，不许信息不够就直接 draw_star_cards 亮牌。\n' +
      '5. 谷子≠小卡，手办≠公仔。\n' +
      '6. 亮牌那一轮，正文只写 2 句：一句引出（比如「给你挑了三张」）、一句建议（拿不准选哪张时选哪张）。商品名、价格、特点句全在牌面上，正文一律不复述、不点名、不报价格；要指代某张牌只许用位置（第一张/中间那张/最后一张）。特点句是系统按真实数据算好、放在牌面上的（工具结果的 trait），你心里有数即可，不要说出来。\n' +
      '7. 换一批由用户在牌面点「下一批」自己翻，不用你处理；用户在对话里明确说换一批时，带 excludeIds 重新 draw_star_cards。\n' +
      '8. 加购用 add_to_cart 真加，不要再提确认条。\n' +
      '9. 识图：消息里带视觉结果时，先看用户问什么——问图里东西本身或店外的事（是什么、市面多少钱、怎么做）就正面回答，需要最新行情先联网查；只有明确要找同款/同类/想买时才搜店内。不要假装看见像素，也不要默认把话题拽回店内找货。\n' +
      '10. 送礼：点到商品后用一句寄语，不要长篇。\n' +
      '11. 对比商品时必须下结论：先摆数据（价格/券后价、规格、销量评分、优惠适配，缺的数据明说没有），最后一句说清选谁、为什么，不许把判断推回用户。\n' +
      '12. 不许把判断过程写出来：像「用户说……，信息不够：……，规则：……」这种复述规则、盘算信息的句子，思考和正文里都绝对不许出现；想清楚了就直接对用户提问或回答。\n\n' +
      '## 办事规矩（能真办事，就不要只动嘴）\n' +
      '1. 用户明确要你办的事，用工具真办：领券 claim_coupon、加购物车 add_to_cart、改数量 update_cart、收藏 add_favorite、写备注 set_order_note、生成待付款订单 create_order。办完的结果会自动记进办事清单给用户看，你在正文里一句话确认即可，不要逐条复述清单。\n' +
      '2. 只有用户明确表达了意图才动手：说「就它了/买这个/帮我下单」才 create_order；说「先加购物车」就只 add_to_cart，不要自作主张替他下单；只是咨询、对比时不许动手。\n' +
      '3. 付款是唯一的闸：你最多把订单生成到待付款，绝不能说「已经下单成功/已经付款」；生成订单后把应付金额说清，并提醒他在清单卡里点「确认下单」付款。\n' +
      '4. 工具返回失败（action.status 是 failed）时如实转告原因，不要假装办成、不要换个说法糊弄过去；可以顺带给一个能点的下一步（如先加地址、先领别的券）。\n' +
      '5. 用户交代备注或贺卡内容时先 set_order_note 记下，同一轮里再 create_order 会自动带上，不用重复问。\n' +
      '6. 下单前若有一张他能领、且明显能省钱的券（get_promotions 里查得到），可以先 claim_coupon 再 create_order，create_order 会自动挑最划算的已领券抵扣。\n' +
      '7. 订单的事走订单工具：问订单到哪了、发货没，先 get_my_orders 查，只信它返回的状态和物流；取消订单用 cancel_order、申请售后用 apply_after_sale，都要先查到订单 id 再动手，用户没指明哪一笔时先问清楚，不许自己挑一笔。售后只是提交申请等后台处理，别说已经退款。\n' +
      '8. 提问时带选项：你这一轮要向用户提问题时，同时调用 suggest_options，把 3~4 个他最可能点的短回答一起给出来（界面会挂成按钮给他点）；一次只问一个问题，选项只对这一个问题；陈述、亮牌、办事的轮次不要调用它，正文里也不要把选项再念一遍。\n' +
      '9. 工具结果里的金额和数量都是服务端复查过的真实数据，汇报时照它说，不要自己再算一遍改口。',
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

// 思考展示前的「去程序词」清洗（2026-11-23 hx 截图实锤后加）：
// 思考里夹了工具名、参数名这类程序标识时，含标识的那一句整句
// 不展示。输入一整轮思考文本，输出清洗后的文本（可能为空串）。
// 为什么整句丢而不是只删那个词：删完词的句子多半不通顺（「带
// 重新。」），整句丢掉用户无感，漏一个词用户立刻出戏。
// 判为程序标识的：下划线命名（draw_star_cards）、反引号代码段、
// 小写开头驼峰词（excludeIds）。商品英文名多是全大写或普通单词，
// 不受影响；DeepSeek 这类首字母大写的词靠词边界避开；iPhone 这
// 类日常词用放行名单兜底。
const THINKING_CAMEL_ALLOW = new Set(['iPhone', 'iPad', 'iOS']);
function sentenceHasCodeId(sentence) {
  if (sentence.includes('`')) return true;
  if (/[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+/.test(sentence)) return true;
  const camels = sentence.match(/\b[a-z]+[A-Z][A-Za-z0-9]*\b/g) || [];
  return camels.some((word) => !THINKING_CAMEL_ALLOW.has(word));
}
// 元叙述整句不展示（2026-11-23 hx 截图实锤第二类）：思考是给用户
// 看的旁白，不是判断过程的倒带——「用户说……，信息不够：……，
// 规则：只问 1 个问题」这种复述规则、盘算槽位的话整句丢。判据取
// 几个内部说法（规则带冒号、信息不够、用户说、槽位、未启程、
// 只问 1 个问题）；正常旁白不会这么说话，误伤面小。注意「退货
// 规则」这类用户话题不带冒号、不在判据里，不受影响。
const THINKING_META_RE = /(规则[:：]|信息不够|用户说|槽位|未启程|档案暂|只问\s*[一1]\s*个|问\s*[一1]\s*个问题|先问\s*[一1]\s*个问题|用户就是想|用户只是想|用户应该是想|可以理解为)/;
function sentenceIsMetaNarration(sentence) {
  if (THINKING_META_RE.test(sentence)) return true;
  // 引着用户原话再下判断的（「翻三张牌」可以理解为……）也是盘算腔，
  // 正常旁白不会这么引；带「」且在讲「理解/意思」的整句不展示。
  return sentence.includes('「') && /(理解为|意思是)/.test(sentence);
}
function sanitizeThinking(text) {
  const parts = String(text).split(/(?<=[。！？!?；;\n])/);
  return parts
    .filter((part) => !sentenceHasCodeId(part) && !sentenceIsMetaNarration(part))
    .join('')
    .trim();
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
    const raw = buffer;
    buffer = '';
    if (!raw) return null;
    // 先去程序词再过语言检查：清洗后整段没了就不展示；长度门槛
    // 也按清洗后的算，脏句被丢后剩下的短报幕照样拦得住。
    const text = sanitizeThinking(raw);
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
  // 办事一轮的共享暂存（先记备注、后下单自动带上，靠它传递）与
  // 本轮最近一次抽牌的批次元数据（总数/还有没有下一批/特点句），
  // 随 fate_cards 事件一起发给 App 做批次翻页。
  const turnState = {};
  let lastDrawMeta = null;
  const homeworkSeen = new Set();
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
  let produced = false; // 本轮有没有产出任何实质内容（正文/卡片/清单/功课），结尾要查账
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
      if (sink.text) produced = true;
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
        result = await executeXiaodouTool(call.name, call.arguments, { userId, messages, dashscope, smartModel, turnState });
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
        if (result.ok !== false && Array.isArray(result.cards)) {
          const traits = {};
          for (const card of result.cards) traits[card.id] = card.trait;
          lastDrawMeta = {
            totalCount: result.totalCount ?? 0,
            hasMore: Boolean(result.hasMore),
            drawArgs: result.drawArgs ?? {},
            traits,
          };
        }
      }
      if (call.name === 'get_product_detail' && result.fullProduct) {
        collectProducts(byId, [result.fullProduct]);
        offerCards = true;
      }
      if (call.name === 'propose_add_to_cart' && result.fullProduct) {
        pendingCart.push(result.fullProduct);
      }
      // 模型自带选项：提问的那一轮它会顺手调 suggest_options，选项
      // 先收进 turnState，整轮说完再发内部事件给外层定夺（亮了牌、
      // 办了事的轮次不挂选项，免得用户分心）。
      if (call.name === 'suggest_options' && Array.isArray(result?.suggestedOptions)) {
        turnState.suggestedOptions = result.suggestedOptions;
      }
      // 办事结果：办成或没办成都发一条 actions 事件，App 实时记进
      // 清单。改购物车数量同轮多次只占一行——把明细攒在 turnState
      // 里重写同一条记录（id 不变，App 按 id 覆盖）。
      if (result?.action) {
        let action = result.action;
        if (action.type === 'cart_update') {
          const merged = (turnState.cartUpdate ??= { items: new Map(), action: null });
          if (result.cartUpdateItem) {
            merged.items.set(result.cartUpdateItem.productId, result.cartUpdateItem);
          }
          if (!merged.action) merged.action = action;
          const parts = [...merged.items.values()].map((item) =>
            item.quantity === 0 ? `${item.name} 已移除` : `${item.name} 改为 ${item.quantity} 件`,
          );
          merged.action = {
            ...merged.action,
            detail: parts.length > 2 ? `共调整 ${parts.length} 件商品` : parts.join('；'),
          };
          action = merged.action;
        }
        yield { type: 'actions', action };
        produced = true;
      }
      // 功课段：数字只从工具结果里摘，同轮同句不重复发，最多 5 条。
      for (const entry of homeworkFrom(call.name, result)) {
        if (homeworkSeen.size >= 5 || homeworkSeen.has(entry.text)) continue;
        homeworkSeen.add(entry.text);
        yield { type: 'homework', entry };
        produced = true;
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
      if (sink.text) produced = true;
    } catch (error) {
      // 收尾轮卡住就直接结束这一轮，别为最后一句把整轮拖垮；
      // 其他错误照常抛出去走保底链。
      if (error?.code !== 'STREAM_STALL') throw error;
      console.warn('[xiaodou-agent] unified final round stalled, end turn:', error.message);
    }
  }

  if (offerCards && byId.size > 0) {
    produced = true;
    const products = [...byId.values()].slice(0, 3);
    if (fateRoles.length >= 2) {
      yield {
        type: 'fate_cards',
        products,
        roles: fateRoles.slice(0, products.length),
        ...(lastDrawMeta ? { batch: lastDrawMeta } : {}),
      };
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
    produced = true;
    yield { type: 'cart_confirm', products: pendingCart.slice(0, 3) };
  }

  // 模型自带选项：整轮说完再交出去，由外层 withQuestionOptions
  // 决定发不发（内部事件，不直接给 App）。
  if (turnState.suggestedOptions?.length) {
    yield { type: 'suggested_options', options: turnState.suggestedOptions };
  }

  // 结尾查账：模型空转一整轮（只吐了被过滤掉的思考、正文为空、
  // 没查成任何工具、没办成任何事）时，不许静默交白卷——抛出去
  // 让 streamXiaodouAgent 走保底链，总得有人把这轮接住
  // （2026-11-23 全面自查修，与问题三「问题没到大脑」同类）。
  if (!produced) {
    throw new Error('统一大脑本轮没有产出任何内容');
  }
}

// 功课段条目：把一次工具结果翻成一句带真实数字的「做了什么」，
// 可点开的候选明细只带名字与价格。数字只能来自工具返回，
// 这里不许出现任何估算或约数（全流程稿拍 3 的硬规矩）。
function homeworkFrom(toolName, result) {
  if (!result || result.ok === false) return [];
  const entries = [];
  const candidateOf = (item) => ({ id: item.id, name: item.name, price: Number(item.price ?? 0) });
  if (toolName === 'search_products' && (result.totalCount ?? 0) > 0) {
    entries.push({
      text: `按你的条件找到 ${result.totalCount} 件商品`,
      candidates: (result.products ?? []).map(candidateOf),
    });
  }
  if (toolName === 'draw_star_cards' && Array.isArray(result.cards) && result.cards.length > 0) {
    entries.push({
      text: `从 ${result.totalCount ?? result.cards.length} 件里挑出 ${result.cards.length} 张牌，价格、销量、评分都比过`,
      candidates: result.cards.map(candidateOf),
    });
    if ((result.reviewTotal ?? 0) > 0) {
      entries.push({ text: `看了这几件的用户评价，一共 ${result.reviewTotal} 条`, candidates: [] });
    }
  }
  if (toolName === 'get_product_detail' && result.product) {
    const p = result.product;
    entries.push({
      text: `细看了「${p.name}」：¥${p.price} · 已售 ${p.sales ?? 0} 件`,
      candidates: [],
    });
  }
  if (toolName === 'get_user_context') {
    const coupons = result.unusedCoupons ?? [];
    if (coupons.length > 0) {
      entries.push({ text: `翻了你的券包：${coupons.length} 张券还没用`, candidates: [] });
    }
    entries.push({ text: `看了你的会员档案：VIP${result.vipLevel ?? 1}`, candidates: [] });
  }
  return entries;
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
      // 保底只给查说工具：办事工具在保底手里不记账、备注还会丢
      // （见 xiaodou-tools.js 的 XIAODOU_GUIDE_TOOLS 说明）。
      tools: XIAODOU_GUIDE_TOOLS,
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
        result = await executeXiaodouTool(name, args, { userId, messages, dashscope });
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

// 提问选项（hx 2026-11-23 定）：小豆这一轮以问句收尾、且没亮牌没给
// 商品时，服务端顺手生成 3~4 个用户最可能点的短回答，随 options 事件
// 下发，App 在气泡下渲染成按钮，点一下就当用户回了这句，省得打字。
// 输入：dashscope 配置、导购这句提问、用户上一句原话。
// 输出：2~4 个短选项的数组；生成失败、解析不出、数量不够都返回空
// 数组（当没有选项）——选项是锦上添花，绝不能因为它拖住或弄丢正文。
async function generateQuestionOptions({ dashscope, question, userText }) {
  try {
    const message = await chatCompletionRaw({
      ...dashscope,
      messages: [
        {
          role: 'system',
          content:
            '你替用户预备回答选项。给你一句导购的提问，你输出用户最可能点的 3 到 4 个简短回答。' +
            '每个选项不超过 8 个字，是用户会直接说出口的话（例如「送朋友」「送对象」「100元内」「不限」）。' +
            '只输出一个 JSON 数组，不要任何解释、不要 markdown，例如 ["送朋友","送对象","送家人","送同担"]。',
        },
        {
          role: 'user',
          content: `用户刚说：${userText || '（没说什么）'}\n导购问：${question}\n给出回答选项：`,
        },
      ],
      temperature: 0.4,
      maxTokens: 200,
      timeoutMs: 8000,
    });
    const raw = String(message?.content ?? '');
    const match = raw.match(/\[[\s\S]*?\]/);
    if (!match) return [];
    const parsed = JSON.parse(match[0]);
    if (!Array.isArray(parsed)) return [];
    const options = [];
    for (const item of parsed) {
      const text = String(item ?? '').trim();
      if (text.length < 1 || text.length > 12) continue;
      if (options.includes(text)) continue;
      options.push(text);
      if (options.length >= 4) break;
    }
    return options.length >= 2 ? options : [];
  } catch (error) {
    log.warn('小豆', '提问选项没生成出来（不影响正文，用户打字回答就行）');
    return [];
  }
}

// 该不该带选项，只看两个硬条件：这一轮在向用户提问，且没亮过牌、
// 没给过商品——有牌时用户的下一步是选牌，不该再被选项分心。
// 提问的判据不能只认「问号结尾」（2026-11-23 真机实锤）：模型常把
// 问题包在中间、末尾再缀一句说明（「……还是送人？或者你直接说个
// 品类也行，我好给你翻出对味的三张。」），只认结尾问号就漏了大半。
// 改判：问号出现在正文最后 80 字内就算这一轮在提问；问号离结尾
// 太远的（正文主体在讲别的事）不给选项，防误挂。
// 带图鉴定那条路自带「找同款/同味道」的选择按钮，不走这里。
function endsWithQuestion(text) {
  const trimmed = String(text ?? '').trim();
  if (trimmed.length < 4) return false;
  if (/[？?]\s*$/.test(trimmed)) return true;
  const lastQuestionAt = Math.max(trimmed.lastIndexOf('？'), trimmed.lastIndexOf('?'));
  return lastQuestionAt >= 0 && trimmed.length - lastQuestionAt <= 80;
}

// 提问选项的主路与安全网（hx 2026-11-23 晚定：要智能一点，别全靠猜）：
// 主路——统一大脑提问时自己调 suggest_options 带上选项（最懂自己在
// 问什么），本函数收到 suggested_options 内部事件先扣下，整轮结束
// 确认没亮牌、没办事、没给商品，才转成 options 事件发给 App。
// 安全网——模型忘了带（或保底路线压根没有这个工具）时，才用
// endsWithQuestion 判据 + 事后补生成兜底。源流抛错时直接往外抛
// （外层的降级守卫照常接住），不会补选项。
async function* withQuestionOptions(source, { dashscope, userText }) {
  let fullText = '';
  let sawCards = false;
  let sawActions = false;
  let modelOptions = null;
  for await (const event of source) {
    if (event.type === 'text') fullText += String(event.content ?? '');
    if (event.type === 'fate_cards' || event.type === 'products' || event.type === 'cart_confirm') {
      sawCards = true;
    }
    if (event.type === 'actions') sawActions = true;
    if (event.type === 'suggested_options') {
      modelOptions = Array.isArray(event.options) ? event.options : null;
      continue;
    }
    yield event;
  }
  if (modelOptions && modelOptions.length >= 2 && !sawCards && !sawActions) {
    yield { type: 'options', options: modelOptions };
    return;
  }
  if (sawCards || !endsWithQuestion(fullText)) return;
  const options = await generateQuestionOptions({
    dashscope,
    question: fullText.trim().slice(-200),
    userText,
  });
  if (options.length > 0) yield { type: 'options', options };
}

export async function* streamXiaodouAgent(
  messages,
  { dashscope, deepseek, userId, imageBase64, mimeType, starwish, vision } = {},
) {
  // 带图消息分两路（2026-11-23 hx 实锤后改）：只有图没字时 App
  // 会补一句默认的找同款文案，这种才走「先鉴定、再让用户选找
  // 同款还是同味道」的拍图找货老流程；用户打了字问别的事（拿
  // 炒面照片问在深圳卖多少钱），图只是问题的一半——视觉结果
  // 降级为背景信息交给统一大脑，先正面回答他问的，不许硬拽
  // 回找同款。老流程是整段拦截：问题根本到不了大脑，必改。
  let imageIntro = null;
  if (dashscope?.apiKey && imageBase64) {
    const userText = (lastUserMessage(messages) || '').trim();
    const isDefaultAsk = !userText || userText === '帮我看看店里有没有同款或同类';
    if (isDefaultAsk) {
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
        log.error('小豆', '看图失败，这张照片没鉴定成（多半是视觉模型或网络的问题）', error);
        yield {
          type: 'appraisal',
          content: '瓶子晃了一下，这张照片我还看不真切。换一张更清楚的，或告诉我品类。',
          vision: null,
        };
        return;
      }
    }
    try {
      const result = await analyzeShoppingImage({ dashscope, imageBase64, mimeType });
      imageIntro = formatImageQuestionHint(result);
    } catch (error) {
      log.error('小豆', '看图失败，这张照片没鉴定成（多半是视觉模型或网络的问题）', error);
      imageIntro =
        '用户发来一张照片，但这次视觉识别失败、没看清图里是什么。' +
        '他问的事若与图有关，如实说没看清、请他补一句图里是什么；与图无关的照常回答。';
    }
  }

  let guideMessages = messages;
  if (imageIntro) {
    guideMessages = [{ role: 'user', content: imageIntro }, ...messages];
  } else if (vision && typeof vision === 'object') {
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
    // 降级守卫按「有没有实质内容已经到用户眼前」算账（正文、卡片、
    // 清单、功课都算；状态与思考只是进度，不算）。已经给了实质
    // 内容才失败的：直接收尾，绝不再叠一份别家的答案打架；什么
    // 都没给成的：才轮到下一档接住（2026-11-23 全面自查修——
    // 以前只认正文，保底只给卡片没给正文时会再叠一份 DeepSeek
    // 的答案与卡片，双份打架）。
    let unifiedYielded = false;
    try {
      for await (const event of withQuestionOptions(runUnifiedAgent(guideMessages, dashscope, { userId, starwish }), { dashscope, userText: lastUserMessage(guideMessages) })) {
        if (event.type !== 'status' && event.type !== 'thinking') unifiedYielded = true;
        yield event;
      }
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] unified failed, fallback guide:', error.message);
      if (unifiedYielded) return;
    }
    let guideYielded = false;
    try {
      for await (const event of withQuestionOptions(runGuideFallback(guideMessages, dashscope, { userId, starwish }), { dashscope, userText: lastUserMessage(guideMessages) })) {
        if (event.type !== 'status' && event.type !== 'thinking') guideYielded = true;
        yield event;
      }
      return;
    } catch (error) {
      console.warn('[xiaodou-agent] qwen failed, fallback deepseek:', error.message);
      if (guideYielded) return;
    }
  }

  if (deepseek?.apiKey) {
    yield* runDeepseekFallback(guideMessages, deepseek);
    return;
  }

  throw new Error('未配置 DASHSCOPE_API_KEY 或 DEEPSEEK_API_KEY');
}
