import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { APP_KNOWLEDGE } from './app-knowledge.js';
import { chatCompletion } from './deepseek.js';
import { streamXiaodouAgent } from './utils/xiaodou-agent.js';
import { drawStarCardsBatch } from './utils/xiaodou-tools.js';
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
import { attachVoiceStreamServer } from './utils/voice-stream.js';
import { syncAllProductSales } from './utils/product-sales.js';
import { persistChatTurn, recordGuideRecommendations } from './utils/chat-history.js';
import { seedAiCommunityIfNeeded } from './utils/ai-community-seed.js';
import { assertProductionConfig } from './utils/startup-check.js';
import { log } from './utils/log.js';

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

// 请求日志中间件（middleware：在每次请求进来时先过一道手的组件）。
// 每个接口请求在控制台留一行中文：调了什么、结果码、耗时；标签按
// 路径第一段翻成中文模块名，hx 搜【订单】就能只看订单的往来。
// 4xx 记警告、5xx 记报错——不用翻每个路由文件也知道哪儿出事了。
const API_TAG_MAP = {
  auth: '账号', products: '商品', banners: '横幅', categories: '分类',
  cart: '购物车', favorites: '收藏', 'browse-history': '足迹',
  coupons: '优惠券', notifications: '通知', addresses: '地址',
  orders: '订单', profile: '个人资料', support: '客服', reviews: '评价',
  ai: 'AI绘画', 'ai-community': 'AI社区', voice: '语音', admin: '后台',
  changelog: '更新日志', chat: '小豆',
};
app.use('/api', (req, res, next) => {
  const startedAt = Date.now();
  res.on('finish', () => {
    const seg = req.path.split('/').filter(Boolean)[0] ?? '';
    const tag = API_TAG_MAP[seg] ?? '请求';
    const line = `${req.method} ${req.originalUrl} → ${res.statusCode} · ${Date.now() - startedAt}ms`;
    if (res.statusCode >= 500) log.error(tag, `服务器内部错误：${line}`);
    else if (res.statusCode >= 400) log.warn(tag, `请求没成功：${line}`);
    else log.info(tag, line);
  });
  next();
});

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
    log.error('小豆', '普通对话回复失败', error);
    res.status(500).json({ code: 500, message: error.message || '对话失败', data: null });
  }
});

// 日志里截一段用户问题预览：只取前 40 字，避免整段对话刷屏。
function lastUserTextPreview(messages) {
  const text = [...messages].reverse().find((m) => m.role === 'user')?.content ?? '';
  return text.length > 40 ? `${text.slice(0, 40)}…` : text;
}

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

  log.info('小豆', `收到提问：${lastUserTextPreview(sanitized)}${imageBase64 ? '（带图片）' : ''}`);

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
      } else if (event.type === 'thinking' || event.type === 'status') {
        // 思考过程与状态提示只给用户看进度，不并入落库的答案全文。
        res.write(`data: ${JSON.stringify({ type: event.type, content: event.content })}\n\n`);
      } else if (event.type === 'products' || event.type === 'fate_cards') {
        if (Array.isArray(event.products) && event.products.length > 0) {
          recommendedProducts = event.products;
        }
        res.write(`data: ${JSON.stringify({ type: event.type, products: event.products, roles: event.roles ?? [], ...(event.batch ? { batch: event.batch } : {}) })}\n\n`);
      } else if (event.type === 'actions') {
        // 办事清单条目：办成一条推一条，App 实时往清单卡里追加；
        // 不落云端聊天记录（清单只存用户手机本地，与设计稿一致）。
        res.write(`data: ${JSON.stringify({ type: 'actions', action: event.action })}\n\n`);
      } else if (event.type === 'homework') {
        res.write(`data: ${JSON.stringify({ type: 'homework', entry: event.entry })}\n\n`);
      } else if (event.type === 'options') {
        // 提问选项：这一轮以问句收尾时随正文下发的短回答按钮，
        // App 渲染在气泡下方，点了就当用户回复；不落库。
        res.write(`data: ${JSON.stringify({ type: 'options', options: event.options ?? [] })}\n\n`);
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
    log.info('小豆', `回复完成，共 ${assistantFullText.length} 字${recommendedProducts.length > 0 ? `，亮牌 ${recommendedProducts.length} 件商品` : ''}`);
    // 落库放在响应结束之后做，不拖慢用户看到回复的速度。
    // 单独包一层：响应已经结束，这里再失败也只能记日志——要是
    // 抛进外层 catch，它会往已关闭的响应里写错误事件，直接崩
    // （2026-11-23 全面自查修）。
    try {
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
    } catch (persistError) {
      log.error('小豆', '聊天记录保存失败（回复已经发给用户，不影响这次使用）', persistError);
    }
  } catch (error) {
    log.error('小豆', '流式回复中途失败', error);
    res.write(`data: ${JSON.stringify({ error: error.message || '对话失败' })}\n\n`);
    res.end();
  }
});

