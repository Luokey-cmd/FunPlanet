import { log } from './log.js';
import { prisma } from '../db.js';
import { AI_FRIENDS, SEED_POSTS } from '../data/ai-friends.js';

function daysAgoDate(days) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date;
}

async function syncAiFriendAvatars() {
  for (const friend of AI_FRIENDS) {
    const avatarPath = friend.avatarPath ?? '';
    if (!avatarPath) continue;
    await prisma.aiFriend.updateMany({
      where: { id: friend.id },
      data: { avatarPath },
    });
  }
}

async function syncSeedPostImages() {
  for (const seed of SEED_POSTS) {
    const imagePath = seed.imagePath ?? '';
    if (!imagePath) continue;
    await prisma.aiCommunityPost.updateMany({
      where: {
        authorType: 'ai_friend',
        aiFriendId: seed.aiFriendId,
        content: seed.content,
      },
      data: { imagePath },
    });
  }
}

export async function seedAiCommunityIfNeeded() {
  const count = await prisma.aiFriend.count();
  if (count > 0) {
    await syncAiFriendAvatars();
    await syncSeedPostImages();
    return;
  }

  log.info('AI社区', '正在初始化社区种子数据（虚拟好友和帖子）…');

  for (const [index, friend] of AI_FRIENDS.entries()) {
    await prisma.aiFriend.create({
      data: {
        id: friend.id,
        name: friend.name,
        avatarPath: friend.avatarPath ?? '',
        avatarColor: friend.avatarColor,
        systemPrompt: friend.systemPrompt,
        sortOrder: index,
      },
    });
  }

  for (const seed of SEED_POSTS) {
    const post = await prisma.aiCommunityPost.create({
      data: {
        authorType: 'ai_friend',
        aiFriendId: seed.aiFriendId,
        content: seed.content,
        imagePath: seed.imagePath ?? '',
        createdAt: daysAgoDate(seed.daysAgo ?? 0),
      },
    });

    for (const friendId of seed.seedLikes ?? []) {
      await prisma.aiCommunityLike.create({
        data: {
          postId: post.id,
          likerKey: `friend:${friendId}`,
          aiFriendId: friendId,
        },
      });
    }
  }

  log.info('AI社区', '社区种子数据初始化完成');
}
