// 天气数据模块：给小豆智能模式提供「正经」的实时天气数据。
//
// 为什么不用联网搜索查天气：搜索引擎翻到的是网页存货，经常是昨天的、
// 甚至别的城市的页面，模型只能诚实拒答。天气是结构化数据，就该问
// 气象服务本身。这里用 Open-Meteo（免费、免密钥、免注册），它聚合
// 各国气象局的数值预报，中国城市覆盖可用；哪天要商用再换和风天气等
// 国内服务商，本文件的导出函数签名不用变。
//
// 对外只导出 buildWeatherContext(messages)：
// 输入：小豆的对话消息数组（{ role, content}，content 为纯文本）。
// 输出：识别出天气问题且城市明确、且数据拿到手时，返回一段可直接
// 塞给模型的「天气数据 + 回答要求」文本；其余情况一律返回
// null（不是天气问题、没说清城市、接口失败），调用方照常走
// 原来的联网搜索流程，天气模块永远不许把聊天弄挂。
// 坑：地名解析靠 Open-Meteo 的地理编码库，县级小地方可能解析不到，
// 解析不到就返回 null 走搜索兜底，不要硬编一个同名大城市。

const GEOCODING_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const FETCH_TIMEOUT_MS = 6000;
const BRIEF_CACHE_MS = 10 * 60 * 1000; // 同一城市 10 分钟内复用，省接口调用

// 出现这些词才认为用户在问天气（购物句里偶尔带「下雨天」之类，没解析出
// 城市时本模块什么都不做，所以误触发的代价为零）。
const WEATHER_WORDS = [
'天气',
'气温',
'温度',
'多少度',
'下雨',
'下雪',
'降雨',
'降水',
'台风',
'雾霾',
'空气质量',
'带伞',
'冷不冷',
'热不热',
];

// 从一句话里剥离天气问法后剩下的部分，当作城市候选。
// 例：「北京今天天气怎么样」->「北京」；「深圳明天会下雨吗」->「深圳」。
const CITY_STRIP_WORDS = [
...WEATHER_WORDS,
'今天',
'明天',
'后天',
'昨天',
'现在',
'早上',
'上午',
'中午',
'下午',
'晚上',
'周末',
'怎么样',
'如何',
'会不会',
'会',
'吗',
'呢',
'啊',
'呀',
'查一下',
'查查',
'帮我看看',
'看看',
'想知道',
'的',
'了',
];

// 这些短句是时间追问或应答，不是城市名，不能拿去解析。
const NOT_CITY_WORDS = new Set([
'今天',
'明天',
'后天',
'昨天',
'现在',
'好的',
'谢谢',
'可以',
'不用',
'是的',
'嗯',
'哦',
]);

// WMO 天气代码 -> 中文说法（Open-Meteo 返回的是这套代码）。
const WEATHER_CODE_TEXT = {
0: '晴',
1: '晴间多云',
2: '多云',
3: '阴',
45: '雾',
48: '雾凇',
51: '毛毛雨',
53: '毛毛雨',
55: '毛毛雨',
56: '冻毛毛雨',
57: '冻毛毛雨',
61: '小雨',
63: '中雨',
65: '大雨',
66: '冻雨',
67: '冻雨',
71: '小雪',
73: '中雪',
75: '大雪',
77: '雪粒',
80: '阵雨',
81: '阵雨',
82: '强阵雨',
85: '阵雪',
86: '阵雪',
95: '雷阵雨',
96: '雷阵雨伴冰雹',
99: '雷阵雨伴冰雹',
};

const geocodeCache = new Map(); // 城市名 -> 地理编码结果（长期有效）
const briefCache = new Map(); // 城市名 -> { at, text}

function messageText(message) {
return typeof message?.content === 'string'? message.content.trim(): '';
}

function hasWeatherWord(text) {
return WEATHER_WORDS.some((word) => text.includes(word));
}

