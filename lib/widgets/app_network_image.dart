import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 带磁盘缓存的网络图片：首次联网下载，之后优先读本地缓存，避免反复空白闪烁。
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = _cachePx(width, dpr);
    final memH = _cachePx(height, dpr);
    final fallback = placeholder ??
        SizedBox(
          width: width?.isFinite == true ? width : null,
          height: height?.isFinite == true ? height : null,
          child: const ColoredBox(color: Color(0xFFE8E8E8)),
        );

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      // 与本地图同一条规矩：解码尺寸只给一个方向，宽高都给会被硬拉变形。
      memCacheWidth: memW,
      memCacheHeight: memW == null ? memH : null,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => errorWidget ?? fallback,
    );
  }

  static int? _cachePx(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round().clamp(1, 4096);
  }
}
