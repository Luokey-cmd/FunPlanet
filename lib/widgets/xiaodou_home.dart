import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'click_effect/app_pressable.dart';
import 'floating_ai_assistant.dart';
import 'product_image.dart';

// 缩放与聊天页保持同一套：统一走 AppScale（字号 t = 写几号是几号，
// 布局 s = 0.8 倍）。2026-11-20 字体规范化时废除了旧版 1.5 倍私自放大，
// 与聊天页 _xs 同步，保证首页区和对话区是一个比例。
double _hs(double value) => AppScale.t(value);

/// 小豆首页区：只在「还没有用户消息」时出现在消息列表顶部（显隐判定在聊天页）。
///
/// 输入：6 个回调，全部由聊天页注入；本组件不直接读 Provider、不调 chat.send。
/// 输出：无返回值，所有动作都通过回调回到聊天页执行。
/// 坑：发送口径必须和底部输入栏完全一致（带 starwish 档案），所以发送只能走
/// onSendText 回调，别图省事在这里自己拼参数——两处口径漂移后很难查。
class XiaodouHome extends StatelessWidget {
  const XiaodouHome({
    super.key,
    required this.onDrawFate,
    required this.onSendText,
    required this.onPickImage,
    required this.onFocusInput,
    required this.onOpenProfile,
    required this.onVoice,
  });

  /// 今日星签卡 → 走聊天页现成的抽三翻逻辑。
  final VoidCallback onDrawFate;

  /// 灵感卡 / 示例句 / 路线 / 快捷行 → 以用户身份发一句话。
  final ValueChanged<String> onSendText;

  /// 拍照找同款 → 与输入栏共用同一份选图逻辑（聊天页层级函数）。
  final VoidCallback onPickImage;

  /// 点大输入框 → 让底部真输入框获得焦点（焦点节点由聊天页持有）。
  final VoidCallback onFocusInput;

  /// 小豆记得你 → 打开改名后的偏好弹层。
  final VoidCallback onOpenProfile;

  /// 语音胶囊 → 借用底部输入栏的语音输入（聊天页经 GlobalKey 转调输入栏的
  /// startVoiceInput）。语音逻辑只有输入栏那一套，首页只是个入口，
  /// 不许在这里再封一个识别服务，两套状态必然漂移。
  final VoidCallback onVoice;

  // 示例句：点即原文发送，写死在这里是因为它们就是首页文案的一部分。
  static const _examples = [
    '给朋友挑生日礼物',
    '想找能挂痛包的毛绒',
    '30 元内吧唧推荐',
  ];

