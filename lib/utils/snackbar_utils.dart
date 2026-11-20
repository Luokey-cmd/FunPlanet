import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_scale.dart';

/// 顶部绿色提示条专用字号（不加 fontBump，保持紧凑）。
TextStyle topSnackBarTextStyle({FontWeight weight = FontWeight.w600}) => TextStyle(
      color: Colors.white,
      fontSize: AppScale.s(12),
      fontWeight: weight,
      height: 1.25,
    );

void showTopSnackBar(
  BuildContext context, {
  required Widget content,
  Color backgroundColor = const Color(0xFF16A34A),
  Duration duration = const Duration(seconds: 3),
}) {
  final mq = MediaQuery.of(context);
  // 键盘占位要扣掉，否则 bottom margin 按全屏算，floating SnackBar 会断言出屏。
  final availableHeight = mq.size.height - mq.viewInsets.bottom;
  final topOffset = mq.padding.top + AppScale.s(16);
  final barReserve = AppScale.s(56);
  final bottomMargin = math.max(0.0, availableHeight - topOffset - barReserve);

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      duration: duration,
      dismissDirection: DismissDirection.up,
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        left: AppScale.s(16),
        right: AppScale.s(16),
      ),
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(16), vertical: AppScale.s(12)),
      content: DefaultTextStyle(
        style: topSnackBarTextStyle(),
        child: content,
      ),
    ),
  );
}
