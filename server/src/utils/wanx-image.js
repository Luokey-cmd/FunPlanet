import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const assetsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../assets');
const WANX_ENDPOINT =
  'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
const DEFAULT_FALLBACK_MODEL = 'wan2.6-t2i';

export function formatWanxErrorMessage(message) {
  const text = String(message ?? '').trim();
  if (!text) return '生成失败，请稍后重试';
  if (/inappropriate content/i.test(text)) {
    if (/output data/i.test(text)) {
      return '生成结果被平台安全审核拦截，请换一段描述或调整风格后重试';
    }
    return '描述内容未通过平台安全审核，请修改后重试';
  }
  return text;
}

export function wrapSafePaintPrompt(prompt) {
  const text = String(prompt ?? '').trim();
  if (!text) return text;
  if (text.startsWith('儿童绘本插画')) return text;
  return `儿童绘本插画，画面温馨治愈、健康积极，${text}`;
}

function isContentBlockedError(message) {
  return /inappropriate content/i.test(String(message ?? ''));
}

function isWanx27Model(model) {
  return /wan2\.7|2\.7-image/i.test(String(model ?? ''));
}

function resolveWanxSize(model, size) {
  const raw = String(size ?? '').trim();
  if (isWanx27Model(model)) {
    return raw || '2K';
  }
  if (!raw || raw === '2K' || raw === '2048*2048') return '1280*1280';
  if (/^\d+\*\d+$/.test(raw)) return raw;
  return '1280*1280';
}

function buildWanxParameters(model, size) {
  const modelName = String(model ?? '');
  const parameters = {
    size: resolveWanxSize(modelName, size),
    n: 1,
    watermark: false,
  };

  if (!modelName.includes('2.7') && !isWanx27Model(modelName)) {
    parameters.prompt_extend = true;
    parameters.negative_prompt = '暴力，血腥，低俗，裸露，恐怖，畸形，写实人体';
  }

  return parameters;
}

async function requestWanxImage(prompt, { apiKey, model, size }) {
  const response = await fetch(WANX_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      input: {
        messages: [
          {
            role: 'user',
            content: [{ text: prompt }],
          },
        ],
      },
      parameters: buildWanxParameters(model, size),
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || (payload?.code && payload.code !== 'Success' && payload.code !== 'success')) {
    const message =
      payload?.message ||
      payload?.output?.message ||
      payload?.code ||
      `万相 API 错误 (${response.status})`;
    throw new Error(formatWanxErrorMessage(message));
  }

  const imageUrl = payload?.output?.choices?.[0]?.message?.content?.find((item) => item?.image)?.image;
  if (!imageUrl) {
    throw new Error('未获取到生成图片');
  }
  return imageUrl;
}

export async function generateWanxImage(
  prompt,
  { apiKey, model = DEFAULT_FALLBACK_MODEL, size = '2K', fallbackModel = DEFAULT_FALLBACK_MODEL } = {},
) {
  if (!apiKey) {
    throw new Error('未配置 DASHSCOPE_API_KEY');
  }

  const safePrompt = wrapSafePaintPrompt(prompt);
  const modelsToTry = [model];
  if (fallbackModel && !modelsToTry.includes(fallbackModel)) {
    modelsToTry.push(fallbackModel);
  }

  let lastError;
  for (const currentModel of modelsToTry) {
    try {
      const imageUrl = await requestWanxImage(safePrompt, { apiKey, model: currentModel, size });
      if (currentModel !== model) {
        console.warn('[wanx] fallback model succeeded', { from: model, to: currentModel });
      }
      return { imageUrl, model: currentModel };
    } catch (error) {
      lastError = error;
      if (!isContentBlockedError(error.message)) {
        throw error;
      }
      console.warn('[wanx] content blocked', { model: currentModel, message: error.message });
    }
  }

  throw lastError ?? new Error('生成失败，请稍后重试');
}

export async function persistRemoteImage(remoteUrl, userId) {
  const response = await fetch(remoteUrl);
  if (!response.ok) {
    throw new Error('图片下载失败');
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  if (buffer.length === 0) {
    throw new Error('图片数据为空');
  }

  const safeUserId = String(userId).replace(/[^a-zA-Z0-9_-]/g, '_');
  const dir = path.join(assetsRoot, 'images/ai-art', safeUserId);
  fs.mkdirSync(dir, { recursive: true });

  const filename = `${crypto.randomUUID()}.png`;
  fs.writeFileSync(path.join(dir, filename), buffer);

  return `assets/images/ai-art/${safeUserId}/${filename}`;
}