// 把一句话剥掉天气问法，剩下的当城市候选；剩不下、太长、或是时间词
// 之类不是地名的，返回空串。
function extractCityCandidate(text) {
let rest = String(text?? '');
for (const word of CITY_STRIP_WORDS) {
rest = rest.split(word).join('');
}
rest = rest.replace(/[\s，。！？、,.!?~～·：:；;（）()「」'"]/g, '');
if (rest.length < 2 || rest.length > 8) return '';
if (NOT_CITY_WORDS.has(rest)) return '';
return rest;
}

// 判断这轮对话是不是在问天气，并定出城市。返回城市字符串或 null。
// 三种命中：
// 1. 本句就是天气问法且带城市（「北京今天天气怎么样」）；
// 2. 上文在聊天气，本句只补了城市（「深圳」）；
// 3. 上文问过带城市的天气，本句是时间追问（「明天呢」），沿用旧城市。
export function detectWeatherCity(messages) {
const list = Array.isArray(messages)? messages: [];
const userTexts = list.filter((m) => m?.role === 'user').map(messageText).filter(Boolean);
if (userTexts.length === 0) return null;
const last = userTexts[userTexts.length - 1];

if (hasWeatherWord(last)) {
const own = extractCityCandidate(last);
if (own) return own;
// 本句没带城市：往前找最近一次带城市的天气问法（连续追问时沿用）。
for (let i = userTexts.length - 2; i >= 0; i -= 1) {
if (!hasWeatherWord(userTexts[i])) continue;
const candidate = extractCityCandidate(userTexts[i]);
if (candidate) return candidate;
}
return null;
}

// 本句没有天气词：只有上文确实在聊天气时，才把短句当补充信息。
const recent = list.slice(-4);
const inWeatherContext = recent.some((m) => hasWeatherWord(messageText(m)));
if (!inWeatherContext) return null;

// 情形 2：本句就是一个城市名（「深圳」）。
const asCity = extractCityCandidate(last);
if (asCity && last.length <= 8) return asCity;

// 情形 3：纯时间追问（「明天呢」），沿用上文天气问法里的城市；
// 其他短句（「好的」「谢谢」）不触发，免得答非所问。
const isDayFollowup = ['今天', '明天', '后天', '周末', '星期', '晚上', '早上'].some((w) =>
  last.includes(w),
);
if (!isDayFollowup) return null;
for (let i = userTexts.length - 2; i >= 0; i -= 1) {
if (!hasWeatherWord(userTexts[i])) continue;
const candidate = extractCityCandidate(userTexts[i]);
if (candidate) return candidate;
}
return null;
}

async function fetchJson(url) {
const controller = new AbortController();
const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
try {
const response = await fetch(url, { signal: controller.signal});
if (!response.ok) throw new Error(`weather http ${response.status}`);
return await response.json();
} finally {
clearTimeout(timer);
}
}

// 城市名 -> 经纬度与规范地名。解析不到返回 null（不要猜同名城市）。
async function geocodeCity(city) {
if (geocodeCache.has(city)) return geocodeCache.get(city);
const url = `${GEOCODING_URL}?name=${encodeURIComponent(city)}&count=1&language=zh&format=json`;
const data = await fetchJson(url);
const hit = Array.isArray(data?.results)? data.results[0]: null;
const place = hit
? {
name: [hit.admin1, hit.name].filter(Boolean).join(' '),
latitude: hit.latitude,
longitude: hit.longitude,
timezone: hit.timezone || 'Asia/Shanghai',
}
: null;
geocodeCache.set(city, place);
return place;
}

function codeText(code) {
return WEATHER_CODE_TEXT[code]?? '天气状况未知';
}

function formatDayLabel(dateText, index) {
const [, month, day] = String(dateText).split('-');
const label = index === 0? '今天': index === 1? '明天': '后天';
return `${label}（${Number(month)}月${Number(day)}日）`;
}

// 拉预报并整理成一段给模型看的数据简报。任何一步失败都抛错，由
// buildWeatherContext 兜成 null。
async function fetchWeatherBrief(city) {
const cached = briefCache.get(city);
if (cached && Date.now() - cached.at < BRIEF_CACHE_MS) return cached.text;

const place = await geocodeCity(city);
if (!place) return null;

const params = new URLSearchParams({
latitude: String(place.latitude),
longitude: String(place.longitude),
current: 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
daily: 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
timezone: place.timezone,
forecast_days: '3',
});
const data = await fetchJson(`${FORECAST_URL}?${params.toString()}`);
const current = data?.current;
const daily = data?.daily;
if (!current ||!daily?.time?.length) return null;

const lines = [`地点：${place.name}`];
const currentTime = String(current.time?? '').slice(11, 16);
lines.push(
`当前${currentTime? `（${currentTime}）`: ''}：${codeText(current.weather_code)}，` +
`${current.temperature_2m}℃，体感 ${current.apparent_temperature}℃，` +
`湿度 ${current.relative_humidity_2m}%，风速 ${current.wind_speed_10m} km/h`,
);
daily.time.forEach((dateText, i) => {
const probability = daily.precipitation_probability_max?.[i];
lines.push(
`${formatDayLabel(dateText, i)}：${codeText(daily.weather_code?.[i])}，` +
`最高 ${daily.temperature_2m_max?.[i]}℃，最低 ${daily.temperature_2m_min?.[i]}℃` +
`${probability == null? '': `，降水概率 ${probability}%`}`,
);
});

const text = lines.join('\n');
briefCache.set(city, { at: Date.now(), text});
return text;
}

// 智能模式入口：是天气问题就先拿真实数据，拼成一段系统注记给模型。
// 返回 null 表示「这轮别管天气」，调用方照常走联网搜索。
export async function buildWeatherContext(messages) {
const city = detectWeatherCity(messages);
if (!city) return null;
try {
const brief = await fetchWeatherBrief(city);
if (!brief) return null;
return (
'\n' +
`${brief}\n` +
'回答要求：直接用上面的数据回答，不要再说没查到、查不了；数据里没有的项目' +
'（例如空气质量）不要编；结合温度和降水概率，顺带给一句穿衣或带伞建议。'
);
} catch (error) {
console.warn('[weather] fetch brief failed:', error.message);
return null;
}
}
