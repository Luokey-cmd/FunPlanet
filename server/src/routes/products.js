import { Router } from 'express';
import { prisma } from '../db.js';
import { ok } from '../utils/response.js';
import { serializeProduct } from '../utils/product.js';

const router = Router();

router.get('/', async (req, res) => {
  const category = String(req.query.category ?? '').trim();
  const keyword = String(req.query.keyword ?? '').trim();

  const where = {};
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

  ok(res, { products: products.map(serializeProduct) });
});

router.get('/:id', async (req, res) => {
  const product = await prisma.product.findUnique({ where: { id: req.params.id } });
  if (!product) {
    res.status(404).json({ code: 404, message: '商品不存在', data: null });
    return;
  }
  ok(res, { product: serializeProduct(product) });
});

export default router;
