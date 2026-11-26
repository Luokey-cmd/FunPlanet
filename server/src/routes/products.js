import { Router } from 'express';
import { prisma } from '../db.js';
import { ok } from '../utils/response.js';
import { serializeProduct } from '../utils/product.js';
import { getFlashPriceMap } from '../utils/promotions.js';

const router = Router();

router.get('/', async (req, res) => {
  const category = String(req.query.category ?? '').trim();
  const keyword = String(req.query.keyword ?? '').trim();

  const where = { isOnShelf: true };
  if (category && category !== 'all') {
    where.category = category;
  }
  if (keyword) {
    where.OR = [
      { name: { contains: keyword } },
      { nameEn: { contains: keyword, mode: 'insensitive' } },
      { subCategory: { contains: keyword } },
      { majorCategory: { contains: keyword } },
      { description: { contains: keyword } },
    ];
  }

  const products = await prisma.product.findMany({
    where,
    orderBy: { id: 'asc' },
  });

  const recentSalesMap = await getRecentSalesMap(products.map((p) => p.id));
  const flashMap = await getFlashPriceMap(products.map((p) => p.id));
  ok(res, { products: products.map((p) => serializeProduct(p, flashMap.get(p.id) ?? null, recentSalesMap.get(p.id) ?? 0)) });
});

router.get('/:id', async (req, res) => {
  const product = await prisma.product.findUnique({ where: { id: req.params.id } });
  if (!product) {
    res.status(404).json({ code: 404, message: '商品不存在', data: null });
    return;
  }
  const recentSalesMap = await getRecentSalesMap([product.id]);
  const flashMap = await getFlashPriceMap([product.id]);
  ok(res, { product: serializeProduct(product, flashMap.get(product.id) ?? null, recentSalesMap.get(product.id) ?? 0) });
});


// 近 30 天销量汇总（「近期热销」排序用）：按订单明细 groupBy 累加件数，
// 只算已付款且未取消的订单（虚拟订单也是 paid/completed、同样计入）。
// 输入：商品 id 列表；输出：Map<商品id, 近30天件数>，没卖出的不在表里（调用方按 0 兜底）。
// 坑：汇总失败不能拖垮商品列表主接口，失败时记日志、返回空表，App 侧会自动退回按总销量排序。
async function getRecentSalesMap(productIds) {
  const map = new Map();
  if (productIds.length === 0) return map;
  try {
    const since = new Date(Date.now() - 30 * 86400000);
    const rows = await prisma.orderItem.groupBy({
      by: ['productId'],
      where: {
        productId: { in: productIds },
        order: { paymentStatus: 'paid', status: { not: 'cancelled' }, createdAt: { gte: since } },
      },
      _sum: { quantity: true },
    });
    for (const row of rows) {
      map.set(row.productId, row._sum.quantity ?? 0);
    }
  } catch (err) {
    console.error('近30天销量汇总失败，近期热销将按总销量兜底排序：', err);
  }
  return map;
}

export default router;
