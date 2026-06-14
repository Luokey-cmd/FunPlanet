import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

/// 漂流瓶背后的光晕与闪烁装饰，仅作用于瓶身区域。
class DriftBottleBackdrop extends StatefulWidget {
  const DriftBottleBackdrop({super.key, required this.bottleHeight});

  final double bottleHeight;

  @override
  State<DriftBottleBackdrop> createState() => _DriftBottleBackdropState();
}

class _DriftBottleBackdropState extends State<DriftBottleBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _sparkles = [
    _SparkleSpec(-0.42, -0.18, 10, 0.00, AppColors.gold),
    _SparkleSpec(0.38, -0.28, 8, 0.18, AppColors.primaryLight),
    _SparkleSpec(0.48, 0.12, 9, 0.35, AppColors.accent),
    _SparkleSpec(-0.28, 0.22, 7, 0.52, AppColors.primary),
    _SparkleSpec(0.08, -0.38, 6, 0.68, Colors.white),
    _SparkleSpec(-0.12, -0.42, 5, 0.82, AppColors.gold),
    _SparkleSpec(0.22, 0.32, 8, 0.45, AppColors.accent),
    _SparkleSpec(-0.10, -0.52, 9, 0.12, AppColors.gold),
    _SparkleSpec(0.14, -0.58, 8, 0.58, AppColors.accent),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = AppScale.s(widget.bottleHeight);
    final w = h * 1.55;

    return IgnorePointer(
      child: SizedBox(
        width: w,
        height: h * 1.15,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _GlowOrb(width: w * 0.92, height: h * 0.78, pulse: t),
                _GlowOrb(
                  width: w * 0.55,
                  height: h * 0.48,
                  pulse: t,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.16),
                    AppColors.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  phase: 0.35,
                ),
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: w * (0.18 + i * 0.18),
                    top: h * (0.08 + (i.isEven ? 0.04 : 0.18)),
                    child: _BubbleDot(
                      size: AppScale.s(5 + i.toDouble()),
                      opacity: 0.18 + 0.22 * math.sin((t + i * 0.21) * math.pi * 2),
                    ),
                  ),
                for (final s in _sparkles)
                  Positioned(
                    left: w * (0.5 + s.dx) - AppScale.s(s.size) / 2,
                    top: h * (0.5 + s.dy) - AppScale.s(s.size) / 2,
                    child: Opacity(
                      opacity: 0.25 + 0.55 * ((math.sin((t + s.phase) * math.pi * 2) + 1) / 2),
                      child: Transform.rotate(
                        angle: (t + s.phase) * math.pi * 2,
                        child: _TwinkleStar(size: AppScale.s(s.size), color: s.color),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: h * 0.08,
                  child: Opacity(
                    opacity: 0.22 + 0.12 * math.sin(t * math.pi * 2),
                    child: Container(
                      width: w * 0.62,
                      height: AppScale.s(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppScale.s(999)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.width,
    required this.height,
    required this.pulse,
    this.colors,
    this.phase = 0,
  });

  final double width;
  final double height;
  final double pulse;
  final List<Color>? colors;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final scale = 0.94 + 0.06 * math.sin((pulse + phase) * math.pi * 2);
    final gradientColors = colors ??
        [
          AppColors.primary.withValues(alpha: 0.22),
          AppColors.primaryLight.withValues(alpha: 0.10),
          AppColors.accent.withValues(alpha: 0.04),
          Colors.transparent,
        ];
    final stops = List<double>.generate(
      gradientColors.length,
      (i) => i / (gradientColors.length - 1),
    );
    return Transform.scale(
      scale: scale,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: gradientColors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}

class _BubbleDot extends StatelessWidget {
  const _BubbleDot({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: opacity * 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: opacity * 0.35),
            blurRadius: size * 0.8,
          ),
        ],
      ),
    );
  }
}

class _TwinkleStar extends StatelessWidget {
  const _TwinkleStar({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(color: color)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.28, cy - r * 0.28)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + r * 0.28, cy + r * 0.28)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.28, cy + r * 0.28)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - r * 0.28, cy - r * 0.28)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => oldDelegate.color != color;
}

class _SparkleSpec {
  const _SparkleSpec(this.dx, this.dy, this.size, this.phase, this.color);

  final double dx;
  final double dy;
  final double size;
  final double phase;
  final Color color;
}
