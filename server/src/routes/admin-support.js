import { Router } from 'express';
import { prisma } from '../db.js';
import { adminAuthRequired } from '../middleware/adminAuth.js';
import { fail, ok } from '../utils/response.js';
import { saveSupportChatImage } from '../utils/support-media.js';
import {
  appendMessage,
  listAdminNotifications,
  serializeConversation,
  serializeMessage,
  supportUserInclude,
} from '../utils/support-chat.js';

const router = Router();

router.get('/notifications', adminAuthRequired, async (_req, res) => {
  const notifications = await listAdminNotifications();
  ok(res, { notifications });
});

router.get('/conversations', adminAuthRequired, async (req, res) => {
  const status = req.query.status ? String(req.query.status) : undefined;
  const where = status ? { status } : {};

  const rows = await prisma.supportConversation.findMany({
    where,
    orderBy: { lastMessageAt: 'desc' },
    include: supportUserInclude,
  });

  ok(res, {
    conversations: rows.map((row) => serializeConversation(row, row.user)),
  });
});

router.get('/conversations/:id/messages', adminAuthRequired, async (req, res) => {
  let conversation = await prisma.supportConversation.findUnique({
    where: { id: req.params.id },
    include: supportUserInclude,
  });
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  if (conversation.status === 'closed') {
    conversation = await prisma.supportConversation.update({
      where: { id: conversation.id },
      data: { status: 'open' },
      include: supportUserInclude,
    });
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

  ok(res, {
    conversation: serializeConversation(conversation, conversation.user),
    messages: messages.map(serializeMessage),
  });
});

router.post('/upload', adminAuthRequired, (req, res) => {
  try {
    const mediaUrl = saveSupportChatImage(req.body ?? {});
    ok(res, { mediaUrl });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/conversations/:id/messages', adminAuthRequired, async (req, res) => {
  const messageType = String(req.body?.messageType ?? 'text');
  const content = req.body?.content != null ? String(req.body.content) : '';
  const mediaUrl = req.body?.mediaUrl ? String(req.body.mediaUrl) : null;
  const stickerId = req.body?.stickerId ? String(req.body.stickerId) : null;

  const conversation = await prisma.supportConversation.findUnique({
    where: { id: req.params.id },
    include: supportUserInclude,
  });
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  try {
    const { message, conversation: updated } = await appendMessage({
      conversationId: conversation.id,
      senderRole: 'admin',
      senderName: req.admin.username,
      content,
      messageType,
      mediaUrl,
      stickerId,
      notifyUser: true,
    });
    ok(res, {
      message: serializeMessage(message),
      conversation: serializeConversation(updated, updated.user),
    });
  } catch (error) {
    fail(res, 400, error.message || '发送失败');
  }
});

router.post('/conversations/:id/read', adminAuthRequired, async (req, res) => {
  const conversation = await prisma.supportConversation.findUnique({
    where: { id: req.params.id },
    include: supportUserInclude,
  });
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  const updated = await prisma.supportConversation.update({
    where: { id: conversation.id },
    data: { unreadAdmin: 0 },
    include: supportUserInclude,
  });

  ok(res, { conversation: serializeConversation(updated, updated.user) });
});

router.patch('/conversations/:id/status', adminAuthRequired, async (req, res) => {
  const status = String(req.body?.status ?? '');
  if (!['open', 'closed'].includes(status)) {
    fail(res, 400, '无效的状态');
    return;
  }

  const conversation = await prisma.supportConversation.findUnique({
    where: { id: req.params.id },
    include: supportUserInclude,
  });
  if (!conversation) {
    fail(res, 404, '会话不存在');
    return;
  }

  const updated = await prisma.supportConversation.update({
    where: { id: conversation.id },
    data: { status },
    include: supportUserInclude,
  });

  ok(res, { conversation: serializeConversation(updated, updated.user) });
});

export default router;
