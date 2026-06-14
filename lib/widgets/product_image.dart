import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return _wrap(_buildImage());
  }

  Widget _buildImage() {
    final path = image.trim();
    if (path.isEmpty) return _placeholder();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _networkImage(path);
    }

    if (path.startsWith('assets/')) {
      return FutureBuilder<String>(
        future: resolveRemoteMediaUrl(path),
        builder: (context, snapshot) {
          final url = snapshot.data ?? '';
          if (url.isNotEmpty) {
            return _networkImage(url, fallbackAsset: path);
          }
          return _assetImage(path);
        },
      );
    }

    return _assetImage(path);
  }

  Widget _networkImage(String url, {String? fallbackAsset}) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        if (fallbackAsset != null) return _assetImage(fallbackAsset);
        return _placeholder();
      },
    );
  }

  Widget _assetImage(String path) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.muted,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: AppColors.mutedForeground, size: AppScale.s(20)),
    );
  }
}
