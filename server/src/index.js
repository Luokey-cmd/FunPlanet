import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { APP_KNOWLEDGE } from './app-knowledge.js';
import { chatCompletion } from './deepseek.js';
import { streamXiaodouAgent } from './utils/xiaodou-agent.js';
import { chatCompletionRaw } from './utils/openai-compatible.js';
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
import voiceRoutes from './routes/voice.js';
import { syncAllProductSales } from './utils/product-sales.js';
import { persistChatTurn, recordGuideRecommendations } from './utils/chat-history.js';
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
const dashscopeConfig = {
  apiKey: process.env.DASHSCOPE_API_KEY,
  baseUrl: process.env.DASHSCOPE_COMPAT_BASE_URL || 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  model: process.env.QWEN_AGENT_MODEL || 'qwen-plus',
};
const deepseekConfig = { apiKey, baseUrl, model };

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
  if (!dashscopeConfig.apiKey && !apiKey) {
    res.status(500).json({ code: 500, message: '未配置 DASHSCOPE_API_KEY 或 DEEPSEEK_API_KEY', data: null });
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
    .map((m) => {
      let content = m.content.trim();
      const ids = Array.isArray(m.productIds) ? m.productIds.map((id) => String(id).trim()).filter(Boolean) : [];
      if (m.role === 'assistant' && ids.length > 0) {
        content += `\n（刚才已展示商品 id：${ids.join('、')}）`;
      }
      return { role: m.role, content };
    })
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
app.use('/api/voice', voiceRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/changelog', changelogRoutes);

// 小豆聊天历史：会话列表与某会话的消息（App 以后做「历史会话」页直接读这里；现在先保证数据有存）
app.get('/api/chat/conversations', authRequired, async (req, res) => {
  const rows = await prisma.aiChatConversation.findMany({
    where: { userId: req.user.sub },
    orderBy: { updatedAt: 'desc' },
    take: 30,
    include: { _count: { select: { messages: true } } },
  });
  res.json({
    code: 0,
    message: 'ok',
    data: {
      conversations: rows.map((c) => ({
        id: c.id,
        title: c.title,
        messageCount: c._count.messages,
        updatedAt: c.updatedAt.toISOString(),
      })),
    },
  });
});

app.get('/api/chat/conversations/:id', authRequired, async (req, res) => {
  const conversation = await prisma.aiChatConversation.findFirst({
    where: { id: req.params.id, userId: req.user.sub },
    include: { messages: { orderBy: { createdAt: 'asc' } } },
  });
  if (!conversation) {
    res.status(404).json({ code: 404, message: '会话不存在', data: null });
    return;
  }
  res.json({
    code: 0,
    message: 'ok',
    data: {
      conversation: {
        id: conversation.id,
        title: conversation.title,
        messages: conversation.messages.map((m) => ({
          role: m.role,
          content: m.content,
          createdAt: m.createdAt.toISOString(),
        })),
      },
    },
  });
});

app.post('/api/chat', authRequired, async (req, res) => {
  if (!ensureApiKey(res)) return;

  const sanitized = sanitizeChatMessages(req.body?.messages);
  if (!sanitized) {
    res.status(400).json({ code: 400, message: '没有有效的对话消息', data: null });
    return;
  }

  try {
    let reply;
    if (dashscopeConfig.apiKey) {
      const message = await chatCompletionRaw({
        ...dashscopeConfig,
        messages: [systemMessage(), ...sanitized],
        temperature: 0.6,
        maxTokens: 700,
      });
      reply = String(message.content ?? '').trim();
    } else {
      reply = await chatCompletion([systemMessage(), ...sanitized], deepseekConfig);
    }
    res.json({ reply });
    // 聊完落库：只存本轮一问一答，失败不影响这次响应（persistChatTurn 内部已吞错误）
    const lastUser = [...sanitized].reverse().find((m) => m.role === 'user');
    await persistChatTurn({
      userId: req.user?.sub,
      userText: lastUser?.content ?? '',
      assistantText: reply,
    });
  } catch (error) {
    console.error('[chat]', error);
    res.status(500).json({ code: 500, message: error.message || '对话失败', data: null });
  }
});

app.post('/api/chat/stream', authRequired, async (req, res) => {
  if (!ensureApiKey(res)) return;

  const imageBase64 = typeof req.body?.imageBase64 === 'string' ? req.body.imageBase64 : '';
  const mimeType = typeof req.body?.mimeType === 'string' ? req.body.mimeType : 'image/jpeg';
  let sanitized = sanitizeChatMessages(req.body?.messages);
  if (!sanitized && imageBase64) {
    sanitized = [{ role: 'user', content: '帮我看看店里有没有同款或同类' }];
  }
  if (!sanitized) {
    res.status(400).json({ code: 400, message: '没有有效的对话消息', data: null });
    return;
  }

  // 流式回复边推边攒全文，推完把这一轮落库（聊天记录 + 导购推荐记录）
  let assistantFullText = '';
  let recommendedProducts = [];
  const lastUserText = [...sanitized].reverse().find((m) => m.role === 'user')?.content ?? '';

  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  try {
    for await (const event of streamXiaodouAgent(sanitized, {
      dashscope: dashscopeConfig,
      deepseek: deepseekConfig,
      userId: req.user?.sub,
      imageBase64: imageBase64 || undefined,
      mimeType,
      starwish: req.body?.starwish && typeof req.body.starwish === 'object' ? req.body.starwish : null,
      vision: req.body?.vision && typeof req.body.vision === 'object' ? req.body.vision : null,
    })) {
      if (event.type === 'text') {
        assistantFullText += String(event.content ?? '');
        res.write(`data: ${JSON.stringify({ type: 'text', content: event.content })}\n\n`);
      } else if (event.type === 'products' || event.type === 'fate_cards') {
        if (Array.isArray(event.products) && event.products.length > 0) {
          recommendedProducts = event.products;
        }
        res.write(`data: ${JSON.stringify({ type: event.type, products: event.products, roles: event.roles ?? [] })}\n\n`);
      } else if (event.type === 'cart_confirm') {
        res.write(`data: ${JSON.stringify({ type: 'cart_confirm', products: event.products })}\n\n`);
      } else if (event.type === 'appraisal') {
        assistantFullText += String(event.content ?? '');
        res.write(`data: ${JSON.stringify({ type: 'appraisal', content: event.content, vision: event.vision ?? null })}\n\n`);
      } else if (event.type === 'gift_note') {
        res.write(`data: ${JSON.stringify({ type: 'gift_note', content: event.content })}\n\n`);
      }
    }
    res.write('data: [DONE]\n\n');
    res.end();
    // 落库放在响应结束之后做，不拖慢用户看到回复的速度
    const conversation = await persistChatTurn({
      userId: req.user?.sub,
      userText: lastUserText,
      assistantText: assistantFullText,
    });
    if (recommendedProducts.length > 0) {
      await recordGuideRecommendations({
        userId: req.user?.sub,
        conversationId: conversation?.id ?? null,
        requestText: lastUserText,
        route: req.body?.starwish?.route ?? req.body?.starwish?.purpose ?? null,
        products: recommendedProducts,
      });
    }
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
  if (!apiKey) console.warn('警告: 未检测到 DEEPSEEK_API_KEY（小豆备援）');
  if (!process.env.DASHSCOPE_API_KEY) console.warn('警告: 未检测到 DASHSCOPE_API_KEY（小豆导购 / AI 绘画）');
  if (process.env.DATABASE_URL) {
    seedAiCommunityIfNeeded()
      .catch((err) => console.warn('AI 社区种子数据初始化失败:', err.message));
    syncAllProductSales()
      .then(() => console.log('商品销量已同步为真实订单数据'))
      .catch((err) => console.warn('商品销量同步失败:', err.message));
  }
});
