import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';

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
            return Image.network(
              snapshot.data!,
              width: width,
              height: height,
              fit: fit,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            );
          },
        ),
      );
    }

    final Widget image;
    if (isBundledAssetAvatarPath(path)) {
      image = Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
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
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return _wrap(image);
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
      child: Icon(Icons.person_outline, color: AppColors.mutedForeground, size: AppScale.s(24)),
    );
  }
}
