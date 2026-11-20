import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 点击粒子控制器：只通知“有哪些 burst”，具体动画在局部小图层里跑。
class ClickEffectController extends ChangeNotifier {
  ClickEffectController._();
  static final ClickEffectController instance = ClickEffectController._();

  /// 对齐 peduliAI / QC：可一键关掉全部点击粒子。
  static bool effectsEnabled = true;

  static const int maxConcurrentBursts = 3;

  // 爆发时长 600ms：对齐参考项目 QuickClipboard 的 particleExplosion（0.6s）。
  // 旧版只有 280ms，粒子一闪而过，眼睛还没看清形状就结束了，是「不像」的主因之一。
  static const Duration burstDuration = Duration(milliseconds: 600);
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
            // 基础距离 14~26px（参考实现是 15~25px）；飞行后半段还会再漂到 1.5 倍，
            // 实际散开范围约 21~39px，紧凑不散漫。
            distance: 14.0 + rand.nextDouble() * 12.0,
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
    // 缓动对齐参考实现：cubic-bezier(0.25, 0.46, 0.45, 0.94)，出得快、收得缓。
    // 旧版 easeOutCubic 叠加画笔里的分段系数等于双重缓动，粒子前半程就冲完、后半程冻住。
    _t = CurvedAnimation(parent: _anim, curve: const Cubic(0.25, 0.46, 0.45, 0.94));
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
    // 逐段照搬参考实现 particleExplosion 的三段关键帧（0% / 50% / 100%）：
    // 前半段：飞到 1.0 倍距离，个头从 1 长到 1.3，透明度只从 1 降到 0.9（几乎不淡）；
    // 后半段：继续往外漂到 1.5 倍距离，个头缩到 0.3，透明度才一路淡到 0。
    // 关键是后半段「还在往外漂、慢慢消失」，旧版后半段几乎原地冻住直接淡没，所以显得急。
    final double travelFactor;
    final double scale;
    final double opacity;
    if (t < 0.5) {
      final u = t / 0.5;
      travelFactor = u;
      scale = 1.0 + 0.3 * u;
      opacity = 1.0 - 0.1 * u;
    } else {
      final u = (t - 0.5) / 0.5;
      travelFactor = 1.0 + 0.5 * u;
      scale = 1.3 - 1.0 * u;
      opacity = 0.9 * (1.0 - u);
    }

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
