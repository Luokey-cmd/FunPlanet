import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/drawn_icon.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/product_image.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/user_avatar_image.dart';
import 'orders_sheet.dart';
import 'ai_community_page.dart';
import 'ai_paint_page.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
import 'user_feature_sheets.dart';

const _profilePageScale = 1.3;

double _ps(double value) => AppScale.s(value * _profilePageScale);

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
          SliverToBoxAdapter(child: _InviteBanner()),
          SliverToBoxAdapter(child: SizedBox(height: _ps(12))),
          SliverToBoxAdapter(child: _AiFeatureEntries()),
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
                Text('我的', style: TextStyle(fontSize: _ps(24), fontWeight: FontWeight.bold)),
                Text('开启惊喜 · 收集快乐', style: TextStyle(fontSize: _ps(12), color: AppColors.mutedForeground)),
              ],
            ),
          ),
          _HexIcon(icon: Icons.settings_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          SizedBox(width: _ps(10)),
          _HexIcon(icon: Icons.notifications_outlined, onTap: () => NotificationSheet.show(context)),
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
    return InkWell(
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
            Positioned(top: _ps(10), right: _ps(28), child: _SparkleStar(size: _ps(8), opacity: 0.42)),
            Positioned(top: _ps(32), right: _ps(72), child: _SparkleStar(size: _ps(5), opacity: 0.28)),
            Positioned(top: _ps(18), left: _ps(108), child: _SparkleStar(size: _ps(6), opacity: 0.24)),
            Positioned(top: _ps(46), left: _ps(196), child: _SparkleStar(size: _ps(4), opacity: 0.2)),
            Column(
              children: [
            Padding(
              padding: EdgeInsets.all(_ps(16)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage())),
                  borderRadius: BorderRadius.circular(_ps(12)),
                  child: Row(
                    children: [
                      Container(
                        width: _ps(56),
                        height: _ps(56),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: _ps(2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: UserAvatarImage(path: user.avatarPath, fit: BoxFit.cover),
                      ),
                      SizedBox(width: _ps(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(user.nickname, style: TextStyle(fontSize: _ps(16), fontWeight: FontWeight.bold, color: Colors.white)),
                                SizedBox(width: _ps(6)),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: _ps(6), vertical: _ps(2)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
                                    borderRadius: BorderRadius.circular(_ps(4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.diamond, size: _ps(10), color: Colors.white),
                                      SizedBox(width: _ps(2)),
                                      Text('VIP${user.vipLevel}', style: TextStyle(fontSize: _ps(10), color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: _ps(4)),
                            Row(
                              children: [
                                Icon(Icons.diamond_outlined, size: _ps(12), color: Colors.white70),
                                SizedBox(width: _ps(4)),
                                Text('ID: ${user.userId}', style: TextStyle(fontSize: _ps(11), color: Colors.white70)),
                                SizedBox(width: _ps(4)),
                                Icon(Icons.chevron_right, size: _ps(14), color: Colors.white70),
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
                      onTap: () => UserFeatureSheets.handleStatBar(context, '积分'),
                    ),
                    _StatCell(
                      label: '趣玩币',
                      value: _fmt(user.funCoins),
                      iconPath: profileStatIconPaths['coins'],
                      onTap: () => UserFeatureSheets.handleStatBar(context, '趣玩币'),
                    ),
                    _StatCell(
                      label: '优惠券',
                      value: _fmt(user.couponCount),
                      iconPath: profileStatIconPaths['coupon'],
                      showBorder: false,
                      onTap: () => UserFeatureSheets.handleStatBar(context, '优惠券'),
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
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.iconPath,
    this.showBorder = true,
    this.onTap,
  });

  final String label;
  final String value;
  final String? iconPath;
  final bool showBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = _ps(18 * 1.4);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_ps(10)),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: _ps(12)),
            decoration: showBorder
                ? BoxDecoration(border: Border(right: BorderSide(color: AppColors.foreground.withValues(alpha: 0.12))))
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
                        errorBuilder: (context, error, stackTrace) => SizedBox(width: iconSize, height: iconSize),
                      ),
                      SizedBox(width: _ps(4)),
                    ],
                    Text(value, style: TextStyle(color: AppColors.foreground, fontWeight: FontWeight.bold, fontSize: _ps(14))),
                  ],
                ),
                SizedBox(height: _ps(2)),
                Text(label, style: TextStyle(color: AppColors.foreground.withValues(alpha: 0.65), fontSize: _ps(11))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSection extends StatelessWidget {
  static const _benefits = [
    (DrawnIconType.memberCoupon, '每月赠券'),
    (DrawnIconType.memberPoints, '积分加成'),
    (DrawnIconType.memberDiscount, '专属折扣'),
    (DrawnIconType.memberGift, '生日礼包'),
    (DrawnIconType.memberShipping, '优先发货'),
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
            Positioned(top: _ps(8), right: _ps(40), child: _SparkleStar(size: _ps(7), opacity: 0.38)),
            Positioned(top: _ps(28), right: _ps(120), child: _SparkleStar(size: _ps(5), opacity: 0.28)),
            Positioned(top: _ps(18), left: _ps(140), child: _SparkleStar(size: _ps(6), opacity: 0.24)),
            Positioned(top: _ps(10), left: _ps(24), child: _SparkleStar(size: _ps(4), opacity: 0.2)),
            Positioned(bottom: _ps(52), right: _ps(24), child: _SparkleStar(size: _ps(7), opacity: 0.22)),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(_ps(14), _ps(14), _ps(14), _ps(12)),
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
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: _ps(40),
                            height: _ps(40),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(_ps(10)),
                            ),
                            child: Icon(Icons.diamond, size: _ps(22), color: AppColors.gold),
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
                              style: TextStyle(color: Colors.white, fontSize: _ps(15), fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: _ps(2)),
                            Text(
                              '尊享专属权益，解锁更多惊喜福利',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: _ps(10)),
                            ),
                          ],
                        ),
                      ),
                      Consumer<UserProvider>(
                        builder: (context, user, _) {
                          final isMember = user.vipLevel >= memberTargetVipLevel;
                          return GestureDetector(
                            onTap: () => UserFeatureSheets.showMemberBenefits(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: _ps(12), vertical: _ps(7)),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.gold, const Color(0xFFF5D78E)]),
                                borderRadius: BorderRadius.circular(_ps(999)),
                              ),
                              child: Text(
                                isMember ? '会员中心 >' : '办理会员 >',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: _ps(11),
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
                            child: InkWell(
                              onTap: () => UserFeatureSheets.handleMemberBenefit(context, _benefits[i].$2),
                              borderRadius: BorderRadius.circular(_ps(8)),
                              child: Column(
                                children: [
                                  DrawnFeatureIcon(
                                    type: _benefits[i].$1,
                                    size: _ps(28),
                                    style: DrawnIconStyle.plain,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: _ps(4)),
                                  Text(
                                    _benefits[i].$2,
                                    style: TextStyle(fontSize: _ps(10), color: AppColors.foreground),
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
        painter: _TitleStarPainter(color: Colors.white.withValues(alpha: opacity)),
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  static const _row1 = [
    (DrawnIconType.order, '我的订单'),
    (DrawnIconType.pendingPayment, '待发货'),
    (DrawnIconType.shipping, '待收货'),
    (DrawnIconType.orderCompleted, '已完成'),
    (DrawnIconType.refund, '售后/退款'),
  ];
  static const _row2 = [
    (DrawnIconType.coupon, '优惠券'),
    (DrawnIconType.coins, '趣玩币明细'),
    (DrawnIconType.address, '地址管理'),
    (DrawnIconType.favoriteStar, '收藏夹'),
    (DrawnIconType.history, '浏览记录'),
    (DrawnIconType.service, '客服中心'),
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
                  child: CustomPaint(painter: _TitleStarPainter(color: AppColors.primary)),
                ),
                SizedBox(width: _ps(6)),
                Text('我的服务', style: TextStyle(fontSize: _ps(15), fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: _ps(14)),
            Consumer<OrderProvider>(
              builder: (context, orders, _) {
                final badgeCounts = <String, int>{};
                final pendingCount = orders.pendingCount;
                final shippingCount = orders.shippingCount;
                if (pendingCount > 0) badgeCounts['待发货'] = pendingCount;
                if (shippingCount > 0) badgeCounts['待收货'] = shippingCount;
                return _ServiceRow(
                  items: _row1,
                  badgeCounts: badgeCounts,
                  onTap: (label) => OrdersSheet.show(context, filterLabel: label),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: _ps(12)),
              child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
            ),
            _ServiceRow(items: _row2, onTap: (label) => UserFeatureSheets.handleService(context, label)),
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
  bool shouldRepaint(covariant _TitleStarPainter oldDelegate) => oldDelegate.color != color;
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.items,
    required this.onTap,
    this.badgeCounts = const {},
  });

  final List<(DrawnIconType, String)> items;
  final ValueChanged<String> onTap;
  final Map<String, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final badge = badgeCounts[item.$2] ?? 0;
        return Expanded(
          child: InkWell(
            onTap: () => onTap(item.$2),
            borderRadius: BorderRadius.circular(_ps(8)),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    DrawnFeatureIcon(type: item.$1, size: _ps(32 * 1.3), style: DrawnIconStyle.line),
                    if (badge > 0)
                      Positioned(
                        top: _ps(-2),
                        right: _ps(-6),
                        child: Container(
                          constraints: BoxConstraints(minWidth: _ps(16), minHeight: _ps(16)),
                          padding: EdgeInsets.symmetric(horizontal: _ps(4)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(_ps(999)),
                            border: Border.all(color: Colors.white, width: _ps(1.2)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _ps(9),
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
                  style: TextStyle(fontSize: _ps(10), color: AppColors.mutedForeground, height: 1.2),
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
                    colors: [Color(0xFFFFE6ED), Color(0xFFFFF6FA), Color(0xFFF3EEFF)],
                  ),
                  borderRadius: BorderRadius.circular(_ps(16)),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
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
                          Text('邀请好友', style: TextStyle(fontSize: _ps(14), fontWeight: FontWeight.bold, height: 1.15)),
                          Text('领好礼', style: TextStyle(fontSize: _ps(14), fontWeight: FontWeight.bold, height: 1.15)),
                          SizedBox(height: _ps(2)),
                          Text('一起开启惊喜之旅', style: TextStyle(fontSize: _ps(10), color: AppColors.foreground)),
                        ],
                      ),
                    ),
                    SizedBox(width: _ps(92)),
                    GestureDetector(
                      onTap: () {
                        showTopSnackBar(context, content: Text('邀请链接已复制', style: TextStyle(fontSize: _ps(14), fontWeight: FontWeight.w600)));
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: _ps(14), vertical: _ps(8)),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(_ps(999)),
                        ),
                        child: Text('立即邀请', style: TextStyle(color: Colors.white, fontSize: _ps(12), fontWeight: FontWeight.w600)),
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

class _AiFeatureEntries extends StatelessWidget {
  static const _entryAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _ps(16)),
      child: Row(
        children: [
          Expanded(
            child: _AiEntryCard(
              imagePath: aiPaintEntryPath,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPaintPage())),
            ),
          ),
          SizedBox(width: _ps(10)),
          Expanded(
            child: _AiEntryCard(
              imagePath: aiCommunityEntryPath,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCommunityPage())),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiEntryCard extends StatelessWidget {
  const _AiEntryCard({required this.imagePath, required this.onTap});

  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_ps(12)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_ps(12)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: AppColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_ps(12)),
            child: AspectRatio(
              aspectRatio: _AiFeatureEntries._entryAspectRatio,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.muted,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_not_supported_outlined, size: _ps(28), color: AppColors.mutedForeground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