  // 路线 chips（第一批定位：话术入口，不是排序开关）：
  // 点一下 = 替用户说出对应那句话，靠这句话影响 AI 选品；
  // 真实的程序排序权重是第二批的事，这里不许出现「已切换为 xx 模式」的假状态。
  static const _routes = [
    ('性价比', '我想看性价比高的'),
    ('实用', '我想看实用、口碑稳的'),
    ('体验好', '我想看体验好的，贵一点也行'),
    ('稀有收藏', '我想看稀有、适合收藏的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _hs(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(),
          _bigInput(context),
          _examplesRow(),
          _inspirationCards(),
          _routesBlock(),
          _trustBar(),
          _quickRow(),
        ],
      ),
    );
  }

  // ---------- A. 主视觉行 ----------
  // 左文案右小豆图；图与顶栏头像同一张（FloatingAiAssistant.assetFull），不引新素材。
  Widget _hero() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 导购 · 星愿远征',
                style: TextStyle(
                  fontSize: _hs(11) + AppScale.fontBump,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(height: _hs(6)),
              Text(
                '今晚想淘\n点什么？',
                style: TextStyle(
                  fontSize: _hs(26) + AppScale.fontBump,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: AppColors.foreground,
                ),
              ),
              SizedBox(height: _hs(8)),
              Text(
                '说想要什么、送给谁、大概多少钱，剩下的交给我。',
                style: TextStyle(
                  fontSize: _hs(13) + AppScale.fontBump,
                  height: 1.5,
                  color: AppColors.secondaryForeground,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: _hs(10)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_hs(24)),
            border: Border.all(color: const Color(0xFFCBE6FF), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_hs(24)),
            child: ProductImage(
              image: FloatingAiAssistant.assetFull,
              width: _hs(92),
              height: _hs(92),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- B. 大输入框（视觉主角） ----------
  // 它不是真输入框：整卡点击只是把焦点交给底部真输入框（onFocusInput），
  // 真正的文字输入、发送仍走底部输入栏那一套，避免出现两个输入状态。
  // 内部两个胶囊有各自的点击区，嵌套手势里内层优先，不会误触整卡的聚焦。
  Widget _bigInput(BuildContext context) {
    return GestureDetector(
      onTap: onFocusInput,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: _hs(14)),
        padding: EdgeInsets.all(_hs(14)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_hs(20)),
          border: Border.all(color: AppColors.primaryLight),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '说你想要的…',
              style: TextStyle(
                fontSize: _hs(14) + AppScale.fontBump,
                color: AppColors.mutedForeground,
              ),
            ),
            SizedBox(height: _hs(2)),
            Text(
              '比如：给同担挑个 30 内的生日吧唧',
              style: TextStyle(
                fontSize: _hs(11) + AppScale.fontBump,
                color: AppColors.mutedForeground,
              ),
            ),
            SizedBox(height: _hs(12)),
            Row(
              children: [
                _inputCapsule(
                  icon: Icons.photo_camera_outlined,
                  label: '拍照找同款',
                  onTap: onPickImage,
                ),
                SizedBox(width: _hs(8)),
                _inputCapsule(
                  icon: Icons.mic_none_outlined,
                  label: '语音',
                  // 语音已接真功能（系统识别）：点击直接开听，识别文字会落进
                  // 底部输入框等用户确认发送；不可用/无权限的提示在输入栏那边给。
                  onTap: onVoice,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onFocusInput,
                  child: Container(
                    width: _hs(38),
                    height: _hs(38),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_upward, size: _hs(18), color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCapsule({required IconData icon, required String label, required VoidCallback onTap}) {
    return AppPressable(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _hs(10), vertical: _hs(6)),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(_hs(999)),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _hs(14), color: AppColors.secondaryForeground),
              SizedBox(width: _hs(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: _hs(11) + AppScale.fontBump,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- C. 示例句（横滑一行，点即发送） ----------
  Widget _examplesRow() {
    return Padding(
      padding: EdgeInsets.only(top: _hs(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _examples.length; i++) ...[
              if (i > 0) SizedBox(width: _hs(8)),
              AppPressable(
                child: GestureDetector(
                  onTap: () => onSendText(_examples[i]),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: _hs(12), vertical: _hs(7)),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(_hs(999)),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _examples[i],
                      style: TextStyle(
                        fontSize: _hs(12) + AppScale.fontBump,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- D. 灵感卡 2×2（点即开始，不弹任何中间层） ----------
  // 用两行 Row + IntrinsicHeight 等高，不用 GridView：首页区本身在 ListView 里，
  // 再嵌一层可滚动网格会抢手势、算高度也容易出问题。
  Widget _inspirationCards() {
    final cards = <_InspirationCard>[
      _InspirationCard(
        icon: Icons.auto_awesome,
        title: '今日星签',
        subtitle: '每天一翻，看今日本命是哪件',
        colors: const [Color(0xFFFFF4C9), Color(0xFFFFE9A8)],
        onTap: onDrawFate,
      ),
      _InspirationCard(
        icon: Icons.card_giftcard,
        title: '送礼不踩雷',
        subtitle: '告诉我送给谁，我帮你避开雷区',
        colors: const [Color(0xFFFFE8F1), Color(0xFFFFD6E7)],
        onTap: () => onSendText('帮我挑一份送人的礼物，别踩雷'),
      ),
      _InspirationCard(
        icon: Icons.sell_outlined,
        title: '平价捡漏',
        subtitle: '同款里挑最值的，有券先提醒你',
        colors: const [Color(0xFFE6FFF2), Color(0xFFCFF7E3)],
        onTap: () => onSendText('帮我找平价又值的，性价比高的'),
      ),
      _InspirationCard(
        icon: Icons.photo_camera_outlined,
        title: '拍照找同款',
        subtitle: '拍一张图，找同款或同风格',
        colors: const [Color(0xFFEAF4FF), Color(0xFFD6E9FF)],
        onTap: onPickImage,
      ),
    ];

    Widget cardCell(_InspirationCard card) {
      return Expanded(
        child: AppPressable(
          child: GestureDetector(
            onTap: card.onTap,
            child: Container(
              padding: EdgeInsets.all(_hs(14)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: card.colors,
                ),
                borderRadius: BorderRadius.circular(_hs(18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(card.icon, size: _hs(20), color: AppColors.foreground.withValues(alpha: 0.75)),
                  SizedBox(height: _hs(8)),
                  Text(
                    card.title,
                    style: TextStyle(
                      fontSize: _hs(15) + AppScale.fontBump,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  SizedBox(height: _hs(3)),
                  Text(
                    card.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _hs(12) + AppScale.fontBump,
                      height: 1.35,
                      color: AppColors.foreground.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: _hs(16)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cardCell(cards[0]),
                SizedBox(width: _hs(10)),
                cardCell(cards[1]),
              ],
            ),
          ),
          SizedBox(height: _hs(10)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cardCell(cards[2]),
                SizedBox(width: _hs(10)),
                cardCell(cards[3]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- E1. 路线 chips ----------
  // 定位见 _routes 上方注释：话术入口。样式四枚完全一致、不做选中态，
  // 因为本批没有「当前路线」这个真实状态，做选中态就是骗用户。
  Widget _routesBlock() {
    return Padding(
      padding: EdgeInsets.only(top: _hs(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '你最在意什么？',
                style: TextStyle(
                  fontSize: _hs(13) + AppScale.fontBump,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              SizedBox(width: _hs(6)),
              Text(
                '点一个，后面按这个挑',
                style: TextStyle(
                  fontSize: _hs(11) + AppScale.fontBump,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          SizedBox(height: _hs(10)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _routes.length; i++) ...[
                  if (i > 0) SizedBox(width: _hs(8)),
                  AppPressable(
                    child: GestureDetector(
                      onTap: () => onSendText(_routes[i].$2),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: _hs(13), vertical: _hs(8)),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(_hs(999)),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _routes[i].$1,
                          style: TextStyle(
                            fontSize: _hs(12) + AppScale.fontBump,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- E2. 信任条 ----------
  // 只是承诺展示：每张牌带理由是第二批落到牌面上的事，本批文案不得再加码。
  Widget _trustBar() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: _hs(14)),
      padding: EdgeInsets.all(_hs(12)),
      decoration: BoxDecoration(
        color: AppColors.foreground,
        borderRadius: BorderRadius.circular(_hs(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: _hs(16), color: AppColors.gold),
          SizedBox(width: _hs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每张牌都说清 为什么选它',
                  style: TextStyle(
                    fontSize: _hs(12) + AppScale.fontBump,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: _hs(2)),
                Text(
                  '销量 · 评分 · 社区口碑，价格库存都是真的',
                  style: TextStyle(
                    fontSize: _hs(11) + AppScale.fontBump,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- E3. 底部快捷行 ----------
  // 前三项走小豆现有对话能力（欢迎语本就承诺可问优惠券/订单），不新开页面；
  // 第四项打开偏好弹层。都是一句话的事，不在这里堆业务逻辑。
  Widget _quickRow() {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.local_offer_outlined, '找优惠', () => onSendText('今天有什么优惠券能用')),
      (Icons.receipt_long_outlined, '我的订单', () => onSendText('帮我看看我的订单')),
      (Icons.local_shipping_outlined, '查物流', () => onSendText('帮我查一下物流到哪了')),
      (Icons.favorite_border, '小豆记得你', onOpenProfile),
    ];
    return Padding(
      padding: EdgeInsets.only(top: _hs(14)),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: AppPressable(
                child: GestureDetector(
                  onTap: item.$3,
                  child: Column(
                    children: [
                      Icon(item.$1, size: _hs(20), color: AppColors.secondaryForeground),
                      SizedBox(height: _hs(4)),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: _hs(11) + AppScale.fontBump,
                          color: AppColors.secondaryForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 灵感卡的数据形状：图标 + 标题 + 一句副文案 + 渐变底色 + 点击动作。
/// 动作在 build 里组装（有的抽牌、有的发话、有的选图），数据类本身不碰业务。
class _InspirationCard {
  const _InspirationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
}
