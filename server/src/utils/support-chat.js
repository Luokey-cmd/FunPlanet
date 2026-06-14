import { prisma } from '../db.js';
import { readAdminSettings } from './admin-settings.js';
import { isDisplayableAvatarPath } from './avatar-media.js';
import { getStickerEmoji, isValidStickerId } from './support-stickers.js';

function previewContent(content, max = 80) {
  const text = String(content ?? '').trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max)}…`;
}

export function messagePreview(message) {
  const type = message.messageType ?? 'text';
  if (type === 'image') return '[图片]';
  if (type === 'sticker') {
    return getStickerEmoji(message.stickerId) ?? message.content ?? '[表情]';
  }
  return previewContent(message.content);
}

export function serializeMessage(message) {
  return {
    id: message.id,
    conversationId: message.conversationId,
    senderRole: message.senderRole,
    senderName: message.senderName ?? null,
    messageType: message.messageType ?? 'text',
    content: message.content,
    mediaUrl: message.mediaUrl ?? null,
    stickerId: message.stickerId ?? null,
    createdAt: message.createdAt.toISOString(),
  };
}

export const supportUserInclude = {
  user: { include: { profile: true } },
};

export function serializeConversation(conversation, user) {
  return {
    id: conversation.id,
    userId: conversation.userId,
    status: conversation.status,
    subject: conversation.subject ?? null,
    productId: conversation.productId ?? null,
    productName: conversation.productName ?? null,
    lastMessageAt: conversation.lastMessageAt.toISOString(),
    lastMessagePreview: conversation.lastMessagePreview ?? null,
    unreadAdmin: conversation.unreadAdmin,
    unreadUser: conversation.unreadUser,
    createdAt: conversation.createdAt.toISOString(),
    userNickname: user?.nickname ?? null,
    userPhone: user?.phone ?? null,
    userAvatarPath: isDisplayableAvatarPath(user?.profile?.avatarPath)
      ? user.profile.avatarPath
      : null,
  };
}

export async function findUserConversation(userId, productId) {
  const where = {
    userId,
    productId: productId ?? null,
  };
  return prisma.supportConversation.findFirst({
    where,
    orderBy: { lastMessageAt: 'desc' },
  });
}

export async function getOrCreateConversation(userId, { productId, productName, subject } = {}) {
  let conversation = await findUserConversation(userId, productId ?? null);
  if (conversation) return conversation;

  const resolvedSubject =
    subject ??
    (productName ? `商品咨询：${productName}` : '在线客服');

  return prisma.supportConversation.create({
    data: {
      userId,
      productId: productId ?? null,
      productName: productName ?? null,
      subject: resolvedSubject,
    },
  });
}

export async function appendMessage({
  conversationId,
  senderRole,
  senderName,
  content = '',
  messageType = 'text',
  mediaUrl = null,
  stickerId = null,
  notifyUser = false,
  notifyAdmin = false,
}) {
  const type = String(messageType || 'text');
  const text = String(content ?? '').trim();

  if (type === 'text' && !text) {
    throw new Error('消息内容不能为空');
  }
  if (type === 'image' && !mediaUrl) {
    throw new Error('图片地址无效');
  }
  if (type === 'sticker' && !isValidStickerId(stickerId)) {
    throw new Error('表情无效');
  }

  let storedContent = text;
  if (type === 'image') {
    storedContent = text || '[图片]';
  } else if (type === 'sticker') {
    storedContent = getStickerEmoji(stickerId) ?? (text || '[表情]');
  }

  return prisma.$transaction(async (tx) => {
    const conversation = await tx.supportConversation.findUnique({
      where: { id: conversationId },
      include: supportUserInclude,
    });
    if (!conversation) {
      throw new Error('会话不存在');
    }

    const message = await tx.supportMessage.create({
      data: {
        conversationId,
        senderRole,
        senderName: senderName ?? null,
        messageType: type,
        content: storedContent,
        mediaUrl: type === 'image' ? mediaUrl : null,
        stickerId: type === 'sticker' ? stickerId : null,
      },
    });

    const preview = messagePreview(message);
    const updateData = {
      lastMessageAt: message.createdAt,
      lastMessagePreview: preview,
      status: 'open',
    };

    if (senderRole === 'user') {
      updateData.unreadAdmin = { increment: 1 };
      updateData.unreadUser = 0;
    } else {
      updateData.unreadUser = { increment: 1 };
      updateData.unreadAdmin = 0;
    }

    const updated = await tx.supportConversation.update({
      where: { id: conversationId },
      data: updateData,
      include: supportUserInclude,
    });

    if (notifyUser && senderRole === 'admin') {
      await tx.notification.create({
        data: {
          userId: conversation.userId,
          title: '客服回复',
          body: previewContent(preview, 120),
          type: 'support',
        },
      });
    }

    return { message, conversation: updated };
  });
}

export function isUserNotifyEnabled() {
  const settings = readAdminSettings();
  return settings.notifications?.userNotify !== false;
}

export async function listAdminNotifications(limit = 20) {
  if (!isUserNotifyEnabled()) {
    return [];
  }

  const rows = await prisma.supportConversation.findMany({
    where: { unreadAdmin: { gt: 0 }, status: 'open' },
    orderBy: { lastMessageAt: 'desc' },
    take: limit,
    include: { user: true },
  });

  return rows.map((row) => ({
    id: row.id,
    conversationId: row.id,
    message: `${row.user.nickname}：${row.lastMessagePreview ?? '发来新消息'}`,
    time: row.lastMessageAt.toISOString(),
    read: false,
    userNickname: row.user.nickname,
    productName: row.productName,
  }));
}
