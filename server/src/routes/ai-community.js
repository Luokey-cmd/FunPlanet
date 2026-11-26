import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
import { log } from '../utils/log.js';
import { markDailyTaskDone } from '../utils/daily-tasks.js';
import {
  assertUserOwnsImagePath,
  saveCommunityImage,
} from '../utils/ai-community-media.js';
import {
  scheduleAiEngagementForUserPost,
  scheduleAiReplyToUserComment,
} from '../utils/ai-community-ai.js';

const router = Router();

const MAX_CONTENT_LEN = 500;
const deepseekConfig = () => ({
  apiKey: process.env.DEEPSEEK_API_KEY,
  baseUrl: process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com',
  model: process.env.DEEPSEEK_MODEL || 'deepseek-chat',
});

function serializeAuthor({ authorType, user, aiFriend }) {
  if (authorType === 'ai_friend' && aiFriend) {
    return {
      type: 'ai_friend',
      id: aiFriend.id,
      name: aiFriend.name,
      avatarPath: aiFriend.avatarPath || '',
      avatarColor: aiFriend.avatarColor || '#A389F4',
    };
  }
  if (authorType === 'user' && user) {
    return {
      type: 'user',
      id: user.id,
      name: user.nickname,
      avatarPath: user.profile?.avatarPath || '',
      avatarColor: '',
    };
  }
  return { type: 'unknown', id: '', name: '未知', avatarPath: '', avatarColor: '#A389F4' };
}

function serializeComment(row) {
  return {
    id: row.id,
    author: serializeAuthor({
      authorType: row.authorType,
      user: row.user,
      aiFriend: row.aiFriend,
    }),
    content: row.content,
    parentId: row.parentId || '0',
    rootId: row.rootId || '0',
    replyToUserId: row.replyToUserId || '',
    replyToUserName: row.replyToUserName || '',
    createdAt: row.createdAt.toISOString(),
  };
}

function serializeLikers(likes) {
  return likes.map((like) => {
    if (like.aiFriendId && like.aiFriend) {
      return {
        type: 'ai_friend',
        id: like.aiFriend.id,
        name: like.aiFriend.name,
        avatarPath: like.aiFriend.avatarPath || '',
        avatarColor: like.aiFriend.avatarColor || '#A389F4',
      };
    }
    if (like.user) {
      return {
        type: 'user',
        id: like.user.id,
        name: like.user.nickname,
        avatarPath: like.user.profile?.avatarPath || '',
        avatarColor: '',
      };
    }
    return { type: 'unknown', id: '', name: '用户', avatarPath: '', avatarColor: '#A389F4' };
  });
}

function serializeLikeNames(likes) {
  return likes.map((like) => {
    if (like.aiFriendId && like.aiFriend) {
      return like.aiFriend.name;
    }
    return like.user?.nickname || '用户';
  });
}

function normalizeImagePaths(row) {
  const paths = Array.isArray(row.imagePaths)
    ? row.imagePaths.map((p) => String(p ?? '').trim()).filter(Boolean)
    : [];
  if (paths.length > 0) return paths.slice(0, 9);
  const single = String(row.imagePath ?? '').trim();
  return single ? [single] : [];
}

function serializePost(row, currentUserId) {
  const likedByMe = row.likes.some(
    (like) => like.likerKey === `user:${currentUserId}` || like.userId === currentUserId,
  );
  const imagePaths = normalizeImagePaths(row);

  return {
    id: row.id,
    author: serializeAuthor({
      authorType: row.authorType,
      user: row.user,
      aiFriend: row.aiFriend,
    }),
    content: row.content,
    imagePath: imagePaths[0] || '',
    imagePaths,
    createdAt: row.createdAt.toISOString(),
    likeCount: row.likes.length,
    likedByMe,
    likeNames: serializeLikeNames(row.likes),
    likers: serializeLikers(row.likes),
    comments: row.comments.map(serializeComment),
  };
}

const postInclude = {
  user: { include: { profile: true } },
  aiFriend: true,
  likes: {
    orderBy: { createdAt: 'asc' },
    include: {
      user: { include: { profile: true } },
      aiFriend: true,
    },
  },
  comments: {
    orderBy: { createdAt: 'asc' },
    include: {
      user: { include: { profile: true } },
      aiFriend: true,
    },
  },
};

router.get('/feed', authRequired, async (req, res) => {
  const take = Math.min(Math.max(Number(req.query.limit) || 20, 1), 50);
  const rows = await prisma.aiCommunityPost.findMany({
    // 隐藏的动态不进信息流（moderationStatus 是 2026-11-20 新增的审核状态字段）
    where: { moderationStatus: 'visible' },
    orderBy: { createdAt: 'desc' },
    take,
    include: postInclude,
  });

  ok(res, {
    posts: rows.map((row) => serializePost(row, req.user.sub)),
  });
});

