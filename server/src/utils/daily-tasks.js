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

// 昨天的中国日期（yyyy-MM-dd）：连签判断用。中国无夏令时，往前推 24 小时再按
// 中国日期格式化，结果就是昨天的日期字符串。
export function previousDailyDate(now = new Date()) {
  return formatChinaDate(new Date(now.getTime() - 24 * 60 * 60 * 1000));
}

// 本周的周 key：本周一的中国日期（yyyy-MM-dd）。每周任务整组状态只对这一周
// 有效，判断和清零都以它为准（同 dailyDate 的口径）。
export function currentWeekKey(now = new Date()) {
  const [y, m, d] = currentDailyDate(now).split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const offset = (date.getUTCDay() + 6) % 7; // 距本周一的天数（周一为 0）
  date.setUTCDate(date.getUTCDate() - offset);
  const mm = String(date.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(date.getUTCDate()).padStart(2, '0');
  return `${date.getUTCFullYear()}-${mm}-${dd}`;
}

// 确认 profile 的每日 / 每月状态属于今天 / 本月；过期就先清零落库再返回新对象。
// client 可以传事务对象（tx），不传就用全局 prisma。
export async function ensureProfileFresh(userId, client = prisma) {
  let profile = await client.userProfile.upsert({
    where: { userId },
    create: { userId, dailyDate: currentDailyDate(), memberCouponMonth: '', weekKey: currentWeekKey() },
    update: {},
  });

  const patch = {};
  if (profile.dailyDate !== currentDailyDate()) {
    patch.dailyCheckInDone = false;
    patch.dailyShareDone = false;
    patch.dailyBrowseRewardClaimed = false;
    patch.dailyBrowseCount = 0;
    patch.dailyFavoriteDone = false;
    patch.dailyFavoriteClaimed = false;
    patch.dailyCartDone = false;
    patch.dailyCartClaimed = false;
    patch.dailyChatDone = false;
    patch.dailyChatClaimed = false;
    patch.dailyCommunityDone = false;
    patch.dailyCommunityClaimed = false;
    patch.dailyDate = currentDailyDate();
  }
  if (profile.weekKey !== currentWeekKey()) {
    patch.weeklyCheckInDays = 0;
    patch.weeklyCheckInClaimed = false;
    patch.weeklyOrderDone = false;
    patch.weeklyOrderClaimed = false;
    patch.weeklyReviewDone = false;
    patch.weeklyReviewClaimed = false;
    patch.weekKey = currentWeekKey();
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
// 行为埋点：收藏 / 加购 / 和小豆聊天 / 社区点赞发生时，把对应每日任务标成
// 「已完成」（奖励由用户在任务页手动领）。失败只吞掉不外抛——记进度绝不能
// 把用户正在做的正事（收藏、加购本身）弄失败。
const DAILY_TASK_FIELDS = ['dailyFavoriteDone', 'dailyCartDone', 'dailyChatDone', 'dailyCommunityDone'];

export async function markDailyTaskDone(userId, field) {
  if (!userId || !DAILY_TASK_FIELDS.includes(field)) return;
  try {
    await ensureProfileFresh(userId);
    await prisma.userProfile.update({ where: { userId }, data: { [field]: true } });
  } catch {
    // 吞掉：任务进度是附带品，主流程优先
  }
}

const WEEKLY_TASK_FIELDS = ['weeklyOrderDone', 'weeklyReviewDone'];

export async function markWeeklyTaskDone(userId, field) {
  if (!userId || !WEEKLY_TASK_FIELDS.includes(field)) return;
  try {
    await ensureProfileFresh(userId);
    await prisma.userProfile.update({ where: { userId }, data: { [field]: true } });
  } catch {
    // 同上
  }
}

export function isMemberCouponClaimedThisMonth(profile, now = new Date()) {
  return Boolean(
    profile?.memberMonthlyCouponClaimed &&
      profile?.memberCouponMonth === currentMonthKey(now),
  );
}
