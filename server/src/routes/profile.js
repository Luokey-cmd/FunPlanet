import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { resetUserData } from '../utils/reset-user.js';
import { recordWalletLedger, serializeLedger } from '../utils/wallet-ledger.js';
import { isDisplayableAvatarPath, saveUserAvatar } from '../utils/avatar-media.js';

const router = Router();

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
    memberMonthlyCouponClaimed: profile.memberMonthlyCouponClaimed,
    dailyCheckInDone: profile.dailyCheckInDone,
    dailyShareDone: profile.dailyShareDone,
    dailyBrowseRewardClaimed: profile.dailyBrowseRewardClaimed,
    dailyBrowseCount: profile.dailyBrowseCount,
    pushEnabled: profile.pushEnabled,
  };
}

async function loadProfileBundle(userId) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return null;
  const profile = await ensureUserProfile(userId);
  return { user, profile };
}

router.get('/', authRequired, async (req, res) => {
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');
  ok(res, { profile: serializeProfile(bundle.user, bundle.profile) });
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

router.post('/actions/:action', authRequired, async (req, res) => {
  const action = String(req.params.action ?? '').trim();
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');

  let profile = bundle.profile;

  switch (action) {
    case 'check-in': {
      if (profile.dailyCheckInDone) return fail(res, 409, '今日已签到');
      profile = await prisma.$transaction(async (tx) => {
        const next = await tx.userProfile.update({
          where: { userId: req.user.sub },
          data: { dailyCheckInDone: true, points: { increment: 50 } },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'points',
          amount: 50,
          title: '每日签到',
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
        });
        return next;
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
          update: { used: false, claimedAt: new Date() },
        });
        await recordWalletLedger(tx, {
          userId: req.user.sub,
          walletType: 'points',
          amount: -cost,
          title: '积分兑换优惠券',
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
        });
        return next;
      });
      break;
    }
    default:
      return fail(res, 400, '未知操作');
  }

  ok(res, { profile: serializeProfile(bundle.user, profile) });
});

router.post('/reset', authRequired, async (req, res) => {
  const bundle = await loadProfileBundle(req.user.sub);
  if (!bundle) return fail(res, 404, '用户不存在');

  await resetUserData(req.user.sub);
  const profile = await ensureUserProfile(req.user.sub);
  ok(res, { profile: serializeProfile(bundle.user, profile) });
});

export default router;
