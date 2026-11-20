import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'click_effect_host.dart';

/// 按下缩放 + 松手回弹 + 可选粒子。
/// 通栏矮按钮/列表行允许动效；大卡片/整页热区跳过。
/// 手感对齐参考项目 QuickClipboard：按下只轻缩到 0.95，松手时跑一遍
/// 0.5 秒的弹簧回弹（先弹出 1.08 再衰减振荡回 1），粒子也在松手时才爆。
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.enabled = true,
    // 参考实现按下是 0.95（开关）~0.98（侧栏按钮）；旧默认 0.86 缩得太狠，像被压扁。
    this.scale = 0.95,
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

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  Offset? _downPos;

  // 松手回弹的动画控制器：500ms 一遍，曲线见 _ButtonBounceCurve。
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  // 松手时播回弹：与粒子同一时刻触发，眼睛看到的是「弹一下 + 星星散开」一整套。
  // 大卡片/整页热区不播（与缩放同一道闸门 _shouldScale）。
  void _playBounce() {
    if (!ClickEffectController.effectsEnabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (!_shouldScale(box?.size)) return;
    _bounce.forward(from: 0);
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
        // 注意：粒子不在这里爆。按下时手指还压在控件上，爆了也被挡住；
        // 参考实现是桌面端 click（≈松手）触发，搬到触屏必须跟着改到松手。
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
        // 只有「在控件内按下、没滑出去取消」的松手才算一次完整点击，爆粒子+回弹。
        final wasPressed = _downPos != null;
        _downPos = null;
        _setPressed(false);
        if (wasPressed && widget.enabled) {
          _burstFromCenter();
          _playBounce();
        }
      },
      onPointerCancel: (_) {
        _downPos = null;
        _setPressed(false);
      },
      // 两层缩放相乘：外层管按下轻缩（110ms 平滑进出，不再瞬时跳变），
      // 内层管松手回弹（500ms 关键帧振荡）。旧版是瞬时 1↔0.86 硬切，所以显得廉价。
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final t = _bounce.value;
            // 教训（2026-11-20 登录按钮文字消失）：Flutter 的 Curve.transform(0)
            // 有端点捷径、直接返回 0，不走 transformInternal。静止时控制器值就是 0，
            // 拿它当缩放会把内容缩成 0。所以端点必须手动归 1，只在动画中段用曲线值。
            final scale = (t <= 0.0 || t >= 1.0)
                ? 1.0
                : const _ButtonBounceCurve().transform(t);
            return Transform.scale(scale: scale, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

// 松手回弹曲线：逐点照搬参考项目 QuickClipboard 的 buttonBounce 关键帧
// （0.5s：先弹大到 1.08，再 0.96 → 1.04 → 0.98 → 1，像果冻一样衰减振荡两下停住）。
// 输入是动画进度 0~1，输出是缩放倍数；首尾都是 1.0，静止时不影响布局。
class _ButtonBounceCurve extends Curve {
  const _ButtonBounceCurve();

  static const _points = <(double, double)>[
    (0.0, 1.0),
    (0.30, 1.08),
    (0.50, 0.96),
    (0.70, 1.04),
    (0.85, 0.98),
    (1.0, 1.0),
  ];

  @override
  double transformInternal(double t) {
    if (t <= 0 || t >= 1) return 1.0;
    for (var i = 1; i < _points.length; i++) {
      final (x1, y1) = _points[i];
      if (t <= x1) {
        final (x0, y0) = _points[i - 1];
        final u = (t - x0) / (x1 - x0);
        return y0 + (y1 - y0) * u;
      }
    }
    return 1.0;
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
      // 聚焦放大改为 200ms 平滑过渡（旧版瞬时跳变，与按下缩放同一个毛病）。
      child: AnimatedScale(
        scale: _focused && ClickEffectController.effectsEnabled ? widget.focusedScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
