import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { saveReviewImage } from '../utils/review-media.js';
import { refreshProductRating, serializeReview, serializeReviewComment } from '../utils/review.js';

const router = Router();

router.get('/products/:productId', async (req, res) => {
  const productId = String(req.params.productId ?? '').trim();
  if (!productId) return fail(res, 400, '商品 ID 无效');

  const reviews = await prisma.productReview.findMany({
    where: { productId },
    orderBy: { createdAt: 'desc' },
    include: {
      user: { include: { profile: true } },
      comments: {
        orderBy: { createdAt: 'asc' },
        include: { user: { include: { profile: true } } },
      },
    },
  });

  ok(res, {
    reviews: reviews.map((r) => serializeReview(r, r.user, r.comments)),
  });
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
    include: {
      comments: {
        orderBy: { createdAt: 'asc' },
        include: { user: { include: { profile: true } } },
      },
    },
  });
  if (!review) return fail(res, 404, '评价不存在');

  const user = await prisma.user.findUnique({
    where: { id: req.user.sub },
    include: { profile: true },
  });

  ok(res, { review: serializeReview(review, user, review.comments) });
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

  ok(res, { review: serializeReview(review, user, []) });
});

router.post('/:reviewId/comments', authRequired, async (req, res) => {
  const reviewId = String(req.params.reviewId ?? '').trim();
  const content = String(req.body?.content ?? '').trim();
  let parentId = String(req.body?.parentId ?? '0').trim() || '0';

  if (!reviewId) return fail(res, 400, '评价 ID 无效');
  if (content.length < 1) return fail(res, 400, '请输入评论内容');
  if (content.length > 300) return fail(res, 400, '评论不能超过 300 字');

  const review = await prisma.productReview.findUnique({ where: { id: reviewId } });
  if (!review) return fail(res, 404, '评价不存在');

  let rootId = '0';
  let replyToUserId = '';
  let replyToUserName = '';

  if (parentId === '0') {
    // 直接回复评价本体：挂在评价楼主下，root 用评价 id 语义由客户端区分；
    // 这里一级评论 parentId='0'，rootId='0'
  } else if (parentId === reviewId) {
    // 兼容：把评价 id 当作「回复评价」入口，转为一级评论
    parentId = '0';
    rootId = '0';
    const owner = await prisma.user.findUnique({ where: { id: review.userId } });
    replyToUserId = review.userId;
    replyToUserName = owner?.nickname || '买家';
  } else {
    const parent = await prisma.productReviewComment.findFirst({
      where: { id: parentId, reviewId },
      include: { user: true },
    });
    if (!parent) return fail(res, 404, '被回复的评论不存在');
    rootId = !parent.rootId || parent.rootId === '0' ? parent.id : parent.rootId;
    replyToUserId = parent.userId;
    replyToUserName = parent.user?.nickname || '用户';
  }

  const created = await prisma.productReviewComment.create({
    data: {
      reviewId,
      userId: req.user.sub,
      parentId,
      rootId,
      replyToUserId,
      replyToUserName,
      content,
    },
    include: { user: { include: { profile: true } } },
  });

  const comments = await prisma.productReviewComment.findMany({
    where: { reviewId },
    orderBy: { createdAt: 'asc' },
    include: { user: { include: { profile: true } } },
  });
  const owner = await prisma.user.findUnique({
    where: { id: review.userId },
    include: { profile: true },
  });

  ok(res, {
    comment: serializeReviewComment(created, created.user),
    review: serializeReview(review, owner, comments),
  });
});

export default router;
