import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { saveReviewImage } from '../utils/review-media.js';
import { refreshProductRating, serializeReview } from '../utils/review.js';

const router = Router();

router.get('/products/:productId', async (req, res) => {
  const productId = String(req.params.productId ?? '').trim();
  if (!productId) return fail(res, 400, '商品 ID 无效');

  const reviews = await prisma.productReview.findMany({
    where: { productId },
    orderBy: { createdAt: 'desc' },
    include: { user: { include: { profile: true } } },
  });

  ok(res, { reviews: reviews.map((r) => serializeReview(r, r.user)) });
});

router.get('/orders/:orderId/products/:productId', authRequired, async (req, res) => {
  const orderId = String(req.params.orderId ?? '').trim();
  const productId = String(req.params.productId ?? '').trim();
  if (!orderId || !productId) return fail(res, 400, '订单或商品信息无效');

  const review = await prisma.productReview.findUnique({
    where: {
      userId_orderId_productId: {
        userId: req.user.sub,
        orderId,
        productId,
      },
    },
  });
  if (!review) return fail(res, 404, '评价不存在');

  const user = await prisma.user.findUnique({
    where: { id: req.user.sub },
    include: { profile: true },
  });

  ok(res, { review: serializeReview(review, user) });
});

router.post('/upload', authRequired, (req, res) => {
  try {
    const imagePath = saveReviewImage(req.body ?? {});
    ok(res, { imagePath });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/', authRequired, async (req, res) => {
  const orderId = String(req.body?.orderId ?? '').trim();
  const productId = String(req.body?.productId ?? '').trim();
  const content = String(req.body?.content ?? '').trim();
  const rating = Math.min(5, Math.max(1, Number(req.body?.rating) || 5));
  const imagePaths = Array.isArray(req.body?.imagePaths)
    ? req.body.imagePaths.map((p) => String(p).trim()).filter(Boolean).slice(0, 6)
    : [];

  if (!orderId || !productId) return fail(res, 400, '订单或商品信息无效');
  if (content.length < 2) return fail(res, 400, '评价内容至少 2 个字');
  if (content.length > 500) return fail(res, 400, '评价内容最多 500 字');

  const order = await prisma.order.findFirst({
    where: { id: orderId, userId: req.user.sub },
    include: { items: true },
  });
  if (!order) return fail(res, 404, '订单不存在');
  if (order.status !== 'completed') return fail(res, 400, '仅已完成订单可评价');

  const inOrder = order.items.some((item) => item.productId === productId);
  if (!inOrder) return fail(res, 400, '该商品不在此订单中');

  const exists = await prisma.productReview.findUnique({
    where: {
      userId_orderId_productId: {
        userId: req.user.sub,
        orderId,
        productId,
      },
    },
  });
  if (exists) return fail(res, 409, '该商品已评价');

  const user = await prisma.user.findUnique({
    where: { id: req.user.sub },
    include: { profile: true },
  });

  const review = await prisma.productReview.create({
    data: {
      userId: req.user.sub,
      productId,
      orderId,
      content,
      rating,
      imagePaths,
    },
  });

  await refreshProductRating(prisma, productId);

  ok(res, { review: serializeReview(review, user) });
});

export default router;
