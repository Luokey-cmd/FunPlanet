import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../pages/checkout_page.dart';
import '../pages/product_detail_page.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_image.dart';

/// 亮牌牌板（2026-11-23 改版 v2，hx 定稿）：
/// - 三张牌是**竖排宽卡**，一张一行，造型参考开场动画最后一格那张牌
///   （奶油底、金边、图装进画框、价格缎带、星星评分、双按钮）；
/// - 牌面**不带任何表面特效**：全息噪点、眩光、星尘一律不要，
///   装饰只靠边框和排版，字必须看得清（旧版深紫全息牌面被否）；
/// - **入场不翻**：牌直接以明牌出现（只留 200ms 淡入防硬闪），
///   没有牌背、没有「点开」；
/// - **翻转只在点选时**：点中哪张，哪张整圈旋转 + 放大（约 0.48 秒），
///   随即进详情页；用的是转牌动画的语言，与开场动画结尾呼应。
/// 批次切换由外层（XiaodouFateSection）换 key 重建本组件。
class XiaodouFateBoard extends StatelessWidget {
  const XiaodouFateBoard({
    super.key,
    required this.products,
    this.traits = const {},
  });

  final List<Product> products;

  /// 商品 id -> 特点句（服务端按真实数据算死，如「卖得最火，已售 1200 件」）。
  final Map<String, String> traits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppScale.s(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0) SizedBox(height: AppScale.s(16)),
            _FadeIn(
              delay: Duration(milliseconds: i * 70),
              child: _FateWideCard(
                product: products[i],
                trait: traits[products[i].id],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 入场淡入（不是翻牌）：透明度 0→1 + 上移 6px 收住，200ms。
/// 只做防硬闪的抛光，牌从第一帧就是明牌。
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    // 延迟用控制器自己的延迟启动：forward 延后调用即可，
    // 组件销毁时控制器一并 dispose，未启动的延时回调靠 mounted 守卫。
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = Curves.easeOut.transform(_ctrl.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _FateWideCard extends StatefulWidget {
  const _FateWideCard({required this.product, this.trait});

  final Product product;

  /// 服务端算好的特点句（可空：老消息没有时用商品字段现拼事实行）。
  final String? trait;

  @override
  State<_FateWideCard> createState() => _FateWideCardState();
}

class _FateWideCardState extends State<_FateWideCard> with SingleTickerProviderStateMixin {
  // 点选转牌：整圈旋转（2π）+ 放大到 1.16 倍，约 0.48 秒；
  // 转完牌面正好转回正面且已放大，详情页用淡入接住，观感连成一气。
  // 坑：动画没跑完就重复点会叠两次导航，_turning 守卫挡住。
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  bool _turning = false;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _turnAndOpen() async {
    if (_turning) return;
    _turning = true;
    await _turn.forward();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, _, _) => ProductDetailPage(product: widget.product),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) {
      _turn.reset();
      _turning = false;
    }
  }

  /// 特点句拆分：服务端格式是「短词，整句」（如「口碑最好，评分 4.8」），
  /// 短词进胶囊、整句作事实行；没有逗号的（兜底格式）不挂胶囊、整句照用。
  (String?, String) _splitTrait() {
    final trait = widget.trait;
    final product = widget.product;
    if (trait == null || trait.isEmpty) {
      return (null, '已售 ${product.sales} 件 · 评分 ${product.rating.toStringAsFixed(1)}');
    }
    final idx = trait.indexOf('，');
    if (idx > 0 && idx <= 5) {
      return (trait.substring(0, idx), trait);
    }
    return (null, trait);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final (pill, fact) = _splitTrait();
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, child) {
        final v = _turn.value;
        final angle = v * math.pi * 2;
        final scale = 1 + 0.16 * v;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle)
            ..scaleByDouble(scale, scale, scale, 1),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _turnAndOpen,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFAF0), Color(0xFFFFF5E2)],
            ),
            borderRadius: BorderRadius.circular(AppScale.s(18)),
            border: Border.all(color: const Color(0xFFD9A94F), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF966E1E).withValues(alpha: 0.13),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.all(AppScale.s(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _framedArtwork(),
                        SizedBox(width: AppScale.s(11)),
                        Expanded(child: _infoColumn(pill, fact)),
                      ],
                    ),
                    SizedBox(height: AppScale.s(11)),
                    _buttons(context),
                  ],
                ),
              ),
              // 四角小星饰 + 顶部正中爱心宝石：对动画牌框的简化引用，
              // 只点缀边框、不碰牌面内容区（特效口径：装饰靠边框）。
              for (final align in const [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: align,
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.s(4)),
                    child: Icon(
                      Icons.auto_awesome,
                      size: AppScale.s(9),
                      color: const Color(0xFFD9A94F),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, -AppScale.s(8)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppScale.s(7),
                      vertical: AppScale.s(1),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD9A94F), width: 1.5),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: AppScale.s(10),
                      color: const Color(0xFF8A5FD6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 商品图装进金色画框：有图裁剪填满，无图用商品色块 + 图标兜底。
  Widget _framedArtwork() {
    final product = widget.product;
    return Container(
      width: AppScale.s(102),
      height: AppScale.s(102),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: const Color(0xFFE7C87E), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppScale.s(10)),
        child: product.imagePath.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      product.imageColor ?? AppColors.secondary,
                      Color.lerp(
                            product.imageColor ?? AppColors.secondary,
                            AppColors.primaryLight,
                            0.3,
                          ) ??
                          AppColors.primaryLight,
                    ],
                  ),
                ),
                child: product.imageIcon == null
                    ? null
                    : Center(
                        child: Icon(
                          product.imageIcon,
                          size: AppScale.s(34),
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
              )
            : LayoutBuilder(
                builder: (context, c) => ProductImage(
                  image: product.imagePath,
                  width: c.maxWidth,
                  height: c.maxHeight,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  Widget _infoColumn(String? pill, String fact) {
    final product = widget.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 价格缎带（照动画那张的粉红缎带）：现价粗体 + 原价划线。
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppScale.s(10),
                vertical: AppScale.s(3),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7D9C), Color(0xFFFF5F8F)],
                ),
                borderRadius: BorderRadius.circular(AppScale.s(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _priceText(product.price),
                    style: TextStyle(
                      fontSize: AppScale.t(15),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (product.originalPrice != null &&
                      product.originalPrice! > product.price) ...[
                    SizedBox(width: AppScale.s(4)),
                    Text(
                      _priceText(product.originalPrice!),
                      style: TextStyle(
                        fontSize: AppScale.t(10),
                        color: Colors.white.withValues(alpha: 0.85),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (pill != null) ...[
              SizedBox(width: AppScale.s(7)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppScale.s(8),
                  vertical: AppScale.s(3),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFCDBCF5)),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    fontSize: AppScale.t(10.5),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: AppScale.s(5)),
        // 星星评分行：实星/半星/空星按评分画，后跟「评分 · 已售」。
        Row(
          children: [
            ..._stars(product.rating),
            SizedBox(width: AppScale.s(5)),
            Text(
              '${product.rating.toStringAsFixed(1)} · 已售 ${product.sales}',
              style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground),
            ),
          ],
        ),
        SizedBox(height: AppScale.s(3)),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppScale.t(14.5),
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: AppScale.s(2)),
        Text(
          fact,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppScale.t(11),
            height: 1.35,
            color: AppColors.mutedForeground,
          ),
        ),
        if (product.spec != null && product.spec!.isNotEmpty) ...[
          SizedBox(height: AppScale.s(2)),
          Text(
            '规格：${product.spec}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }

  // 评分画星：满 1 分一颗实星，零头 ≥0.3 给半星，其余空星；输出 5 颗。
  List<Widget> _stars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.3;
    return [
      for (var i = 0; i < 5; i++)
        Icon(
          i < full
              ? Icons.star
              : (i == full && half ? Icons.star_half : Icons.star_border),
          size: AppScale.s(13),
          color: const Color(0xFFF5A623),
        ),
    ];
  }

  // 底部双按钮（照动画那张）：加购走购物车 + 顶部提示，购买走快捷结算。
  // 按钮是牌身 GestureDetector 的子手势，点击会先命中按钮、不会触发转牌。
  Widget _buttons(BuildContext context) {
    final product = widget.product;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CartProvider>().addItem(product);
              showTopSnackBar(
                context,
                content: Text(
                  '已加入购物车',
                  style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD9E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: AppScale.s(15),
                    color: const Color(0xFFD6336C),
                  ),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '加入购物车',
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD6336C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: AppScale.s(9)),
        Expanded(
          child: GestureDetector(
            onTap: () => CheckoutPage.openBuyNow(context, product),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A5FD6), AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: AppScale.s(15), color: Colors.white),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '立即购买',
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 价格文案与旧牌面同口径：整数不带小数，非整数保留两位。
  String _priceText(double price) =>
      '¥${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
}
