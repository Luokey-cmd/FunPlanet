import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

/// 循环首尾淡入淡出，避免 repeat 跳变闪烁
double _loopFadeOpacity(double t, {double fadePortion = 0.06}) {
  if (t < fadePortion) {
    return Curves.easeInOut.transform(t / fadePortion);
  }
  if (t > 1 - fadePortion) {
    return Curves.easeInOut.transform((1 - t) / fadePortion);
  }
  return 1.0;
}

/// 登录/注册页动态背景：流动渐变、波浪光带、潮玩符号随流漂浮
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageGradient),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final opacity = _loopFadeOpacity(t);
            return Opacity(
              opacity: opacity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _AuthBgPainter(t: t),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  IgnorePointer(child: _AuthFloatLayer(t: t)),
                ],
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _AuthFloatLayer extends StatelessWidget {
  const _AuthFloatLayer({required this.t});

  final double t;

  static const _items = [
    _FloatSpec(Icons.auto_awesome_rounded, AppColors.primary, 0.10, 0.14, 26, 0.00),
    _FloatSpec(Icons.favorite_rounded, AppColors.accent, 0.86, 0.12, 22, 0.25),
    _FloatSpec(Icons.star_rounded, AppColors.gold, 0.78, 0.72, 24, 0.55),
    _FloatSpec(Icons.extension_rounded, AppColors.primaryLight, 0.08, 0.68, 28, 0.40),
    _FloatSpec(Icons.emoji_emotions_rounded, AppColors.tagHot, 0.92, 0.48, 20, 0.70),
    _FloatSpec(Icons.diamond_rounded, AppColors.secondaryForeground, 0.18, 0.42, 18, 0.85),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            for (final item in _items)
              Positioned(
                left: _flowX(w, item.fx, item.phase, t),
                top: _flowY(h, item.fy, item.phase, t),
                child: Transform.rotate(
                  angle: math.sin((t * 2 + item.phase) * math.pi * 2) * 0.12,
                  child: Opacity(
                    opacity: 0.20 + 0.10 * math.sin((t * 3 + item.phase) * math.pi * 2),
                    child: Container(
                      width: AppScale.s(item.size + 16),
                      height: AppScale.s(item.size + 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.55),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.18),
                            blurRadius: AppScale.s(14),
                          ),
                        ],
                      ),
                      child: Icon(item.icon, size: AppScale.s(item.size), color: item.color),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _flowX(double w, double fx, double phase, double t) {
    final drift = ((t * 0.35 + phase) % 1.0) * 2 - 1;
    return w * fx + drift * AppScale.s(28) + math.sin((t + phase) * math.pi * 2) * AppScale.s(8);
  }

  double _flowY(double h, double fy, double phase, double t) {
    return h * fy + math.sin((t * 1.6 + phase) * math.pi * 2) * AppScale.s(14);
  }
}

class _FloatSpec {
  const _FloatSpec(this.icon, this.color, this.fx, this.fy, this.size, this.phase);

  final IconData icon;
  final Color color;
  final double fx;
  final double fy;
  final double size;
  final double phase;
}

class _AuthBgPainter extends CustomPainter {
  _AuthBgPainter({required this.t});

  final double t;

  static const _sparkles = [
    (0.06, 0.22, 2.2, 0.0),
    (0.22, 0.08, 1.8, 0.15),
    (0.38, 0.18, 2.6, 0.32),
    (0.55, 0.06, 1.6, 0.48),
    (0.72, 0.20, 2.0, 0.62),
    (0.90, 0.28, 2.4, 0.78),
    (0.14, 0.52, 1.7, 0.12),
    (0.30, 0.62, 2.3, 0.28),
    (0.48, 0.55, 1.5, 0.44),
    (0.66, 0.58, 2.1, 0.58),
    (0.84, 0.50, 1.9, 0.72),
    (0.08, 0.82, 2.0, 0.88),
    (0.26, 0.88, 1.6, 0.05),
    (0.52, 0.78, 2.5, 0.22),
    (0.74, 0.86, 1.8, 0.38),
    (0.94, 0.76, 2.2, 0.52),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawBaseGradient(canvas, size);
    _drawFlowWaves(canvas, size);
    _drawFlowRibbons(canvas, size);
    _drawFlowStreams(canvas, size);
    _drawFlowingOrbs(canvas, size);
    _drawSparkles(canvas, size);
    _drawBottomGlow(canvas, size);
  }

  void _drawBaseGradient(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shift = math.sin(t * math.pi * 2) * 0.15;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + shift, -1),
          end: Alignment(1 - shift, 1),
          colors: const [
            Color(0xFFE8DEFF),
            Color(0xFFF5E8FF),
            Color(0xFFFFF5FA),
            Colors.white,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(rect),
    );
  }

  void _drawFlowWaves(Canvas canvas, Size size) {
    final layers = [
      (AppColors.primary, 0.18, 0.07, 1.4, 0.00, 0.14),
      (AppColors.accent, 0.32, 0.05, 1.8, 0.33, 0.11),
      (AppColors.primaryLight, 0.48, 0.06, 1.2, 0.55, 0.10),
      (AppColors.secondaryForeground, 0.62, 0.04, 2.0, 0.72, 0.08),
    ];

    for (final layer in layers) {
      final path = _wavePath(
        size,
        baseY: size.height * layer.$2,
        amplitude: size.height * layer.$3,
        frequency: layer.$4,
        phase: t * math.pi * 2 + layer.$5,
        thickness: size.height * 0.22,
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, size.height * layer.$2),
            Offset(size.width, size.height * (layer.$2 + 0.2)),
            [
              layer.$1.withValues(alpha: 0.0),
              layer.$1.withValues(alpha: layer.$6),
              layer.$1.withValues(alpha: 0.0),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
    }
  }

  Path _wavePath(
    Size size, {
    required double baseY,
    required double amplitude,
    required double frequency,
    required double phase,
    required double thickness,
  }) {
    double waveY(double x) {
      return baseY +
          math.sin((x / size.width) * math.pi * 2 * frequency + phase) * amplitude +
          math.sin((x / size.width) * math.pi * 4 + phase * 0.7) * amplitude * 0.35;
    }

    final path = Path()..moveTo(-size.width * 0.05, waveY(-size.width * 0.05));
    for (var x = -size.width * 0.05; x <= size.width * 1.05; x += 6) {
      path.lineTo(x, waveY(x));
    }
    for (var x = size.width * 1.05; x >= -size.width * 0.05; x -= 6) {
      path.lineTo(x, waveY(x) + thickness);
    }
    path.close();
    return path;
  }

  void _drawFlowRibbons(Canvas canvas, Size size) {
    final ribbons = [
      (AppColors.primary, 0.22, 0.0),
      (AppColors.accent, 0.38, 0.45),
      (AppColors.gold, 0.55, 0.72),
    ];

    for (final ribbon in ribbons) {
      final path = _ribbonPath(size, yFactor: ribbon.$2, phase: t + ribbon.$3, thickness: size.height * 0.09);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height * ribbon.$2),
            [
              ribbon.$1.withValues(alpha: 0.0),
              ribbon.$1.withValues(alpha: 0.20),
              ribbon.$1.withValues(alpha: 0.14),
              ribbon.$1.withValues(alpha: 0.0),
            ],
            [0.0, 0.3, 0.7, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  Path _ribbonPath(Size size, {required double yFactor, required double phase, required double thickness}) {
    double curveY(double x) {
      final nx = x / size.width;
      return size.height * yFactor +
          math.sin(nx * math.pi * 3 + phase * math.pi * 2) * size.height * 0.07 +
          math.cos(nx * math.pi * 2 - phase * math.pi * 1.5) * size.height * 0.04;
    }

    final path = Path()..moveTo(-size.width * 0.08, curveY(-size.width * 0.08));
    for (var x = -size.width * 0.08; x <= size.width * 1.08; x += 5) {
      path.lineTo(x, curveY(x));
    }
    for (var x = size.width * 1.08; x >= -size.width * 0.08; x -= 5) {
      path.lineTo(x, curveY(x) + thickness);
    }
    path.close();
    return path;
  }

  void _drawFlowStreams(Canvas canvas, Size size) {
    final streams = [
      (AppColors.primaryLight, 0.16, 0.28, 0.0),
      (AppColors.accent, 0.34, 0.22, 0.35),
      (AppColors.primary, 0.52, 0.26, 0.62),
    ];

    for (final stream in streams) {
      final progress = (t * stream.$3 + stream.$4) % 1.0;
      final bandW = size.width * 0.75;
      final x = -bandW + progress * (size.width + bandW);
      final rect = Rect.fromLTWH(x, size.height * stream.$2, bandW, size.height * 0.07);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.topRight,
            [
              stream.$1.withValues(alpha: 0.0),
              stream.$1.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.12),
              stream.$1.withValues(alpha: 0.18),
              stream.$1.withValues(alpha: 0.0),
            ],
            [0.0, 0.25, 0.5, 0.75, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  void _drawFlowingOrbs(Canvas canvas, Size size) {
    final orbs = [
      (AppColors.primary, 0.0, 0.30),
      (AppColors.accent, 0.33, 0.26),
      (AppColors.primaryLight, 0.55, 0.28),
      (AppColors.gold, 0.72, 0.24),
    ];

    for (final orb in orbs) {
      final flow = (t + orb.$2) % 1.0;
      final cx = size.width * (0.1 + flow * 0.8) +
          math.sin(flow * math.pi * 4) * size.width * 0.06;
      final cy = size.height * (0.15 + orb.$2 * 0.55) +
          math.sin(flow * math.pi * 2 + orb.$2) * size.height * 0.08;
      final radius = size.width * orb.$3;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              orb.$1.withValues(alpha: 0.32),
              orb.$1.withValues(alpha: 0.10),
              orb.$1.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _sparkles) {
      final flicker = 0.35 + 0.65 * ((math.sin((t * 2 + s.$4) * math.pi * 2) + 1) / 2);
      final drift = math.sin((t + s.$4) * math.pi * 2) * size.width * 0.02;
      paint.color = Colors.white.withValues(alpha: 0.12 + 0.50 * flicker);
      final cx = size.width * s.$1 + drift;
      final cy = size.height * s.$2 + math.cos((t + s.$4) * math.pi * 2) * AppScale.s(6);
      final r = AppScale.s(s.$3);
      _drawStar(canvas, Offset(cx, cy), r, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
    }
    canvas.drawPath(path, paint..strokeWidth = AppScale.s(1.2)..style = PaintingStyle.stroke);
    canvas.drawCircle(center, r * 0.35, paint..style = PaintingStyle.fill);
  }

  void _drawBottomGlow(Canvas canvas, Size size) {
    final sweep = (t * 0.5) % 1.0;
    final rect = Rect.fromLTWH(-size.width * 0.2, size.height * 0.58, size.width * 1.4, size.height * 0.42);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * sweep, size.height * 0.58),
          Offset(size.width * (sweep + 0.6), size.height),
          [
            Colors.transparent,
            AppColors.secondary.withValues(alpha: 0.16),
            AppColors.accentSoft.withValues(alpha: 0.14),
            Colors.transparent,
          ],
          [0.0, 0.35, 0.65, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AuthBgPainter oldDelegate) => oldDelegate.t != t;
}
