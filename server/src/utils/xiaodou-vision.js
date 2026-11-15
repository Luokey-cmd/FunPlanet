import { prisma } from '../db.js';
import { chatCompletionRaw } from './openai-compatible.js';
import { MAJOR_CATEGORIES } from './xiaodou-tools.js';

const MAX_BYTES = 4 * 1024 * 1024;

function parseVisionJson(raw) {
  const text = String(raw ?? '');
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

export async function analyzeShoppingImage({ dashscope, imageBase64, mimeType }) {
  const mime = ['image/jpeg', 'image/png', 'image/webp'].includes(String(mimeType))
    ? String(mimeType)
    : 'image/jpeg';
  const raw = String(imageBase64 ?? '').replace(/^data:[^;]+;base64,/, '').replace(/\s/g, '');
  if (!raw) throw new Error('图片数据为空');

  const bytes = Buffer.from(raw, 'base64');
  if (bytes.length === 0 || bytes.length > MAX_BYTES) {
    throw new Error('识图图片需在 4MB 以内');
  }

  const catalog = await prisma.product.findMany({
    select: { id: true, name: true, majorCategory: true },
    orderBy: { sales: 'desc' },
    take: 80,
  });
  const list = catalog.map((p) => `${p.id}｜${p.majorCategory}｜${p.name}`).join('\n');

  const vlModel = process.env.QWEN_VL_MODEL || 'qwen-vl-plus';
  const message = await chatCompletionRaw({
    apiKey: dashscope.apiKey,
    baseUrl: dashscope.baseUrl,
    model: vlModel,
    skipThinking: true,
    timeoutMs: 40000,
    temperature: 0.1,
    maxTokens: 280,
    messages: [
      {
        role: 'user',
        content: [
          { type: 'image_url', image_url: { url: `data:${mime};base64,${raw}` } },
          {
            type: 'text',
            text:
              '你是趣玩星球店内导购的视觉识别。用户拍了一件潮玩/文具/手办等物品。' +
              `大分类只能是：${MAJOR_CATEGORIES.join('、')}。` +
              '对照下面店内在售清单，判断最接近的一款（可空）以及检索关键词。\n' +
              `店内商品：\n${list}\n\n` +
              '只输出 JSON：{"productId":"最接近的id或空字符串","majorCategory":"六类之一","query":"2到6个中文检索词","notes":"一句外观描述"}。' +
              'productId 必须来自清单，对不上就留空。不要编造价格。',
          },
        ],
      },
    ],
  });

  const parsed = parseVisionJson(message.content);
  const allowedIds = new Set(catalog.map((p) => p.id));
  const productId = allowedIds.has(String(parsed?.productId ?? '')) ? String(parsed.productId) : '';
  const majorCategory = MAJOR_CATEGORIES.includes(parsed?.majorCategory) ? parsed.majorCategory : '';
  const query = String(parsed?.query ?? '').trim().slice(0, 40);
  const notes = String(parsed?.notes ?? '').trim().slice(0, 80);

  return {
    productId,
    majorCategory,
    query: query || notes || '潮玩',
    notes,
  };
}

export function formatVisionHint(vision) {
  const parts = ['用户发来一张商品照片，请按视觉结果搜店内同款或同类，不要编造未搜到的商品。'];
  if (vision.majorCategory) parts.push(`品类：${vision.majorCategory}`);
  if (vision.query) parts.push(`关键词：${vision.query}`);
  if (vision.notes) parts.push(`外观：${vision.notes}`);
  if (vision.productId) parts.push(`最接近商品 id：${vision.productId}，可优先推荐它和同类。`);
  return parts.join('\n');
}
