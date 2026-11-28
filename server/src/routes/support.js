import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import { saveSupportChatImage } from '../utils/support-media.js';
import {
  appendMessage,
  getOrCreateConversation,
  recallSupportMessage,
  serializeConversation,
  serializeMessage,
} from '../utils/support-chat.js';

const router = Router();

async function loadUserConversation(userId, conversationId) {
  return prisma.supportConversation.findFirst({
    where: { id: conversationId, userId },
    include: { user: true },
  });
}

router.get('/conversations', authRequired, async (req, res) => {
  const rows = await prisma.supportConversation.findMany({
    where: { userId: req.user.sub },
    orderBy: { lastMessageAt: 'desc' },
    include: { user: true },
  });
  ok(res, {
    conversations: rows.map((row) => serializeConversation(row, row.user)),
  });
});

router.post('/conversations', authRequired, async (req, res) => {
  const productId = req.body?.productId ? String(req.body.productId) : null;
  const productName = req.body?.productName ? String(req.body.productName) : null;
  const subject = req.body?.subject ? String(req.body.subject) : null;

  const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
  if (!user) {
    fail(res, 404, '用户不存在');
    return;
  }

  const conversation = await getOrCreateConversation(req.user.sub, {
    productId,
    productName,
    subject,
  });

  const fresh = await prisma.supportConversation.findUnique({
    where: { id: conversation.id },
    include: { user: true },
  });

  ok(res, {
    conversation: serializeConversation(fresh, fresh.user),
    messages: [],
  });
});

router.get('/conversations/:id/messages', authRequired, async (req, res) => {
  const conversation = await loadUserConversation(req.user.sub, req.params.id);
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  const after = req.query.after ? new Date(String(req.query.after)) : null;
  const where = { conversationId: conversation.id };
  if (after && !Number.isNaN(after.getTime())) {
    where.createdAt = { gt: after };
  }

  const messages = await prisma.supportMessage.findMany({
    where,
    orderBy: { createdAt: 'asc' },
  });

  ok(res, { messages: messages.map(serializeMessage) });
});

router.post('/upload', authRequired, (req, res) => {
  try {
    const mediaUrl = saveSupportChatImage(req.body ?? {});
    ok(res, { mediaUrl });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/conversations/:id/messages', authRequired, async (req, res) => {
  const messageType = String(req.body?.messageType ?? 'text');
  const content = req.body?.content != null ? String(req.body.content) : '';
  const mediaUrl = req.body?.mediaUrl ? String(req.body.mediaUrl) : null;
  const stickerId = req.body?.stickerId ? String(req.body.stickerId) : null;

  const conversation = await loadUserConversation(req.user.sub, req.params.id);
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  const user = await prisma.user.findUnique({ where: { id: req.user.sub } });

  try {
    const { message, conversation: updated } = await appendMessage({
      conversationId: conversation.id,
      senderRole: 'user',
      senderName: user?.nickname ?? null,
      content,
      messageType,
      mediaUrl,
      stickerId,
      notifyAdmin: true,
    });
    log.info('客服', `用户发来一条${messageType === 'text' ? '文字' : '多媒体'}消息（会话 id ${conversation.id}）`);
    ok(res, {
      message: serializeMessage(message),
      conversation: serializeConversation(updated, updated.user),
    });
  } catch (error) {
    fail(res, 400, error.message || '发送失败');
  }
});

// 撤回自己刚发的消息（2 分钟内）：标记 recalledAt，两端轮询到后显示占位。
router.post('/conversations/:id/messages/:messageId/recall', authRequired, async (req, res) => {
  const conversation = await loadUserConversation(req.user.sub, req.params.id);
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  try {
    const updated = await recallSupportMessage({
      conversationId: conversation.id,
      messageId: req.params.messageId,
      senderRole: 'user',
    });
    log.info('客服', `用户撤回一条消息（会话 id ${conversation.id}）`);
    ok(res, { message: serializeMessage(updated) });
  } catch (error) {
    fail(res, 400, error.message || '撤回失败');
  }
});

router.post('/conversations/:id/read', authRequired, async (req, res) => {
  const conversation = await loadUserConversation(req.user.sub, req.params.id);
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  const updated = await prisma.supportConversation.update({
    where: { id: conversation.id },
    data: { unreadUser: 0 },
    include: { user: true },
  });

  ok(res, { conversation: serializeConversation(updated, updated.user) });
});

export default router;
