import { prisma } from '../db.js';

// 营销活动计价口径（2026-11-24 营销中心，全系统只此一份）：
// - 活动双闸：isActive 为真且当前时间在 [startsAt, endsAt] 内才生效。
// - 限时特价（flash）：一件商品被多个活动覆盖时取最低特价（对用户最划算，
//   结果也确定，不依赖活动创建顺序）。
// - 满减（threshold）：全店口径，按商品小计（已含特价）判定门槛；
//   多档同时满足时取减得最多的一档；减额不超过小计。
// - 满减与优惠券可叠加：总价 = 小计 - 满减 - 券优惠 + 运费（下单处计算）。
// 下单的两条路径（App 结算、小豆 create_order）都必须走这里的函数，
// 不许在别处另算一份，理由同 orders.js 里共用函数的注释。

async function listActivePromotions(type) {
  const now = new Date();
  return prisma.promotion.findMany({
    where: {
      type,
      isActive: true,
      startsAt: { lte: now },
      endsAt: { gte: now },
    },
    include: type === 'flash' ? { items: true } : undefined,
    orderBy: { createdAt: 'asc' },
  });
}

// 输入：一批商品 id。输出：Map<商品id, {price, promotionName, endsAt}>
// ——命中的限时特价；没命中的商品不在 Map 里。
export async function getFlashPriceMap(productIds) {
  const map = new Map();
  const ids = [...new Set((productIds ?? []).filter(Boolean))];
  if (ids.length === 0) return map;
  const promotions = await listActivePromotions('flash');
  for (const promo of promotions) {
    for (const item of promo.items ?? []) {
      if (!ids.includes(item.productId)) continue;
      const price = Number(item.promoPrice);
      const existing = map.get(item.productId);
      if (!existing || price < existing.price) {
        map.set(item.productId, {
          price,
          promotionName: promo.name,
          endsAt: promo.endsAt,
        });
      }
    }
  }
  return map;
}

// 输入：商品小计（已按特价算过）。输出：{amount, name}——最优满减；
// 没有满足的活动时 amount 为 0、name 为 null。
export async function resolvePromotionDiscount(subtotal) {
  const promotions = await listActivePromotions('threshold');
  let best = { amount: 0, name: null };
  for (const promo of promotions) {
    const threshold = Number(promo.thresholdAmount ?? 0);
    const discount = Number(promo.discountAmount ?? 0);
    if (threshold <= 0 || discount <= 0) continue;
    if (subtotal < threshold) continue;
    if (discount > best.amount) {
      best = { amount: Math.min(discount, subtotal), name: promo.name };
    }
  }
  return best;
}

// 给结算页展示用：当前生效的全部满减档（按门槛升序），App 侧自己
// 按同一口径算「已享哪档、还差多少到下一档」，服务端下单时再复算。
export async function listActiveThresholdPromotions() {
  const promotions = await listActivePromotions('threshold');
  return promotions
    .map((promo) => ({
      id: promo.id,
      name: promo.name,
      thresholdAmount: Number(promo.thresholdAmount ?? 0),
      discountAmount: Number(promo.discountAmount ?? 0),
      endsAt: promo.endsAt.toISOString(),
    }))
    .filter((promo) => promo.thresholdAmount > 0 && promo.discountAmount > 0)
    .sort((a, b) => a.thresholdAmount - b.thresholdAmount);
}