// 社区未读回复数（hx 2026-11-26 拍板）：口径只认评论不认点赞——帖子作者是
// 当前用户、评论时间晚于已读标记、且评论者不是本人（AI 好友的自动回复算
// 「有人回复」，其他真实用户也算；本人在自己帖子下的评论不算）。
// 已读标记 communityLastReadAt 为空 = 从没标过：先把标记立在当前时间再返 0，
// 防功能首次启用时把历史回复全算成未读（倒灌）。
router.get('/unread-replies', authRequired, async (req, res) => {
  const me = req.user.sub;
  const profile = await prisma.userProfile.findUnique({
    where: { userId: me },
    select: { communityLastReadAt: true },
  });
  if (!profile?.communityLastReadAt) {
    await prisma.userProfile.upsert({
      where: { userId: me },
      update: { communityLastReadAt: new Date() },
      create: { userId: me, communityLastReadAt: new Date() },
    });
    return ok(res, { unreadCount: 0 });
  }
  const unreadCount = await prisma.aiCommunityComment.count({
    where: {
      createdAt: { gt: profile.communityLastReadAt },
      post: { authorType: 'user', userId: me },
      // NOT(作者是本人)：AI 好友评论 authorType 是 ai_friend 天然通过，
      // 真人评论里只排除我自己写的那几条。
      NOT: { authorType: 'user', userId: me },
    },
  });
  ok(res, { unreadCount });
});

// 标已读：进社区页时调，把已读标记推到当前时间，未读数归零。
router.post('/unread-replies/read', authRequired, async (req, res) => {
  const me = req.user.sub;
  await prisma.userProfile.upsert({
    where: { userId: me },
    update: { communityLastReadAt: new Date() },
    create: { userId: me, communityLastReadAt: new Date() },
  });
  ok(res, { unreadCount: 0 });
});

router.get('/posts/:id', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const row = await prisma.aiCommunityPost.findUnique({
    where: { id },
    include: postInclude,
  });
  if (!row) return fail(res, 404, '动态不存在');
  ok(res, { post: serializePost(row, req.user.sub) });
});

router.post('/upload', authRequired, (req, res) => {
  try {
    const imagePath = saveCommunityImage(req.body ?? {});
    ok(res, { imagePath });
  } catch (error) {
    fail(res, 400, error.message || '上传失败');
  }
});

router.post('/posts', authRequired, async (req, res) => {
  const content = String(req.body?.content ?? '').trim();
  const rawPaths = Array.isArray(req.body?.imagePaths)
    ? req.body.imagePaths
    : [req.body?.imagePath];
  const imagePaths = rawPaths
    .map((p) => String(p ?? '').trim())
    .filter(Boolean)
    .slice(0, 9);
  const imagePath = imagePaths[0] || '';

  if (content.length < 1 && imagePaths.length === 0) {
    return fail(res, 400, '请输入内容或添加图片');
  }
  if (content.length > MAX_CONTENT_LEN) return fail(res, 400, `内容不能超过 ${MAX_CONTENT_LEN} 字`);

  try {
    for (const path of imagePaths) {
      await assertUserOwnsImagePath(path, req.user.sub);
    }
  } catch (error) {
    return fail(res, 400, error.message);
  }

  const post = await prisma.aiCommunityPost.create({
    data: {
      authorType: 'user',
      userId: req.user.sub,
      content: content || (imagePaths.length > 0 ? '分享图片' : ''),
      imagePath,
      imagePaths,
    },
    include: postInclude,
  });

  scheduleAiEngagementForUserPost({
    postId: post.id,
    content: post.content,
    prisma,
    config: deepseekConfig(),
  });

  log.info('AI社区', `用户发了新帖子，帖子 id ${post.id}`);
  ok(res, { post: serializePost(post, req.user.sub) });
});

router.post('/posts/:id/like', authRequired, async (req, res) => {
  const postId = String(req.params.id ?? '').trim();
  const post = await prisma.aiCommunityPost.findUnique({ where: { id: postId } });
  if (!post) return fail(res, 404, '动态不存在');

  const likerKey = `user:${req.user.sub}`;
  const existing = await prisma.aiCommunityLike.findUnique({
    where: { postId_likerKey: { postId, likerKey } },
  });

  if (existing) {
    await prisma.aiCommunityLike.delete({ where: { id: existing.id } });
  } else {
    await prisma.aiCommunityLike.create({
      data: {
        postId,
        likerKey,
        userId: req.user.sub,
      },
    });
    await markDailyTaskDone(req.user.sub, 'dailyCommunityDone');
  }

  const row = await prisma.aiCommunityPost.findUnique({
    where: { id: postId },
    include: postInclude,
  });

  ok(res, { post: serializePost(row, req.user.sub) });
});

