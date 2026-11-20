import { Router } from 'express';
import { authRequired } from '../middleware/auth.js';

const router = Router();

function joinUrl(baseUrl, path) {
  return `${String(baseUrl).replace(/\/$/, '')}${path}`;
}

/** 华为等机型无系统语音弹窗：客户端录音后走千问 ASR。 */
router.post('/transcribe', authRequired, async (req, res) => {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ code: 500, message: '未配置 DASHSCOPE_API_KEY', data: null });
  }

  const audioBase64 = typeof req.body?.audioBase64 === 'string' ? req.body.audioBase64.trim() : '';
  const mimeType = typeof req.body?.mimeType === 'string' && req.body.mimeType.trim()
    ? req.body.mimeType.trim()
    : 'audio/mp4';

  if (!audioBase64) {
    return res.status(400).json({ code: 400, message: '缺少音频数据', data: null });
  }
  // Base64 膨胀后约 10MB 上限；原始约 7MB，短语音远不到。
  if (audioBase64.length > 14_000_000) {
    return res.status(400).json({ code: 400, message: '音频过长，请缩短后再说', data: null });
  }

  const dataUri = `data:${mimeType};base64,${audioBase64}`;
  const baseUrl = process.env.DASHSCOPE_COMPAT_BASE_URL
    || 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  const model = process.env.QWEN_ASR_MODEL || 'qwen3-asr-flash';

  try {
    const response = await fetch(joinUrl(baseUrl, '/chat/completions'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        stream: false,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'input_audio',
                input_audio: { data: dataUri },
              },
            ],
          },
        ],
        asr_options: {
          language: 'zh',
          enable_itn: true,
        },
      }),
      signal: AbortSignal.timeout(45000),
    });

    const raw = await response.text();
    if (!response.ok) {
      console.error('[voice/transcribe]', response.status, raw.slice(0, 400));
      return res.status(502).json({
        code: 502,
        message: '语音识别服务暂时不可用',
        data: null,
      });
    }

    let data;
    try {
      data = JSON.parse(raw);
    } catch (_) {
      return res.status(502).json({ code: 502, message: '语音识别返回格式错误', data: null });
    }

    const content = data?.choices?.[0]?.message?.content;
    let text = '';
    if (typeof content === 'string') {
      text = content;
    } else if (Array.isArray(content)) {
      text = content
        .map((part) => {
          if (typeof part === 'string') return part;
          if (part && typeof part.text === 'string') return part.text;
          return '';
        })
        .join('');
    }

    text = String(text || '').trim();
    return res.json({ code: 0, message: 'ok', data: { text } });
  } catch (error) {
    console.error('[voice/transcribe]', error);
    return res.status(500).json({
      code: 500,
      message: error?.message || '语音识别失败',
      data: null,
    });
  }
});

export default router;
