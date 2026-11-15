import 'package:flutter/material.dart';

import 'app_pressable.dart';

class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: onPressed != null,
      enableParticle: true,
      child: FilledButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        child: child,
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: onPressed != null,
      scale: 0.86,
      enableParticle: true,
      child: TextButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        child: child,
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: onPressed != null,
      enableParticle: true,
      child: OutlinedButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        child: child,
      ),
    );
  }
}