router.post('/posts/:id/comments', authRequired, async (req, res) => {
  const postId = String(req.params.id ?? '').trim();
  const content = String(req.body?.content ?? '').trim();
  // App 传 '0' 表示一级评论，落库转空，理由同评价评论
  let parentId = String(req.body?.parentId ?? '0').trim() || '0';

  if (content.length < 1) return fail(res, 400, '请输入评论内容');
  if (content.length > 300) return fail(res, 400, '评论不能超过 300 字');

  const post = await prisma.aiCommunityPost.findUnique({
    where: { id: postId },
    include: { aiFriend: true, user: true },
  });
  if (!post) return fail(res, 404, '动态不存在');

  let rootId = null;
  let replyToUserId = '';
  let replyToUserName = '';

  if (parentId !== '0') {
    const parent = await prisma.aiCommunityComment.findFirst({
      where: { id: parentId, postId },
      include: {
        user: true,
        aiFriend: true,
      },
    });
    if (!parent) return fail(res, 404, '被回复的评论不存在');
    rootId = parent.rootId && parent.rootId !== '0' ? parent.rootId : parent.id; // 兼容老数据：升级前存的 '0' 也当一级处理
    if (parent.authorType === 'user' && parent.user) {
      replyToUserId = parent.user.id;
      replyToUserName = parent.user.nickname || '用户';
    } else if (parent.authorType === 'ai_friend' && parent.aiFriend) {
      replyToUserId = parent.aiFriend.id;
      replyToUserName = parent.aiFriend.name || 'AI好友';
    }
  }

  const newComment = await prisma.aiCommunityComment.create({
    data: {
      postId,
      authorType: 'user',
      userId: req.user.sub,
      parentId: parentId === '0' ? null : parentId,
      rootId,
      replyToUserId,
      replyToUserName,
      content,
    },
  });

  // AI 回复触发条件（放开到第二回合）：
  // 1) 在 AI 好友的帖子下发一级评论 → 帖主 AI 回复；
  // 2) 回复的是某位 AI 好友的评论（不限帖子作者）→ 那位 AI 接着回。
  // 同一评论串里 AI 最多回 3 次，防止无限聊和刷屏。
  let replyFriend = null;
  let parentComment = null;
  if (parentId !== '0') {
    parentComment = await prisma.aiCommunityComment.findFirst({
      where: { id: parentId, postId },
      include: { aiFriend: true },
    });
    if (parentComment?.authorType === 'ai_friend' && parentComment.aiFriend) {
      replyFriend = parentComment.aiFriend;
    }
  } else if (post.authorType === 'ai_friend' && post.aiFriend) {
    replyFriend = post.aiFriend;
  }

  if (replyFriend) {
    const threadRoot = rootId ?? newComment.id;
    const aiRepliesInThread = await prisma.aiCommunityComment.count({
      where: { postId, rootId: threadRoot, authorType: 'ai_friend' },
    });
    if (aiRepliesInThread < 3) {
      const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
      const recent = await prisma.aiCommunityComment.findMany({
        where: { postId },
        orderBy: { createdAt: 'asc' },
        take: 10,
        include: { user: true, aiFriend: true },
      });
      const contextComments = recent.map((c) => ({
        name:
          c.authorType === 'ai_friend'
            ? c.aiFriend?.name || 'AI好友'
            : c.user?.nickname || '用户',
        content: c.content,
      }));
      scheduleAiReplyToUserComment({
        postId,
        post,
        friend: replyFriend,
        userComment: content,
        userName: user?.nickname || '朋友',
        prisma,
        config: deepseekConfig(),
        parentCommentId: newComment.id,
        rootId: threadRoot,
        replyToUserId: req.user.sub,
        replyToUserName: user?.nickname || '朋友',
        contextComments,
      });
    }
  }

  const row = await prisma.aiCommunityPost.findUnique({
    where: { id: postId },
    include: postInclude,
  });

  ok(res, { post: serializePost(row, req.user.sub) });
});

router.delete('/posts/:id', authRequired, async (req, res) => {
  const postId = String(req.params.id ?? '').trim();
  const post = await prisma.aiCommunityPost.findUnique({ where: { id: postId } });
  if (!post) return fail(res, 404, '动态不存在');
  if (post.authorType !== 'user' || post.userId !== req.user.sub) {
    return fail(res, 403, '只能删除自己的动态');
  }

  await prisma.aiCommunityPost.delete({ where: { id: postId } });
  ok(res, { deleted: true });
});

export default router;
