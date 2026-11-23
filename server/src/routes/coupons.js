import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import {
  currentMonthKey,
  ensureProfileFresh,
  isMemberCouponClaimedThisMonth,
} from '../utils/daily-tasks.js';

const router = Router();

export const CLAIM_GROUPS = {
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

// 领券核心（路由与小豆的办事工具共用同一份口径，规则只许在这里改）：
// 输入：userId + groupKey（newcomer / member_monthly / center）。
// 输出：{ ok: true, coupons } 或 { ok: false, status, error }。
// 坑：会员月券有 VIP2 门槛和跨月再领规则，都在这一层判断完，
// 调用方不要再各判一遍，否则两边口径迟早不一致。
export async function claimCouponGroupForUser(userId, groupKey) {
  const templateIds = CLAIM_GROUPS[groupKey];
  if (!templateIds) return { ok: false, status: 400, error: '无效的领取类型' };
  const flagField =
    groupKey === 'newcomer'
      ? 'newcomerClaimed'
      : groupKey === 'member_monthly'
        ? 'memberMonthlyCouponClaimed'
        : null;

  const profile = await ensureProfile(userId);
  if (groupKey === 'member_monthly' && (profile?.vipLevel ?? 1) < 2) {
    return { ok: false, status: 403, error: '请先开通会员' };
  }

  // 会员月券的「已领」按月份判断；新人券仍是终身一次的布尔判断；
  // 领券中心的券看有没有领过这一张。
  let alreadyClaimed = false;
  if (groupKey === 'member_monthly') {
    alreadyClaimed = isMemberCouponClaimedThisMonth(profile);
  } else if (flagField) {
    alreadyClaimed = Boolean(profile?.[flagField]);
  } else {
    const existing = await prisma.userCoupon.findUnique({
      where: { userId_templateId: { userId, templateId: templateIds[0] } },
    });
    alreadyClaimed = Boolean(existing);
  }
  if (alreadyClaimed) {
    return { ok: false, status: 409, error: '已领取过' };
  }

  const templates = await prisma.couponTemplate.findMany({
    where: { id: { in: templateIds } },
  });
  if (templates.length !== templateIds.length) {
    return { ok: false, status: 500, error: '优惠券配置不完整，请重新 seed' };
  }

  // 发行侧检查：还没到领取时间、或总量已领完的券不能再发
  const now = new Date();
  for (const template of templates) {
    if (template.claimStartAt && now < template.claimStartAt) {
      return { ok: false, status: 400, error: '优惠券尚未开始领取' };
    }
    if (template.totalQuantity != null && template.issuedCount >= template.totalQuantity) {
      return { ok: false, status: 409, error: '优惠券已领完' };
    }
    if (template.expireAt && now > template.expireAt) {
      return { ok: false, status: 400, error: '优惠券已过期' };
    }
  }

  const isMonthlyReclaim = groupKey === 'member_monthly';
  const created = [];
  for (const templateId of templateIds) {
    const row = await prisma.userCoupon.upsert({
      where: {
        userId_templateId: { userId, templateId },
      },
      create: { userId, templateId },
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
      where: { userId },
      data,
    });
  }

  return { ok: true, coupons: created };
}

const CLAIM_GROUP_LABELS = { newcomer: '新人券', member_monthly: '会员月券', center: '领券中心' };

async function respondClaim(req, res, groupKey) {
  const result = await claimCouponGroupForUser(req.user.sub, groupKey);
  if (!result.ok) {
    log.warn('优惠券', `领取${CLAIM_GROUP_LABELS[groupKey] ?? groupKey}没成：${result.error}`);
    return fail(res, result.status, result.error);
  }
  log.info('优惠券', `领取${CLAIM_GROUP_LABELS[groupKey] ?? groupKey}成功，共 ${result.coupons.length} 张（用户 id ${req.user.sub}）`);
  return ok(res, { coupons: result.coupons });
}

router.post('/claim/newcomer', authRequired, (req, res) =>
  respondClaim(req, res, 'newcomer'),
);

router.post('/claim/member-monthly', authRequired, (req, res) =>
  respondClaim(req, res, 'member_monthly'),
);

router.post('/claim/center', authRequired, (req, res) =>
  respondClaim(req, res, 'center'),
);

export default router;
