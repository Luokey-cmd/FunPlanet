import 'dart:math';

class XiaodouCopy {
  static const openings = [
    '旅人，瓶子里亮了一小格。今晚想寻什么？',
    '我在货架深处听你说话。慢慢说，我替你揭一层。',
    '星签还温着。你要犒劳自己，还是给谁带一封短笺？',
  ];

  static const emptyShelf = [
    '这件光还不在我们货架上。要不要改寻「同类气味」？',
    '今晚这一格是空的。换个品类，或把预算松开一点，我再往深处摸。',
  ];

  static const moreShelf = [
    '要左边这封，还是再往货架深处？',
    '这三张是这一层。想换一层，就说「再揭开」。',
  ];

  static const confirmCart = '要把这封星愿放进旅途背包吗？';

  static const visionSame = '找几乎一样的';
  static const visionVibe = '只要这个味道';
  static const visionMiss = '这件光还不在我们货架上。要不要改寻「同类气味」？';

  static const giftNotes = {
    'understood': '托小豆带到你桌上的第一颗星，希望你被准确看见。',
    'comforted': '这是一封不催你坚强的短笺，拆开时先被轻轻接住。',
    'surprised': '不许提前拆——里面藏着一颗会眨眼的小意外。',
    'default': '托小豆带到你桌上的第一颗星。',
  };

  static String pick(List<String> pool, [Random? random]) {
    final rng = random ?? Random();
    return pool[rng.nextInt(pool.length)];
  }

  static String giftNote(String feeling) => giftNotes[feeling] ?? giftNotes['default']!;
}
