import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { resetUserData } from '../utils/reset-user.js';
import { recordWalletLedger, serializeLedger } from '../utils/wallet-ledger.js';
import {
  currentDailyDate,
  currentMonthKey,
  currentWeekKey,
  ensureProfileFresh,
  isMemberCouponClaimedThisMonth,
  previousDailyDate,
} from '../utils/daily-tasks.js';
import { isDisplayableAvatarPath, saveUserAvatar } from '../utils/avatar-media.js';

const router = Router();

// 趣玩币充值档位（2026-11-26 hx 定 B 方案：1 元 = 15 币，会员 299 币约合 20 元）。
// 输入只认 packageId，币数与金额一律查这张表，客户端报多少都不算数，防改包刷币。
// App 侧 lib/data/product_data.dart 有一份同表（只供展示），改档位两边一起改。
export const RECHARGE_PACKAGES = {
  r6: { yuan: 6, coins: 90 },
  r12: { yuan: 12, coins: 180 },
  r20: { yuan: 20, coins: 320 },
  r48: { yuan: 48, coins: 780 },
  r98: { yuan: 98, coins: 1590 },
};

function validateNickname(nickname) {
  const value = nickname?.trim() ?? '';
  if (value.length < 2) return '昵称至少 2 个字';
  if (value.length > 16) return '昵称最多 16 个字';
  return null;
}

export async function ensureUserProfile(userId) {
  return prisma.userProfile.upsert({
    where: { userId },
    create: { userId },
    update: {},
  });
}

function serializeProfile(user, profile) {
  return {
    nickname: user.nickname,
    userId: user.userId,
    phone: user.phone,
    points: profile.points,
    funCoins: profile.funCoins,
    vipLevel: profile.vipLevel,
    avatarPath: profile.avatarPath,
    newcomerClaimed: profile.newcomerClaimed,
    guideRewardClaimed: profile.guideRewardClaimed,
    // 会员月券是否已领：一律按「本月口径」输出，不能直接透传数据库布尔值（跨月它还是上个月的真）
    memberMonthlyCouponClaimed: isMemberCouponClaimedThisMonth(profile),
    dailyCheckInDone: profile.dailyCheckInDone,
    dailyShareDone: profile.dailyShareDone,
    dailyBrowseRewardClaimed: profile.dailyBrowseRewardClaimed,
    dailyBrowseCount: profile.dailyBrowseCount,
    // 每日/每周任务扩展字段（2026-11-26）：Done=已完成待领、Claimed=已领取；
    // 老 App 不读这些键、不受影响
    dailyFavoriteDone: profile.dailyFavoriteDone,
    dailyFavoriteClaimed: profile.dailyFavoriteClaimed,
    dailyCartDone: profile.dailyCartDone,
    dailyCartClaimed: profile.dailyCartClaimed,
    dailyChatDone: profile.dailyChatDone,
    dailyChatClaimed: profile.dailyChatClaimed,
    dailyCommunityDone: profile.dailyCommunityDone,
    dailyCommunityClaimed: profile.dailyCommunityClaimed,
    checkInStreak: profile.checkInStreak ?? 0,
    weeklyCheckInDays: profile.weeklyCheckInDays ?? 0,
    weeklyCheckInClaimed: profile.weeklyCheckInClaimed,
    weeklyOrderDone: profile.weeklyOrderDone,
    weeklyOrderClaimed: profile.weeklyOrderClaimed,
    weeklyReviewDone: profile.weeklyReviewDone,
    weeklyReviewClaimed: profile.weeklyReviewClaimed,
    pushEnabled: profile.pushEnabled,
    // 新增资料字段：性别 / 生日 / 简介 / 成长值 / 会员到期 / 每日日期，老 App 不读这些键、不受影响
    gender: profile.gender ?? null,
    birthday: profile.birthday ? profile.birthday.toISOString().slice(0, 10) : null,
    bio: profile.bio ?? null,
    growthPoints: profile.growthPoints ?? 0,
    vipExpireAt: profile.vipExpireAt ? profile.vipExpireAt.toISOString() : null,
    dailyDate: profile.dailyDate ?? '',
    memberCouponMonth: profile.memberCouponMonth ?? '',
  };
}

