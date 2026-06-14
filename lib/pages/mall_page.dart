import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/page_scales.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/sparkle_background.dart';
import 'search_page.dart';

class MallPage extends StatefulWidget {
  const MallPage({super.key});

  @override
  State<MallPage> createState() => _MallPageState();
}

class _MallPageState extends State<MallPage> {
  String _activeCategory = 'all';

  List<Product> get _filtered => productsByCategory(_activeCategory);

  void _claimCoupon(UserProvider user) {
    if (user.newcomerClaimed) return;
    if (user.claimNewcomerCoupon()) {
      showTopSnackBar(
        context,
        content: Text('优惠券领取成功', style: TextStyle(fontSize: hmS(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SparkleBackground(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _MallHeader()),
          SliverToBoxAdapter(child: SizedBox(height: hmS(12))),
          SliverToBoxAdapter(
            child: CategoryChipBar(
              activeId: _activeCategory,
              categories: mallCategoryTags,
              scale: homeMallPageScale,
              chipHorizontalPadding: 12.7776,
              chipVerticalPadding: 5.4,
              barHeight: 30.6,
              padding: EdgeInsets.symmetric(horizontal: hmS(12)),
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
            child: GestureDetector(
              onTap: () => SearchPage.open(context, hint: '搜索系列 / 角色 / 品类'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hmS(14), vertical: hmS(10)),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(hmS(999)),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: hmS(18), color: AppColors.mutedForeground),
                    SizedBox(width: hmS(8)),
                    Text(
                      '搜索系列 / 角色 / 品类',
                      style: TextStyle(fontSize: hmS(13), color: AppColors.mutedForeground),
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
    return InkWell(
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
                  style: TextStyle(color: Colors.white, fontSize: hmS(8), fontWeight: FontWeight.bold),
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
                  Text('新人优惠券', style: TextStyle(fontSize: hmS(15), fontWeight: FontWeight.bold)),
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
                    style: TextStyle(fontSize: hmS(10), color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            Consumer<UserProvider>(
              builder: (context, user, _) {
                return GestureDetector(
                  onTap: () => onClaim(user),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: hmS(16), vertical: hmS(10)),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(hmS(999)),
                    ),
                    child: Text(
                      user.newcomerClaimed ? '已领取' : '立即领取',
                      style: TextStyle(color: Colors.white, fontSize: hmS(12), fontWeight: FontWeight.w600),
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
      child: Text(text, style: TextStyle(fontSize: hmS(11), fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }
}