import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { APP_KNOWLEDGE } from './app-knowledge.js';
import { chatCompletion, streamChatCompletion } from './deepseek.js';
import { streamXiaodouAgent } from './utils/xiaodou-agent.js';
import { prisma } from './db.js';
import { authRequired } from './middleware/auth.js';
import addressRoutes from './routes/addresses.js';
import authRoutes from './routes/auth.js';
import bannerRoutes from './routes/banners.js';
import browseHistoryRoutes from './routes/browse-history.js';
import cartRoutes from './routes/cart.js';
import categoryRoutes from './routes/categories.js';
import couponRoutes from './routes/coupons.js';
import favoriteRoutes from './routes/favorites.js';
import notificationRoutes from './routes/notifications.js';
import orderRoutes from './routes/orders.js';
import productRoutes from './routes/products.js';
import profileRoutes from './routes/profile.js';
import adminRoutes from './routes/admin.js';
import changelogRoutes from './routes/changelog.js';
import supportRoutes from './routes/support.js';
import reviewRoutes from './routes/reviews.js';
import aiRoutes from './routes/ai.js';
import aiCommunityRoutes from './routes/ai-community.js';
import { syncAllProductSales } from './utils/product-sales.js';
import { seedAiCommunityIfNeeded } from './utils/ai-community-seed.js';
import { assertProductionConfig } from './utils/startup-check.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
assertProductionConfig();

const app = express();
const port = Number(process.env.PORT || 3000);

const apiKey = process.env.DEEPSEEK_API_KEY;
const baseUrl = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com';
const model = process.env.DEEPSEEK_MODEL || 'deepseek-chat';

const corsOrigins = String(process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean);

if (corsOrigins.length > 0) {
  app.use(cors({ origin: corsOrigins }));
} else if (process.env.NODE_ENV === 'production') {
  app.use(cors());
  console.warn('[startup] 警告: 未配置 CORS_ORIGINS，管理后台跨域可能受限');
} else {
  app.use(cors());
}

app.use(express.json({ limit: '100mb' }));

const assetsRoot = path.resolve(__dirname, '../../assets');
app.use('/assets', express.static(assetsRoot));

function ensureApiKey(res) {
  if (!apiKey) {
    res.status(500).json({ code: 500, message: '未配置 DEEPSEEK_API_KEY', data: null });
    return false;
  }
  return true;
}

function systemMessage() {
  return { role: 'system', content: APP_KNOWLEDGE };
}

function sanitizeChatMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0) return null;
  const sanitized = messages
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
    .slice(-20)
    .map((m) => ({ role: m.role, content: m.content.trim() }))
    .filter((m) => m.content.length > 0);
  return sanitized.length === 0 ? null : sanitized;
}

app.get('/api/health', async (_req, res) => {
  let dbOk = false;
  if (process.env.DATABASE_URL) {
    try {
      await prisma.$queryRaw`SELECT 1`;
      dbOk = true;
    } catch {
      dbOk = false;
    }
  }

  res.json({
    ok: dbOk || !process.env.DATABASE_URL,
    app: 'funplanet',
    db: dbOk,
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/banners', bannerRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/browse-history', browseHistoryRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/addresses', addressRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/ai-community', aiCommunityRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/changelog', changelogRoutes);

app.post('/api/chat', authRequired, async (req, res) => {
  if (!ensureApiKey(res)) return;

  const sanitized = sanitizeChatMessages(req.body?.messages);
  if (!sanitized) {
    res.status(400).json({ code: 400, message: '没有有效的对话消息', data: null });
    return;
  }

  try {
    const reply = await chatCompletion([systemMessage(), ...sanitized], { apiKey, baseUrl, model });
    res.json({ reply });
  } catch (error) {
    console.error('[chat]', error);
    res.status(500).json({ code: 500, message: error.message || '对话失败', data: null });
  }
});

app.post('/api/chat/stream', authRequired, async (req, res) => {
  if (!ensureApiKey(res)) return;

  const sanitized = sanitizeChatMessages(req.body?.messages);
  if (!sanitized) {
    res.status(400).json({ code: 400, message: '没有有效的对话消息', data: null });
    return;
  }

  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  try {
    for await (const event of streamXiaodouAgent(sanitized, { apiKey, baseUrl, model })) {
      if (event.type === 'text') {
        res.write(`data: ${JSON.stringify({ type: 'text', content: event.content })}\n\n`);
      } else if (event.type === 'products') {
        res.write(`data: ${JSON.stringify({ type: 'products', products: event.products })}\n\n`);
      }
    }
    res.write('data: [DONE]\n\n');
    res.end();
  } catch (error) {
    console.error('[chat/stream]', error);
    res.write(`data: ${JSON.stringify({ error: error.message || '对话失败' })}\n\n`);
    res.end();
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`趣玩星球 API 已启动: http://127.0.0.1:${port}`);
  if (!process.env.DATABASE_URL) console.warn('警告: 未检测到 DATABASE_URL');
  if (!process.env.JWT_SECRET && process.env.NODE_ENV !== 'production') {
    console.warn('警告: 未检测到 JWT_SECRET，使用默认值不安全');
  }
  if (!apiKey) console.warn('警告: 未检测到 DEEPSEEK_API_KEY');
  if (!process.env.DASHSCOPE_API_KEY) console.warn('警告: 未检测到 DASHSCOPE_API_KEY');
  if (process.env.DATABASE_URL) {
    seedAiCommunityIfNeeded()
      .catch((err) => console.warn('AI 社区种子数据初始化失败:', err.message));
    syncAllProductSales()
      .then(() => console.log('商品销量已同步为真实订单数据'))
      .catch((err) => console.warn('商品销量同步失败:', err.message));
  }
});
