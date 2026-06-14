import { formatChinaDateTime } from './datetime.js';

export function serializeReview(review, user) {
  return {
    id: review.id,
    productId: review.productId,
    orderId: review.orderId,
    content: review.content,
    rating: review.rating,
    imagePaths: review.imagePaths ?? [],
    createdAt: formatChinaDateTime(review.createdAt),
    userNickname: user?.nickname ?? '趣玩用户',
    userAvatarPath: user?.profile?.avatarPath ?? '',
  };
}

export async function refreshProductRating(prisma, productId) {
  const agg = await prisma.productReview.aggregate({
    where: { productId },
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
