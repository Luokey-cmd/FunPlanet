import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';
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

function serializePost(row, currentUserId) {
  const likedByMe = row.likes.some(
    (like) => like.likerKey === `user:${currentUserId}` || like.userId === currentUserId,
  );

  return {
    id: row.id,
    author: serializeAuthor({
      authorType: row.authorType,
      user: row.user,
      aiFriend: row.aiFriend,
    }),
    content: row.content,
    imagePath: row.imagePath || '',
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
    orderBy: { createdAt: 'desc' },
    take,
    include: postInclude,
  });

  ok(res, {
    posts: rows.map((row) => serializePost(row, req.user.sub)),
  });
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
  const imagePath = String(req.body?.imagePath ?? '').trim();

  if (content.length < 1) return fail(res, 400, '请输入朋友圈内容');
  if (content.length > MAX_CONTENT_LEN) return fail(res, 400, `内容不能超过 ${MAX_CONTENT_LEN} 字`);

  try {
    if (imagePath) {
      await assertUserOwnsImagePath(imagePath, req.user.sub);
    }
  } catch (error) {
    return fail(res, 400, error.message);
  }

  const post = await prisma.aiCommunityPost.create({
    data: {
      authorType: 'user',
      userId: req.user.sub,
      content,
      imagePath: imagePath || '',
    },
    include: postInclude,
  });

  scheduleAiEngagementForUserPost({
    postId: post.id,
    content,
    prisma,
    config: deepseekConfig(),
  });

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

  if (content.length < 1) return fail(res, 400, '请输入评论内容');
  if (content.length > 300) return fail(res, 400, '评论不能超过 300 字');

  const post = await prisma.aiCommunityPost.findUnique({
    where: { id: postId },
    include: { aiFriend: true, user: true },
  });
  if (!post) return fail(res, 404, '动态不存在');

  await prisma.aiCommunityComment.create({
    data: {
      postId,
      authorType: 'user',
      userId: req.user.sub,
      content,
    },
  });

  if (post.authorType === 'ai_friend' && post.aiFriend) {
    const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
    scheduleAiReplyToUserComment({
      postId,
      post,
      friend: post.aiFriend,
      userComment: content,
      userName: user?.nickname || '朋友',
      prisma,
      config: deepseekConfig(),
    });
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
