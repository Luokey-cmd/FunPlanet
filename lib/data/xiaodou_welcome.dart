import 'dart:math';

class XiaodouWelcome {
  static const defaultMessage =
      '嗨，我是小豆～趣玩星球的 AI 导购。可以帮你挑礼物、按预算找货；点相机还能拍图找同款。';

  static const _messages = [
    defaultMessage,
    '你好呀，我是小豆～想找手办、谷子、小夜灯或礼物，直接说预算和喜好，我去店里帮你搜。',
    '欢迎来找小豆～我会先问清品类和预算，再推荐店里真实在售的商品卡片，可以加购或立刻买。',
    '嗨~小豆在线！购物、优惠券、VIP 都可以问。也可以发一张照片，我帮你在店里找同款。',
  ];

  static String pick([Random? random]) {
    final rng = random ?? Random();
    return _messages[rng.nextInt(_messages.length)];
  }
}
