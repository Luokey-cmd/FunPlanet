import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/product_image.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/staggered_product_grid.dart';
import '../widgets/sparkle_background.dart';
import '../services/review_api_service.dart';
import '../widgets/product_review_card.dart';
import 'checkout_page.dart';
import 'image_preview_page.dart';
import 'support_chat_page.dart';
import 'xiaodou_chat_page.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_buttons.dart';

const _detailTextScale = 1.0;

/// 详情页单独压字号（不影响图片/间距布局缩放）
const _detailFontScale = 0.93;

/// 价格显示：整数不带小数，有小数保留两位（输入是金额，输出是给用户看的文本）。
String _priceText(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

/// 商品详情页（2026-11-24 按主流购物 App 结构整页改版）。
/// 结构自上而下：整幅滑图（可带视频）→ 价格/标题 → 优惠条 → 小豆点评 →
/// 服务行 → 规格行 → 系列图鉴 → 评价 → 商品详情（参数/卖点/介绍/长图）→ 猜你喜欢。
/// 坑：页面里所有数字只准读商品与接口的真实字段（价格、销量、评分、库存、评价），
/// 不许为了好看现编；字段为空的区块整段不显示，不占位。
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _scrollController = ScrollController();
  final _pageController = PageController();
  final _reviewsKey = GlobalKey();
  final _detailKey = GlobalKey();
  final _recommendKey = GlobalKey();
  final _seriesKey = GlobalKey();

  int _imageIndex = 0;
  bool _showAnchors = false;
  int _activeAnchor = 0;
  double _viewportWidth = 375;

  // 评价只拉一次：价格区的「N 条评价」和评价区共用同一份，免得两处各拉一遍对不上。
  List<ProductReview>? _reviews;
  bool _reviewsError = false;

  Product get product => widget.product;

  bool get _hasVideo => (product.videoPath ?? '').trim().isNotEmpty;

  /// 图集总页数：有视频时视频占第一页，后面才是图片。
  int get _slideCount {
    final images = product.galleryImages.length;
    return (_hasVideo ? 1 : 0) + (images == 0 ? 1 : images);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().addBrowseRecord(widget.product.id);
      }
    });
    ReviewApiService().fetchProductReviews(product.id).then((list) {
      if (mounted) setState(() => _reviews = list);
    }).catchError((_) {
      if (mounted) setState(() => _reviewsError = true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > _viewportWidth * 0.75;
    if (show != _showAnchors) setState(() => _showAnchors = show);
    // 锚点高亮：哪个区块的顶部刚滑过锚点条下沿，就亮哪个。
    final keys = [_reviewsKey, _detailKey, _recommendKey];
    var active = 0;
    for (var i = 0; i < keys.length; i++) {
      final ctx = keys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy <= 150) active = i + 1;
    }
    if (active != _activeAnchor) setState(() => _activeAnchor = active);
  }

  /// 点锚点滚动到对应区块。输入是锚点序号（0 商品 / 1 评价 / 2 详情 / 3 推荐）。
  /// 坑：顶栏是悬浮覆盖层，滚动时要把它的高度让出来，不然区块标题会被顶栏盖住。
  void _scrollToAnchor(int index) {
    setState(() => _activeAnchor = index);
    if (index == 0) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      return;
    }
    final keys = [_reviewsKey, _detailKey, _recommendKey];
    final ctx = keys[index - 1].currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final target = _scrollController.offset + box.localToGlobal(Offset.zero).dy - 108;
    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _openFullScreenImage(BuildContext context, String imagePath) {
    if (imagePath.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          child: ProductImage(
            image: imagePath,
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
    _viewportWidth = MediaQuery.sizeOf(context).width;
    final isFavorite = context.watch<UserProvider>().isFavorite(product.id);
    final recommendations = products
        .where((p) => p.id != product.id && p.category == product.category)
        .take(6)
        .toList();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_detailFontScale)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SparkleBackground(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildMediaCarousel(context)),
                        SliverToBoxAdapter(child: _PriceTitleBlock(product: product, reviewCount: _reviews?.length)),
                        SliverToBoxAdapter(child: _SectionGap()),
                        SliverToBoxAdapter(child: _CouponStrip(product: product)),
                        SliverToBoxAdapter(child: _XiaodouCard(product: product)),
                        SliverToBoxAdapter(child: _ServiceRows(product: product)),
                        SliverToBoxAdapter(
                          child: _SpecRow(
                            product: product,
                            onTap: () => _showPurchaseSheet(context, product, buyNow: false),
                          ),
                        ),
                        SliverToBoxAdapter(child: _SectionGap()),
                        SliverToBoxAdapter(
                          child: Container(key: _seriesKey, child: _SeriesSection(product: product)),
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            key: _reviewsKey,
                            child: _ReviewsSection(
                            product: product,
                            reviews: _reviews,
                              hasError: _reviewsError,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: _SectionGap()),
                        SliverToBoxAdapter(
                          child: Container(key: _detailKey, child: _DetailSection(product: product)),
                        ),
                        if (recommendations.isNotEmpty) ...[
                          SliverToBoxAdapter(child: _SectionGap()),
                          SliverToBoxAdapter(
                            child: Container(
                              key: _recommendKey,
                              child: Padding(
                              padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(16), AppScale.s(16), 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('猜你喜欢', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                                  SizedBox(height: AppScale.s(12)),
                                  StaggeredProductGrid(products: recommendations),
                                ],
                              ),
                              ),
                            ),
                          ),
                        ],
                        SliverToBoxAdapter(child: SizedBox(height: AppScale.s(24))),
                      ],
                    ),
                  ),
                  _BottomBar(
                    product: product,
                    isFavorite: isFavorite,
                    onFavorite: () => context.read<UserProvider>().toggleFavorite(product.id),
                    onAddToCart: () => _showPurchaseSheet(context, product, buyNow: false),
                    onBuyNow: () => _showPurchaseSheet(context, product, buyNow: true),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopChrome(
                  product: product,
                  showAnchors: _showAnchors,
                  activeAnchor: _activeAnchor,
                  onAnchorTap: _scrollToAnchor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 图区：整幅方形、手指滑页；有视频时视频是第一页。
  Widget _buildMediaCarousel(BuildContext context) {
    final size = _viewportWidth;
    final images = product.galleryImages;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slideCount,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (context, index) {
              if (_hasVideo && index == 0) {
                return _VideoSlide(product: product);
              }
              final imageIndex = _hasVideo ? index - 1 : index;
              final path = images.isEmpty ? product.imagePath : images[imageIndex.clamp(0, images.length - 1)];
              return AppGestureDetector(
                onTap: () => _openFullScreenImage(context, path),
                child: ProductThumbnail(
                  product: product,
                  imagePathOverride: path,
                  width: size,
                  height: size,
                  borderRadius: 0,
                  fit: BoxFit.cover,
                  showIcon: false,
                ),
              );
            },
          ),
          Positioned(
            left: AppScale.s(12),
            bottom: AppScale.s(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(8), vertical: AppScale.s(3)),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppScale.s(999))),
              child: Text('官方正品', style: TextStyle(color: Colors.white, fontSize: AppScale.t(10), fontWeight: FontWeight.w600)),
            ),
          ),
          if (_slideCount > 1)
            Positioned(
              right: AppScale.s(12),
              bottom: AppScale.s(12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(8), vertical: AppScale.s(3)),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(AppScale.s(999))),
                child: Text('${_imageIndex + 1}/$_slideCount', style: TextStyle(color: Colors.white, fontSize: AppScale.t(10))),
              ),
            ),
        ],
      ),
    );
  }
}

