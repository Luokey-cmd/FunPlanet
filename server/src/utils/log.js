// ============================================================
// 中文日志工具（服务端）
// 输入：模块名（中文标签，如 '订单'）+ 一句人话说明；报错时可再附
//       原始错误对象。没有返回值。
// 输出：一行带时刻的中文日志，例如
//       [17:23:05]【订单】创建订单成功，订单号 103，应付 ¥103
//       hx 在控制台里搜【订单】就能只看订单相关的日志。
// 规则：
// - 级别由环境变量 LOG_LEVEL 控制：error < warn < info < debug，
//   默认 info。info 看业务事件与每个请求的汇总行；debug 再加
//   细碎流水；warn 只看警告和报错（想让控制台清净时用）。
// - 报错统一走 error()：中文说明在前、英文原文紧随其后打印——
//   hx 看中文就懂发生了什么；要复制给 AI 定位时，英文原文也在。
// 坑：密码、钥匙、token、完整手机号绝不打进日志；用户信息只打
//     用户 id 这类无害字段。请求体也不要整包打印（太大且含隐私）。
// ============================================================

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const currentLevel =
  LEVELS[String(process.env.LOG_LEVEL || 'info').toLowerCase()] ?? LEVELS.info;

function timeStr() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function emit(level, tag, message) {
  if (LEVELS[level] > currentLevel) return;
  const line = `[${timeStr()}]【${tag}】${message}`;
  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
}

export const log = {
  // 业务事件：发生了什么事（登录成功、订单创建、券已领取……）
  info(tag, message) {
    emit('info', tag, message);
  },
  // 细碎流水：默认不显示，LOG_LEVEL=debug 时才开
  debug(tag, message) {
    emit('debug', tag, message);
  },
  // 警告：事情没成但也不算崩（参数不对、请求被拒绝等）
  warn(tag, message) {
    emit('warn', tag, message);
  },
  // 报错：中文说明在前，原始错误对象紧随其后完整打印
  error(tag, message, err) {
    emit('error', tag, message);
    if (err !== undefined) console.error(err);
  },
};
