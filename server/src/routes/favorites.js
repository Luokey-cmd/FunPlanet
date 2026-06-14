import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.favorite.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: 'desc' },
  });
  ok(res, { productIds: rows.map((r) => r.productId) });
});

router.post('/toggle', authRequired, async (req, res) => {
  const productId = String(req.body?.productId ?? '').trim();
  if (!productId) return fail(res, 400, '缺少 productId');

  const product = await prisma.product.findUnique({ where: { id: productId } });
  if (!product) return fail(res, 404, '商品不存在');

  const existing = await prisma.favorite.findUnique({
    where: { userId_productId: { userId: req.user.sub, productId } },
  });

  if (existing) {
    await prisma.favorite.delete({ where: { id: existing.id } });
    ok(res, { productId, favorited: false });
    return;
  }

  await prisma.favorite.create({
    data: { userId: req.user.sub, productId },
  });
  ok(res, { productId, favorited: true });
});

export default router;
