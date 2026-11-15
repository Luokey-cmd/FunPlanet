import 'package:flutter/material.dart';
import '../theme/app_scale.dart';

void showTopSnackBar(
  BuildContext context, {
  required Widget content,
  Color backgroundColor = const Color(0xFF16A34A),
  Duration duration = const Duration(seconds: 3),
}) {
  final mq = MediaQuery.of(context);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      duration: duration,
      dismissDirection: DismissDirection.up,
      margin: EdgeInsets.only(
        bottom: mq.size.height - mq.padding.top - AppScale.s(80) - AppScale.s(16),
        left: AppScale.s(16),
        right: AppScale.s(16),
      ),
      content: content,
    ),
  );
}
