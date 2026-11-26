import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import {
  currentDailyDate,
  currentMonthKey,
  ensureProfileFresh,
  isMemberCouponClaimedThisMonth,
} from '../utils/daily-tasks.js';
import { recordWalletLedger } from '../utils/wallet-ledger.js';

const router = Router();

export const CLAIM_GROUPS = {
  newcomer: ['c1', 'c4'],
  member_monthly: ['c5'],
  center: ['c6'],
  // 领券中心扩容（2026-11-26）：满200减40 与满300减80 各自单独成组，
  // 在领券中心里一张卡一个按钮单独领，不跟满120减25 捆在一起。
  center_200: ['c8'],
  center_300: ['c3'],
  // 会员每日礼包（2026-11-26）：组里只有礼包券 c9，但领取成功时还要
  // 连带发积分与趣玩币（数量在下面两个常量），三件一起到账才算领成。
  member_daily: ['c9'],
};

// 会员每日礼包的附带奖励：积分与趣玩币各发多少只许在这里改，
// App 卡面文案（积分 +10 / 趣玩币 +5）要跟这两个数字保持一致。
const MEMBER_DAILY_GIFT_POINTS = 10;
const MEMBER_DAILY_GIFT_COINS = 5;

// 会员每日礼包「今日已领」的唯一判断口径：上次领取日期就是今天（中国日期）。
// 展示和领取判断都用它，不要直接拿 memberDailyGiftDate 字符串到处比。
export function isMemberDailyGiftClaimedToday(profile, now = new Date()) {
  return Boolean(profile?.memberDailyGiftDate) &&
    profile.memberDailyGiftDate === currentDailyDate(now);
}

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
    // 首页会员每日礼包卡靠它定按钮四态（已领就灰掉），口径与领取判断共用同一函数
    memberDailyGiftClaimedToday: isMemberDailyGiftClaimedToday(profile),
  });
});

// 领券核心（路由与小豆的办事工具共用同一份口径，规则只许在这里改）：
// 输入：userId + groupKey（newcomer / member_monthly / center / member_daily 等）。
// 输出：{ ok: true, coupons } 或 { ok: false, status, error }。
// 坑：会员月券与每日礼包有 VIP2 门槛、跨月/跨天再领规则，都在这一层判断完，
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
  if (
    (groupKey === 'member_monthly' || groupKey === 'member_daily') &&
    (profile?.vipLevel ?? 1) < 2
  ) {
    return { ok: false, status: 403, error: '请先开通会员' };
  }

  // 会员月券的「已领」按月份判断；每日礼包按领取日期判断；新人券仍是
  // 终身一次的布尔判断；领券中心的券看有没有领过这一张。
  let alreadyClaimed = false;
  if (groupKey === 'member_monthly') {
    alreadyClaimed = isMemberCouponClaimedThisMonth(profile);
  } else if (groupKey === 'member_daily') {
    alreadyClaimed = isMemberDailyGiftClaimedToday(profile);
  } else if (flagField) {
    alreadyClaimed = Boolean(profile?.[flagField]);
  } else {
    const existing = await prisma.userCoupon.findUnique({
      where: { userId_templateId: { userId, templateId: templateIds[0] } },
    });
    alreadyClaimed = Boolean(existing);
  }
  if (alreadyClaimed) {
    return {
      ok: false,
      status: 409,
      error: groupKey === 'member_daily' ? '今日已领取' : '已领取过',
    };
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

  // 周期再领组（月券跨月、每日礼包跨天）：userCoupon 还是同一行，
  // 再领时必须把已用状态清掉、领取时间刷新，不然用户领到的会是昨天用过的旧券。
  const isCycleReclaim = groupKey === 'member_monthly' || groupKey === 'member_daily';
  const created = [];
  for (const templateId of templateIds) {
    const row = await prisma.userCoupon.upsert({
      where: {
        userId_templateId: { userId, templateId },
      },
      create: { userId, templateId },
      update: isCycleReclaim
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
    if (groupKey === 'member_monthly') data.memberCouponMonth = currentMonthKey();
    await prisma.userProfile.update({
      where: { userId },
      data,
    });
  }

  // 每日礼包的附带奖励：券之外还要真发积分 +10、趣玩币 +5。
  // 发法与每日任务领奖同一套：先改余额、再用 recordWalletLedger 记流水
  // （顺序反了流水里的余额快照会差一笔）；refType 固定 member_daily_gift、
  // refId 存今天日期，任务页「今日已赚」汇总与积分/币明细都靠它认这笔。
  if (groupKey === 'member_daily') {
    const today = currentDailyDate();
    await prisma.userProfile.update({
      where: { userId },
      data: {
        memberDailyGiftDate: today,
        points: { increment: MEMBER_DAILY_GIFT_POINTS },
        funCoins: { increment: MEMBER_DAILY_GIFT_COINS },
      },
    });
    await recordWalletLedger(prisma, {
      userId,
      walletType: 'points',
      amount: MEMBER_DAILY_GIFT_POINTS,
      title: '会员每日礼包',
      refType: 'member_daily_gift',
      refId: today,
    });
    await recordWalletLedger(prisma, {
      userId,
      walletType: 'coins',
      amount: MEMBER_DAILY_GIFT_COINS,
      title: '会员每日礼包',
      refType: 'member_daily_gift',
      refId: today,
    });
    return {
      ok: true,
      coupons: created,
      rewards: { points: MEMBER_DAILY_GIFT_POINTS, coins: MEMBER_DAILY_GIFT_COINS },
    };
  }

  return { ok: true, coupons: created };
}

const CLAIM_GROUP_LABELS = {
  newcomer: '新人券',
  member_monthly: '会员月券',
  center: '领券中心',
  center_200: '领券中心满200减40',
  center_300: '领券中心满300减80',
  member_daily: '会员每日礼包',
};

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

router.post('/claim/center-200', authRequired, (req, res) =>
  respondClaim(req, res, 'center_200'),
);

router.post('/claim/center-300', authRequired, (req, res) =>
  respondClaim(req, res, 'center_300'),
);

router.post('/claim/member-daily', authRequired, (req, res) =>
  respondClaim(req, res, 'member_daily'),
);

export default router;
