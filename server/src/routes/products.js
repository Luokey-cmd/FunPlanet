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

  const flashMap = await getFlashPriceMap(products.map((p) => p.id));
  ok(res, { products: products.map((p) => serializeProduct(p, flashMap.get(p.id) ?? null)) });
});

router.get('/:id', async (req, res) => {
  const product = await prisma.product.findUnique({ where: { id: req.params.id } });
  if (!product) {
    res.status(404).json({ code: 404, message: '商品不存在', data: null });
    return;
  }
  const flashMap = await getFlashPriceMap([product.id]);
  ok(res, { product: serializeProduct(product, flashMap.get(product.id) ?? null) });
});

export default router;