async function loadProfileBundle(userId) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return null;
  // 每次读资料先过新鲜度：跨天/跨月时先把每日与月券状态清零，调用方拿到的永远是今天的口径
  const profile = await ensureProfileFresh(userId);
  return { user, profile };
}

// 今日已赚：把今天的每日任务流水按钱包类型汇总（refId 统一存今天日期，
// 每周任务的 refId 是周 key、天然不混进来）。任务页顶部展示用。
const DAILY_LEDGER_REF_TYPES = [
  'checkin',
  'checkin_bonus',
  'daily_share',
  'daily_browse',
  'daily_favorite',
  'daily_cart',
  'daily_chat',
  'daily_community',
  // 会员每日礼包的积分/币流水（在 coupons.js 领取核心里记）：refId 同样存
  // 今天日期，加进名单后「今日已赚」能把这笔算进去，口径与每日任务一致。
  'member_daily_gift',
];

async function withDailyEarned(userId, profileObj) {
  const groups = await prisma.walletLedger.groupBy({
    by: ['walletType'],
    where: { userId, refId: currentDailyDate(), refType: { in: DAILY_LEDGER_REF_TYPES } },
    _sum: { amount: true },
  });
  const earned = { points: 0, coins: 0 };
  for (const g of groups) {
    if (g.walletType === 'points') earned.points = g._sum.amount ?? 0;
    if (g.walletType === 'coins') earned.coins = g._sum.amount ?? 0;
  }
  return { ...profileObj, dailyEarnedPoints: earned.points, dailyEarnedCoins: earned.coins };
}

// 生日礼包（2026-11-26 做真）：生日当天（中国日期的月日对上）首次查资料时
// 发 +50 趣玩币，一年一次。防重复靠 birthdayGiftYear 原子占位：updateMany
// 带「年份小于今年」的条件，抢到（count=1）的人才发币、记流水、发通知。
// 输入：userId、profile（原始资料行，含 birthday 与 birthdayGiftYear）
// 坑：任何异常都吞掉——礼包是锦上添花，不能拖垮资料接口本身。
async function maybeGrantBirthdayGift(userId, profile) {
  try {
    if (!profile?.birthday) return;
    const today = currentDailyDate(new Date());
    if (today.slice(5, 10) !== profile.birthday.toISOString().slice(5, 10)) return;
    const year = Number(today.slice(0, 4));
    if ((profile.birthdayGiftYear ?? 0) >= year) return;
    const claimed = await prisma.userProfile.updateMany({
      where: { userId, birthdayGiftYear: { lt: year } },
      data: { birthdayGiftYear: year, funCoins: { increment: 50 } },
    });
    if (claimed.count !== 1) return;
    await recordWalletLedger(prisma, {
      userId,
      walletType: 'coins',
      amount: 50,
      title: '生日礼包',
      refType: 'birthday',
      refId: String(year),
    });
    await prisma.notification.create({
      data: {
        userId,
        title: '生日快乐',
        body: '生日礼包已到账：趣玩币 +50，去挑件喜欢的吧',
        type: 'system',
        targetType: null,
        targetId: null,
      },
    });
  } catch {
    // 礼包发放失败不挡资料读取
  }
}

router.get('/', authRequired, async (req, res) => {
  // 生日礼包在读资料前先判：发成功后下面读到的就是到账后的余额
  const preProfile = await prisma.userProfile.findUnique({ where: { userId: req.user.sub } });
  if (preProfile) await maybeGrantBirthdayGift(req.user.sub, preProfile);
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');
  ok(res, { profile: await withDailyEarned(req.user.sub, serializeProfile(bundle.user, bundle.profile)) });
});