/// 区块之间的浅色分隔带（主流详情页的通用做法，代替大面积装饰）。
class _SectionGap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: AppScale.s(8), color: AppColors.muted);
  }
}

/// 视频页：初始化失败就退回主图，不让坏视频挡住整个图区。
/// 输入是商品（读 videoPath）；视频地址三种形态都接：http 直链、assets 打包路径、
/// 服务端相对路径（走 resolveRemoteMediaUrl 拼当前服务端地址）。
class _VideoSlide extends StatefulWidget {
  const _VideoSlide({required this.product});

  final Product product;

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = (widget.product.videoPath ?? '').trim();
    try {
      final VideoPlayerController controller;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(path));
      } else if (path.startsWith('assets/')) {
        controller = VideoPlayerController.asset(path);
      } else {
        final url = await resolveRemoteMediaUrl(path);
        if (url.isEmpty) throw StateError('empty video url');
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ProductThumbnail(
            product: widget.product,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).width,
            borderRadius: 0,
            fit: BoxFit.cover,
            showIcon: false,
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(AppScale.s(10)),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
              child: Icon(_failed ? Icons.videocam_off_outlined : Icons.play_arrow, color: Colors.white, size: AppScale.s(28)),
            ),
          ),
        ],
      );
    }
    return AppGestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Center(
              child: Container(
                padding: EdgeInsets.all(AppScale.s(10)),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow, color: Colors.white, size: AppScale.s(28)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 顶部悬浮栏：没滑动时是透明底的圆形按钮（返回 / 分享 / 收藏）；
/// 滑过图区后变成白底锚点条（商品 / 评价 / 详情 / 推荐）。
class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.product,
    required this.showAnchors,
    required this.activeAnchor,
    required this.onAnchorTap,
  });

  final Product product;
  final bool showAnchors;
  final int activeAnchor;
  final void Function(int index) onAnchorTap;

  void _share(BuildContext context) {
    final user = context.read<UserProvider>();
    if (user.completeDailyShare()) {
      showTopSnackBar(
        context,
        content: Text('分享成功，获得 20 趣玩币', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    } else {
      showTopSnackBar(
        context,
        content: Text('已分享「${product.name}」', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isFavorite = context.watch<UserProvider>().isFavorite(product.id);

    if (!showAnchors) {
      return Padding(
        padding: EdgeInsets.fromLTRB(AppScale.s(12), top + AppScale.s(8), AppScale.s(12), AppScale.s(8)),
        child: Row(
          children: [
            _CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            const Spacer(),
            _CircleBtn(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              iconColor: isFavorite ? AppColors.priceRed : AppColors.foreground,
              onTap: () => context.read<UserProvider>().toggleFavorite(product.id),
            ),
            SizedBox(width: AppScale.s(8)),
            _CircleBtn(icon: Icons.share_outlined, onTap: () => _share(context)),
          ],
        ),
      );
    }

    const labels = ['商品', '评价', '详情', '推荐'];
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: AppScale.s(8), offset: Offset(0, AppScale.s(2)))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: AppScale.s(22), color: AppColors.foreground),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < labels.length; i++)
                  AppGestureDetector(
                    onTap: () => onAnchorTap(i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppScale.s(10), horizontal: AppScale.s(6)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: AppScale.t(13),
                              fontWeight: i == activeAnchor ? FontWeight.bold : FontWeight.normal,
                              color: i == activeAnchor ? AppColors.primaryDark : AppColors.foreground,
                            ),
                          ),
                          SizedBox(height: AppScale.s(3)),
                          Container(
                            width: AppScale.s(18),
                            height: AppScale.s(2.5),
                            decoration: BoxDecoration(
                              color: i == activeAnchor ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppScale.s(2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: AppScale.s(22),
              color: isFavorite ? AppColors.priceRed : AppColors.foreground,
            ),
            onPressed: () => context.read<UserProvider>().toggleFavorite(product.id),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.iconColor});

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        width: AppScale.s(34),
        height: AppScale.s(34),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: AppScale.s(6))],
        ),
        child: Icon(icon, size: AppScale.s(19), color: iconColor ?? AppColors.foreground),
      ),
    );
  }
}

