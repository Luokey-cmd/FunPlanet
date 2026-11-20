import { prisma } from '../db.js';

// 小豆聊天落库
//
// 背景：之前 /api/chat 是无状态接口，聊完不存，历史只在手机本地，换手机 / 清数据就没了，
// 服务端也统计不了导购效果。现在每次对话结束把「这一轮」存进 AiChatConversation / AiChatMessage，
// 命运牌 / 商品推荐同时记进 GuideRecommendation。
//
// 输入：userId、userText（本轮用户原话）、assistantText（本轮小豆回复全文）
// 输出：conversation（会话对象）；失败返回 null
// 坑：
// - 只存本轮的一问一答，不要把请求里带的历史消息整段再存一遍，会越存越重复；
// - 落库失败绝不能影响聊天本身，所以这里内部吞掉错误、只打日志，调用方不用再包一层也行；
// - 会话复用规则：30 分钟内有会话就接着用，超过就开新会话。App 以后传 conversationId 时再改成按 id 找。

const REUSE_WINDOW_MS = 30 * 60 * 1000;

export async function persistChatTurn({ userId, userText, assistantText }) {
  if (!userId || (!userText && !assistantText)) return null;
  try {
    const since = new Date(Date.now() - REUSE_WINDOW_MS);
    let conversation = await prisma.aiChatConversation.findFirst({
      where: { userId, updatedAt: { gte: since } },
      orderBy: { updatedAt: 'desc' },
    });
    if (!conversation) {
      conversation = await prisma.aiChatConversation.create({
        data: {
          userId,
          title: String(userText ?? '').trim().slice(0, 24),
        },
      });
    }
    const messages = [];
    if (userText) messages.push({ conversationId: conversation.id, role: 'user', content: String(userText).slice(0, 4000) });
    if (assistantText) messages.push({ conversationId: conversation.id, role: 'assistant', content: String(assistantText).slice(0, 8000) });
    if (messages.length > 0) {
      await prisma.aiChatMessage.createMany({ data: messages });
      await prisma.aiChatConversation.update({
        where: { id: conversation.id },
        data: { updatedAt: new Date() },
      });
    }
    return conversation;
  } catch (error) {
    console.warn('[chat-history] persist turn failed', error.message);
    return null;
  }
}

// 记录一批导购推荐（命运三翻 / 普通商品推荐共用）
// products 是序列化后的商品数组；reason 优先用商品自带的推荐理由，没有就用商品的结构化卖点兜底拼一句
export async function recordGuideRecommendations({ userId, conversationId = null, requestText = '', route = null, products = [] }) {
  if (!userId || !Array.isArray(products) || products.length === 0) return;
  try {
    const rows = products
      .filter((p) => p && p.id)
      .map((p, index) => ({
        userId,
        conversationId: conversationId ?? null,
        requestText: String(requestText ?? '').slice(0, 1000),
        productId: String(p.id),
        route: route ? String(route).slice(0, 50) : null,
        reason: String(
          p.guideReason ?? p.reason ?? (Array.isArray(p.sellingPoints) ? p.sellingPoints[0] ?? '' : ''),
        ).slice(0, 1000),
        rank: index + 1,
        outcome: 'recommended',
      }));
    if (rows.length > 0) {
      await prisma.guideRecommendation.createMany({ data: rows });
    }
  } catch (error) {
    console.warn('[chat-history] record recommendations failed', error.message);
  }
}
