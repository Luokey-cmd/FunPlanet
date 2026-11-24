import 'package:flutter/material.dart';
import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'product_image.dart';

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.product,
    this.width,
    this.height,
    this.borderRadius,
    this.showIcon = true,
    this.fit = BoxFit.contain,
    // 详情页图集翻页时传当前图；不传就用商品主图，其他页面行为不变。
    this.imagePathOverride,
  });

  final Product product;
  final double? width;
  final double? height;
  final double? borderRadius;
  final bool showIcon;
  final BoxFit fit;
  final String? imagePathOverride;

  @override
  Widget build(BuildContext context) {
    final w = width ?? double.infinity;
    final h = height ?? AppScale.s(120);
    final radius = borderRadius ?? AppScale.s(12);
    final bgColor = product.imageColor ?? AppColors.secondary;
    final displayPath = imagePathOverride ?? product.imagePath;

    if (displayPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: w,
          height: h,
          color: Colors.white,
          // 这里绝不能加 alignment 居中：居中会把尺寸约束放松，图片组件
          // 会按照片自身比例缩成居中的小方块，fit（cover/contain）写了也
          // 不生效、圆角裁切也裁不到照片本体（2026-11-24 实锤：卡片图改
          // cover 后仍是居中方图、直角，就是栽在这行居中上）。不加居中时
          // 图片拿到整个框的紧约束，fit 才真正决定铺满裁切还是完整显示。
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxW = width ??
                  (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
              // 展示口径（2026-11-24 hx 定稿）：照片完整显示、不裁不拉，
              // 以框的短边为边长在框中央摆一个正方形，照片在方框里铺满
              // （商品图本就是方形，等于整张摆出来），方框自带圆角裁切——
              // 圆的是照片本身的四个角；方框外留白是卡片底色，属于设计
              // 的一部分。此前误改成照片铺满整个宽框（cover 裁掉上下），
              // hx 明确不要，已改回。
              final side = boxW == null ? h : (boxW < h ? boxW : h);
              return Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: ProductImage(
                    image: displayPath,
                    width: side,
                    height: side,
                    fit: fit,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            Color.lerp(bgColor, AppColors.primaryLight, 0.3)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -AppScale.s(10),
            bottom: -AppScale.s(10),
            child: Container(
              width: AppScale.s(60),
              height: AppScale.s(60),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          if (showIcon && product.imageIcon != null)
            Center(
              child: Icon(
                product.imageIcon,
                size: (h * 0.35).clamp(AppScale.s(28), AppScale.s(48)),
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
}

class BannerVisual extends StatelessWidget {
  const BannerVisual({super.key, required this.banner, this.scale = 1.0});

  final BannerItem banner;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => AppScale.s(value * scale);
    return SizedBox.expand(
      child: Image.asset(
        banner.imagePath,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.secondary,
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined, size: s(40), color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}
