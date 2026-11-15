class SupportSticker {
  const SupportSticker({required this.id, required this.emoji, required this.label});

  final String id;
  final String emoji;
  final String label;
}

const supportStickers = <SupportSticker>[
  SupportSticker(id: 'wave', emoji: '👋', label: '打招呼'),
  SupportSticker(id: 'smile', emoji: '😊', label: '微笑'),
  SupportSticker(id: 'thanks', emoji: '🙏', label: '谢谢'),
  SupportSticker(id: 'heart', emoji: '❤️', label: '爱心'),
  SupportSticker(id: 'thumbs', emoji: '👍', label: '点赞'),
  SupportSticker(id: 'cry', emoji: '😭', label: '委屈'),
  SupportSticker(id: 'party', emoji: '🎉', label: '庆祝'),
  SupportSticker(id: 'ok', emoji: '👌', label: 'OK'),
  SupportSticker(id: 'thinking', emoji: '🤔', label: '思考'),
  SupportSticker(id: 'gift', emoji: '🎁', label: '礼物'),
  SupportSticker(id: 'star', emoji: '⭐', label: '星星'),
  SupportSticker(id: 'fire', emoji: '🔥', label: '超赞'),
];

SupportSticker? findSupportSticker(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final sticker in supportStickers) {
    if (sticker.id == id) return sticker;
  }
  return null;
}
