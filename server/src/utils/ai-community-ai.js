import { chatCompletion } from '../deepseek.js';
import { log } from './log.js';
import { AI_FRIENDS } from '../data/ai-friends.js';

// 兜底文案：没有配模型密钥或调用失败时使用。每人 8 条，长度与人设
// 和正常生成（30～90 字）保持接近，避免一眼看出是罐头回复。
const FALLBACK_COMMENTS = {
  xiaoxing: [
    '也太可爱了吧！这个配色和氛围我直接心动，眼睛都移不开了 ✨',
    '这个 vibe 我爱了，感觉一整天的心情都被点亮啦 🐱 你也这么觉得吗？',
    '周末就该看这种治愈画面，整个人都放松下来了，你是在哪拍的呀？',
    '救命，这个细节也太戳我了，越看越喜欢是怎么回事 ✨',
    '好有画面感！脑子里已经自动配上音乐了，你脑洞也太大了吧～',
    '被你安利到了，这种风格真的百看不腻，下次还想看你发新的 🐱',
    '呜呜这也太萌了，心都要化了，你是怎么发现这个角度的？',
    '喜欢喜欢！这种日常里的小闪光，就是最治愈的东西呀 ✨',
  ],
  amu: [
    '构图不错，主体很稳。可以试着再压一点前景，层次会更出来。',
    '配色克制，整体观感舒服。细节上阴影再收一点，会更干净。',
    '主题表达清晰，这是加分项。下次换个光影方向，效果可能完全不同。',
    '嗯，这个处理方式可以。留白给得对，画面呼吸感就有了。',
    '视角选得准。建议再试一版低机位，对比一下哪版张力更强。',
    '完成度挺高。唯一的小问题是边缘略杂，裁掉一点点会更利落。',
    '思路不错，执行也稳。这种题材多试几种色调，很容易出惊喜。',
    '光影是这张的亮点。主体再往视觉中心靠一点，就更无可挑剔了。',
  ],
  tangtang: [
    '好温柔呀，看得心里软软的，好像被轻轻抱了一下 🌸',
    '被你治愈到了，今天份的小确幸收下啦，你也要好好照顾自己哦 ☁️',
    '也想听听这张背后的故事呢，感觉一定是个很温暖的瞬间吧？',
    '慢慢看会觉得心里安静下来，这种氛围真的好难得呀 🌸',
    '你总是能发现这些温柔的小角落，跟着你看世界都变柔和了呢',
    '这份心情我懂的，被好好珍藏的感觉，隔着屏幕都能感受到 ☁️',
    '谢谢你分享出来呀，坏心情看到这个，一下子就被抚平了',
    '好喜欢这种不慌不忙的感觉，愿你每天都有这样的小美好 🌸',
  ],
  tuanzi: [
    '这个系列我懂！做工细节是真的可，摆在桌上每天看都开心，入股不亏～',
    '隐藏款体质也太让人羡慕了吧哈哈，你这手气是被幸运女神吻过吗 😆',
    '趣玩星球好物 +1，这个质感对得起价格，收藏架又要扩容了',
    '开箱的快乐谁懂啊！这个涂装和配件诚意很足，值得单独给它留个 C 位',
    '同款爱好者握手，这个系列最难收的就是它了，你居然拿下了？',
    '细节控狂喜，关节、配色、底座都在线，这种做工现在不多见了',
    '被你种草了，本来还在观望，看完这组图直接列入必入清单 ✓',
    '晒单的仪式感拉满了，灯光一打氛围直接到位，同系列还差哪只呀？',
  ],
  kele: [
    '哈哈哈有被笑到，今日快乐源泉找到了，功德 +1 😂',
    '这图信息量有点大啊，我盯着看了半天，越看越有梗是怎么回事',
    '本来今天平平无奇，刷到你这条直接精神了，干得漂亮 😂',
    '好家伙，这个展开我是没想到的，评论区肯定要热闹了',
    '笑死，这个氛围拿捏得死死的，你是懂怎么制造快乐的',
    '存了存了，这种图就适合周一早上看，瞬间回血 😂',
    '不愧是你，每次出现都能整点新花样，今天份的快乐承包了',
    '这个我必须手动点赞，顺便蹲一个后续，没有后续我可要闹了',
  ],
  youzi: [
    '像午后慢慢落下的光，不急不赶，看着看着心就静下来了。',
    '安静的一瞬最打动人，这样的画面，适合什么都不想地看一会儿。',
    '窗边的时光总是特别温柔，你把这一刻留住了，真好。',
    '有种季节在慢慢走的感觉，你拍照时心里在想什么呢？',
    '不热闹，但很耐看。这样的日常碎片，反而最容易被记住。',
    '光影很诚实，没有用力过猛，生活本来的样子就很好看了。',
    '看到这张，忽然想给自己泡杯茶，慢慢过一个下午了。',
    '留白留得好，剩下的让看的人自己慢慢补完，很高级。',
  ],
  nihong: [
    'Neon vibe 拉满，这个夜色和灯光的对撞，cool，视觉冲击直接到位。',
    '未来感有了，色调再大胆一点都不为过，这就是夜城该有的味道。',
    '这构图很赛博，机械感和光影咬合得不错，一眼就被拽进去了。',
    '蓝紫调控得稳，没糊成一片，细节经得起放大看，不错。',
    '有种下一秒就要接入虚拟世界的错觉，这种氛围感很难复刻。',
    '灯光层次是亮点，暗部留得住信息，这张的完成度我给高分。',
    '街景选得妙，霓虹一衬，平平无奇的角落立刻有了故事感。',
    '这种冷硬里带点浪漫的调调，正是科幻视觉最迷人的地方。',
  ],
  mobai: [
    '留白处见韵，甚美。不必说满，意已到了，令人驻足良久。',
    '意境清雅，配色克制有度，传统的东西被你拍出了新意。',
    '国风一笔，已是风情。这份韵味，急不得，也装不来。',
    '扇面、色彩、光影都恰到好处，像从旧画里走出来的一幕。',
    '难得的是这份安静，如今愿意慢下来看的人不多了，你很好。',
    '细节里有讲究，边角的处理见功力，越品越有味道。',
    '此景只应慢观。匆匆划过的人，怕是要错过最动人的那一分。',
    '雅致而不刻意，这便是国风最难得的分寸感了，佩服。',
  ],
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
    log.warn('AI社区', `AI 好友生成内容失败：${error.message}`);
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

export async function generateFriendReply(friend, post, userComment, userName, config, contextComments = []) {
  const contextText = (contextComments ?? [])
    .slice(-8)
    .map((c) => `${c.name}：${c.content}`)
    .join('\n');
  const prompt = `朋友圈原文：
${post.content}
${contextText ? `\n这条朋友圈下已有的评论（按时间先后）：\n${contextText}\n` : ''}
用户「${userName}」最新评论说：
${userComment}

请以「${friend.name}」的身份回复这条最新评论：结合前面的聊天内容自然地接话，不要重复自己或别人已经说过的话，不要复述原文。直接输出回复正文，不要引号、不要前缀，30～80 字。`;
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
  log.info('AI社区', `新帖子已安排 AI 好友互动：约 ${friendsForLike.length} 个点赞、${friendsForComment.length} 条评论会陆续出现（帖子 id ${postId}）`);

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
        log.warn('AI社区', `AI 好友点赞失败：${error.message}`);
      }
    }
  }, randomBetween(3000, 8000));

  friendsForComment.forEach((friend, index) => {
    setTimeout(async () => {
      try {
        const post = await prisma.aiCommunityPost.findUnique({ where: { id: postId } });
        if (!post) return;
        // 同一个 AI 好友对同一条帖子只评论一次，避免重复捧场
        const existing = await prisma.aiCommunityComment.findFirst({
          where: { postId, authorType: 'ai_friend', aiFriendId: friend.id },
        });
        if (existing) return;
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
        log.warn('AI社区', `AI 好友自动评论失败：${error.message}`);
      }
      // 延迟与 App 端轮询窗口对齐：首条 5～10 秒，后续每条再错开 3～6 秒
    }, randomBetween(5000, 10000) + index * randomBetween(3000, 6000));
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
  parentCommentId,
  rootId,
  replyToUserId,
  replyToUserName,
  contextComments = [],
}) {
  log.info('AI社区', `已安排 AI 好友回复用户评论（帖子 id ${postId}）`);
  setTimeout(async () => {
    try {
      const reply = await generateFriendReply(friend, post, userComment, userName, config, contextComments);
      await prisma.aiCommunityComment.create({
        data: {
          postId,
          authorType: 'ai_friend',
          aiFriendId: friend.id,
          // 挂到用户那条评论下面，并标明回复对象，不再变成无头的一级评论
          // 落库用空表示一级（字段已改为可空）；序列化返回时仍会转回 '0' 给 App
          parentId: parentCommentId ?? null,
          rootId: rootId ?? null,
          replyToUserId: replyToUserId ?? '',
          replyToUserName: replyToUserName ?? '',
          content: reply.slice(0, 500),
        },
      });
    } catch (error) {
      log.warn('AI社区', `AI 好友自动回复失败：${error.message}`);
    }
  }, randomBetween(3000, 12000));
}

export { sleep, randomBetween };
