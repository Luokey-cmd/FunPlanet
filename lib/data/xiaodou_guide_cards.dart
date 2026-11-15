class XiaodouGuideCard {
  const XiaodouGuideCard({
    required this.badge,
    required this.seal,
    required this.title,
    required this.body,
    required this.nextLabel,
  });

  final String badge;
  final String seal;
  final String title;
  final String body;
  final String nextLabel;
}

const xiaodouGuideCards = [
  XiaodouGuideCard(
    badge: '其一',
    seal: '探头许可',
    title: '右边那颗探头的，是我',
    body: '不是广告，不是bug，是守瓶精灵小豆。我会贴在屏幕边上偷偷看你逛。点一下，货架就亮一格。今晚想寻什么，对着瓶子吹口气就好。',
    nextLabel: '揭开下一封',
  ),
  XiaodouGuideCard(
    badge: '其二',
    seal: '星签盖章',
    title: '先在档案上按四颗小星星',
    body: '心情、预算、犒劳自己还是送礼——像给今晚盖个章。盖完我就不追着盘问啦，免得变成查户口的小精灵。',
    nextLabel: '再亮一颗星',
  ),
  XiaodouGuideCard(
    badge: '其三',
    seal: '命运三翻',
    title: '牌一次只掀三张，不许偷看',
    body: '本命、遇见、余韵。点开哪张，哪张才肯亮。贪心的旅人会被瓶子轻轻敲手背——我们卖可爱，不卖一屏幕热销。',
    nextLabel: '继续冒险',
  ),
  XiaodouGuideCard(
    badge: '其四',
    seal: '光之鉴定',
    title: '把亮晶晶放进瓶子里',
    body: '点相机，丢一张你心动的图进来。我先眯眼鉴定，再问：要「几乎一样」，还是「只要这个味道」？送礼的话，还附赠一句肉麻但不长的寄语。',
    nextLabel: '去找小豆咬耳朵',
  ),
];
