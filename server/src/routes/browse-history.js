import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();
const MAX_HISTORY = 20;

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.browseHistoryItem.findMany({
    where: { userId: req.user.sub },
    orderBy: { viewedAt: 'desc' },
    take: MAX_HISTORY,
  });
  ok(res, { productIds: rows.map((r) => r.productId) });
});

router.post('/', authRequired, async (req, res) => {
  const productId = String(req.body?.productId ?? '').trim();
  if (!productId) return fail(res, 400, '缺少 productId');

  const product = await prisma.product.findUnique({ where: { id: productId } });
  if (!product) return fail(res, 404, '商品不存在');

  await prisma.browseHistoryItem.deleteMany({
    where: { userId: req.user.sub, productId },
  });

  await prisma.browseHistoryItem.create({
    data: { userId: req.user.sub, productId },
  });

  await prisma.userProfile.upsert({
    where: { userId: req.user.sub },
    create: { userId: req.user.sub, dailyBrowseCount: 1 },
    update: { dailyBrowseCount: { increment: 1 } },
  });

  const overflow = await prisma.browseHistoryItem.findMany({
    where: { userId: req.user.sub },
    orderBy: { viewedAt: 'desc' },
    skip: MAX_HISTORY,
    select: { id: true },
  });
  if (overflow.length > 0) {
    await prisma.browseHistoryItem.deleteMany({
      where: { id: { in: overflow.map((r) => r.id) } },
    });
  }

  ok(res, { productId });
});

export default router;
