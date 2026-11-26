import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/product_catalog_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/page_scales.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/sparkle_background.dart';
import 'search_page.dart';

import '../widgets/click_effect/app_pressable.dart';
class MallPage extends StatefulWidget {
  const MallPage({super.key});

  @override
  State<MallPage> createState() => _MallPageState();
}

class _MallPageState extends State<MallPage> {
  String _activeCategory = 'all';

  // 下拉刷新（2026-11-27 hx 追加）：先换一套穿插编织的随机种子，
  // 再向服务端重拉一次商品目录；重拉失败不挡事，本地换序照样生效。
  Future<void> _onRefresh() async {
    bumpProductShuffleEpoch();
    try {
      await context.read<ProductCatalogProvider>().load();
    } catch (_) {
      // 目录重拉失败时保持现有数据，只换序、不报错。
    }
    if (mounted) setState(() {});
  }

  // 商城综合排序（2026-11-26 hx 拍板：销量为主 + 新品加权）：
  // 分数 = 0.7 × 销量分 + 0.3 × 新品分。
  // 销量分 = ln(销量+1) ÷ ln(本列表最高销量+1)：全店销量差距悬殊
  // （最高 8569、中位只有 197），直接比销量会让几个老爆款焊死榜首；
  // 取对数压平后爆款仍在前排，又不至于整屏都是老货。
  // 新品分 = 商品编号 ÷ 本列表最大编号：编号越新分越高，
  // 让新系列的商品穿插进前几屏。同分时编号大的在前，保证顺序稳定。
  List<Product> get _filtered {
    final list = List<Product>.of(productsByCategory(_activeCategory));
    if (list.length < 2) return list;
    var maxSales = 0;
    var maxId = 0;
    for (final p in list) {
      if (p.sales > maxSales) maxSales = p.sales;
      final n = _idNum(p.id);
      if (n > maxId) maxId = n;
    }
    final maxLog = math.log(maxSales + 1);
    double score(Product p) {
      final salesPart = maxLog > 0 ? math.log(p.sales + 1) / maxLog : 0.0;
      final newPart = maxId > 0 ? _idNum(p.id) / maxId : 0.0;
      return 0.7 * salesPart + 0.3 * newPart;
    }

    list.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : _idNum(b.id).compareTo(_idNum(a.id));
    });
    // 与首页推荐同口径：综合分排完做偏向新品的随机穿插（新品占多数），
    // 不然销量悬殊时前几屏全是老爆款（2026-11-27 hx 定稿）。
    // 先名次窗口扰动再穿插：与首页推荐同口径，下拉刷新能真换一批
    // （见 product_data 的 jitterRankedByWindow）。
    return avoidImmediateRepeats(interleaveNewProducts(jitterRankedByWindow(list)), scope: 'mall:$_activeCategory');
  }

  // 商品编号取数字部分（p123 → 123），取不到按 0 算。
  static int _idNum(String id) =>
      int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _claimCoupon(UserProvider user) {
    if (user.newcomerClaimed) return;
    if (user.claimNewcomerCoupon()) {
      showTopSnackBar(
        context,
        content: Text('优惠券领取成功', style: TextStyle(fontSize: hmS(14) + AppScale.fontBump, fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 首页分类小按钮带过来的待选分类：读到就选中它（效果与在本页点
    // 那个分类按钮一致），并在本帧结束后清掉记号，免得之后每次重建
    // 都被强行拨回这个分类（hx 2026-11-26：首页小按钮与商城同效）。
    final tabProvider = context.watch<AppTabProvider>();
    final pendingCategory = tabProvider.pendingMallCategory;
    if (pendingCategory != null) {
      _activeCategory = pendingCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tabProvider.clearPendingMallCategory();
      });
    }
    return SparkleBackground(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
          SliverToBoxAdapter(child: _MallHeader()),
          SliverToBoxAdapter(child: SizedBox(height: hmS(12))),
          SliverToBoxAdapter(
            child: CategoryChipBar(
              activeId: _activeCategory,
              categories: mallCategoryTags,
              compact: true,
              chipHorizontalPadding: 18.5,
              chipVerticalPadding: 3.9,
              barHeight: 33.8,
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
              onSelected: (cat) => setState(() => _activeCategory = cat.id),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: hmS(12))),
          SliverToBoxAdapter(child: _CouponBanner(onClaim: _claimCoupon)),
          SliverToBoxAdapter(child: SizedBox(height: hmS(12))),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hmS(16)),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, rowIndex) {
                  final left = rowIndex * 2;
                  final right = left + 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: hmS(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ProductCard(
                            product: _filtered[left],
                            layout: ProductCardLayout.mall,
                            scale: homeMallPageScale,
                          ),
                        ),
                        SizedBox(width: hmS(12)),
                        Expanded(
                          child: right < _filtered.length
                              ? ProductCard(
                                  product: _filtered[right],
                                  layout: ProductCardLayout.mall,
                                  scale: homeMallPageScale,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );
                },
                childCount: (_filtered.length + 1) ~/ 2,
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: hmS(20))),
        ],
        ),
      ),
    );
  }
}

