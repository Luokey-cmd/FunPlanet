import { Router } from 'express';
import { prisma } from '../db.js';
import { ok } from '../utils/response.js';

const router = Router();

router.get('/', async (_req, res) => {
  const banners = await prisma.banner.findMany({
    orderBy: { sortOrder: 'asc' },
    include: { product: { select: { id: true, name: true } } },
  });

  ok(res, {
    banners: banners.map((b) => ({
      id: b.id,
      imagePath: b.imagePath,
      productId: b.productId,
      productName: b.product.name,
      sortOrder: b.sortOrder,
    })),
  });
});

export default router;