router.get('/ledger', authRequired, async (req, res) => {
  const type = String(req.query.type ?? 'points').trim();
  if (!['points', 'coins'].includes(type)) {
    return fail(res, 400, 'type 必须是 points 或 coins');
  }

  const entries = await prisma.walletLedger.findMany({
    where: { userId: req.user.sub, walletType: type },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  ok(res, { entries: entries.map(serializeLedger) });
});

router.patch('/', authRequired, async (req, res) => {
  const nickname = req.body?.nickname != null ? String(req.body.nickname).trim() : null;
  const avatarPath = req.body?.avatarPath != null ? String(req.body.avatarPath).trim() : null;
  const pushEnabled = req.body?.pushEnabled;
  const gender = req.body?.gender != null ? String(req.body.gender).trim() : null;
  const bio = req.body?.bio != null ? String(req.body.bio).trim() : null;
  const birthdayRaw = req.body?.birthday != null ? String(req.body.birthday).trim() : null;

  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');

  if (nickname != null) {
    const nicknameError = validateNickname(nickname);
    if (nicknameError) return fail(res, 400, nicknameError);
    await prisma.user.update({ where: { id: req.user.sub }, data: { nickname } });
    bundle.user.nickname = nickname;
  }

  const profileData = {};
  if (avatarPath != null) {
    if (avatarPath.length === 0) {
      profileData.avatarPath = '';
    } else if (isDisplayableAvatarPath(avatarPath)) {
      profileData.avatarPath = avatarPath;
    } else {
      return fail(res, 400, '头像需通过上传接口设置');
    }
  }
  if (typeof pushEnabled === 'boolean') profileData.pushEnabled = pushEnabled;
  if (gender != null) profileData.gender = gender || null;
  if (bio != null) profileData.bio = bio ? bio.slice(0, 200) : null;
  if (birthdayRaw != null) {
    if (!birthdayRaw) {
      profileData.birthday = null;
    } else {
      const parsed = new Date(birthdayRaw);
      if (Number.isNaN(parsed.getTime())) return fail(res, 400, '生日格式不正确');
      profileData.birthday = parsed;
    }
  }

  const profile = Object.keys(profileData).length
    ? await prisma.userProfile.update({ where: { userId: req.user.sub }, data: profileData })
    : bundle.profile;

  ok(res, { profile: serializeProfile(bundle.user, profile) });
});

router.post('/avatar', authRequired, async (req, res) => {
  try {
    const avatarPath = saveUserAvatar({
      userId: req.user.sub,
      imageBase64: req.body?.imageBase64,
      mimeType: req.body?.mimeType,
    });
    await ensureUserProfile(req.user.sub);
    const profile = await prisma.userProfile.update({
      where: { userId: req.user.sub },
      data: { avatarPath },
    });
    const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
    ok(res, { profile: serializeProfile(user, profile), avatarPath });
  } catch (error) {
    fail(res, 400, error.message || '头像上传失败');
  }
});


// 任务领奖的统一骨架：事务里置「已领」、加余额、记一笔钱包流水。
// 输入：patch（要置的已领字段）、walletType（points 积分 / coins 趣玩币）、
// amount、title（流水标题）、refType / refId（流水出处，每日任务用今天日期、
// 每周任务用周 key，今日已赚汇总就靠 refId 对日期）。
// 输出：更新后的 profile。达标与防重复领取的判断留在各 case 里写明，不藏这里。
async function runTaskClaim(userId, { patch, walletType, amount, title, refType, refId }) {
  return prisma.$transaction(async (tx) => {
    const next = await tx.userProfile.update({
      where: { userId },
      data: {
        ...patch,
        ...(walletType === 'points' ? { points: { increment: amount } } : { funCoins: { increment: amount } }),
      },
    });
    await recordWalletLedger(tx, { userId, walletType, amount, title, refType, refId });
    return next;
  });
}
router.post('/actions/:action', authRequired, async (req, res) => {
  const action = String(req.params.action ?? '').trim();
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');

  let profile = bundle.profile;

  switch (action) {
    case 'check-in': {
      if (profile.dailyCheckInDone) return fail(res, 409, '今日已签到');
      // 连签：上次签到是昨天就接上、否则从 1 重新数。7 天一轮，
      // 轮内第 3 天额外 +30 积分、第 7 天额外 +100 积分，随签到一起发。
      const streak = profile.lastCheckInDate === previousDailyDate() ? (profile.checkInStreak ?? 0) + 1 : 1;
      const cycleDay = ((streak - 1) % 7) + 1;
      const bonus = cycleDay === 3 ? 30 : cycleDay === 7 ? 100 : 0;
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: {
            dailyCheckInDone: true,
            checkInStreak: streak,
            lastCheckInDate: currentDailyDate(),
            weeklyCheckInDays: { increment: 1 },
            points: { increment: 50 + bonus },
          },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'points',
          amount: 50,
          title: '每日签到',
          refType: 'checkin',
          refId: currentDailyDate(),
        });
        if (bonus > 0) {
          await recordWalletLedger(tx, {
            userId: req.user.sub,
            walletType: 'points',
            amount: bonus,
            title: `连签奖励（第 ${cycleDay} 天）`,
            refType: 'checkin_bonus',
            refId: currentDailyDate(),
          });
        }
        return next;
      });
      break;
    }
    case 'guide-reward': {
      // 新手引导完成奖励：20 趣玩币，一辈子一次，判重只看 guideRewardClaimed。
      if (profile.guideRewardClaimed) return fail(res, 409, '新手引导奖励已领取');
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { guideRewardClaimed: true, funCoins: { increment: 20 } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'coins',
          amount: 20,
          title: '新手引导奖励',
          refType: 'guide_reward',
          refId: 'once',
        });
        return next;
      });
      break;
    }
    case 'daily-share': {
      if (profile.dailyShareDone) return fail(res, 409, '今日分享任务已完成');
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { dailyShareDone: true, funCoins: { increment: 20 } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'coins',
          amount: 20,
          title: '分享奖励',
          refType: 'daily_share',
          refId: currentDailyDate(),
        });
        return next;
      });
      break;
    }
    case 'daily-browse-reward': {
      if (profile.dailyBrowseRewardClaimed) return fail(res, 409, '今日浏览奖励已领取');
      if (profile.dailyBrowseCount < 3) return fail(res, 400, '请先浏览 3 件商品');
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { dailyBrowseRewardClaimed: true, funCoins: { increment: 30 } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'coins',
          amount: 30,
          title: '每日任务',
          refType: 'daily_browse',
          refId: currentDailyDate(),
        });
        return next;
      });
      break;
    }
    case 'daily-favorite-reward': {
      if (profile.dailyFavoriteClaimed) return fail(res, 409, '今日收藏奖励已领取');
      if (!profile.dailyFavoriteDone) return fail(res, 400, '请先收藏 1 件商品');
      profile = await runTaskClaim(req.user.sub, {
        patch: { dailyFavoriteClaimed: true },
        walletType: 'coins',
        amount: 15,
        title: '收藏任务',
        refType: 'daily_favorite',
        refId: currentDailyDate(),
      });
      break;
    }
    case 'daily-cart-reward': {
      if (profile.dailyCartClaimed) return fail(res, 409, '今日加购奖励已领取');
      if (!profile.dailyCartDone) return fail(res, 400, '请先把 1 件商品加入购物车');
      profile = await runTaskClaim(req.user.sub, {
        patch: { dailyCartClaimed: true },
        walletType: 'coins',
        amount: 15,
        title: '加购任务',
        refType: 'daily_cart',
        refId: currentDailyDate(),
      });
      break;
    }
    case 'daily-chat-reward': {
      if (profile.dailyChatClaimed) return fail(res, 409, '今日聊天奖励已领取');
      if (!profile.dailyChatDone) return fail(res, 400, '请先和小豆聊一句');
      profile = await runTaskClaim(req.user.sub, {
        patch: { dailyChatClaimed: true },
        walletType: 'points',
        amount: 20,
        title: '小豆聊天任务',
        refType: 'daily_chat',
        refId: currentDailyDate(),
      });
      break;
    }
    case 'daily-community-reward': {
      if (profile.dailyCommunityClaimed) return fail(res, 409, '今日社区奖励已领取');
      if (!profile.dailyCommunityDone) return fail(res, 400, '请先在 AI 社区点赞 1 次');
      profile = await runTaskClaim(req.user.sub, {
        patch: { dailyCommunityClaimed: true },
        walletType: 'points',
        amount: 20,
        title: '社区互动任务',
        refType: 'daily_community',
        refId: currentDailyDate(),
      });
      break;
    }
    case 'weekly-checkin-reward': {
      if (profile.weeklyCheckInClaimed) return fail(res, 409, '本周签到奖励已领取');
      if ((profile.weeklyCheckInDays ?? 0) < 5) return fail(res, 400, '本周签到满 5 天才能领取');
      profile = await runTaskClaim(req.user.sub, {
        patch: { weeklyCheckInClaimed: true },
        walletType: 'points',
        amount: 100,
        title: '每周签到奖励',
        refType: 'weekly_checkin',
        refId: currentWeekKey(),
      });
      break;
    }
    case 'weekly-order-reward': {
      if (profile.weeklyOrderClaimed) return fail(res, 409, '本周下单奖励已领取');
      if (!profile.weeklyOrderDone) return fail(res, 400, '本周先完成 1 笔订单');
      profile = await runTaskClaim(req.user.sub, {
        patch: { weeklyOrderClaimed: true },
        walletType: 'coins',
        amount: 50,
        title: '每周下单奖励',
        refType: 'weekly_order',
        refId: currentWeekKey(),
      });
      break;
    }
    case 'weekly-review-reward': {
      if (profile.weeklyReviewClaimed) return fail(res, 409, '本周评价奖励已领取');
      if (!profile.weeklyReviewDone) return fail(res, 400, '本周先评价 1 件商品');
      profile = await runTaskClaim(req.user.sub, {
        patch: { weeklyReviewClaimed: true },
        walletType: 'coins',
        amount: 30,
        title: '每周评价奖励',
        refType: 'weekly_review',
        refId: currentWeekKey(),
      });
      break;
    }
    case 'redeem-points-coupon': {
      const cost = 500;
      const templateId = 'c7';
      if (profile.points < cost) return fail(res, 400, `积分不足，还差 ${cost - profile.points}`);

      const template = await prisma.couponTemplate.findUnique({ where: { id: templateId } });
      if (!template) return fail(res, 500, '兑换券配置缺失，请重新 seed');

      const existing = await prisma.userCoupon.findUnique({
        where: { userId_templateId: { userId: req.user.sub, templateId } },
      });
      if (existing && !existing.used) return fail(res, 409, '你已拥有该兑换券，请先使用后再兑换');

      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { points: { decrement: cost } },
        });
        await tx.userCoupon.upsert({
          where: { userId_templateId: { userId: req.user.sub, templateId } },
          create: { userId: req.user.sub, templateId, used: false },
          update: { used: false, usedAt: null, orderId: null, claimedAt: new Date() },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'points',
          amount: -cost,
          title: '积分兑换优惠券',
          refType: 'coupon_template',
          refId: templateId,
        });
        return next;
      });
      break;
    }
    case 'recharge-coins': {
      // 模拟支付：与订单付款同口径（无真实支付网关），支付成功即到账。
      // 档位查 RECHARGE_PACKAGES，body 里多报的金额/币数字段一律忽略。
      const packageId = String(req.body?.packageId ?? '').trim();
      const pack = RECHARGE_PACKAGES[packageId];
      if (!pack) return fail(res, 400, '充值档位不存在');
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { funCoins: { increment: pack.coins } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'coins',
          amount: pack.coins,
          title: '充值',
          refType: 'recharge',
          refId: packageId,
        });
        return next;
      });
      break;
    }
    case 'subscribe-member': {
      const cost = 299;
      const targetLevel = 2;
      if (profile.vipLevel >= targetLevel) return fail(res, 409, '您已是会员');
      if (profile.funCoins < cost) {
        return fail(res, 400, `趣玩币不足，还差 ${cost - profile.funCoins}`);
      }
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { vipLevel: targetLevel, funCoins: { decrement: cost } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'coins',
          amount: -cost,
          title: '开通趣玩会员',
          refType: 'vip',
          refId: `level_${targetLevel}`,
        });
        return next;
      });
      break;
    }
    default:
      return fail(res, 400, '未知操作');
  }

  ok(res, { profile: await withDailyEarned(req.user.sub, serializeProfile(bundle.user, profile)) });
});

router.post('/reset', authRequired, async (req, res) => {
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');

  await resetUserData(req.user.sub);
  const profile = await ensureUserProfile(req.user.sub);
  ok(res, { profile: serializeProfile(bundle.user, profile) });
});

export default router;
