import { prisma } from '../db.js';

const DEFAULT_AVATAR = '';

export async function resetUserData(userId) {
  await prisma.$transaction(async (tx) => {
    await tx.cartItem.deleteMany({ where: { userId } });
    await tx.favorite.deleteMany({ where: { userId } });
    await tx.browseHistoryItem.deleteMany({ where: { userId } });
    await tx.userCoupon.deleteMany({ where: { userId } });
    await tx.notification.deleteMany({ where: { userId } });
    await tx.address.deleteMany({ where: { userId } });
    await tx.order.deleteMany({ where: { userId } });
    await tx.walletLedger.deleteMany({ where: { userId } });

    await tx.userProfile.upsert({
      where: { userId },
      create: {
        userId,
        points: 0,
        funCoins: 0,
        vipLevel: 1,
        avatarPath: DEFAULT_AVATAR,
        newcomerClaimed: false,
        memberMonthlyCouponClaimed: false,
        dailyCheckInDone: false,
        dailyShareDone: false,
        dailyBrowseRewardClaimed: false,
        dailyBrowseCount: 0,
        pushEnabled: true,
      },
      update: {
        points: 0,
        funCoins: 0,
        vipLevel: 1,
        avatarPath: DEFAULT_AVATAR,
        newcomerClaimed: false,
        memberMonthlyCouponClaimed: false,
        dailyCheckInDone: false,
        dailyShareDone: false,
        dailyBrowseRewardClaimed: false,
        dailyBrowseCount: 0,
      },
    });
  });
}

export async function resetUserByPhone(phone) {
  const user = await prisma.user.findUnique({ where: { phone } });
  if (!user) throw new Error(`用户不存在: ${phone}`);
  await resetUserData(user.id);
  return user;
}
