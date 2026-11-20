import { formatChinaDateTime } from './datetime.js';

export function serializeReviewComment(comment, user) {
  return {
    id: comment.id,
    reviewId: comment.reviewId,
    content: comment.content,
    parentId: comment.parentId || '0',
    rootId: comment.rootId || '0',
    replyToUserId: comment.replyToUserId || '',
    replyToUserName: comment.replyToUserName || '',
    createdAt: formatChinaDateTime(comment.createdAt),
    userNickname: user?.nickname ?? '趣玩用户',
    userAvatarPath: user?.profile?.avatarPath ?? '',
    userId: user?.id ?? comment.userId ?? '',
  };
}

export function serializeReview(review, user, comments = []) {
  return {
    id: review.id,
    productId: review.productId,
    orderId: review.orderId,
    content: review.content,
    rating: review.rating,
    imagePaths: review.imagePaths ?? [],
    moderationStatus: review.moderationStatus ?? 'visible',
    createdAt: formatChinaDateTime(review.createdAt),
    userNickname: user?.nickname ?? '趣玩用户',
    userAvatarPath: user?.profile?.avatarPath ?? '',
    userId: user?.id ?? review.userId ?? '',
    comments: comments.map((c) => serializeReviewComment(c, c.user)),
  };
}

export async function refreshProductRating(prisma, productId) {
  const agg = await prisma.productReview.aggregate({
    // 评分只统计可见评价，隐藏的不算
    where: { productId, moderationStatus: 'visible' },
    _avg: { rating: true },
    _count: { rating: true },
  });
  if (!agg._count.rating) return;
  const avg = Math.round((agg._avg.rating ?? 5) * 10) / 10;
  await prisma.product.update({
    where: { id: productId },
    data: { rating: avg },
  });
}
