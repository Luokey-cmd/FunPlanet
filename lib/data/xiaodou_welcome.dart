import 'dart:math';

class XiaodouWelcome {
  static const defaultMessage =
      '嗨，我是小豆～趣玩星球 App 答疑助手，商品搜索、优惠活动、下单购物和使用问题都可以问我！说「帮我买」「帮我下单」还能直接推荐商品卡片哦～';

  static const _messages = [
    defaultMessage,
    '你好呀，我是小豆～趣玩星球 App 答疑助手！想找趣玩商品、查优惠，或者不懂 App 怎么用时，随时问我～',
    '欢迎来找小豆～趣玩星球 App 答疑助手！商品推荐、活动详情、新人福利、会员权益这些，我都能帮你解答。',
    '嗨~小豆在线！我是趣玩星球 App 答疑助手有关趣玩星球App的任何问题，包括商品情况、活动详情、优惠指引、VIP办理的问题等，尽管问我吧。',
  ];

  static String pick([Random? random]) {
    final rng = random ?? Random();
    return _messages[rng.nextInt(_messages.length)];
  }
}
