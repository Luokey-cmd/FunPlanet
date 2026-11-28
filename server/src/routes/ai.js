import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { formatChinaDate } from '../utils/datetime.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import { deletePersistedArtwork, formatWanxErrorMessage, generateWanxImage, persistRemoteImage } from '../utils/wanx-image.js';

const router = Router();

const DAILY_LIMIT = 20;
const MAX_PROMPT_LEN = 500;
// 画幅白名单：只认 App 画幅预设这五种尺寸，乱传一律回落方图（与 lib/models/ai_artwork.dart 的 aiRatioPresets 对齐，改尺寸两边一起改）。
const ALLOWED_SIZES = new Set(['1280*1280', '960*1280', '1280*960', '1280*720', '720*1280']);
// 单次只出 1 张（2026-11-28 hx 点名去掉两张候选）：App 不再传别的张数，这里也钉死。
const MAX_COUNT_PER_DRAW = 1;

function serializeArtwork(row) {
  return {
    id: row.id,
    prompt: row.prompt,
    style: row.style || '',
    imagePath: row.imagePath,
    model: row.model,
    moderationStatus: row.moderationStatus ?? 'visible',
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
    // 被后台隐藏的作品（moderationStatus=hidden）不再出现在列表里
    where: { userId: req.user.sub, moderationStatus: 'visible' },
    orderBy: { createdAt: 'desc' },
    take,
  });
  ok(res, { artworks: rows.map(serializeArtwork) });
});

// 批量删除自己的作品（App「我的作品」多选删除）：只删属于当前用户的行，
// 磁盘上的成图文件顺手清掉；混进别人的 id 会被过滤掉、不报错。
router.post('/artworks/delete', authRequired, async (req, res) => {
  const rawIds = Array.isArray(req.body?.ids) ? req.body.ids : [];
  const ids = [...new Set(rawIds.map((id) => String(id)).filter(Boolean))].slice(0, 50);
  if (ids.length === 0) {
    fail(res, 400, '请选择要删除的作品');
    return;
  }
  const rows = await prisma.aiArtwork.findMany({
    where: { id: { in: ids }, userId: req.user.sub },
    select: { id: true, imagePath: true },
  });
  if (rows.length > 0) {
    await prisma.aiArtwork.deleteMany({ where: { id: { in: rows.map((row) => row.id) } } });
    for (const row of rows) {
      deletePersistedArtwork(row.imagePath);
    }
  }
  log.info('AI绘画', `用户 id ${req.user.sub} 删除作品 ${rows.length} 张`);
  ok(res, { deleted: rows.length });
});

router.post('/draw', authRequired, async (req, res) => {
  const prompt = String(req.body?.prompt ?? '').trim();
  const style = String(req.body?.style ?? '').trim().slice(0, 32);

  log.info('AI绘画', `开始生成：用户 id ${req.user.sub}，描述 ${prompt.length} 字，风格 ${style || '默认'}`);

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

  // 画幅与张数：size 只认白名单；count 钳在 1（已去掉两张候选），再按今日剩余张数收口。
  const requestedSize = String(req.body?.size ?? '').trim();
  const size = ALLOWED_SIZES.has(requestedSize) ? requestedSize : (process.env.WANX_SIZE || '1280*1280');
  const requestedCount = Math.min(Math.max(Number(req.body?.count) || 1, 1), MAX_COUNT_PER_DRAW);

  const used = await countTodayArtworks(req.user.sub);
  if (used >= DAILY_LIMIT) {
    fail(res, 429, `今日可生成张数已达上限（${DAILY_LIMIT} 张）`);
    return;
  }
  const count = Math.min(requestedCount, DAILY_LIMIT - used);

  const model = process.env.WANX_MODEL || 'wan2.6-t2i';

  try {
    // 逐张生成：一张失败不连累已成功的（至少成一张就返回成图，全失败才报错）。
    const artworks = [];
    let lastError;
    for (let i = 0; i < count; i += 1) {
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
        artworks.push(artwork);
      } catch (error) {
        lastError = error;
        log.warn('AI绘画', `第 ${i + 1} 张生成失败：${error.message}`);
        if (artworks.length === 0 && i === count - 1) throw error;
      }
    }
    if (artworks.length === 0) throw lastError ?? new Error('生成失败，请稍后重试');

    ok(res, {
      // artwork 保留第一张兼容老版 App；artworks 是本批成图（现恒 1 张），新版 App 用它展示结果。
      artwork: serializeArtwork(artworks[0]),
      artworks: artworks.map(serializeArtwork),
      remainingToday: Math.max(0, DAILY_LIMIT - used - artworks.length),
    });
    log.info('AI绘画', `生成成功，本批 ${artworks.length} 张，作品 id ${artworks.map((a) => a.id).join(',')}`);
  } catch (error) {
    log.error('AI绘画', '生成失败', error);
    fail(res, 500, formatWanxErrorMessage(error.message));
  }
});

export default router;
