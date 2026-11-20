import { prisma } from '../db.js';
import { formatChinaDate } from './datetime.js';

// 每日 / 每月任务的「新鲜度」工具
//
// 背景（旧 bug）：UserProfile 里的 dailyCheckInDone 等字段只有「做没做」的开关、没有日期，
// 服务端又没有任何地方在新的一天清零，结果用户第一天签完到，第二天永远显示「今日已签到」，
// 会员每月赠券同理（领一次后再也领不了）。
//
// 现在的规则：
// - 输入：userId（用户内部 id）
// - 输出：已确认是「今天 / 本月」口径的最新 profile 对象
// - 坑：判断和清零必须在读 profile 的入口统一做，任何新接口读每日字段前都要先过这里，
//   不要在各接口里自己写清零逻辑，口径会散。
// - 日期一律按 Asia/Shanghai 算（formatChinaDate），不能用服务器本地日期，云服务器时区不一定是中国。

export function currentDailyDate(now = new Date()) {
  return formatChinaDate(now);
}

export function currentMonthKey(now = new Date()) {
  return formatChinaDate(now).slice(0, 7);
}

// 确认 profile 的每日 / 每月状态属于今天 / 本月；过期就先清零落库再返回新对象。
// client 可以传事务对象（tx），不传就用全局 prisma。
export async function ensureProfileFresh(userId, client = prisma) {
  let profile = await client.userProfile.upsert({
    where: { userId },
    create: { userId, dailyDate: currentDailyDate(), memberCouponMonth: '' },
    update: {},
  });

  const patch = {};
  if (profile.dailyDate !== currentDailyDate()) {
    patch.dailyCheckInDone = false;
    patch.dailyShareDone = false;
    patch.dailyBrowseRewardClaimed = false;
    patch.dailyBrowseCount = 0;
    patch.dailyDate = currentDailyDate();
  }
  if (profile.memberCouponMonth !== currentMonthKey()) {
    // 只清「已领」标记；月份本身在真正领取成功时再写，避免没领的人也被标成已领月份
    if (profile.memberMonthlyCouponClaimed) patch.memberMonthlyCouponClaimed = false;
  }

  if (Object.keys(patch).length > 0) {
    profile = await client.userProfile.update({
      where: { userId },
      data: patch,
    });
  }
  return profile;
}

// 会员月券「本月已领」的唯一判断口径：月份对得上且标记为真。
// 展示和领取判断都用它，不要再直接读 memberMonthlyCouponClaimed 布尔值。
export function isMemberCouponClaimedThisMonth(profile, now = new Date()) {
  return Boolean(
    profile?.memberMonthlyCouponClaimed &&
      profile?.memberCouponMonth === currentMonthKey(now),
  );
}
