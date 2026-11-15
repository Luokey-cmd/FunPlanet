import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 参考 QuickClipboard：局部合成层粒子；空闲停 Ticker，绝不整树 setState。
class ClickEffectController extends ChangeNotifier {
  ClickEffectController._();
  static final ClickEffectController instance = ClickEffectController._();

  /// 对齐 peduliAI / QC：可一键关掉全部点击粒子。
  static bool effectsEnabled = true;

  final List<ClickBurst> _bursts = [];
  List<ClickBurst> get bursts => _bursts;

  void burstAt(Offset globalCenter, {Color? color}) {
    if (!effectsEnabled) return;
    final burst = ClickBurst(
      id: DateTime.now().microsecondsSinceEpoch ^ _bursts.length,
      center: globalCenter,
      color: color ?? const Color(0xFF60A5FA),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _bursts.add(burst);
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      _bursts.removeWhere((b) => b.id == burst.id);
      notifyListeners();
    });
  }

  void burstFromWidget(BuildContext context, {Color? color}) {
    if (!effectsEnabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    burstAt(box.localToGlobal(box.size.center(Offset.zero)), color: color);
  }
}

class ClickBurst {
  ClickBurst({
    required this.id,
    required this.center,
    required this.color,
    required this.createdAtMs,
  }) : particles = List.generate(12, (i) {
          final rand = math.Random(id + i);
          return ClickParticle(
            angleDeg: i * 30.0 + rand.nextDouble() * 12.0,
            distance: 22.0 + rand.nextDouble() * 18.0,
            size: 5.5 + rand.nextDouble() * 3.0,
          );
        });

  final int id;
  final Offset center;
  final Color color;
  final int createdAtMs;
  final List<ClickParticle> particles;
}

class ClickParticle {
  const ClickParticle({
    required this.angleDeg,
    required this.distance,
    required this.size,
  });

  final double angleDeg;
  final double distance;
  final double size;
}

/// 挂在 MaterialApp.builder：child 用 RepaintBoundary 隔离；粒子只靠 repaint 通知重绘。
class ClickEffectHost extends StatefulWidget {
  const ClickEffectHost({super.key, required this.child});

  final Widget child;

  @override
  State<ClickEffectHost> createState() => _ClickEffectHostState();
}

class _ClickEffectHostState extends State<ClickEffectHost> with SingleTickerProviderStateMixin {
  final _controller = ClickEffectController.instance;
  final _paintTick = ValueNotifier<int>(0);
  late final Ticker _ticker;
  final _paint = Paint()..style = PaintingStyle.fill;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _paintTick.value++);
    _controller.addListener(_onBurstsChanged);
  }

  void _onBurstsChanged() {
    final has = _controller.bursts.isNotEmpty;
    if (has) {
      if (!_ticker.isActive) _ticker.start();
      _paintTick.value++;
    } else if (_ticker.isActive) {
      _ticker.stop();
      _paintTick.value++;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.removeListener(_onBurstsChanged);
    _paintTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.child),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ClickBurstPainter(
                controller: _controller,
                paintTick: _paintTick,
                sharedPaint: _paint,
                hostContext: context,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClickBurstPainter extends CustomPainter {
  _ClickBurstPainter({
    required this.controller,
    required this.paintTick,
    required this.sharedPaint,
    required this.hostContext,
  }) : super(repaint: Listenable.merge([controller, paintTick]));

  final ClickEffectController controller;
  final ValueNotifier<int> paintTick;
  final Paint sharedPaint;
  final BuildContext hostContext;

  @override
  void paint(Canvas canvas, Size size) {
    final bursts = controller.bursts;
    if (bursts.isEmpty) return;

    final hostBox = hostContext.findRenderObject() as RenderBox?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final burst in bursts) {
      final t = ((nowMs - burst.createdAtMs) / 420.0).clamp(0.0, 1.0);
      if (t >= 1.0) continue;
      final origin = hostBox != null && hostBox.hasSize
          ? hostBox.globalToLocal(burst.center)
          : burst.center;
      final eased = Curves.easeOutCubic.transform(t);

      for (final p in burst.particles) {
        final travel = p.distance * (t < 0.5 ? (t / 0.5) : (1.0 + 0.5 * ((t - 0.5) / 0.5)));
        final scale = t < 0.5 ? (1.0 + 0.3 * (t / 0.5)) : (1.3 - 1.0 * ((t - 0.5) / 0.5));
        final opacity = t < 0.5 ? 1.0 : ((1.0 - eased) * 0.9 + 0.1 * (1 - t)).clamp(0.0, 1.0);
        final rad = p.angleDeg * math.pi / 180.0;
        sharedPaint.color = burst.color.withValues(alpha: opacity);
        canvas.drawCircle(
          origin + Offset(math.sin(rad) * travel, -math.cos(rad) * travel),
          p.size * scale.clamp(0.2, 1.4) / 2,
          sharedPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClickBurstPainter oldDelegate) => false;
}
