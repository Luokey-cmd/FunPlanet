import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/guide_controller.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_image.dart';
import '../widgets/starwish_dossier_sheet.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/user_avatar_image.dart';
import 'orders_sheet.dart';
import 'xiaodou_records_page.dart';
import 'ai_community_page.dart';
import 'ai_paint_page.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
import 'user_feature_sheets.dart';

import '../widgets/click_effect/app_pressable.dart';

const _profilePageScale = 1.3;

double _ps(double value) => AppScale.s(value * _profilePageScale);

/// 我的页正文字号：相对原设计加大一号（+2），顶栏「我的 / 副标题」不用。
double _pt(double value) => _ps(value + 2) + AppScale.fontBump;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SparkleBackground(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _ProfileHeader()),
          SliverToBoxAdapter(child: _UserCard()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(12))),
          SliverToBoxAdapter(child: _MemberSection()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(16))),
          SliverToBoxAdapter(child: _ServiceSection()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(16))),
          SliverToBoxAdapter(child: _ContentSection()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(16))),
          SliverToBoxAdapter(child: _InviteBanner()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(24))),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(_ps(16), top + _ps(12), _ps(16), _ps(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的',
                  style: TextStyle(
                    fontSize: _ps(24) + AppScale.fontBump,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '开启惊喜 · 收集快乐',
                  style: TextStyle(
                    fontSize: _ps(12) + AppScale.fontBump,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          // 消息铃铛已撤（2026-11-23）：通知入口统一到底部导航「消息」页，
          // 这里只留设置，避免两个入口各挂一套未读角标对不上。
          _HexIcon(
            icon: Icons.settings_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HexIcon extends StatelessWidget {
  const _HexIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_ps(10)),
      child: Container(
        width: _ps(36),
        height: _ps(36),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(_ps(10)),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Icon(icon, size: _ps(18), color: AppColors.foreground),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.profileCardGradient,
          borderRadius: BorderRadius.circular(_ps(20)),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: _ps(10),
              right: _ps(28),
              child: _SparkleStar(size: _ps(8), opacity: 0.42),
            ),
            Positioned(
              top: _ps(32),
              right: _ps(72),
              child: _SparkleStar(size: _ps(5), opacity: 0.28),
            ),
            Positioned(
              top: _ps(18),
              left: _ps(108),
              child: _SparkleStar(size: _ps(6), opacity: 0.24),
            ),
            Positioned(
              top: _ps(46),
              left: _ps(196),
              child: _SparkleStar(size: _ps(4), opacity: 0.2),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(_ps(16)),
                  child: Material(
                    color: Colors.transparent,
                    child: AppInkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(_ps(12)),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: _ps(56),
                              height: _ps(56),
                              child: UserAvatarImage(
                                path: user.avatarPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: _ps(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.nickname,
                                      style: TextStyle(
                                        fontSize: _pt(16),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: _ps(6)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _ps(6),
                                        vertical: _ps(2),
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.gold,
                                            AppColors.goldDark,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          _ps(4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.diamond,
                                            size: _ps(10),
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: _ps(2)),
                                          Text(
                                            'VIP${user.vipLevel}',
                                            style: TextStyle(
                                              fontSize: _pt(10),
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: _ps(4)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.diamond_outlined,
                                      size: _ps(12),
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: _ps(4)),
                                    Text(
                                      'ID: ${user.userId}',
                                      style: TextStyle(
                                        fontSize: _pt(11),
                                        color: Colors.white70,
                                      ),
                                    ),
                                    // 点小图标复制 ID（加好友/联系客服时常用），
                                    // 不走整行的编辑资料跳转，所以单独给个点击区。
                                    AppGestureDetector(
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: '${user.userId}',
                                          ),
                                        );
                                        showTopSnackBar(
                                          context,
                                          content: Text(
                                            'ID 已复制',
                                            style: TextStyle(
                                              fontSize: _pt(12),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.all(_ps(3)),
                                        child: Icon(
                                          Icons.copy_outlined,
                                          size: _ps(11),
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: _ps(2)),
                                    // 原来只有一个箭头，用户看不出点进去是编辑资料，补明文
                                    Text(
                                      '编辑资料',
                                      style: TextStyle(
                                        fontSize: _pt(11),
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: _ps(14),
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: _ps(56),
                            height: _ps(56),
                            child: Transform.translate(
                              offset: Offset(-_ps(56 * 1.2) * 0.3, 0),
                              child: Transform.scale(
                                scale: 1.12 * 1.2,
                                child: ProductImage(
                                  image: oneEyedGiftBoxPath,
                                  width: _ps(56),
                                  height: _ps(56),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(_ps(12), 0, _ps(12), _ps(12)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(_ps(14)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _StatCell(
                          label: '积分',
                          value: _fmt(user.points),
                          iconPath: profileStatIconPaths['points'],
                          // 数字下面带下一步：0 分时告诉用户去哪赚，别只摆个 0
                          subLabel: user.points == 0 ? '签到得积分' : '查看明细',
                          onTap: () =>
                              UserFeatureSheets.handleStatBar(context, '积分'),
                        ),
                        _StatCell(
                          label: '趣玩币',
                          value: _fmt(user.funCoins),
                          iconPath: profileStatIconPaths['coins'],
                          subLabel: '查看明细',
                          onTap: () =>
                              UserFeatureSheets.handleStatBar(context, '趣玩币'),
                        ),
                        _StatCell(
                          label: '优惠券',
                          value: _fmt(user.couponCount),
                          iconPath: profileStatIconPaths['coupon'],
                          showBorder: false,
                          subLabel: _couponHint(user).$1,
                          subLabelWarn: _couponHint(user).$2,
                          onTap: () =>
                              UserFeatureSheets.handleStatBar(context, '优惠券'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(0)}万+';
    return '$n';
  }

  // 优惠券格子的小字：优先提醒快到期的券（7 天内到期标橙色），没有临期券就报可用张数。
  // 输入是当前用户，输出 (文案, 是否警示色)。expire 是 '2025-12-31' 这样的字符串，
  // 解析不了就退回只报张数——这里绝不能因为一条脏数据让整个卡片报错。
  (String, bool) _couponHint(UserProvider user) {
    final avail = user.coupons.where((c) => !c.used).toList();
    if (avail.isEmpty) return ('暂无可用券', false);
    DateTime? nearest;
    for (final c in avail) {
      final d = DateTime.tryParse(c.expire);
      if (d != null && (nearest == null || d.isBefore(nearest))) {
        nearest = d;
      }
    }
    if (nearest != null) {
      final days = nearest.difference(DateTime.now()).inDays;
      if (days < 0) return ('有券已过期', true);
      if (days == 0) return ('今天有券到期', true);
      if (days <= 7) return ('$days 天后有券到期', true);
    }
    return ('共 ${avail.length} 张可用', false);
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.iconPath,
    this.showBorder = true,
    this.onTap,
    this.subLabel,
    this.subLabelWarn = false,
  });

  final String label;
  final String value;
  final String? iconPath;
  final bool showBorder;
  final VoidCallback? onTap;

  // 数字下方的小字（下一步提示，如「签到得积分」「3 天后有券到期」），可空
  final String? subLabel;

  // 小字是否用警示色（快过期这类需要用户注意的才用）
  final bool subLabelWarn;

  @override
  Widget build(BuildContext context) {
    final iconSize = _ps(18 * 1.4);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: AppInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_ps(10)),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: _ps(12)),
            decoration: showBorder
                ? BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: AppColors.foreground.withValues(alpha: 0.12),
                      ),
                    ),
                  )
                : null,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconPath != null) ...[
                      Image.asset(
                        iconPath!,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            SizedBox(width: iconSize, height: iconSize),
                      ),
                      SizedBox(width: _ps(4)),
                    ],
                    Text(
                      value,
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontWeight: FontWeight.bold,
                        fontSize: _pt(14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _ps(2)),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.foreground.withValues(alpha: 0.65),
                    fontSize: _pt(11),
                  ),
                ),
                if (subLabel != null) ...[
                  SizedBox(height: _ps(1)),
                  Text(
                    subLabel!,
                    style: TextStyle(
                      color: subLabelWarn
                          ? const Color(0xFFEA580C)
                          : AppColors.foreground.withValues(alpha: 0.45),
                      fontSize: _pt(9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSection extends StatelessWidget {
  // 第三个元素是权益的数值小字：只写名字用户感知不到值不值，
  // 数值与会员权益说明页（showMemberBenefits）里的文案保持一致，改一处要同步改另一处。
  static const _benefits = [
    ('assets/images/icon_pf_monthly_coupon.png', '每月赠券', '满88减20'),
    ('assets/images/icon_pf_points_boost.png', '积分加成', '购物×1.5'),
    ('assets/images/icon_pf_discount.png', '专属折扣', '指定95折'),
    ('assets/images/icon_pf_birthday_gift.png', '生日礼包', '+50趣玩币'),
    ('assets/images/icon_pf_priority_shipping.png', '优先发货', '24h内发出'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.profileMemberGradient,
          borderRadius: BorderRadius.circular(_ps(16)),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: _ps(8),
              right: _ps(40),
              child: _SparkleStar(size: _ps(7), opacity: 0.38),
            ),
            Positioned(
              top: _ps(28),
              right: _ps(120),
              child: _SparkleStar(size: _ps(5), opacity: 0.28),
            ),
            Positioned(
              top: _ps(18),
              left: _ps(140),
              child: _SparkleStar(size: _ps(6), opacity: 0.24),
            ),
            Positioned(
              top: _ps(10),
              left: _ps(24),
              child: _SparkleStar(size: _ps(4), opacity: 0.2),
            ),
            Positioned(
              bottom: _ps(52),
              right: _ps(24),
              child: _SparkleStar(size: _ps(7), opacity: 0.22),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _ps(14),
                    _ps(14),
                    _ps(14),
                    _ps(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_ps(10)),
                        child: Image.asset(
                          memberBadgePath,
                          width: _ps(40),
                          height: _ps(40),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: _ps(40),
                                height: _ps(40),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(_ps(10)),
                                ),
                                child: Icon(
                                  Icons.diamond,
                                  size: _ps(22),
                                  color: AppColors.gold,
                                ),
                              ),
                        ),
                      ),
                      SizedBox(width: _ps(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '趣玩星球会员',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _pt(15),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: _ps(2)),
                            // 副标题不再放空话：没开通的直接报价格，已开通的报状态。
                            // 会员门槛是 VIP2（memberTargetVipLevel），价格 memberSubscribeCoinPrice 趣玩币/月。
                            Consumer<UserProvider>(
                              builder: (context, user, _) {
                                final isMember =
                                    user.vipLevel >= memberTargetVipLevel;
                                // 已开通且服务端给了到期日（vipExpireAt）就报日期，没给仍报权益数。
                                final expireDt =
                                    DateTime.tryParse(user.vipExpireAt)?.toLocal();
                                final expireDate = expireDt == null
                                    ? ''
                                    : '${expireDt.year}-${expireDt.month.toString().padLeft(2, '0')}-${expireDt.day.toString().padLeft(2, '0')}';
                                return Text(
                                  isMember
                                      ? (expireDate.isNotEmpty
                                            ? '会员生效中 · 有效期至 $expireDate'
                                            : '会员生效中 · 5 项权益已解锁')
                                      : '$memberSubscribeCoinPrice 趣玩币/月 · 开通即享 5 项权益',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: _pt(10),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Consumer<UserProvider>(
                        builder: (context, user, _) {
                          final isMember =
                              user.vipLevel >= memberTargetVipLevel;
                          return AppGestureDetector(
                            onTap: () =>
                                UserFeatureSheets.showMemberBenefits(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _ps(12),
                                vertical: _ps(7),
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold,
                                    const Color(0xFFF5D78E),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(_ps(999)),
                              ),
                              child: Text(
                                isMember ? '会员中心 >' : '办理会员 >',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: _pt(11),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(_ps(10), 0, _ps(10), _ps(10)),
                  padding: EdgeInsets.symmetric(vertical: _ps(12)),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(_ps(12)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < _benefits.length; i++) ...[
                          if (i > 0)
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: AppColors.border.withValues(alpha: 0.6),
                            ),
                          Expanded(
                            child: AppInkWell(
                              onTap: () =>
                                  UserFeatureSheets.handleMemberBenefit(
                                    context,
                                    _benefits[i].$2,
                                  ),
                              borderRadius: BorderRadius.circular(_ps(8)),
                              child: Column(
                                children: [
                                  Image.asset(
                                    _benefits[i].$1,
                                    width: _ps(34),
                                    height: _ps(34),
                                  ),
                                  SizedBox(height: _ps(4)),
                                  Text(
                                    _benefits[i].$2,
                                    style: TextStyle(
                                      fontSize: _pt(10),
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  SizedBox(height: _ps(1)),
                                  Text(
                                    _benefits[i].$3,
                                    style: TextStyle(
                                      fontSize: _pt(9),
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleStar extends StatelessWidget {
  const _SparkleStar({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TitleStarPainter(
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  // 上面 5 个是订单状态：补上了原来缺的待付款、待评价；
  // 「我的订单」升到卡头当「全部订单」入口，「已完成」在全部订单里看，不再占格子。
  static const _row1 = [
    ('assets/images/icon_pf_to_pay.png', '待付款'),
    ('assets/images/icon_pf_to_ship.png', '待发货'),
    ('assets/images/icon_pf_to_receive.png', '待收货'),
    ('assets/images/icon_pf_to_review.png', '待评价'),
    ('assets/images/icon_pf_after_sales.png', '售后/退款'),
  ];

  // 下面 5 个是工具：去掉与资产栏重复的优惠券、趣玩币，换进「我的钱包」，
  // 正好 5+5（hz 2026-11-20 拍板）。钱包是三种资产的总入口，见 UserFeatureSheets.showWallet。
  static const _row2 = [
    ('assets/images/icon_pf_wallet.png', '我的钱包'),
    ('assets/images/icon_pf_address.png', '地址管理'),
    ('assets/images/icon_pf_favorites.png', '收藏夹'),
    ('assets/images/icon_pf_history.png', '浏览记录'),
    ('assets/images/icon_pf_support.png', '客服中心'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: Container(
        padding: EdgeInsets.fromLTRB(_ps(16), _ps(14), _ps(16), _ps(16)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_ps(16)),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: _ps(14),
                  height: _ps(14),
                  child: CustomPaint(
                    painter: _TitleStarPainter(color: AppColors.primary),
                  ),
                ),
                SizedBox(width: _ps(6)),
                Text(
                  '我的服务',
                  style: TextStyle(
                    fontSize: _pt(15),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 「我的订单」的新位置：卡头右侧的全部订单入口，点开是不过滤的订单列表
                AppInkWell(
                  onTap: () => OrdersSheet.show(context),
                  borderRadius: BorderRadius.circular(_ps(6)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _ps(4),
                      vertical: _ps(2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '全部订单',
                          style: TextStyle(
                            fontSize: _pt(11),
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: _ps(13),
                          color: AppColors.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: _ps(14)),
            Consumer<OrderProvider>(
              builder: (context, orders, _) {
                // 角标只数各自状态：待付款数 pending、待发货数 paid，
                // 别再用旧的混合数（待付款会被误算进待发货）。
                final badgeCounts = <String, int>{};
                if (orders.unpaidCount > 0) {
                  badgeCounts['待付款'] = orders.unpaidCount;
                }
                if (orders.toShipCount > 0) {
                  badgeCounts['待发货'] = orders.toShipCount;
                }
                if (orders.shippingCount > 0) {
                  badgeCounts['待收货'] = orders.shippingCount;
                }
                if (orders.reviewCount > 0) {
                  badgeCounts['待评价'] = orders.reviewCount;
                }
                return _ServiceRow(
                  items: _row1,
                  badgeCounts: badgeCounts,
                  onTap: (label) =>
                      OrdersSheet.show(context, filterLabel: label),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: _ps(12)),
              child: Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            _ServiceRow(
              items: _row2,
              onTap: (label) => UserFeatureSheets.handleService(context, label),
            ),
          ],
        ),
      ),
    );
  }
}

// 「我的内容」栏（2026-11-20 定稿新加）：放用户自己产生的内容——
// 社区帖子、AI 绘画、小豆记得你、买到手的盒柜、写过的评价。
// 以前 AI 社区/绘画只有页面最底下两张大图卡，进了社区也找不到「我的」东西；
// 现在收成一行 5 个入口，大图卡已删除（一处入口只出现一次）。
class _ContentSection extends StatelessWidget {
  static const _items = [
    ('assets/images/icon_pf_community.png', 'AI 社区'),
    ('assets/images/icon_pf_ai_paint.png', 'AI绘画'),
    ('assets/images/icon_pf_starwish.png', '小豆记得你'),
    ('assets/images/icon_pf_cabinet.png', '我的盒柜'),
    ('assets/images/icon_pf_my_reviews.png', '我的评价'),
  ];

  // 每个入口都落到已有的页面/弹层，不新建页面：
  // 社区和绘画是现成整页；小豆记得你复用小豆聊天页同款记忆弹层；
  // 盒柜是按订单汇藏品的弹层；我的评价复用订单列表（只看已评价订单）。
  void _handleTap(BuildContext context, String label) {
    switch (label) {
      case 'AI 社区':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiCommunityPage()),
        );
      case 'AI绘画':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiPaintPage()),
        );
      case '小豆记得你':
        showStarwishDossierSheet(context);
      case '我的盒柜':
        UserFeatureSheets.showCollectionCabinet(context);
      case '我的评价':
        OrdersSheet.show(context, filterLabel: '我的评价');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: Container(
        padding: EdgeInsets.fromLTRB(_ps(16), _ps(14), _ps(16), _ps(16)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_ps(16)),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: _ps(14),
                  height: _ps(14),
                  child: CustomPaint(
                    painter: _TitleStarPainter(color: AppColors.primary),
                  ),
                ),
                SizedBox(width: _ps(6)),
                Text(
                  '我的内容',
                  style: TextStyle(
                    fontSize: _pt(15),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: _ps(14)),
            _ServiceRow(
              items: _items,
              onTap: (label) => _handleTap(context, label),
            ),
            SizedBox(height: _ps(10)),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            // 小豆办事记录入口（Agent 第二步）：整行可点，进汇总页
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const XiaodouRecordsPage()),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: _ps(10)),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: _ps(19), color: AppColors.primary),
                    SizedBox(width: _ps(8)),
                    Expanded(
                      child: Text(
                        '小豆办事记录',
                        style: TextStyle(fontSize: _pt(13), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '小豆替你办过的事都在这',
                      style: TextStyle(fontSize: _pt(11), color: AppColors.mutedForeground),
                    ),
                    Icon(Icons.chevron_right, size: _ps(16), color: AppColors.mutedForeground),
                  ],
                ),
              ),
            ),
            SizedBox(height: _ps(10)),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            // 新手引导入口：没领过奖时用奖励勾着回来做完；领过显示已完成、可重玩。
            Builder(
              builder: (context) {
                final claimed = context.watch<UserProvider>().guideRewardClaimed;
                return InkWell(
                  onTap: () => context.read<GuideController>().startManual(),
                  child: Padding(
                    padding: EdgeInsets.only(top: _ps(10)),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, size: _ps(19), color: AppColors.primary),
                        SizedBox(width: _ps(8)),
                        Expanded(
                          child: Text(
                            '新手引导',
                            style: TextStyle(fontSize: _pt(13), fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          claimed ? '已完成，可重玩' : '完成得 20 趣玩币',
                          style: TextStyle(
                            fontSize: _pt(11),
                            fontWeight: claimed ? FontWeight.w400 : FontWeight.w700,
                            color: claimed ? AppColors.mutedForeground : AppColors.primary,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: _ps(16), color: AppColors.mutedForeground),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleStarPainter extends CustomPainter {
  _TitleStarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.28, cy - r * 0.28)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + r * 0.28, cy + r * 0.28)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.28, cy + r * 0.28)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - r * 0.28, cy - r * 0.28)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TitleStarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.items,
    required this.onTap,
    this.badgeCounts = const {},
  });

  final List<(String, String)> items;
  final ValueChanged<String> onTap;
  final Map<String, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final badge = badgeCounts[item.$2] ?? 0;
        return Expanded(
          child: AppInkWell(
            onTap: () => onTap(item.$2),
            borderRadius: BorderRadius.circular(_ps(8)),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      item.$1,
                      width: _ps(32 * 1.3),
                      height: _ps(32 * 1.3),
                    ),
                    if (badge > 0)
                      Positioned(
                        top: _ps(-2),
                        right: _ps(-6),
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: _ps(16),
                            minHeight: _ps(16),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: _ps(4)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(_ps(999)),
                            border: Border.all(
                              color: Colors.white,
                              width: _ps(1.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _pt(9),
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: _ps(6)),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: _pt(10),
                    color: AppColors.foreground,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InviteBanner extends StatelessWidget {
  static const _slotHeight = 100.0;
  static const _cardHeight = 84.0;
  static const _characterHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: SizedBox(
        height: _ps(_slotHeight),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _ps(_cardHeight),
              child: Container(
                padding: EdgeInsets.fromLTRB(_ps(16), 0, _ps(12), 0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFE6ED),
                      Color(0xFFFFF6FA),
                      Color(0xFFF3EEFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_ps(16)),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.25),
                  ),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '邀请好友',
                            style: TextStyle(
                              fontSize: _pt(14),
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            '领好礼',
                            style: TextStyle(
                              fontSize: _pt(14),
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: _ps(2)),
                          Text(
                            '一起开启惊喜之旅',
                            style: TextStyle(
                              fontSize: _pt(10),
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _ps(92)),
                    AppGestureDetector(
                      onTap: () {
                        showTopSnackBar(
                          context,
                          content: Text(
                            '邀请链接已复制',
                            style: TextStyle(
                              fontSize: _pt(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _ps(14),
                          vertical: _ps(8),
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(_ps(999)),
                        ),
                        child: Text(
                          '立即邀请',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _pt(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: _ps(100),
              bottom: 0,
              child: ProductImage(
                image: inviteCharactersPath,
                height: _ps(_characterHeight),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

