import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_image.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/staggered_product_grid.dart';
import '../widgets/sparkle_background.dart';
import '../services/review_api_service.dart';
import '../widgets/product_review_card.dart';
import 'checkout_page.dart';
import 'image_preview_page.dart';
import 'support_chat_page.dart';

const _detailTextScale = 1.3;

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> with SingleTickerProviderStateMixin {
  int _imageIndex = 0;
  int _detailTab = 0;
  late TabController _tabController;

  static const _imageCount = 1;
  static const _detailTabs = ['商品介绍', '评价', '猜你喜欢', '购买须知'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _detailTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _detailTab = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().addBrowseRecord(widget.product.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Product get product => widget.product;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<UserProvider>().isFavorite(product.id);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_detailTextScale)),
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _DetailTopBar(product: product)),
                  SliverToBoxAdapter(child: _ProductImageSection(
                    product: product,
                    imageIndex: _imageIndex,
                    imageCount: _imageCount,
                    onPrev: () => setState(() => _imageIndex = (_imageIndex - 1 + _imageCount) % _imageCount),
                    onNext: () => setState(() => _imageIndex = (_imageIndex + 1) % _imageCount),
                  )),
                  SliverToBoxAdapter(child: _InfoCard(product: product)),
                  SliverToBoxAdapter(child: _DescriptionSection(product: product)),
                  SliverToBoxAdapter(child: _DetailTabs(tabController: _tabController, tabs: _detailTabs)),
                  SliverToBoxAdapter(child: _DetailContent(tabIndex: _detailTab, product: product)),
                  SliverToBoxAdapter(child: SizedBox(height: AppScale.s(20))),
                ],
              ),
            ),
            _BottomBar(
              product: product,
              isFavorite: isFavorite,
              onFavorite: () => context.read<UserProvider>().toggleFavorite(product.id),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(8), top + AppScale.s(8), AppScale.s(8), AppScale.s(8)),
      child: Row(
        children: [
          _CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
          Expanded(
            child: Text(
              '商品详情',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppScale.s(16), fontWeight: FontWeight.w600, color: AppColors.foreground),
            ),
          ),
          _CircleBtn(
            icon: context.watch<UserProvider>().isFavorite(product.id) ? Icons.favorite : Icons.favorite_border,
            onTap: () => context.read<UserProvider>().toggleFavorite(product.id),
          ),
          SizedBox(width: AppScale.s(8)),
          _CircleBtn(
            icon: Icons.share_outlined,
            onTap: () {
              final user = context.read<UserProvider>();
              if (user.completeDailyShare()) {
                showTopSnackBar(
                  context,
                  content: Text('分享成功，获得 20 趣玩币', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                );
              } else {
                showTopSnackBar(
                  context,
                  content: Text('已分享「${product.name}」', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ProductImageSection extends StatelessWidget {
  const _ProductImageSection({
    required this.product,
    required this.imageIndex,
    required this.imageCount,
    required this.onPrev,
    required this.onNext,
  });

  final Product product;
  final int imageIndex;
  final int imageCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  void _openFullScreenImage(BuildContext context) {
    if (product.imagePath.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          child: ProductImage(
            image: product.imagePath,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height * 0.75,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const imageInsetH = 6.0;
    const imageInsetTop = 12.0;
    const imageInsetBottom = 12.0;
    const badgeVPad = 4.0;
    const badgeFontSize = 11.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final badgeTextSize = AppScale.s(badgeFontSize);
    final badgePadding = AppScale.s(badgeVPad) * _detailTextScale;
    final badgeStyle = TextStyle(
      color: Colors.white,
      fontSize: badgeTextSize,
      height: 1,
      fontWeight: FontWeight.w600,
    );
    final badgePainter = TextPainter(
      text: TextSpan(text: '官方正品', style: badgeStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout();
    final badgeHeight = badgePadding * 2 + badgePainter.height;
    final topGap = badgeHeight / 2;
    final imageHeight = AppScale.s(296 * 0.8) * _detailTextScale;
    final imageRadius = AppScale.s(14) * _detailTextScale;
    final frameInsetH = AppScale.s(imageInsetH) * _detailTextScale;
    final frameInsetTop = AppScale.s(imageInsetTop) * _detailTextScale;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppScale.s(10) * _detailTextScale,
        AppScale.s(4) * _detailTextScale,
        AppScale.s(10) * _detailTextScale,
        0,
      ),
      child: GestureDetector(
        onTap: () => _openFullScreenImage(context),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.secondary, AppColors.accentSoft, AppColors.background],
            ),
            borderRadius: BorderRadius.circular(AppScale.s(20) * _detailTextScale),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(frameInsetH, frameInsetTop, frameInsetH, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.only(top: topGap),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProductThumbnail(
                            product: product,
                            height: imageHeight,
                            borderRadius: imageRadius,
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppScale.s(10) * _detailTextScale,
                                vertical: badgePadding,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(AppScale.s(999) * _detailTextScale),
                              ),
                              child: Text('官方正品', style: badgeStyle),
                            ),
                          ),
                          if (imageCount > 1) ...[
                            Positioned(
                              bottom: AppScale.s(16) * _detailTextScale,
                              right: AppScale.s(16) * _detailTextScale,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppScale.s(10) * _detailTextScale,
                                  vertical: AppScale.s(4) * _detailTextScale,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(AppScale.s(999) * _detailTextScale),
                                ),
                                child: Text(
                                  '${imageIndex + 1}/$imageCount',
                                  style: TextStyle(color: Colors.white, fontSize: AppScale.s(12) * _detailTextScale),
                                ),
                              ),
                            ),
                            Positioned(
                              left: AppScale.s(4) * _detailTextScale,
                              top: imageHeight / 2 - AppScale.s(20) * _detailTextScale,
                              child: _CircleBtn(icon: Icons.chevron_left, onTap: onPrev, small: true),
                            ),
                            Positioned(
                              right: AppScale.s(4) * _detailTextScale,
                              top: imageHeight / 2 - AppScale.s(20) * _detailTextScale,
                              child: _CircleBtn(icon: Icons.chevron_right, onTap: onNext, small: true),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppScale.s(imageInsetBottom) * _detailTextScale),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.small = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = small ? AppScale.s(32) : AppScale.s(36);
    return Material(
      color: AppColors.card.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: s,
          height: s,
          child: Icon(icon, size: small ? AppScale.s(18) : AppScale.s(20), color: AppColors.foreground),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(12), AppScale.s(16), 0),
      padding: EdgeInsets.all(AppScale.s(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(20)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: AppScale.s(17),
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: AppScale.s(6)),
                      Text(
                        '${product.majorCategory} > ${product.subCategory}',
                        style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${product.price.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: AppScale.s(20), fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            SizedBox(height: AppScale.s(12)),
            Wrap(
              spacing: AppScale.s(8),
              runSpacing: AppScale.s(6),
              children: [product.majorCategory, product.subCategory, '广州发货'].map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppScale.s(999)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: AppScale.s(12), color: AppColors.primary),
                      SizedBox(width: AppScale.s(4)),
                      Text(tag, style: TextStyle(fontSize: AppScale.s(11), color: AppColors.primary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(16), AppScale.s(16), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('折叠式产品介绍', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
          SizedBox(height: AppScale.s(8)),
          Text(
            product.description,
            style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.tabController, required this.tabs});

  final TabController tabController;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.mutedForeground,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontSize: AppScale.s(13), fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: AppScale.s(13)),
      tabs: tabs.map((t) => Tab(text: t)).toList(),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.tabIndex, required this.product});

  final int tabIndex;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppScale.s(16)),
      child: switch (tabIndex) {
        0 => Text(product.description, style: TextStyle(fontSize: AppScale.s(13), color: AppColors.mutedForeground, height: 1.6)),
        1 => _ProductReviewsSection(productId: product.id),
        2 => StaggeredProductGrid(
            products: products
                .where((p) => p.id != product.id && p.category == product.category)
                .take(6)
                .toList(),
          ),
        _ => Text(
            product.purchaseNotes.replaceAll('；', '。\n'),
            style: TextStyle(fontSize: AppScale.s(13), color: AppColors.mutedForeground, height: 1.6),
          ),
      },
    );
  }
}

class _ProductReviewsSection extends StatefulWidget {
  const _ProductReviewsSection({required this.productId});

  final String productId;

  @override
  State<_ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<_ProductReviewsSection> {
  final _api = ReviewApiService();
  late Future<List<ProductReview>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchProductReviews(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductReview>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.hasError) {
          return Text('评价加载失败', style: TextStyle(fontSize: AppScale.s(13), color: AppColors.mutedForeground));
        }
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Text('暂无评价，快来成为第一个评价的人吧～', style: TextStyle(fontSize: AppScale.s(13), color: AppColors.mutedForeground));
        }
        return Column(
          children: reviews.map((review) => Padding(
            padding: EdgeInsets.only(bottom: AppScale.s(12)),
            child: ProductReviewCard(review: review),
          )).toList(),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppScale.s(16),
        AppScale.s(10),
        AppScale.s(16),
        AppScale.s(10) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: AppScale.s(8),
            offset: Offset(0, -AppScale.s(2)),
          ),
        ],
      ),
      child: Row(
        children: [
          _BarIcon(icon: Icons.storefront_outlined, label: '店铺'),
          SizedBox(width: AppScale.s(12)),
          _BarIcon(
            icon: Icons.chat_bubble_outline,
            label: '客服',
            onTap: () => SupportChatPage.openForProduct(
              context,
              productId: product.id,
              productName: product.name,
            ),
          ),
          SizedBox(width: AppScale.s(12)),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                context.read<CartProvider>().addItem(product);
                showTopSnackBar(context, content: Text('已加入购物车', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppScale.s(999))),
              ),
              child: Text('加入购物车', style: TextStyle(fontSize: AppScale.s(13), fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: AppScale.s(10)),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppScale.s(999)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => CheckoutPage.openBuyNow(context, product),
                  borderRadius: BorderRadius.circular(AppScale.s(999)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                    child: Center(
                      child: Text('立即购买', style: TextStyle(color: Colors.white, fontSize: AppScale.s(13), fontWeight: FontWeight.w600)),
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

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppScale.s(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppScale.s(26), color: AppColors.foreground),
            SizedBox(height: AppScale.s(3)),
            Text(
              label,
              style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}