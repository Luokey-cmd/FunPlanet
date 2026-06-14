const WEAK_JWT_SECRETS = new Set([
  '',
  'dev-only-change-me',
  'change-me-in-production',
  'change-this-to-a-long-random-secret-key',
]);

export function assertProductionConfig() {
  const isProd = process.env.NODE_ENV === 'production';
  if (!isProd) return;

  const secret = String(process.env.JWT_SECRET ?? '').trim();
  if (WEAK_JWT_SECRETS.has(secret) || secret.length < 32) {
    console.error('[startup] 生产环境 JWT_SECRET 必须设置为至少 32 位的强随机字符串');
    process.exit(1);
  }

  if (!process.env.DATABASE_URL) {
    console.error('[startup] 生产环境必须配置 DATABASE_URL');
    process.exit(1);
  }

  const pgPassword = process.env.POSTGRES_PASSWORD ?? '';
  if (pgPassword === 'funplanet123' || pgPassword.length < 12) {
    console.warn('[startup] 警告: POSTGRES_PASSWORD 过弱，请使用强密码');
  }

  if (!process.env.DEEPSEEK_API_KEY) {
    console.warn('[startup] 警告: 未配置 DEEPSEEK_API_KEY，小豆 AI 不可用');
  }

  if (!process.env.DASHSCOPE_API_KEY) {
    console.warn('[startup] 警告: 未配置 DASHSCOPE_API_KEY，AI 绘画不可用');
  }
}

export function getJwtSecret() {
  return process.env.JWT_SECRET || 'dev-only-change-me';
}
