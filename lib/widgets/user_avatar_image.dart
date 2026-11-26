import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import 'app_network_image.dart';

bool isAssetAvatarPath(String path) => path.startsWith('assets/');

bool isBundledAssetAvatarPath(String path) {
  return isAssetAvatarPath(path) && !path.contains('/user-avatars/');
}

bool isRemoteAvatarPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return false;
  if (p.startsWith('http://') || p.startsWith('https://')) return true;
  return p.contains('/user-avatars/');
}

class UserAvatarImage extends StatelessWidget {
  const UserAvatarImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) {
      return _wrap(_placeholder());
    }

    if (isRemoteAvatarPath(path)) {
      return _wrap(
        FutureBuilder<String>(
          future: resolveRemoteMediaUrl(path),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _placeholder();
            }
            return AppNetworkImage(
              url: snapshot.data!,
              width: width,
              height: height,
              fit: fit,
              placeholder: _placeholder(),
              errorWidget: _placeholder(),
            );
          },
        ),
      );
    }

    // 解码尺寸上限（2026-11-27 闪退教训）：本地大照片按原尺寸解码
    // 一张就是一两百 MB 内存，会被系统杀掉。按显示宽度×像素密度
    // 解码、上限 1024，肉眼看不出差别；没给宽度时按 256 解码
    // （头像出现的地方都是小尺寸）。网络头像走 AppNetworkImage，
    // 那边自有口径，不走这里。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width == null
        ? 256
        : (width! * dpr).round().clamp(64, 1024);

    final Widget image;
    if (isBundledAssetAvatarPath(path)) {
      image = Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    } else {
      image = Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return _wrap(image);
  }

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
        ),
        child: ClipRRect(borderRadius: borderRadius!, child: child),
      );
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.muted,
      alignment: Alignment.center,
      child: Icon(Icons.person_outline, color: AppColors.mutedForeground, size: AppScale.s(24)),
    );
  }
}
