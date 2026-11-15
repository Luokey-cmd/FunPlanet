import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

const CLAIM_GROUPS = {
  newcomer: ['c1', 'c4'],
  member_monthly: ['c5'],
  center: ['c6'],
};

function formatExpire(date) {
  return date.toISOString().slice(0, 10);
}

function serializeCoupon(row) {
  return {
    id: row.templateId,
    title: row.template.title,
    discount: Number(row.template.discount),
    condition: row.template.condition,
    expire: formatExpire(row.template.expireAt),
    used: row.used,
  };
}

async function ensureProfile(userId) {
  return prisma.userProfile.upsert({
    where: { userId },
    create: { userId },
    update: {},
  });
}

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.userCoupon.findMany({
    where: { userId: req.user.sub },
    include: { template: true },
    orderBy: { claimedAt: 'desc' },
  });
  const profile = await prisma.userProfile.findUnique({ where: { userId: req.user.sub } });
  ok(res, {
    coupons: rows.map(serializeCoupon),
    newcomerClaimed: profile?.newcomerClaimed ?? false,
    memberMonthlyCouponClaimed: profile?.memberMonthlyCouponClaimed ?? false,
  });
});

async function claimGroup(req, res, groupKey, flagField) {
  const templateIds = CLAIM_GROUPS[groupKey];
  if (!templateIds) return fail(res, 400, '无效的领取类型');

  const profile = await ensureProfile(req.user.sub);
  if (flagField && profile[flagField]) {
    return fail(res, 409, '已领取过');
  }

  const templates = await prisma.couponTemplate.findMany({
    where: { id: { in: templateIds } },
  });
  if (templates.length !== templateIds.length) {
    return fail(res, 500, '优惠券配置不完整，请重新 seed');
  }

  const created = [];
  for (const templateId of templateIds) {
    const row = await prisma.userCoupon.upsert({
      where: {
        userId_templateId: { userId: req.user.sub, templateId },
      },
      create: { userId: req.user.sub, templateId },
      update: {},
      include: { template: true },
    });
    created.push(serializeCoupon(row));
  }

  if (flagField) {
    await prisma.userProfile.update({
      where: { userId: req.user.sub },
      data: { [flagField]: true },
    });
  }

  ok(res, { coupons: created });
}

router.post('/claim/newcomer', authRequired, (req, res) =>
  claimGroup(req, res, 'newcomer', 'newcomerClaimed'),
);

router.post('/claim/member-monthly', authRequired, async (req, res) => {
  const profile = await ensureProfile(req.user.sub);
  if (profile.vipLevel < 2) return fail(res, 403, '请先开通会员');
  return claimGroup(req, res, 'member_monthly', 'memberMonthlyCouponClaimed');
});

router.post('/claim/center', authRequired, async (req, res) => {
  const existing = await prisma.userCoupon.findUnique({
    where: {
      userId_templateId: { userId: req.user.sub, templateId: 'c6' },
    },
  });
  if (existing) return fail(res, 409, '已领取过');
  return claimGroup(req, res, 'center', null);
});

export default router;
