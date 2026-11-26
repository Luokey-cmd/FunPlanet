import { log } from './log.js';
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

// 提示词预处理（2026-11-26 修正）：只做去空白，不再强制加「儿童绘本插画，温馨治愈」前缀。
// 旧版给每张图套同一句画风，结果用户选什么风格出来的都一个味；
// 内容安全靠 buildWanxParameters 的负面词 + 平台自身的审核拦截，不再靠改画风实现。
// 函数保留是为了不动 routes/ai.js 之外的调用面，进出都是同一段文本。
export function wrapSafePaintPrompt(prompt) {
  return String(prompt ?? '').trim();
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
    // 自动扩写关掉：平台扩写会把每个人的描述润色成同一种审美，图容易撞脸；
    // 关掉后模型直接按用户原话 + 所选风格前缀生成，差异和可控性都更好。
    parameters.prompt_extend = false;
    parameters.negative_prompt = '暴力，血腥，低俗，裸露，恐怖，畸形，低质量，模糊，水印';
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
        log.warn('AI绘画', `主模型没成，已用备用模型 ${currentModel} 生成成功`);
      }
      return { imageUrl, model: currentModel };
    } catch (error) {
      lastError = error;
      if (!isContentBlockedError(error.message)) {
        throw error;
      }
      log.warn('AI绘画', `内容被模型拦截（${currentModel}）：${error.message}`);
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
