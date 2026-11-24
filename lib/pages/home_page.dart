import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/product_card.dart';
import 'user_feature_sheets.dart';

import '../widgets/click_effect/app_pressable.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 市集 tab 状态（原 _MarketSection 的状态上移到这里）：市集网格改
  // 按需加载（见下方 build 的说明）后，标题行、榜单切换行、网格是
  // CustomScrollView 里并列的几个 sliver，不再是一整个组件，状态
  // 只能由页面统一持有。
  MarketTab _marketTab = MarketTab.recommend;
  RankingSubTab _rankingSub = RankingSubTab.sales;

  void _selectMarketTab(MarketTab next) {
    if (next == _marketTab) return;
    setState(() => _marketTab = next);
  }

  void _selectRankingSub(RankingSubTab next) {
    if (next == _rankingSub) return;
    setState(() => _rankingSub = next);
  }

  /// 市集网格的一张卡：图高沿用原瀑布流的交错规则（偶数位看 id 哈希、
  /// 奇数位反着来，在 130/160 之间交错），只是构建时机改成滚到才建。
  Widget _marketCard(Product product, int index) {
    final hashEven = product.id.hashCode.isEven;
    final tall = index.isEven ? !hashEven : hashEven;
    return ProductCard(
      product: product,
      layout: ProductCardLayout.staggered,
      imageHeight: AppScale.s(tall ? 160 : 130),
    );
  }

  void _claimNewcomer(UserProvider user) {
    if (user.newcomerClaimed) {
      UserFeatureSheets.showCoupons(context);
      return;
    }
    if (user.claimNewcomerCoupon()) {
      showTopSnackBar(
        context,
        content: Text('领取成功！新人优惠券已放入账户', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketItems = productsByMarketTab(_marketTab, rankingSub: _rankingSub);
    return RepaintBoundary(
      child: SparkleBackground(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: HomeTopBar()),
            const SliverToBoxAdapter(child: BannerCarousel()),
            SliverToBoxAdapter(child: SizedBox(height: AppScale.s(12))),
            const SliverToBoxAdapter(child: _QuickActions()),
            SliverToBoxAdapter(child: SizedBox(height: AppScale.s(20))),
            SliverToBoxAdapter(child: _NewcomerSection(onClaim: _claimNewcomer)),
            SliverToBoxAdapter(child: SizedBox(height: AppScale.s(24))),
            SliverToBoxAdapter(
              child: _MarketHeader(tab: _marketTab, onSelect: _selectMarketTab),
            ),
            if (_marketTab == MarketTab.ranking)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RankingChip(
                            label: '收藏排行榜单',
                            active: _rankingSub == RankingSubTab.collect,
                            onTap: () => _selectRankingSub(RankingSubTab.collect),
                          ),
                          SizedBox(width: AppScale.s(8)),
                          _RankingChip(
                            label: '售卖排行榜单',
                            active: _rankingSub == RankingSubTab.sales,
                            onTap: () => _selectRankingSub(RankingSubTab.sales),
                          ),
                        ],
                      ),
                      SizedBox(height: AppScale.s(12)),
                    ],
                  ),
                ),
              ),
            // 市集网格按需加载（2026-11-24 治切页卡顿）：原来是
            // StaggeredProductGrid 把全部商品卡塞进两列 Column 一次
            // 建完——商品涨到 260 件后，一次构建实测 517 毫秒（性能
            // 图 Build 阶段），切到首页必卡一帧大的。改成与商城页
            // 同款的 SliverList 按行构建：滚到哪建到哪，首屏只建
            // 看得见的约 6 张。代价：市集内部切 tab 时原先整块内容
            // 的滑动淡入动画（AnimatedSwitcher）保不住了——内容成
            // 了 sliver 就没有整块可换，hx 已确认简化掉。
            if (marketItems.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
                  child: Text(
                    '暂无推荐商品',
                    style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rowIndex) {
                      final leftIndex = rowIndex * 2;
                      final rightIndex = leftIndex + 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: AppScale.s(10)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _marketCard(marketItems[leftIndex], leftIndex)),
                            SizedBox(width: AppScale.s(10)),
                            Expanded(
                              child: rightIndex < marketItems.length
                                  ? _marketCard(marketItems[rightIndex], rightIndex)
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: (marketItems.length + 1) ~/ 2,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: AppScale.s(20))),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _items = ['每日任务', '会员专享', '领券中心', '趣玩分类'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
      child: Row(
        children: _items.map((label) {
          return Expanded(
            child: AppInkWell(
              onTap: () => UserFeatureSheets.handleQuickAction(context, label),
              borderRadius: BorderRadius.circular(AppScale.s(12)),
              child: Column(
                children: [
                  Image.asset(
                    quickActionIconPaths[label]!,
                    width: AppScale.s(48),
                    height: AppScale.s(48),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(height: AppScale.s(6)),
                  Text(
                    label,
                    style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w500, color: AppColors.foreground),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NewcomerSection extends StatelessWidget {
  const _NewcomerSection({required this.onClaim});

  final void Function(UserProvider) onClaim;

  static const _paddingTopBase = 10.0;
  static const _paddingBottom = 10.0;
  static const _paddingH = 12.0;
  static const _titleGap = 8.0;
  static const _rowHeight = 72.0;
  static const _titleRowHeight = 20.0;

  static double get _cardHeight =>
      _paddingTopBase + _titleRowHeight + _titleGap + _rowHeight + _paddingBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return Container(
            clipBehavior: Clip.none,
            height: AppScale.s(_cardHeight * 1.1),
            padding: EdgeInsets.fromLTRB(
              AppScale.s(_paddingH),
              0,
              AppScale.s(10),
              AppScale.s(_paddingBottom),
            ),
            decoration: BoxDecoration(
              gradient: AppColors.memberBenefitCardGradient,
              borderRadius: BorderRadius.circular(AppScale.s(16)),
              boxShadow: AppColors.cardShadow,
              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.28)),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '会员专享福利',
                      style: TextStyle(
                        fontSize: AppScale.t(15),
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ' · 登录领取每日惊喜礼包',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppScale.t(11),
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppScale.s(8)),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: AppScale.s(72),
                            child: Row(
                              children: [
                                _BenefitMiniCard(iconPath: memberBenefitIconPaths['coupon']!, value: '¥ 5', label: '新人券包'),
                                SizedBox(width: AppScale.s(8)),
                                _BenefitMiniCard(iconPath: memberBenefitIconPaths['coins']!, value: '10', label: '积分奖励'),
                                SizedBox(width: AppScale.s(8)),
                                _BenefitMiniCard(iconPath: memberBenefitIconPaths['gift']!, label: '专属抽奖', iconSize: 31.2),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: AppScale.s(6)),
                        _MemberBenefitAction(
                          claimed: user.newcomerClaimed,
                          onTap: () => onClaim(user),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

class _BenefitMiniCard extends StatelessWidget {
  const _BenefitMiniCard({
    required this.iconPath,
    required this.label,
    this.value,
    this.iconSize = 28.6,
  });

  final String iconPath;
  final String? value;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(4), vertical: AppScale.s(4)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppScale.s(12)),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  iconPath,
                  width: AppScale.s(iconSize),
                  height: AppScale.s(iconSize),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    width: AppScale.s(iconSize),
                    height: AppScale.s(iconSize),
                  ),
                ),
                if (value != null) ...[
                  SizedBox(width: AppScale.s(3)),
                  Text(
                    value!,
                    style: TextStyle(
                      fontSize: AppScale.t(15),
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: AppScale.s(4)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(10),
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBenefitAction extends StatelessWidget {
  const _MemberBenefitAction({required this.claimed, required this.onTap});

  final bool claimed;
  final VoidCallback onTap;

  static const _buttonHeight = 36.0;
  /// 虚拟 IP 目标显示高度（逻辑 px，会乘 AppScale.factor）
  static const _mascotHeight = 100.0;
  static const _mascotOverlapRatio = 0.32;
  static const _mascotBaseWidth = 102.0;
  static const _mascotCanvasAspect = 1024 / 1536;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = AppScale.s(_buttonHeight);
    final targetHeight = AppScale.s(_mascotHeight);
    final baseWidth = AppScale.s(_mascotBaseWidth);
    final baseHeight = baseWidth * _mascotCanvasAspect;
    final scale = targetHeight / baseHeight;
    final displayWidth = baseWidth * scale;
    final actionWidth = math.max(baseWidth, displayWidth);
    final mascotBottom = buttonHeight - targetHeight * _mascotOverlapRatio;

    return SizedBox(
      width: actionWidth,
      height: AppScale.s(72),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: mascotBottom,
            left: 0,
            right: 0,
            child: SizedBox(
              height: targetHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        memberMascotPath,
                        width: baseWidth,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -AppScale.s(6),
                    right: AppScale.s(0),
                    child: const _MemberSpeechBubble(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppGestureDetector(
              onTap: onTap,
              child: Material(
              color: Colors.transparent,
              elevation: AppScale.s(2),
              shadowColor: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppScale.s(999)),
              child: Container(
                height: buttonHeight,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppScale.s(999)),
                ),
                alignment: Alignment.center,
                child: Text(
                  claimed ? '前往查看' : '立即领取',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppScale.t(13),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberSpeechBubble extends StatelessWidget {
  const _MemberSpeechBubble();

  @override
  Widget build(BuildContext context) {
    final lineStyle = TextStyle(
      fontSize: AppScale.t(9),
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    return CustomPaint(
      painter: _ChatBubblePainter(
        fillColor: Colors.white,
        borderColor: AppColors.primaryLight.withValues(alpha: 0.5),
        radius: AppScale.s(8),
        tailLength: AppScale.s(9),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppScale.s(8),
          AppScale.s(4),
          AppScale.s(8),
          AppScale.s(11),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('会员', style: lineStyle),
            Text('领好礼', style: lineStyle),
          ],
        ),
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  const _ChatBubblePainter({
    required this.fillColor,
    required this.borderColor,
    required this.radius,
    required this.tailLength,
  });

  final Color fillColor;
  final Color borderColor;
  final double radius;
  final double tailLength;

  Path _bubblePath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, math.min(w, h) / 2 - 1);
    final bodyBottom = h - tailLength;
    final path = Path();

    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, bodyBottom - r);
    path.quadraticBezierTo(w, bodyBottom, w - r, bodyBottom);
    path.lineTo(r + 6, bodyBottom);
    // 左下转角探出，尖端朝 IP（左下方）
    path.lineTo(-1.2, h - 0.8);
    path.lineTo(0, bodyBottom - 1);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bubblePath(size);

    canvas.drawShadow(path, const Color(0x22000000), 2, false);
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatBubblePainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor ||
      radius != oldDelegate.radius ||
      tailLength != oldDelegate.tailLength;
}

/// 市集标题行 + tab 条（原 _MarketSection 的上半截）：网格改按需
/// 加载后，它只是 CustomScrollView 里并列的一个普通 sliver 盒子，
/// tab 状态由 _HomePageState 持有、经参数传进来。
class _MarketHeader extends StatelessWidget {
  const _MarketHeader({required this.tab, required this.onSelect});

  final MarketTab tab;
  final ValueChanged<MarketTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('趣玩市集', style: TextStyle(fontSize: AppScale.t(18), fontWeight: FontWeight.bold)),
              AppGestureDetector(
                onTap: () => context.read<AppTabProvider>().goTo(AppTab.mall),
                child: Text('全部 >', style: TextStyle(fontSize: AppScale.t(15), color: AppColors.mutedForeground)),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(12)),
          SizedBox(
            height: AppScale.s(32),
            child: Row(
              children: marketTabs.map((t) {
                final active = tab == t.$1;
                return Expanded(
                  child: AppGestureDetector(
                    onTap: () => onSelect(t.$1),
                    behavior: HitTestBehavior.opaque,
                    enablePressScale: false,
                    enableParticle: false,
                    child: Column(
                      children: [
                        Text(
                          t.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppScale.t(13),
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                            color: active ? AppColors.primary : AppColors.foreground,
                          ),
                        ),
                        SizedBox(height: AppScale.s(4)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: active ? AppScale.s(20) : 0,
                          height: AppScale.s(3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppScale.s(999)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: AppScale.s(12)),
        ],
      ),
    );
  }
}

class _RankingChip extends StatelessWidget {
  const _RankingChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
        decoration: BoxDecoration(
          color: active ? AppColors.secondary : AppColors.muted,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
          border: Border.all(color: active ? AppColors.primaryLight : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppScale.t(11),
            color: active ? AppColors.primary : AppColors.mutedForeground,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
