import 'dart:math';

class XiaodouCopy {
  // 开场白池（第一批换脸）：全换成导购口径——先说清小豆能干什么、第一句话该说什么。
  // 旧的瓶子/揭一层/短笺类散文比喻已删：用户看完不知道能买什么，已被 hz 否掉。
  static const openings = [
    '我是小豆。你说想要什么、送给谁、大概多少钱，我直接给你翻三张牌，每张都告诉你为什么选它。',
    '想淘点什么直接说，拿不准就点上面的卡，我带你一步步挑。',
    '送礼怕踩雷、自己买怕买贵，都交给我——先说说你想找什么。',
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