/// 价格 + 标题块：现价/原价/折扣、销量评分行、库存提示、商品名、系列与稀有度。
/// 数据全是现成字段：originalPrice 以前有数据没展示，这次补上。
class _PriceTitleBlock extends StatelessWidget {
  const _PriceTitleBlock({required this.product, required this.reviewCount});

  final Product product;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.price;
    final discountZhe = hasDiscount ? (product.price / product.originalPrice! * 10) : null;
    final soldOut = product.stock <= 0;
    final lowStock = !soldOut && product.stock <= 10;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(14), AppScale.s(16), AppScale.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('¥', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              Text(
                _priceText(product.price),
                style: TextStyle(fontSize: AppScale.t(26), fontWeight: FontWeight.bold, color: AppColors.primaryDark, height: 1),
              ),
              if (hasDiscount) ...[
                SizedBox(width: AppScale.s(8)),
                Padding(
                  padding: EdgeInsets.only(bottom: AppScale.s(2)),
                  child: Text(
                    '¥${_priceText(product.originalPrice!)}',
                    style: TextStyle(
                      fontSize: AppScale.t(13),
                      color: AppColors.mutedForeground,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                if (discountZhe != null && discountZhe < 9.9) ...[
                  SizedBox(width: AppScale.s(6)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(2)),
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppScale.s(4))),
                    child: Text('${discountZhe.toStringAsFixed(1)}折', style: TextStyle(fontSize: AppScale.t(11), fontWeight: FontWeight.w600, color: AppColors.priceRed)),
                  ),
                ],
              ],
              const Spacer(),
              if (soldOut)
                Text('已售完', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600, color: AppColors.priceRed))
              else if (lowStock)
                Text('仅剩 ${product.stock} 件', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600, color: AppColors.tagHot)),
            ],
          ),
          SizedBox(height: AppScale.s(6)),
          Text(
            '已售 ${product.sales} 件 · 评分 ${product.rating.toStringAsFixed(1)}${reviewCount == null ? '' : ' · $reviewCount 条评价'}',
            style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground),
          ),
          SizedBox(height: AppScale.s(10)),
          Text(
            product.name,
            style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.bold, color: AppColors.foreground, height: 1.35),
          ),
          if ((product.series != null && product.series!.isNotEmpty) ||
              (product.rarity != null && product.rarity!.isNotEmpty) ||
              (product.tag != null && product.tag!.isNotEmpty)) ...[
            SizedBox(height: AppScale.s(8)),
            Row(
              children: [
                if (product.series != null && product.series!.isNotEmpty)
                  Text(
                    '${product.series} 系列',
                    style: TextStyle(fontSize: AppScale.t(12), color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                  ),
                if (product.rarity != null && product.rarity!.isNotEmpty) ...[
                  SizedBox(width: AppScale.s(8)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(1.5)),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(AppScale.s(4)),
                    ),
                    child: Text(product.rarity!, style: TextStyle(fontSize: AppScale.t(10), fontWeight: FontWeight.w600, color: AppColors.goldDark)),
                  ),
                ],
                if (product.tag != null && product.tag!.isNotEmpty) ...[
                  SizedBox(width: AppScale.s(8)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(1.5)),
                    decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppScale.s(4))),
                    child: Text(product.tag!, style: TextStyle(fontSize: AppScale.t(10), fontWeight: FontWeight.w600, color: AppColors.secondaryForeground)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 优惠条：有未用券先报券（真实券名），没有再看可领的组（新人 / 会员月券 / 领券中心）。
/// 坑：可领判断必须和服务端领券口径一致——新人看 newcomerClaimed、会员月券看
/// memberMonthlyCouponClaimed 且要 VIP2、领券中心看有没有 c6；领取走 UserProvider 现成方法。
class _CouponStrip extends StatelessWidget {
  const _CouponStrip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final unused = user.coupons.where((c) => !c.used).toList();

    String? text;
    String? actionText;
    VoidCallback? onTap;

    if (unused.isNotEmpty) {
      final best = unused.reduce((a, b) => a.discount >= b.discount ? a : b);
      text = '券 · ${best.title}';
      actionText = '下单可用';
      onTap = () => _showMyCoupons(context, unused);
    } else if (!user.newcomerClaimed) {
      text = '新人专享券待领取';
      actionText = '领取';
      onTap = () => _claim(context, user.claimNewcomerCoupon());
    } else if (user.vipLevel >= 2 && !user.memberMonthlyCouponClaimed) {
      text = '本月会员券待领取';
      actionText = '领取';
      onTap = () => _claim(context, user.claimMemberMonthlyCoupon());
    } else if (!user.coupons.any((c) => c.id == 'c6')) {
      text = '领券中心有券待领取';
      actionText = '领取';
      onTap = () => _claim(context, user.claimCouponCenterGift());
    }

    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(12), AppScale.s(16), 0),
      child: AppGestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(9)),
          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppScale.s(10))),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, size: AppScale.s(16), color: AppColors.primaryDark),
              SizedBox(width: AppScale.s(6)),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600, color: AppColors.secondaryForeground),
                ),
              ),
              Text(actionText!, style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              Icon(Icons.chevron_right, size: AppScale.s(16), color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }

  void _claim(BuildContext context, bool ok) {
    showTopSnackBar(
      context,
      content: Text(
        ok ? '已领取，结算时可用' : '已领取过或暂不符合条件',
        style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showMyCoupons(BuildContext context, List<Coupon> coupons) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(20)))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(16), AppScale.s(20), AppScale.s(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的优惠券（未使用）', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                SizedBox(height: AppScale.s(12)),
                ...coupons.map(
                  (c) => Padding(
                    padding: EdgeInsets.only(bottom: AppScale.s(10)),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer_outlined, size: AppScale.s(18), color: AppColors.primaryDark),
                        SizedBox(width: AppScale.s(8)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600, color: AppColors.foreground)),
                              Text('${c.condition} · 有效期至 ${c.expire}', style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('结算时自动可选用，优惠金额以下单页为准。', style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 小豆点评卡：文案只许用现成数据拼（卖点第一条 + 适合谁），没有就用评分销量兜底，
/// 不让模型现编。点整张卡带着这件商品去小豆页提问。
class _XiaodouCard extends StatelessWidget {
  const _XiaodouCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (product.sellingPoints.isNotEmpty) lines.add(product.sellingPoints.first);
    if (product.suitableFor != null && product.suitableFor!.isNotEmpty) {
      lines.add('适合：${product.suitableFor}');
    }
    if (lines.isEmpty) {
      lines.add('这件评分 ${product.rating.toStringAsFixed(1)} 分，已售 ${product.sales} 件。');
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(12), AppScale.s(16), 0),
      child: AppGestureDetector(
        onTap: () => XiaodouChatPage.open(
          context,
          initialPrompt: '小豆，帮我看看「${product.name}」怎么样？值不值得买，适合送人吗？',
        ),
        child: Container(
          padding: EdgeInsets.all(AppScale.s(12)),
          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppScale.s(14))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppScale.s(26),
                    height: AppScale.s(26),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Icon(Icons.smart_toy_outlined, size: AppScale.s(15), color: Colors.white),
                  ),
                  SizedBox(width: AppScale.s(8)),
                  Text('小豆点评', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                  const Spacer(),
                  Text('问小豆', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                  Icon(Icons.chevron_right, size: AppScale.s(15), color: AppColors.primaryDark),
                ],
              ),
              SizedBox(height: AppScale.s(8)),
              ...lines.map(
                (line) => Padding(
                  padding: EdgeInsets.only(bottom: AppScale.s(2)),
                  child: Text(line, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.secondaryForeground, height: 1.45)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 服务行：配送与保障各一行，点开是同一个说明弹层（购买须知并进弹层，不再单独占页签）。
class _ServiceRows extends StatelessWidget {
  const _ServiceRows({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(14), AppScale.s(16), AppScale.s(4)),
      child: Column(
        children: [
          _serviceRow(context, Icons.local_shipping_outlined, '配送', '广州发货 · 包邮 · 48小时内发货'),
          Divider(height: AppScale.s(14), color: AppColors.border),
          _serviceRow(context, Icons.verified_user_outlined, '保障', '正品保障 · 七天无理由退换 · 假一赔十'),
        ],
      ),
    );
  }

  Widget _serviceRow(BuildContext context, IconData icon, String label, String text) {
    return AppGestureDetector(
      onTap: () => _showServiceSheet(context, product),
      child: Row(
        children: [
          Icon(icon, size: AppScale.s(17), color: AppColors.primaryDark),
          SizedBox(width: AppScale.s(8)),
          Text(label, style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.bold, color: AppColors.foreground)),
          SizedBox(width: AppScale.s(10)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.chevron_right, size: AppScale.s(16), color: AppColors.mutedForeground),
        ],
      ),
    );
  }
}

void _showServiceSheet(BuildContext context, Product product) {
  final notes = product.purchaseNotes
      .split('；')
      .map((e) => e.trim().replaceAll('。', ''))
      .where((e) => e.isNotEmpty)
      .toList();

  Widget group(String title, List<String> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppScale.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
          SizedBox(height: AppScale.s(6)),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: AppScale.s(3)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: AppScale.s(14), color: AppColors.primary),
                  SizedBox(width: AppScale.s(6)),
                  Expanded(child: Text(item, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground, height: 1.45))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  showModalBottomSheet<void>(
    context: context,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(20)))),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(16), AppScale.s(20), AppScale.s(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('服务说明', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground)),
              SizedBox(height: AppScale.s(12)),
              group('配送', ['广州发货，全国包邮', '付款后 48 小时内发货']),
              group('保障', ['官方正品保障', '支持七天无理由退换', '假一赔十']),
              if (notes.isNotEmpty) group('购买须知', notes),
            ],
          ),
        ),
      );
    },
  );
}

