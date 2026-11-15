import { prisma } from '../db.js';

/** 已付款且未取消订单的商品销量 */
export async function getPaidSalesMap(client = prisma) {
  const rows = await client.orderItem.groupBy({
    by: ['productId'],
    _sum: { quantity: true },
    where: {
      order: {
        paymentStatus: 'paid',
        status: { not: 'cancelled' },
      },
    },
  });
  return new Map(rows.map((r) => [r.productId, r._sum.quantity ?? 0]));
}

/** 将 products.sales 同步为真实已付款销量 */
export async function syncAllProductSales(client = prisma) {
  const salesMap = await getPaidSalesMap(client);
  const products = await client.product.findMany({ select: { id: true } });
  await client.$transaction(
    products.map((p) =>
      client.product.update({
        where: { id: p.id },
        data: { sales: salesMap.get(p.id) ?? 0 },
      }),
    ),
  );
}
