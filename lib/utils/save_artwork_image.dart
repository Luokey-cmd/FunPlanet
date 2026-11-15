import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import 'media_url.dart';

class SaveArtworkImageException implements Exception {
  SaveArtworkImageException(this.message);
  final String message;

  @override
  String toString() => message;
}

bool get _supportsGallerySave {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
}

Future<void> saveArtworkImageToGallery(String imagePath) async {
  if (!_supportsGallerySave) {
    throw SaveArtworkImageException('保存到相册仅支持 Android / iOS 设备');
  }

  final url = await resolveRemoteMediaUrl(imagePath);
  if (url.isEmpty) {
    throw SaveArtworkImageException('图片地址无效');
  }

  final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
  if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
    throw SaveArtworkImageException('下载图片失败');
  }

  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw SaveArtworkImageException('需要相册权限才能保存');
      }
    }

    final name = 'funplanet_ai_${DateTime.now().millisecondsSinceEpoch}';
    await Gal.putImageBytes(response.bodyBytes, name: name);
  } on MissingPluginException {
    throw SaveArtworkImageException(
      '保存插件未加载，请完全退出 App 后重新执行：flutter clean → flutter pub get → flutter run',
    );
  }
}
