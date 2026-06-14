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
  });

  final Product product;
  final double? width;
  final double? height;
  final double? borderRadius;
  final bool showIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = width ?? double.infinity;
    final h = height ?? AppScale.s(120);
    final radius = borderRadius ?? AppScale.s(12);
    final bgColor = product.imageColor ?? AppColors.secondary;

    if (product.imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: w,
          height: h,
          color: Colors.white,
          alignment: Alignment.center,
          child: ProductImage(
            image: product.imagePath,
            width: w == double.infinity ? null : w,
            height: h,
            fit: fit,
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
