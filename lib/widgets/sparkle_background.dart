import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 全页渐变底：上淡紫 → 下白
class SparkleBackground extends StatelessWidget {
  const SparkleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageGradient),
        ),
        child,
      ],
    );
  }
}
