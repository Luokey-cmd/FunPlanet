import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'click_effect_host.dart';

/// 按下缩放 + 可选粒子。
/// 通栏矮按钮/列表行允许动效；大卡片/整页热区跳过。
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.86,
    this.includeSemantics = true,
    this.enableParticle = true,
    this.enableHaptic = false,
  });

  final Widget child;
  final bool enabled;
  final double scale;
  final bool includeSemantics;
  final bool enableParticle;
  final bool enableHaptic;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  Offset? _downPos;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  bool _shouldScale(Size? size) {
    if (!ClickEffectController.effectsEnabled) return false;
    if (size == null) return true;
    // 仅跳过接近整页的热区；商品卡允许轻缩放
    if (size.height >= 360) return false;
    if (size.width * size.height >= 140000) return false;
    return true;
  }

  bool _shouldParticle(Size? size) {
    if (!widget.enableParticle || !ClickEffectController.effectsEnabled) return false;
    if (size == null) return false;
    // 通栏矮控件/按钮可粒子；商品卡等高区域只缩放
    if (size.height > 100) return false;
    if (size.width * size.height > 56000) return false;
    return true;
  }

  void _burstFromCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (!_shouldParticle(box?.size)) return;
    ClickEffectController.instance.burstFromWidget(
      context,
      color: AppColors.primaryLight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (!_shouldScale(box?.size)) return;
        _downPos = event.position;
        _setPressed(true);
        _burstFromCenter();
        if (widget.enableHaptic) {
          HapticFeedback.selectionClick();
        }
      },
      onPointerMove: (event) {
        if (_downPos == null) return;
        if ((event.position - _downPos!).distance > 12) {
          _downPos = null;
          _setPressed(false);
        }
      },
      onPointerUp: (_) {
        _downPos = null;
        _setPressed(false);
      },
      onPointerCancel: (_) {
        _downPos = null;
        _setPressed(false);
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 40)
            : const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// 输入框聚焦：轻微放大 + 一次中心粒子（监听子树焦点，不抢输入）。
class AppFocusable extends StatefulWidget {
  const AppFocusable({
    super.key,
    required this.child,
    this.enableParticle = true,
    this.focusedScale = 1.02,
  });

  final Widget child;
  final bool enableParticle;
  final double focusedScale;

  @override
  State<AppFocusable> createState() => _AppFocusableState();
}

class _AppFocusableState extends State<AppFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
        if (focused && widget.enableParticle && ClickEffectController.effectsEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ClickEffectController.instance.burstFromWidget(
              context,
              color: AppColors.primaryLight,
            );
          });
        }
      },
      child: AnimatedScale(
        scale: _focused && ClickEffectController.effectsEnabled ? widget.focusedScale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// 带聚焦动效的 TextField。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.enableInteractiveSelection,
    this.inputFormatters,
    this.enableParticle = true,
    this.focusedScale = 1.02,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool? enabled;
  final bool readOnly;
  final bool autofocus;
  final TextAlign textAlign;
  final bool? enableInteractiveSelection;
  final List<TextInputFormatter>? inputFormatters;
  final bool enableParticle;
  final double focusedScale;

  @override
  Widget build(BuildContext context) {
    return AppFocusable(
      enableParticle: enableParticle,
      focusedScale: focusedScale,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: decoration,
        style: style,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        enabled: enabled,
        readOnly: readOnly,
        autofocus: autofocus,
        textAlign: textAlign,
        enableInteractiveSelection: enableInteractiveSelection,
        inputFormatters: inputFormatters,
      ),
    );
  }
}

class AppGestureDetector extends StatelessWidget {
  const AppGestureDetector({
    super.key,
    this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.behavior,
    this.excludeFromSemantics = false,
    this.enablePressScale = true,
    this.enableParticle = true,
  });

  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
  final HitTestBehavior? behavior;
  final bool excludeFromSemantics;
  final bool enablePressScale;
  final bool enableParticle;

  @override
  Widget build(BuildContext context) {
    final detector = GestureDetector(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      behavior: behavior,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
    if (!enablePressScale || onTap == null) return detector;
    return AppPressable(
      enableParticle: enableParticle,
      child: detector,
    );
  }
}

class AppInkWell extends StatelessWidget {
  const AppInkWell({
    super.key,
    this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.borderRadius,
    this.customBorder,
    this.splashColor,
    this.highlightColor,
    this.overlayColor,
    this.enablePressScale = true,
    this.enableParticle = true,
  });

  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onDoubleTap;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? splashColor;
  final Color? highlightColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final bool enablePressScale;
  final bool enableParticle;

  @override
  Widget build(BuildContext context) {
    final ink = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      borderRadius: borderRadius,
      customBorder: customBorder,
      splashColor: splashColor,
      highlightColor: highlightColor,
      overlayColor: overlayColor,
      child: child,
    );
    if (!enablePressScale || onTap == null) return ink;
    return AppPressable(
      enableParticle: enableParticle,
      child: ink,
    );
  }
}
