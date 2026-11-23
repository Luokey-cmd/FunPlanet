import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { serializeProduct } from '../utils/product.js';

const router = Router();

function serializeCartItem(item) {
  return {
    id: item.id,
    productId: item.productId,
    quantity: item.quantity,
    spec: item.spec,
    product: serializeProduct(item.product),
  };
}

router.get('/', authRequired, async (req, res) => {
  const items = await prisma.cartItem.findMany({
    where: { userId: req.user.sub },
    include: { product: true },
    orderBy: { updatedAt: 'desc' },
  });
  ok(res, { items: items.map(serializeCartItem) });
});

router.post('/', authRequired, async (req, res) => {
  const productId = String(req.body?.productId ?? '').trim();
  const delta = Number(req.body?.quantity ?? 1);
  if (!productId) return fail(res, 400, '缺少 productId');
  if (!Number.isFinite(delta) || delta === 0) return fail(res, 400, 'quantity 无效');

  const product = await prisma.product.findUnique({ where: { id: productId } });
  if (!product) return fail(res, 404, '商品不存在');

  // 查已有行必须带上 spec：购物车唯一约束是（用户、商品、规格）三字段，
  // findUnique 写 userId_productId 会在运行时报 Unknown argument 直接 500
  // （2026-11-23 云端实测踩实；旧版能跑只是靠本地生成的旧客户端撑着）。
  const existing = await prisma.cartItem.findFirst({
    where: { userId: req.user.sub, productId, spec: product.spec ?? '' },
  });

  let item;
  if (existing) {
    const quantity = existing.quantity + delta;
    if (quantity <= 0) {
      await prisma.cartItem.delete({ where: { id: existing.id } });
      ok(res, { item: null });
      return;
    }
    item = await prisma.cartItem.update({
      where: { id: existing.id },
      data: { quantity },
      include: { product: true },
    });
  } else {
    if (delta <= 0) return fail(res, 400, '数量无效');
    item = await prisma.cartItem.create({
      data: {
        userId: req.user.sub,
        productId,
        quantity: delta,
        // CartItem.spec 已改为必填：商品没规格时存空文字，不许传 null
        spec: product.spec ?? '',
      },
      include: { product: true },
    });
  }

  ok(res, { item: serializeCartItem(item) });
});

router.put('/:productId', authRequired, async (req, res) => {
  const productId = String(req.params.productId ?? '').trim();
  const quantity = Number(req.body?.quantity);
  if (!productId) return fail(res, 400, '缺少 productId');
  if (!Number.isFinite(quantity)) return fail(res, 400, 'quantity 无效');

  // 同上：不用 findUnique 的复合键，按用户+商品取最近更新的一行
  // （App 里同一商品只会有一种规格的一行）。
  const existing = await prisma.cartItem.findFirst({
    where: { userId: req.user.sub, productId },
    orderBy: { updatedAt: 'desc' },
  });
  if (!existing) return fail(res, 404, '购物车无此商品');

  if (quantity <= 0) {
    await prisma.cartItem.delete({ where: { id: existing.id } });
    ok(res, { item: null });
    return;
  }

  const item = await prisma.cartItem.update({
    where: { id: existing.id },
    data: { quantity },
    include: { product: true },
  });
  ok(res, { item: serializeCartItem(item) });
});

router.delete('/:productId', authRequired, async (req, res) => {
  const productId = String(req.params.productId ?? '').trim();
  await prisma.cartItem.deleteMany({
    where: { userId: req.user.sub, productId },
  });
  ok(res, { removed: true });
});

router.delete('/', authRequired, async (req, res) => {
  await prisma.cartItem.deleteMany({ where: { userId: req.user.sub } });
  ok(res, { cleared: true });
});

export default router;
