import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 点击粒子控制器：只通知“有哪些 burst”，具体动画在局部小图层里跑。
class ClickEffectController extends ChangeNotifier {
  ClickEffectController._();
  static final ClickEffectController instance = ClickEffectController._();

  /// 对齐 peduliAI / QC：可一键关掉全部点击粒子。
  static bool effectsEnabled = true;

  static const int maxConcurrentBursts = 3;
  static const Duration burstDuration = Duration(milliseconds: 280);
  static const int particleCount = 8;
  static const double burstRadius = 56;

  final List<ClickBurst> _bursts = [];
  List<ClickBurst> get bursts => _bursts;

  void burstAt(Offset globalCenter, {Color? color}) {
    if (!effectsEnabled) return;

    // 叠太多时丢掉最旧的，避免连点把帧预算打满。
    while (_bursts.length >= maxConcurrentBursts) {
      _bursts.removeAt(0);
    }

    final burst = ClickBurst(
      id: DateTime.now().microsecondsSinceEpoch ^ (_bursts.length * 9973),
      globalCenter: globalCenter,
      color: color ?? const Color(0xFF60A5FA),
    );
    _bursts.add(burst);
    notifyListeners();
  }

  void burstFromWidget(BuildContext context, {Color? color}) {
    if (!effectsEnabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    burstAt(box.localToGlobal(box.size.center(Offset.zero)), color: color);
  }

  void removeBurst(int id) {
    final before = _bursts.length;
    _bursts.removeWhere((b) => b.id == id);
    if (_bursts.length != before) notifyListeners();
  }
}

class ClickBurst {
  ClickBurst({
    required this.id,
    required this.globalCenter,
    required this.color,
  }) : particles = List<ClickParticle>.generate(ClickEffectController.particleCount, (i) {
          final rand = math.Random(id + i * 17);
          final angle = (i / ClickEffectController.particleCount) * math.pi * 2 + rand.nextDouble() * 0.35;
          return ClickParticle(
            dirX: math.cos(angle),
            dirY: math.sin(angle),
            distance: 18.0 + rand.nextDouble() * 16.0,
            size: 4.5 + rand.nextDouble() * 2.5,
          );
        });

  final int id;
  final Offset globalCenter;
  final Color color;
  final List<ClickParticle> particles;
}

class ClickParticle {
  const ClickParticle({
    required this.dirX,
    required this.dirY,
    required this.distance,
    required this.size,
  });

  final double dirX;
  final double dirY;
  final double distance;
  final double size;
}

/// 挂在 MaterialApp.builder：业务树与粒子层互相隔离；每个 burst 只脏一小块区域。
class ClickEffectHost extends StatefulWidget {
  const ClickEffectHost({super.key, required this.child});

  final Widget child;

  @override
  State<ClickEffectHost> createState() => _ClickEffectHostState();
}

class _ClickEffectHostState extends State<ClickEffectHost> {
  final _controller = ClickEffectController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onBurstsChanged);
  }

  void _onBurstsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onBurstsChanged);
    super.dispose();
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.globalToLocal(global);
    }
    return global;
  }

  @override
  Widget build(BuildContext context) {
    final bursts = _controller.bursts;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.child),
        if (bursts.isNotEmpty)
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final burst in bursts)
                  _BurstLayer(
                    key: ValueKey(burst.id),
                    localCenter: _toLocal(burst.globalCenter),
                    burst: burst,
                    onFinished: () => _controller.removeBurst(burst.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({
    super.key,
    required this.localCenter,
    required this.burst,
    required this.onFinished,
  });

  final Offset localCenter;
  final ClickBurst burst;
  final VoidCallback onFinished;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _t;

  static const _extent = ClickEffectController.burstRadius * 2;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: ClickEffectController.burstDuration,
    );
    _t = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.localCenter;
    return Positioned(
      left: center.dx - ClickEffectController.burstRadius,
      top: center.dy - ClickEffectController.burstRadius,
      width: _extent,
      height: _extent,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(_extent, _extent),
              painter: _BurstPainter(
                progress: _t.value,
                burst: widget.burst,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.burst,
  });

  final double progress;
  final ClickBurst burst;

  static final _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final origin = Offset(size.width * 0.5, size.height * 0.5);
    final t = progress;
    // 前半冲出，后半减速淡出；算子保持简单，避免每粒子 Curves 查表。
    final travelFactor = t < 0.55 ? (t / 0.55) : (1.0 + 0.28 * ((t - 0.55) / 0.45));
    final scale = t < 0.45 ? (1.0 + 0.25 * (t / 0.45)) : (1.25 * (1.0 - (t - 0.45) / 0.55)).clamp(0.15, 1.25);
    final opacity = t < 0.4 ? 1.0 : (1.0 - (t - 0.4) / 0.6).clamp(0.0, 1.0);

    _paint.color = burst.color.withValues(alpha: opacity);
    for (final p in burst.particles) {
      final travel = p.distance * travelFactor;
      canvas.drawCircle(
        origin + Offset(p.dirX * travel, p.dirY * travel),
        p.size * scale * 0.5,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.burst.id != burst.id;
  }
}
