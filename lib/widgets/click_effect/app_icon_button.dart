import 'package:flutter/material.dart';

import 'app_pressable.dart';

/// 带按下缩放的 IconButton（粒子由全局层触发）。
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize,
    this.padding,
    this.constraints,
    this.splashRadius,
    this.visualDensity,
    this.style,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double? splashRadius;
  final VisualDensity? visualDensity;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      color: color,
      iconSize: iconSize,
      padding: padding,
      constraints: constraints,
      splashRadius: splashRadius,
      visualDensity: visualDensity,
      style: style,
    );
    if (onPressed == null) return button;
    return AppPressable(scale: 0.82, enableParticle: true, child: button);
  }
}
