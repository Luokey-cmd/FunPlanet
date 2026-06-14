export const SUPPORT_STICKERS: Record<string, { emoji: string; label: string }> = {
  wave: { emoji: "👋", label: "打招呼" },
  smile: { emoji: "😊", label: "微笑" },
  thanks: { emoji: "🙏", label: "谢谢" },
  heart: { emoji: "❤️", label: "爱心" },
  thumbs: { emoji: "👍", label: "点赞" },
  cry: { emoji: "😭", label: "委屈" },
  party: { emoji: "🎉", label: "庆祝" },
  ok: { emoji: "👌", label: "OK" },
  thinking: { emoji: "🤔", label: "思考" },
  gift: { emoji: "🎁", label: "礼物" },
  star: { emoji: "⭐", label: "星星" },
  fire: { emoji: "🔥", label: "超赞" },
};

export const SUPPORT_STICKER_LIST = Object.entries(SUPPORT_STICKERS).map(([id, item]) => ({
  id,
  ...item,
}));

export function getSupportStickerEmoji(stickerId: string | null | undefined) {
  if (!stickerId) return null;
  return SUPPORT_STICKERS[stickerId]?.emoji ?? null;
}