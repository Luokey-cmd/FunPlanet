import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import 'app_network_image.dart';

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
    return _wrap(context, _buildImage(context));
  }

  Widget _buildImage(BuildContext context) {
    final path = image.trim();
    if (path.isEmpty) return _placeholder();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _networkImage(path);
    }

    // 打包进 App 的商品图直接读本地，避免切页时 FutureBuilder/网络图反复空白闪烁。
    if (path.startsWith('assets/')) {
      return _assetImage(context, path);
    }

    // 上传图等相对路径仍走后端地址解析。
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data ?? '';
        if (url.isNotEmpty) return _networkImage(url);
        return _placeholder();
      },
    );
  }

  Widget _networkImage(String url, {Widget? fallback}) {
    final placeholder = fallback ?? _placeholder();
    return AppNetworkImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }

  Widget _assetFallback(String path) {
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data ?? '';
        if (url.isEmpty) return _placeholder();
        return _networkImage(url);
      },
    );
  }

  Widget _assetImage(BuildContext context, String path) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = _cachePx(width, dpr);
    final cacheH = _cachePx(height, dpr);
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: (context, error, stackTrace) => _assetFallback(path),
    );
  }

  Widget _wrap(BuildContext context, Widget child) {
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

  static int? _cachePx(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round().clamp(1, 2048);
  }
}
