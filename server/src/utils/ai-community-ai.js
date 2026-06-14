import { chatCompletion } from '../deepseek.js';
import { AI_FRIENDS } from '../data/ai-friends.js';

const FALLBACK_COMMENTS = {
  xiaoxing: ['也太可爱了吧！✨', '这个 vibe 我爱了 🐱', '周末就该看这种治愈画面～'],
  amu: ['构图不错，可以再加强层次。', '配色稳，细节还能再抠一下。', '主题清晰，继续试试不同光影。'],
  tangtang: ['好温柔呀，看得心里软软的 🌸', '被你治愈到了～', '也想听听你背后的故事呢'],
  tuanzi: ['这个系列我懂！做工细节很可～', '隐藏款体质羡慕了哈哈', '趣玩星球好物+1'],
  kele: ['哈哈哈有被笑到 😂', '今日快乐源泉找到了', '这图信息量有点大啊'],
  youzi: ['像午后慢慢落下的光。', '安静的一瞬，很打动人。', '窗边的时光总是特别温柔。'],
  nihong: ['Neon vibe 拉满，cool。', '未来感有了，视觉冲击不错。', '这色调，夜城味道对了。'],
  mobai: ['留白处见韵，甚美。', '意境清雅，令人驻足。', '国风一笔，已是风情。'],
};

function pickRandom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function randomBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function scoreFriendForPost(friend, content) {
  const text = String(content ?? '');
  const rules = {
    xiaoxing: /二次|动漫|萌|可爱|Q版|猫|emoji/i,
    amu: /绘画|画|构图|配色|层次|AI/i,
    tangtang: /温柔|治愈|想起|心情|软/i,
    tuanzi: /盲盒|周边|开箱|收藏|手办|趣玩/i,
    kele: /哈哈|笑|搞笑|精神|平淡/i,
    youzi: /傍晚|窗台|茶|安静|慢|氛围/i,
    nihong: /赛博|科幻|霓虹|未来|夜景|vibe/i,
    mobai: /国风|古风|樱花|扇|留白|韵/i,
  };
  return rules[friend.id]?.test(text) ? 3 : 1;
}

export function pickFriendsForUserPost(content, count = 3) {
  const scored = AI_FRIENDS.map((friend) => ({
    friend,
    score: scoreFriendForPost(friend, content) + Math.random(),
  }))
    .sort((a, b) => b.score - a.score)
    .slice(0, Math.max(2, count));

  const picked = new Map();
  while (picked.size < Math.min(count, AI_FRIENDS.length)) {
    const item = scored[picked.size % scored.length]?.friend ?? pickRandom(AI_FRIENDS);
    picked.set(item.id, item);
  }
  return [...picked.values()];
}

export function pickFriendsForLikes(content, count = 3) {
  return pickFriendsForUserPost(content, count + 1).slice(0, count);
}

async function generateText(systemPrompt, userPrompt, config) {
  if (!config?.apiKey) {
    return null;
  }
  try {
    return await chatCompletion(
      [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      config,
    );
  } catch (error) {
    console.warn('[ai-community-ai]', error.message);
    return null;
  }
}

export async function generateFriendComment(friend, post, config) {
  const prompt = `以下是社区里的一条朋友圈：
${post.content}
${post.imagePath ? '（含配图）' : '（纯文字）'}

请以「${friend.name}」的身份写一条评论，直接输出评论正文，不要引号、不要「${friend.name}：」前缀，30～90 字。`;
  const text = await generateText(friend.systemPrompt, prompt, config);
  return text || pickRandom(FALLBACK_COMMENTS[friend.id] || ['说得真好！']);
}

export async function generateFriendReply(friend, post, userComment, userName, config) {
  const prompt = `你发的朋友圈：
${post.content}

用户「${userName}」评论说：
${userComment}

请以「${friend.name}」的身份回复这条评论，直接输出回复正文，不要引号、不要前缀，30～80 字。`;
  const text = await generateText(friend.systemPrompt, prompt, config);
  return text || pickRandom(FALLBACK_COMMENTS[friend.id] || ['收到～']);
}

export async function scheduleAiEngagementForUserPost({
  postId,
  content,
  prisma,
  config,
}) {
  const friendsForLike = pickFriendsForLikes(content, randomBetween(2, 4));
  const friendsForComment = pickFriendsForUserPost(content, randomBetween(1, 3));

  setTimeout(async () => {
    for (const friend of friendsForLike) {
      try {
        await prisma.aiCommunityLike.upsert({
          where: {
            postId_likerKey: {
              postId,
              likerKey: `friend:${friend.id}`,
            },
          },
          update: {},
          create: {
            postId,
            likerKey: `friend:${friend.id}`,
            aiFriendId: friend.id,
          },
        });
      } catch (error) {
        console.warn('[ai-community] like failed', error.message);
      }
    }
  }, randomBetween(3000, 8000));

  friendsForComment.forEach((friend, index) => {
    setTimeout(async () => {
      try {
        const post = await prisma.aiCommunityPost.findUnique({ where: { id: postId } });
        if (!post) return;
        const commentText = await generateFriendComment(friend, post, config);
        await prisma.aiCommunityComment.create({
          data: {
            postId,
            authorType: 'ai_friend',
            aiFriendId: friend.id,
            content: commentText.slice(0, 500),
          },
        });
      } catch (error) {
        console.warn('[ai-community] auto comment failed', error.message);
      }
    }, randomBetween(8000, 20000) + index * randomBetween(2000, 5000));
  });
}

export async function scheduleAiReplyToUserComment({
  postId,
  post,
  friend,
  userComment,
  userName,
  prisma,
  config,
}) {
  setTimeout(async () => {
    try {
      const reply = await generateFriendReply(friend, post, userComment, userName, config);
      await prisma.aiCommunityComment.create({
        data: {
          postId,
          authorType: 'ai_friend',
          aiFriendId: friend.id,
          content: reply.slice(0, 500),
        },
      });
    } catch (error) {
      console.warn('[ai-community] auto reply failed', error.message);
    }
  }, randomBetween(3000, 12000));
}

export { sleep, randomBetween };
