import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import {
  currentMonthKey,
  ensureProfileFresh,
  isMemberCouponClaimedThisMonth,
} from '../utils/daily-tasks.js';

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
    // 门槛金额是数字字段（minAmount），condition 只给人看；老 App 不读新键、不受影响
    minAmount: row.template.minAmount == null ? 0 : Number(row.template.minAmount),
    couponType: row.template.couponType ?? 'fixed',
    scope: row.template.scope ?? 'all',
    expire: formatExpire(row.template.expireAt),
    used: row.used,
    usedAt: row.usedAt ? row.usedAt.toISOString() : null,
  };
}

async function ensureProfile(userId) {
  // 领券和展示都要先过新鲜度：会员月券跨月自动恢复可领
  return ensureProfileFresh(userId);
}

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.userCoupon.findMany({
    where: { userId: req.user.sub },
    include: { template: true },
    orderBy: { claimedAt: 'desc' },
  });
  const profile = await ensureProfile(req.user.sub);
  ok(res, {
    coupons: rows.map(serializeCoupon),
    newcomerClaimed: profile?.newcomerClaimed ?? false,
    memberMonthlyCouponClaimed: isMemberCouponClaimedThisMonth(profile),
  });
});

async function claimGroup(req, res, groupKey, flagField) {
  const templateIds = CLAIM_GROUPS[groupKey];
  if (!templateIds) return fail(res, 400, '无效的领取类型');

  const profile = await ensureProfile(req.user.sub);
  // 会员月券的「已领」按月份判断；新人券仍是终身一次的布尔判断
  const alreadyClaimed =
    groupKey === 'member_monthly'
      ? isMemberCouponClaimedThisMonth(profile)
      : flagField
        ? Boolean(profile[flagField])
        : false;
  if (alreadyClaimed) {
    return fail(res, 409, '已领取过');
  }

  const templates = await prisma.couponTemplate.findMany({
    where: { id: { in: templateIds } },
  });
  if (templates.length !== templateIds.length) {
    return fail(res, 500, '优惠券配置不完整，请重新 seed');
  }

  // 发行侧检查：还没到领取时间、或总量已领完的券不能再发
  const now = new Date();
  for (const template of templates) {
    if (template.claimStartAt && now < template.claimStartAt) {
      return fail(res, 400, '优惠券尚未开始领取');
    }
    if (template.totalQuantity != null && template.issuedCount >= template.totalQuantity) {
      return fail(res, 409, '优惠券已领完');
    }
    if (template.expireAt && now > template.expireAt) {
      return fail(res, 400, '优惠券已过期');
    }
  }

  const isMonthlyReclaim = groupKey === 'member_monthly';
  const created = [];
  for (const templateId of templateIds) {
    const row = await prisma.userCoupon.upsert({
      where: {
        userId_templateId: { userId: req.user.sub, templateId },
      },
      create: { userId: req.user.sub, templateId },
      // 会员月券跨月再领时复用同一行：把已用状态清掉、领取时间刷新；其他组保持原样不动
      update: isMonthlyReclaim
        ? { used: false, usedAt: null, orderId: null, claimedAt: now }
        : {},
      include: { template: true },
    });
    await prisma.couponTemplate.update({
      where: { id: templateId },
      data: { issuedCount: { increment: 1 } },
    });
    created.push(serializeCoupon(row));
  }

  if (flagField) {
    const data = { [flagField]: true };
    // 领月券时把月份一起钉住，下个月新鲜度检查靠它放行
    if (isMonthlyReclaim) data.memberCouponMonth = currentMonthKey();
    await prisma.userProfile.update({
      where: { userId: req.user.sub },
      data,
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