/// 规格行：点开购买弹层（和底部按钮共用同一个弹层）。
class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(10), AppScale.s(16), AppScale.s(14)),
      child: AppGestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Text('规格', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.bold, color: AppColors.foreground)),
            SizedBox(width: AppScale.s(10)),
            Expanded(
              child: Text(
                (product.spec != null && product.spec!.isNotEmpty) ? product.spec! : '默认规格',
                style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: AppScale.s(16), color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// 购买弹层：加入购物车与立即购买共用，区别只在确认按钮的去向。
/// 输入：页面 context（关弹层后还要用它跳结算/弹提示，必须用页面那一份）、商品、buyNow。
/// 坑：数量上限跟库存走；售完时整层只给看、不给确认。
void _showPurchaseSheet(BuildContext context, Product product, {required bool buyNow}) {
  final pageContext = context;
  final soldOut = product.stock <= 0;
  final maxQty = soldOut ? 1 : (product.stock > 99 ? 99 : product.stock);
  var quantity = 1;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(20)))),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(16), AppScale.s(20), AppScale.s(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductThumbnail(product: product, width: AppScale.s(72), height: AppScale.s(72), borderRadius: AppScale.s(10), fit: BoxFit.cover),
                      SizedBox(width: AppScale.s(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¥${_priceText(product.price)}',
                              style: TextStyle(fontSize: AppScale.t(19), fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                            SizedBox(height: AppScale.s(4)),
                            Text(
                              soldOut ? '已售完' : '库存 ${product.stock} 件',
                              style: TextStyle(fontSize: AppScale.t(12), color: soldOut ? AppColors.priceRed : AppColors.mutedForeground),
                            ),
                            SizedBox(height: AppScale.s(2)),
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                      AppGestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Icon(Icons.close, size: AppScale.s(20), color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  SizedBox(height: AppScale.s(16)),
                  Text('规格', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                  SizedBox(height: AppScale.s(8)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(7)),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(AppScale.s(8)),
                    ),
                    child: Text(
                      (product.spec != null && product.spec!.isNotEmpty) ? product.spec! : '默认规格',
                      style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600, color: AppColors.secondaryForeground),
                    ),
                  ),
                  SizedBox(height: AppScale.s(16)),
                  Row(
                    children: [
                      Text('数量', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                      const Spacer(),
                      _StepperButton(
                        icon: Icons.remove,
                        enabled: quantity > 1,
                        onTap: () => setSheetState(() => quantity -= 1),
                      ),
                      SizedBox(
                        width: AppScale.s(40),
                        child: Text('$quantity', textAlign: TextAlign.center, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600, color: AppColors.foreground)),
                      ),
                      _StepperButton(
                        icon: Icons.add,
                        enabled: quantity < maxQty,
                        onTap: () => setSheetState(() => quantity += 1),
                      ),
                    ],
                  ),
                  SizedBox(height: AppScale.s(20)),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: soldOut ? null : AppColors.primaryGradient,
                        color: soldOut ? AppColors.muted : null,
                        borderRadius: BorderRadius.circular(AppScale.s(999)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: AppInkWell(
                          onTap: soldOut
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  if (buyNow) {
                                    CheckoutPage.openBuyNow(pageContext, product, quantity: quantity);
                                  } else {
                                    pageContext.read<CartProvider>().addItem(product, quantity: quantity);
                                    showTopSnackBar(
                                      pageContext,
                                      content: Text('已加入购物车', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(AppScale.s(999)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppScale.s(13)),
                            child: Center(
                              child: Text(
                                soldOut ? '已售完' : (buyNow ? '立即购买' : '加入购物车'),
                                style: TextStyle(color: Colors.white, fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: AppScale.s(28),
        height: AppScale.s(28),
        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppScale.s(8))),
        child: Icon(icon, size: AppScale.s(16), color: enabled ? AppColors.foreground : AppColors.mutedForeground),
      ),
    );
  }
}

/// 系列图鉴：同系列全部商品横滑一览，当前这件有「当前」标、买过的有「已拥有」标。
/// 已拥有从我的订单里算（排除已取消）；订单拉不到时就不标，不挡图鉴本身。
class _SeriesSection extends StatefulWidget {
  const _SeriesSection({required this.product});

  final Product product;

  @override
  State<_SeriesSection> createState() => _SeriesSectionState();
}

class _SeriesSectionState extends State<_SeriesSection> {
  Set<String> _ownedIds = const {};
  bool _ownedLoaded = false;

  List<Product> get _seriesProducts {
    final series = widget.product.series;
    if (series == null || series.isEmpty) return const [];
    final list = products.where((p) => p.series == series).toList();
    list.sort((a, b) => b.sales.compareTo(a.sales));
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwned());
  }

  Future<void> _loadOwned() async {
    try {
      final orders = context.read<OrderProvider>();
      if (orders.orders.isEmpty) await orders.loadFromRemote();
      if (!mounted) return;
      final owned = <String>{};
      for (final order in orders.orders) {
        if (order.status == OrderStatus.cancelled) continue;
        for (final item in order.items) {
          final pid = item.productId;
          if (pid != null && pid.isNotEmpty) owned.add(pid);
        }
      }
      setState(() {
        _ownedIds = owned;
        _ownedLoaded = true;
      });
    } catch (_) {
      // 订单没接上就不标已拥有，图鉴照常显示。
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _seriesProducts;
    if (list.length < 2) return const SizedBox.shrink();
    final ownedCount = list.where((p) => _ownedIds.contains(p.id)).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(16), AppScale.s(16), AppScale.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '「${widget.product.series}」系列图鉴',
                  style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '共 ${list.length} 款${_ownedLoaded && ownedCount > 0 ? ' · 已拥有 $ownedCount 款' : ''}',
                style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(12)),
          SizedBox(
            height: AppScale.s(148),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => SizedBox(width: AppScale.s(10)),
              itemBuilder: (context, index) {
                final item = list[index];
                final isSelf = item.id == widget.product.id;
                final owned = _ownedIds.contains(item.id);
                return AppGestureDetector(
                  onTap: isSelf
                      ? null
                      : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(builder: (_) => ProductDetailPage(product: item)),
                          ),
                  child: SizedBox(
                    width: AppScale.s(92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppScale.s(12)),
                                border: isSelf ? Border.all(color: AppColors.primary, width: 2) : null,
                              ),
                              child: ProductThumbnail(
                                product: item,
                                width: AppScale.s(92),
                                height: AppScale.s(92),
                                borderRadius: AppScale.s(12),
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (isSelf || owned)
                              Positioned(
                                left: 0,
                                top: 0,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(2)),
                                  decoration: BoxDecoration(
                                    color: isSelf ? AppColors.primary : AppColors.gold,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(AppScale.s(12)),
                                      bottomRight: Radius.circular(AppScale.s(8)),
                                    ),
                                  ),
                                  child: Text(
                                    isSelf ? '当前' : '已拥有',
                                    style: TextStyle(fontSize: AppScale.t(9), fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: AppScale.s(6)),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppScale.t(11), color: AppColors.foreground),
                        ),
                        SizedBox(height: AppScale.s(2)),
                        Text(
                          '¥${_priceText(item.price)}',
                          style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 评价区：摘要（大分数 + 条数）+ 最新 2 条直接露在主流程里，全部评价点进去看。
/// 评价数据由页面统一拉取后传进来（和价格区的条数共用一份）。
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.product, required this.reviews, required this.hasError});

  final Product product;
  final List<ProductReview>? reviews;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(16), AppScale.s(16), AppScale.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('商品评价', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground)),
              const Spacer(),
              if (reviews != null && reviews!.length > 2)
                AppGestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => _AllReviewsPage(product: product, reviews: reviews!)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('查看全部', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
                      Icon(Icons.chevron_right, size: AppScale.s(15), color: AppColors.mutedForeground),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: AppScale.s(12)),
          if (reviews == null && !hasError)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppScale.s(16)),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else if (hasError)
            Text('评价加载失败', style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground))
          else if (reviews!.isEmpty)
            Text('暂无评价，快来成为第一个评价的人吧～', style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  product.rating.toStringAsFixed(1),
                  style: TextStyle(fontSize: AppScale.t(22), fontWeight: FontWeight.bold, color: AppColors.foreground, height: 1),
                ),
                SizedBox(width: AppScale.s(8)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < product.rating.round() ? Icons.star : Icons.star_border,
                        size: AppScale.s(14),
                        color: AppColors.gold,
                      ),
                  ],
                ),
                SizedBox(width: AppScale.s(8)),
                Text('${reviews!.length} 条评价', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
              ],
            ),
            SizedBox(height: AppScale.s(12)),
            ...reviews!.take(2).map(
                  (review) => Padding(
                    padding: EdgeInsets.only(bottom: AppScale.s(12)),
                    child: ProductReviewCard(review: review),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AllReviewsPage extends StatelessWidget {
  const _AllReviewsPage({required this.product, required this.reviews});

  final Product product;
  final List<ProductReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('全部评价', style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.w600, color: AppColors.foreground)),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppScale.s(16)),
        children: reviews
            .map(
              (review) => Padding(
                padding: EdgeInsets.only(bottom: AppScale.s(12)),
                child: ProductReviewCard(review: review),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 商品详情区：参数表 → 亮点（结构化卖点）→ 商品介绍 → 详情长图。
/// 没填的字段整行/整段跳过，长图为空时不显示（后台补了图自然出现）。
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final params = <(String, String)>[
      if (product.brand != null && product.brand!.isNotEmpty) ('品牌', product.brand!),
      if (product.series != null && product.series!.isNotEmpty) ('系列', product.series!),
      if (product.rarity != null && product.rarity!.isNotEmpty) ('稀有度', product.rarity!),
      if (product.spec != null && product.spec!.isNotEmpty) ('规格', product.spec!),
      ('分类', '${product.majorCategory} · ${product.subCategory}'),
    ];
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(16), AppScale.s(16), AppScale.s(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('商品详情', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold, color: AppColors.foreground)),
          SizedBox(height: AppScale.s(12)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppScale.s(12))),
            child: Column(
              children: [
                for (final (label, value) in params)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(5)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: AppScale.s(52),
                          child: Text(label, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
                        ),
                        Expanded(child: Text(value, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.foreground))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (product.sellingPoints.isNotEmpty) ...[
            SizedBox(height: AppScale.s(16)),
            Text('亮点', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
            SizedBox(height: AppScale.s(8)),
            ...product.sellingPoints.map(
              (point) => Padding(
                padding: EdgeInsets.only(bottom: AppScale.s(6)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: AppScale.s(15), color: AppColors.primary),
                    SizedBox(width: AppScale.s(6)),
                    Expanded(child: Text(point, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.foreground, height: 1.5))),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: AppScale.s(16)),
          Text('商品介绍', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.bold, color: AppColors.foreground)),
          SizedBox(height: AppScale.s(8)),
          Text(product.description, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground, height: 1.6)),
          if (product.detailImages.isNotEmpty) ...[
            SizedBox(height: AppScale.s(16)),
            ...product.detailImages.map(
              (path) => Padding(
                padding: EdgeInsets.only(bottom: AppScale.s(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppScale.s(12)),
                  child: ProductImage(image: path, width: width - AppScale.s(32), fit: BoxFit.fitWidth),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 底部栏：客服 / 收藏 / 购物车（带角标）+ 加入购物车 / 立即购买。
/// 两个购买按钮都先走规格弹层选数量；售完时换成一个置灰的「已售完」。
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().totalCount;
    final soldOut = product.stock <= 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppScale.s(12),
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
          _BarIcon(
            icon: Icons.chat_bubble_outline,
            label: '客服',
            onTap: () => SupportChatPage.openForProduct(
              context,
              productId: product.id,
              productName: product.name,
            ),
          ),
          _BarIcon(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            label: '收藏',
            iconColor: isFavorite ? AppColors.priceRed : AppColors.foreground,
            onTap: onFavorite,
          ),
          _BarIcon(
            icon: Icons.shopping_cart_outlined,
            label: '购物车',
            badgeCount: cartCount,
            onTap: () {
              final tabs = context.read<AppTabProvider>();
              Navigator.popUntil(context, (route) => route.isFirst);
              tabs.goTo(AppTab.cart);
            },
          ),
          SizedBox(width: AppScale.s(6)),
          if (soldOut)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppScale.s(999))),
                child: Center(
                  child: Text('已售完', style: TextStyle(color: AppColors.mutedForeground, fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
                ),
              ),
            )
          else ...[
            Expanded(
              child: AppOutlinedButton(
                onPressed: onAddToCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppScale.s(999))),
                ),
                child: Text('加入购物车', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
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
                  child: AppInkWell(
                    onTap: onBuyNow,
                    borderRadius: BorderRadius.circular(AppScale.s(999)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                      child: Center(
                        child: Text('立即购买', style: TextStyle(color: Colors.white, fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.label, this.onTap, this.iconColor, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppScale.s(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(7), vertical: AppScale.s(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: AppScale.s(24), color: iconColor ?? AppColors.foreground),
                if (badgeCount > 0)
                  Positioned(
                    right: -AppScale.s(7),
                    top: -AppScale.s(5),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(4), vertical: AppScale.s(1)),
                      decoration: BoxDecoration(color: AppColors.priceRed, borderRadius: BorderRadius.circular(AppScale.s(999))),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(color: Colors.white, fontSize: AppScale.t(8), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppScale.s(3)),
            Text(label, style: TextStyle(fontSize: AppScale.t(10), color: AppColors.foreground)),
          ],
        ),
      ),
    );
  }
}
