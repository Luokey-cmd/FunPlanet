// ============================================================
// 中文日志工具（App 版）
// 输入：模块名（中文标签，如 '购物车'）+ 一句人话说明；报错时可再
//       附原始错误对象。没有返回值。
// 输出（只在调试模式下）：【购物车】加入购物车：星尘徽章
//       hx 在 Android Studio 下方的控制台里搜【购物车】，就能只
//       看购物车相关的日志。
// 规则：
// - 只在调试模式（kDebugMode）打印；正式打包的版本自动沉默，
//   不给用户看、也不拖慢 App。
// - 报错走 error()：中文说明在前，错误原文附在后面——hx 看中文
//   就懂，复制给 AI 定位时原文也在。
// 坑：密码、token 绝不打进日志；接口只打路径，不打请求内容。
// ============================================================

import 'package:flutter/foundation.dart';

class AppLog {
  AppLog._();

  /// 业务事件：发生了什么事（登录成功、加入购物车、选好图片……）
  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('【$tag】$message');
  }

  /// 报错：中文说明在前，错误原文附后
  static void error(String tag, String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint('【$tag】$message${error == null ? '' : '（原文：$error）'}');
  }
}
