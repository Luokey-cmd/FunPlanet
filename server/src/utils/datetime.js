const CHINA_TZ = 'Asia/Shanghai';

export function formatChinaDateTime(date) {
  return date.toLocaleString('sv-SE', { timeZone: CHINA_TZ }).slice(0, 16);
}

export function formatChinaDate(date) {
  return date.toLocaleString('sv-SE', { timeZone: CHINA_TZ }).slice(0, 10);
}
