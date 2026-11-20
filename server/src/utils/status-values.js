// 全项目状态取值对照表
//
// 背景：订单状态、支付状态这些字段在数据库里都是 String（文字），数据库本身不限制取值，
// 拼错一个字母也存得进去，直到页面筛不出来才发现。所以取值只能靠全项目照这张表写：
// - 新增状态值时先加到这里，再去用它的地方改；
// - 不要在某个文件里临时发明新写法（比如发货到底是 shipping，不许另写 shipped）。
// 数据库字段这次没有改成枚举，是为了兼容 App 和后台已经在用的字符串口径；
// 等以后单独做状态治理时，再按这张表迁成枚举。

export const ORDER_STATUSES = [
  'pending', // 待付款
  'paid', // 已付款待发货
  'shipping', // 已发货待收货
  'completed', // 已完成（确认收货后）
  'cancelled', // 已取消
  'returned', // 已退货（历史兼容值，后台售后筛选会把 cancelled 也算进退货类，新逻辑不要再主动写入这个值，售后走 AfterSaleRequest）
];

export const PAYMENT_STATUSES = ['pending', 'paid', 'failed', 'refunded'];

export const PAYMENT_METHODS = ['mock', 'wechat', 'alipay'];

export const AFTER_SALE_TYPES = ['refund', 'return'];
export const AFTER_SALE_STATUSES = ['pending', 'approved', 'rejected', 'completed'];

export const USER_STATUSES = ['active', 'disabled', 'deleted'];

export const MODERATION_STATUSES = ['visible', 'hidden', 'pending'];

export const GUIDE_OUTCOMES = ['recommended', 'clicked', 'ordered', 'dismissed'];

export function isOneOf(list, value) {
  return list.includes(value);
}
