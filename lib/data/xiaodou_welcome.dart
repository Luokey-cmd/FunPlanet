import 'dart:math';

class XiaodouWelcome {
  // 欢迎语池（第一批换脸）：与 XiaodouCopy.openings 同一导购口径，
  // 保留「可问优惠券/订单、可拍照找同款」的信息点，不用比喻、不先问问题。
  static const defaultMessage =
      '我是小豆，趣玩星球的 AI 导购。你说想要什么、送给谁、大概多少钱，我直接给你翻三张牌，每张都告诉你为什么选它。';

  static const _messages = [
    defaultMessage,
    '你好呀，我是小豆～想找手办、谷子、吧唧或礼物，直接说预算和喜好，我去店里帮你搜，每件都说清为什么选它。',
    '欢迎来找小豆～点上面的卡就能开始：今日星签、送礼不踩雷、平价捡漏、拍照找同款，不用先填任何表。',
    '嗨，小豆在线！挑东西、查优惠券、看订单都可以问我；也可以发一张照片，我帮你在店里找同款。',
  ];

  static String pick([Random? random]) {
    final rng = random ?? Random();
    return _messages[rng.nextInt(_messages.length)];
  }
}
