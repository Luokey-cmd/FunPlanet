import { Router } from 'express';
import { prisma } from '../db.js';
import { ok } from '../utils/response.js';

const router = Router();

router.get('/', async (_req, res) => {
  const now = new Date();
  const banners = await prisma.banner.findMany({
    // 只给 App 返回启用中、且在生效时间窗内的轮播；停用和过期的是后台留着的，不下发
    where: {
      isActive: true,
      OR: [{ startsAt: null }, { startsAt: { lte: now } }],
      AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
    },
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
      title: b.title ?? null,
      linkType: b.linkType ?? 'product',
      linkTarget: b.linkTarget ?? null,
    })),
  });
});

export default router;