// 亮牌批次翻页：App 点「下一批」时直达这里，不经模型——拿上一批的
// 抽牌条件 + 已展示的商品 id，接着抽下一批。纯查库，不需要 AI 钥匙。
app.post('/api/chat/draw-batch', authRequired, async (req, res) => {
  try {
    const body = req.body ?? {};
    const excludeIds = (Array.isArray(body.excludeIds) ? body.excludeIds : [])
      .map((id) => String(id).trim())
      .filter(Boolean)
      .slice(0, 200);
    const result = await drawStarCardsBatch({
      query: typeof body.query === 'string' ? body.query : undefined,
      majorCategory: typeof body.majorCategory === 'string' ? body.majorCategory : undefined,
      minPrice: Number.isFinite(Number(body.minPrice)) && body.minPrice != null ? Number(body.minPrice) : undefined,
      maxPrice: Number.isFinite(Number(body.maxPrice)) && body.maxPrice != null ? Number(body.maxPrice) : undefined,
      sort: typeof body.sort === 'string' ? body.sort : undefined,
      excludeIds,
    });
    log.info('小豆', `亮牌翻页：已排除 ${excludeIds.length} 件，这批 ${result?.products?.length ?? 0} 件${result?.hasMore ? '，后面还有' : '，已是最后一批'}`);
    res.json({ code: 0, message: 'ok', data: result });
  } catch (error) {
    log.error('小豆', '亮牌翻页（下一批）失败', error);
    res.status(500).json({ code: 500, message: error.message || '抽牌失败', data: null });
  }
});

const httpServer = app.listen(port, '0.0.0.0', () => {
  log.info('系统', `趣玩星球服务端已启动：http://127.0.0.1:${port}`);
  if (!process.env.DATABASE_URL) log.warn('系统', '未检测到 DATABASE_URL（数据库地址），数据功能不可用');
  if (!process.env.JWT_SECRET && process.env.NODE_ENV !== 'production') {
    log.warn('系统', '未检测到 JWT_SECRET（登录令牌密钥），正在用默认值，不安全');
  }
  if (!apiKey) log.warn('系统', '未检测到 DEEPSEEK_API_KEY（小豆备援大脑的钥匙）');
  if (!process.env.DASHSCOPE_API_KEY) log.warn('系统', '未检测到 DASHSCOPE_API_KEY（小豆导购 / AI 绘画的钥匙）');
  if (process.env.DATABASE_URL) {
    // 启动自检：真连一次数据库，成败都打中文日志，免得 hx 对着
    // 后面的报错猜是不是数据库没起来。
    prisma.$queryRaw`SELECT 1`
      .then(() => log.info('系统', '数据库连接成功'))
      .catch((err) => log.error('系统', '数据库连接失败，先检查数据库容器是否启动', err));
    seedAiCommunityIfNeeded()
      .then(() => log.debug('系统', 'AI 社区种子数据检查完成'))
      .catch((err) => log.warn('系统', `AI 社区种子数据初始化失败：${err.message}`));
    syncAllProductSales()
      .then(() => log.info('系统', '商品销量已同步为真实订单数据'))
      .catch((err) => log.warn('系统', `商品销量同步失败：${err.message}`));
  }
});

// 语音流式识别（WebSocket 中转）与 HTTP 接口共用同一个服务与端口。
attachVoiceStreamServer(httpServer);