class _MallHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(hmS(16), top + hmS(12), hmS(16), 0),
      child: Row(
        children: [
          Expanded(
            child: AppGestureDetector(
              onTap: () => SearchPage.open(context, hint: '搜索系列 / 角色 / 品类'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hmS(14), vertical: hmS(10)),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(hmS(999)),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: AppScale.s(18), color: AppColors.mutedForeground),
                    SizedBox(width: hmS(8)),
                    Transform.translate(
                      offset: Offset(0, -AppScale.s(1)),
                      child: Text(
                        '搜索系列 / 角色 / 品类',
                        style: TextStyle(
                          fontSize: AppScale.t(13),
                          color: AppColors.mutedForeground,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: hmS(10)),
          _HeaderIcon(
            icon: Icons.shopping_cart_outlined,
            badge: context.watch<CartProvider>().totalCount,
            onTap: () => context.read<AppTabProvider>().goTo(AppTab.cart),
          ),
          SizedBox(width: hmS(8)),
          _HeaderIcon(
            icon: Icons.notifications_outlined,
            badge: context.watch<UserProvider>().unreadNotificationCount,
            onTap: () => NotificationSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(hmS(999)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(hmS(10)),
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              boxShadow: AppColors.softShadow,
            ),
            child: Icon(icon, size: hmS(20), color: AppColors.foreground),
          ),
          if (badge > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(hmS(3)),
                decoration: const BoxDecoration(color: AppColors.tagNew, shape: BoxShape.circle),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: TextStyle(color: Colors.white, fontSize: hmS(8) + AppScale.fontBump, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CouponBanner extends StatelessWidget {
  const _CouponBanner({required this.onClaim});

  final void Function(UserProvider) onClaim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hmS(16)),
      child: Container(
        padding: EdgeInsets.all(hmS(16)),
        decoration: BoxDecoration(
          gradient: AppColors.couponGradient,
          borderRadius: BorderRadius.circular(hmS(16)),
          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('新人优惠券', style: TextStyle(fontSize: hmS(19) + AppScale.fontBump, fontWeight: FontWeight.bold)),
                  SizedBox(height: hmS(6)),
                  Row(
                    children: [
                      _CouponTag('满30减5'),
                      SizedBox(width: hmS(8)),
                      _CouponTag('满50减10'),
                    ],
                  ),
                  SizedBox(height: hmS(4)),
                  Text(
                    '2024.11.01 – 2024.11.30',
                    style: TextStyle(fontSize: hmS(14) + AppScale.fontBump, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            Consumer<UserProvider>(
              builder: (context, user, _) {
                return AppGestureDetector(
                  onTap: () => onClaim(user),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: hmS(16), vertical: hmS(10)),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(hmS(999)),
                    ),
                    child: Text(
                      user.newcomerClaimed ? '已领取' : '立即领取',
                      style: TextStyle(color: Colors.white, fontSize: hmS(16) + AppScale.fontBump, fontWeight: FontWeight.w600),
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

class _CouponTag extends StatelessWidget {
  const _CouponTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hmS(8), vertical: hmS(3)),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(hmS(6)),
      ),
      child: Text(text, style: TextStyle(fontSize: hmS(15) + AppScale.fontBump, fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }
}