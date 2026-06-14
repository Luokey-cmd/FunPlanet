import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { formatChinaDate } from '../utils/datetime.js';
import { fail, ok } from '../utils/response.js';
import { formatWanxErrorMessage, generateWanxImage, persistRemoteImage } from '../utils/wanx-image.js';

const router = Router();

const DAILY_LIMIT = 20;
const MAX_PROMPT_LEN = 500;

function serializeArtwork(row) {
  return {
    id: row.id,
    prompt: row.prompt,
    style: row.style || '',
    imagePath: row.imagePath,
    model: row.model,
    createdAt: row.createdAt.toISOString(),
  };
}

function chinaDayStartUtc() {
  const day = formatChinaDate(new Date());
  return new Date(`${day}T00:00:00+08:00`);
}

async function countTodayArtworks(userId) {
  return prisma.aiArtwork.count({
    where: {
      userId,
      createdAt: { gte: chinaDayStartUtc() },
    },
  });
}

router.get('/quota', authRequired, async (req, res) => {
  const used = await countTodayArtworks(req.user.sub);
  ok(res, {
    dailyLimit: DAILY_LIMIT,
    usedToday: used,
    remainingToday: Math.max(0, DAILY_LIMIT - used),
  });
});

router.get('/artworks', authRequired, async (req, res) => {
  const take = Math.min(Math.max(Number(req.query.limit) || 30, 1), 50);
  const rows = await prisma.aiArtwork.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: 'desc' },
    take,
  });
  ok(res, { artworks: rows.map(serializeArtwork) });
});

router.post('/draw', authRequired, async (req, res) => {
  const prompt = String(req.body?.prompt ?? '').trim();
  const style = String(req.body?.style ?? '').trim().slice(0, 32);

  console.log('[ai/draw] start', { userId: req.user.sub, promptLen: prompt.length, style });

  if (!prompt) {
    fail(res, 400, '请输入画面描述');
    return;
  }
  if (prompt.length > MAX_PROMPT_LEN) {
    fail(res, 400, `描述不能超过 ${MAX_PROMPT_LEN} 字`);
    return;
  }

  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    fail(res, 503, 'AI 绘画服务未配置');
    return;
  }

  const used = await countTodayArtworks(req.user.sub);
  if (used >= DAILY_LIMIT) {
    fail(res, 429, `今日创作次数已达上限（${DAILY_LIMIT} 次）`);
    return;
  }

  const model = process.env.WANX_MODEL || 'wan2.6-t2i';
  const size = process.env.WANX_SIZE || '1280*1280';

  try {
    const { imageUrl, model: usedModel } = await generateWanxImage(prompt, { apiKey, model, size });
    const imagePath = await persistRemoteImage(imageUrl, req.user.sub);
    const artwork = await prisma.aiArtwork.create({
      data: {
        userId: req.user.sub,
        prompt,
        style,
        imagePath,
        model: usedModel,
      },
    });

    ok(res, {
      artwork: serializeArtwork(artwork),
      remainingToday: Math.max(0, DAILY_LIMIT - used - 1),
    });
    console.log('[ai/draw] ok', { userId: req.user.sub, artworkId: artwork.id });
  } catch (error) {
    console.error('[ai/draw]', error);
    fail(res, 500, formatWanxErrorMessage(error.message));
  }
});

export default router;
