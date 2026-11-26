import 'package:flutter/services.dart';

/// 系统分享：走 MainActivity 的 funplanet/share 通道拉起 Android 原生
/// 分享面板（微信/QQ/复制链接等由系统列出），不引第三方插件。
///
/// 返回 true = 分享面板真的弹出来了；false = 当前平台没有这个通道
/// （比如 iOS 还没接），调用方自己兜底（复制到剪贴板）。
class ShareService {
  static const MethodChannel _channel = MethodChannel('funplanet/share');

  static Future<bool> shareText(String text) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', {'text': text});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
