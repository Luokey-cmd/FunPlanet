import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// 全息卡引擎：按 poke-holo（simeydotme）的交互模型与光配方移植到 Flutter。
// 关键参数（与演示版一致，hz 2026-11-17 定版）：
// - 倾斜角 = 指针偏离中心 / 3.5，最大约 ±14 度
// - 跟随弹簧 stiffness 0.042 / damping 0.21（慢韵律版）
// - 闪膜背景层只在 37%~63% / 33%~67% 的窄范围内挪动
// - 松手延迟 500ms 后以 0.01 / 0.06 的极软弹簧慢漂回位
// - 点击放大时的整圈旋转用 0.016 / 0.30 的弹簧，约 2~3 秒转完一圈

enum HoloRarity { silver, gold, cosmos }

extension HoloRarityProps on HoloRarity {
  Color get glow {
    switch (this) {
      case HoloRarity.silver:
        return const Color(0xFF9DB8E8);
      case HoloRarity.gold:
        return const Color(0xFFF5C65C);
      case HoloRarity.cosmos:
        return const Color(0xFFC07DFF);
    }
  }

  Color get border {
    switch (this) {
      case HoloRarity.silver:
        return const Color(0xFFCED8EB);
      case HoloRarity.gold:
        return const Color(0xFFFFCE69);
      case HoloRarity.cosmos:
        return const Color(0xFFE0A0FF);
    }
  }
}

/// 单值弹簧，复刻 Svelte spring 的逐帧积分模型
/// （加速度 = stiffness * 位移 - damping * 速度）。
class _Spring1 {
  _Spring1(this.value) : last = value, target = value;

  double value;
  double last;
  double target;
  double stiffness = 0.05;
  double damping = 0.24;

  void set(double t, {double? k, double? d}) {
    target = t;
    if (k != null) stiffness = k;
    if (d != null) damping = d;
  }

  bool get settled =>
      (target - value).abs() < 0.005 && (value - last).abs() < 0.005;

  void tick() {
    final delta = target - value;
    final vel = value - last;
    final acc = stiffness * delta - damping * vel;
    final step = vel + acc;
    last = value;
    if (step.abs() < 0.005 && delta.abs() < 0.005) {
      value = target;
    } else {
      value += step;
    }
  }
}

/// 噪点颗粒纹理（银卡闪膜用），运行时生成一次，全局共享，不占安装包。
class _NoiseTex {
  static ui.Image? image;
  static bool _started = false;
  static final List<VoidCallback> _waiters = [];

  static void ensure(VoidCallback onReady) {
    if (image != null) return;
    _waiters.add(onReady);
    if (_started) return;
    _started = true;
    const size = 128;
    final bytes = Uint8List(size * size * 4);
    final rnd = math.Random(42);
    for (var i = 0; i < size * size; i++) {
      final v = rnd.nextInt(256);
      bytes[i * 4] = v;
      bytes[i * 4 + 1] = v;
      bytes[i * 4 + 2] = v;
      bytes[i * 4 + 3] = 255;
    }
    ui.decodeImageFromPixels(bytes, size, size, ui.PixelFormat.rgba8888, (img) {
      image = img;
      final cbs = List<VoidCallback>.from(_waiters);
      _waiters.clear();
      for (final cb in cbs) {
        cb();
      }
    });
  }
}

double _clampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

/// 光层画笔：按稀有度配方逐层绘制（混合模式与 CSS 版一一对应）。
class _HoloPainter extends CustomPainter {
  _HoloPainter({
    required this.rarity,
    required this.bgX,
    required this.bgY,
    required this.glareX,
    required this.glareY,
    required this.opacity,
    required this.hyp,
    required this.artRect,
    required this.radius,
    required this.noise,
  });

  final HoloRarity rarity;
  final double bgX; // 37..63
  final double bgY; // 33..67
  final double glareX; // 0..100
  final double glareY; // 0..100
  final double opacity; // 0..1
  final double hyp; // 指针离中心距离 0..1
  final Rect? artRect; // 金卡光柱裁剪窗口（商品图区域）
  final double radius;
  final ui.Image? noise;

  Color _a(Color c, double f) =>
      c.withValues(alpha: _clampD(c.a * opacity * f, 0, 1));

  Paint _layer(BlendMode mode) => Paint()..blendMode = mode;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    // 商品图窗挖空：全息/眩光不叠到图上，避免变色挡看图。
    if (artRect != null) {
      final hole = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addRect(artRect!);
      canvas.clipPath(hole);
    }
    switch (rarity) {
      case HoloRarity.gold:
        _paintGold(canvas, size, rect);
        break;
      case HoloRarity.silver:
        _paintSilver(canvas, size, rect);
        break;
      case HoloRarity.cosmos:
        _paintCosmos(canvas, size, rect);
        break;
    }
    _paintGlare(canvas, size);
    canvas.restore();
  }

  // Rare Holo：竖直彩虹光柱 + 条纹 + 光斑（绕开商品图窗）。
  void _paintGold(Canvas canvas, Size size, Rect rect) {
    final bf = (hyp + 0.7) * 0.7; // 他源码里的亮度公式
    final w = size.width;
    final h = size.height;
    // 1) 色相光柱（16 段色相与黑条交替，周期 64）
    final barColors = <Color>[];
    final barStops = <double>[];
    for (var i = 0; i < 16; i++) {
      final hueColor = HSLColor.fromAHSL(1, i * 21.0, 0.7, 0.5).toColor();
      final s0 = (2 * i) / 64;
      final s1 = (2 * i + 2) / 64;
      barColors.add(_a(hueColor, bf));
      barStops.add(s0);
      barColors.add(_a(hueColor, bf));
      barStops.add(s1);
      barColors.add(_a(const Color(0xFF000000), bf));
      barStops.add(s1);
      barColors.add(_a(const Color(0xFF000000), bf));
      barStops.add(math.min(1, s1 + 2 / 64));
    }
    var p = _layer(BlendMode.softLight);
    p.shader = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(64, 0),
      barColors,
      barStops,
      TileMode.repeated,
    );
    canvas.drawRect(rect, p);
    // 2) 彩虹渐变（相位随背景层大幅滑动）
    final phase = (bgX - 50) * w * 0.11;
    p = _layer(BlendMode.softLight);
    p.shader = ui.Gradient.linear(
      Offset(-w + phase, 0),
      Offset(w + phase, 0),
      [
        _a(const Color(0xFFC929F1), bf),
        _a(const Color(0xFF0DBDE9), bf),
        _a(const Color(0xFF21E985), bf),
        _a(const Color(0xFFEEDF10), bf),
        _a(const Color(0xFFF80E7B), bf),
        _a(const Color(0xFFC929F1), bf),
      ],
      const [0, 0.2, 0.4, 0.6, 0.8, 1],
      TileMode.repeated,
    );
    canvas.drawRect(rect, p);
    // 3) 光束条纹 A
    _beams(
      canvas,
      rect,
      w * 1.1,
      -bgX * 1.2,
      bgY / 100 * h * 0.2,
      BlendMode.screen,
      0.9 * bf,
    );
    // 4) 光束条纹 B
    _beams(
      canvas,
      rect,
      w * 0.95,
      -bgX / 100 * w * 0.5,
      -bgY / 100 * h * 0.5,
      BlendMode.overlay,
      0.8 * bf,
    );
    // 5) 指针光斑（farthest-corner 径向）
    final center = Offset(glareX / 100 * w, glareY / 100 * h);
    final r = _farthestCorner(center, size);
    p = _layer(BlendMode.srcOver);
    p.shader = ui.Gradient.radial(
      center,
      r,
      [
        _a(const Color(0xFFE6E6E6), 0.85 * bf),
        _a(const Color(0xFFC8C8C8), 0.1 * bf),
        _a(const Color(0xFF000000), 0.9 * bf),
      ],
      const [0, 0.25, 0.9],
    );
    canvas.drawRect(rect, p);
  }

  void _beams(
    Canvas canvas,
    Rect rect,
    double period,
    double offX,
    double offY,
    BlendMode mode,
    double strength,
  ) {
    final colors = [
      _a(const Color(0xFF0A0A0A), strength),
      _a(const Color(0xFF0A0A0A), strength),
      _a(const Color(0x99FFFFFF), strength),
      _a(const Color(0xFF0A0A0A), strength),
      _a(const Color(0x99FFFFFF), strength),
      _a(const Color(0xFF0A0A0A), strength),
      _a(const Color(0xFF0A0A0A), strength),
    ];
    const stops = [0.0, 48 / 288, 72 / 288, 84 / 288, 96 / 288, 120 / 288, 1.0];
    final p = _layer(mode);
    p.shader = ui.Gradient.linear(
      Offset(offX, offY),
      Offset(offX + period, offY),
      colors,
      stops,
      TileMode.repeated,
    );
    canvas.drawRect(rect, p);
  }

  // Rare Holo V：噪点颗粒 + 横向彩虹细纹 + 133 度蚀刻线。
  void _paintSilver(Canvas canvas, Size size, Rect rect) {
    final w = size.width;
    final h = size.height;
    // 1) 颗粒
    if (noise != null) {
      canvas.saveLayer(
        rect,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity * 0.55),
      );
      final p = _layer(BlendMode.screen);
      p.shader = ImageShader(
        noise!,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
      canvas.drawRect(rect, p);
      canvas.restore();
    }
    // 2) 彩虹细纹（沿 Y 方向的色带）
    final period = h * 0.7;
    final offY = (bgY - 50) * 4;
    var p = _layer(BlendMode.hue);
    p.shader = ui.Gradient.linear(
      Offset(0, offY),
      Offset(0, offY + period),
      [
        _a(const Color(0xFFFF7773), 0.85),
        _a(const Color(0xFFFFED5F), 0.85),
        _a(const Color(0xFFA8FF5F), 0.85),
        _a(const Color(0xFF83FFF7), 0.85),
        _a(const Color(0xFF7894FF), 0.85),
        _a(const Color(0xFFD875FF), 0.85),
        _a(const Color(0xFFFF7773), 0.85),
      ],
      const [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
      TileMode.repeated,
    );
    canvas.drawRect(rect, p);
    // 3) 蚀刻斜线（133 度）
    final ep = _layer(BlendMode.hardLight);
    final eOff = Offset((bgX - 50) * 0.6, (bgY - 50) * 0.6);
    ep.shader = ui.Gradient.linear(
      Offset(eOff.dx, h + eOff.dy),
      Offset(eOff.dx + 34, h + eOff.dy - 34),
      [
        _a(const Color(0xFF0E152E), 0.7),
        _a(const Color(0xFF0E152E), 0.7),
        _a(HSLColor.fromAHSL(1, 180, 0.10, 0.60).toColor(), 0.7),
        _a(HSLColor.fromAHSL(1, 180, 0.29, 0.66).toColor(), 0.7),
        _a(const Color(0xFF0E152E), 0.7),
        _a(const Color(0xFF0E152E), 0.7),
      ],
      const [0, 0.62, 0.74, 0.86, 0.92, 1],
      TileMode.repeated,
    );
    canvas.drawRect(rect, ep);
    // 4) 指针处暗色径向（压暗中心，突出边缘光）
    final center = Offset(glareX / 100 * w, glareY / 100 * h);
    final rp = _layer(BlendMode.srcOver);
    rp.shader = ui.Gradient.radial(
      center,
      _farthestCorner(center, size),
      [
        _a(const Color(0xFF000000), 0.10),
        _a(const Color(0xFF000000), 0.15),
        _a(const Color(0xFF000000), 0.25),
      ],
      const [0.12, 0.2, 1],
    );
    canvas.drawRect(rect, rp);
  }

  // Rare Rainbow：大彩虹条纹（-20 度）+ 交叉蚀刻线（130 度）。
  void _paintCosmos(Canvas canvas, Size size, Rect rect) {
    final w = size.width;
    final h = size.height;
    final bf = hyp * 0.25 + 0.66; // 他源码里的亮度公式
    final center = Offset(glareX / 100 * w, glareY / 100 * h);
    // 1) 粉彩光晕
    var p = _layer(BlendMode.srcOver);
    p.shader = ui.Gradient.radial(
      center,
      _farthestCorner(center, size),
      [
        _a(const Color(0xFFFFBEFA), 0.35 * bf),
        _a(const Color(0xFF9678FF), 0.12 * bf),
        _a(const Color(0xFF9678FF), 0),
      ],
      const [0, 0.4, 0.75],
    );
    canvas.drawRect(rect, p);
    // 2) 彩虹条纹（-20 度）
    final axis = Offset(math.cos(-0.349) * w * 1.6, math.sin(-0.349) * w * 1.6);
    final start = Offset(
      -((bgY - 50) * 1.5) * 0.94,
      -((bgY - 50) * 1.5) * -0.34,
    );
    p = _layer(BlendMode.softLight);
    p.shader = ui.Gradient.linear(
      start,
      start + axis,
      [
        _a(const Color(0xFFFD4741), bf),
        _a(const Color(0xFFFFF397), bf),
        _a(const Color(0xFFA8FF5F), bf),
        _a(const Color(0xFF83FFF7), bf),
        _a(const Color(0xFF4BC6FF), bf),
        _a(const Color(0xFFFF49F6), bf),
        _a(const Color(0xFFFF3831), bf),
      ],
      const [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
      TileMode.repeated,
    );
    canvas.drawRect(rect, p);
    // 3) 蚀刻交叉线（130 度）
    final ep = _layer(BlendMode.hardLight);
    final eOff = Offset((bgX - 50) * 0.5, (bgY - 50) * 0.5);
    ep.shader = ui.Gradient.linear(
      Offset(eOff.dx, eOff.dy),
      Offset(eOff.dx + 26, eOff.dy + 31),
      [
        _a(const Color(0x80592E50), 0.8 * bf),
        _a(HSLColor.fromAHSL(1, 118, 0.43, 0.76).toColor(), 0.8 * bf),
        _a(const Color(0xFFDF60CA), 0.8 * bf),
        _a(HSLColor.fromAHSL(1, 180, 0.57, 0.56).toColor(), 0.8 * bf),
        _a(const Color(0x800E152E), 0.8 * bf),
      ],
      const [0, 0.3, 0.5, 0.7, 1],
      TileMode.repeated,
    );
    canvas.drawRect(rect, ep);
  }

  // 镜面反光（所有稀有度共用，farthest-side 径向，overlay 混合）。
  void _paintGlare(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(glareX / 100 * w, glareY / 100 * h);
    final r = math.max(
      math.max(center.dx, w - center.dx),
      math.max(center.dy, h - center.dy),
    );
    final p = _layer(BlendMode.overlay);
    p.shader = ui.Gradient.radial(
      center,
      r,
      [
        _a(const Color(0xCCFFFFFF), 1),
        _a(const Color(0xCCFFFFFF), 1),
        _a(const Color(0xA6FFFFFF), 1),
        _a(const Color(0x80000000), 1),
        _a(const Color(0x80000000), 1),
      ],
      const [0, 0.1, 0.2, 0.9, 1],
    );
    canvas.drawRect(Offset.zero & size, p);
  }

  double _farthestCorner(Offset c, Size s) {
    var m = 0.0;
    for (final corner in [
      Offset.zero,
      Offset(s.width, 0),
      Offset(0, s.height),
      Offset(s.width, s.height),
    ]) {
      m = math.max(m, (c - corner).distance);
    }
    return m;
  }

  @override
  bool shouldRepaint(covariant _HoloPainter old) =>
      old.bgX != bgX ||
      old.bgY != bgY ||
      old.glareX != glareX ||
      old.glareY != glareY ||
      old.opacity != opacity ||
      old.hyp != hyp ||
      old.noise != noise ||
      old.rarity != rarity ||
      old.artRect != artRect;
}

Widget _holoOverlay({
  required HoloRarity rarity,
  required double bgX,
  required double bgY,
  required double glareX,
  required double glareY,
  required double opacity,
  required Size size,
  required Rect? artWindow,
  required double radius,
}) {
  final dx = (glareX - 50) / 50;
  final dy = (glareY - 50) / 50;
  Rect? artRect;
  if (artWindow != null && size.width > 0 && size.height > 0) {
    artRect = Rect.fromLTRB(
      artWindow.left * size.width,
      artWindow.top * size.height,
      artWindow.right * size.width,
      artWindow.bottom * size.height,
    );
  }
  return Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(
        painter: _HoloPainter(
          rarity: rarity,
          bgX: bgX,
          bgY: bgY,
          glareX: glareX,
          glareY: glareY,
          opacity: opacity,
          hyp: _clampD(math.sqrt(dx * dx + dy * dy), 0, 1),
          artRect: artRect,
          radius: radius,
          noise: _NoiseTex.image,
        ),
      ),
    ),
  );
}

/// 全息卡：3D 倾斜 + 稀有度光层 + 翻牌 + 点击飞向屏幕中央放大旋转。
///
/// 未翻开时点按触发 [onTap]（由父级决定翻牌）；已翻开时点按打开
/// 飞向中央的放大层（每点一次旋转一圈）。手指按住拖动时牌面跟随倾斜，
/// 松手后按原版节奏慢漂回位。
class HoloCard extends StatefulWidget {
  const HoloCard({
    super.key,
    required this.front,
    required this.back,
    required this.rarity,
    required this.flipped,
    this.onTap,
    this.artWindow,
    this.radius = 14,
    this.enablePopover = true,
  });

  final Widget front;
  final Widget back;
  final HoloRarity rarity;
  final bool flipped;
  final VoidCallback? onTap;

  /// 商品图窗口在卡面上的位置（0~1 分数，LTRB），金卡光柱裁剪用。
  final Rect? artWindow;
  final double radius;
  final bool enablePopover;

  @override
  State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard>
    with SingleTickerProviderStateMixin {
  final _rotateX = _Spring1(0);
  final _rotateY = _Spring1(0);
  final _glareX = _Spring1(50);
  final _glareY = _Spring1(50);
  final _glareO = _Spring1(0);
  final _bgX = _Spring1(50);
  final _bgY = _Spring1(50);
  final _flip = _Spring1(0);

  late final Ticker _ticker;
  Timer? _snapTimer;
  bool _interacting = false;
  DateTime _lastInteractAt = DateTime.now();
  Size _size = Size.zero;

  List<_Spring1> get _springs => [
    _rotateX,
    _rotateY,
    _glareX,
    _glareY,
    _glareO,
    _bgX,
    _bgY,
    _flip,
  ];

  @override
  void initState() {
    super.initState();
    _flip.value = _flip.last = _flip.target = widget.flipped ? 180 : 0;
    _ticker = createTicker(_onTick);
    _NoiseTex.ensure(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HoloCard old) {
    super.didUpdateWidget(old);
    if (old.flipped != widget.flipped) {
      _flip.set(widget.flipped ? 180 : 0, k: 0.02, d: 0.35);
      _pump();
    }
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _pump() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    for (final s in _springs) {
      s.tick();
    }
    if (!mounted) return;
    setState(() {});
    // 鼠标悬停移出没有抬起事件，超过 1.5 秒无新互动则自动收尾
    if (_interacting &&
        DateTime.now().difference(_lastInteractAt).inMilliseconds > 1500 &&
        _springs.every((s) => s.settled)) {
      _endInteract();
    }
    if (!_interacting && _springs.every((s) => s.settled)) {
      _ticker.stop();
    }
  }

  void _interact(Offset local) {
    if (_size.width <= 0 || _size.height <= 0) return;
    _snapTimer?.cancel();
    _interacting = true;
    _lastInteractAt = DateTime.now();
    final px = _clampD(local.dx / _size.width * 100, 0, 100);
    final py = _clampD(local.dy / _size.height * 100, 0, 100);
    final cx = px - 50;
    final cy = py - 50;
    _bgX.set(37 + px * 0.26, k: 0.05, d: 0.24);
    _bgY.set(33 + py * 0.34, k: 0.05, d: 0.24);
    _rotateY.set(-(cx / 3.5), k: 0.042, d: 0.21);
    _rotateX.set(cy / 3.5, k: 0.042, d: 0.21);
    _glareX.set(px, k: 0.05, d: 0.24);
    _glareY.set(py, k: 0.05, d: 0.24);
    _glareO.set(1, k: 0.05, d: 0.24);
    _pump();
  }

  void _endInteract() {
    _interacting = false;
    _scheduleSnap(500);
  }

  /// 原版回位：延迟后换极软弹簧，慢慢漂回原位、光效渐隐。
  void _scheduleSnap(int delayMs) {
    _snapTimer?.cancel();
    _snapTimer = Timer(Duration(milliseconds: delayMs), () {
      _rotateX.set(0, k: 0.01, d: 0.06);
      _rotateY.set(0, k: 0.01, d: 0.06);
      _glareX.set(50, k: 0.01, d: 0.06);
      _glareY.set(50, k: 0.01, d: 0.06);
      _glareO.set(0, k: 0.01, d: 0.06);
      _bgX.set(50, k: 0.01, d: 0.06);
      _bgY.set(50, k: 0.01, d: 0.06);
      _pump();
    });
  }

  void _handleTap() {
    if (!widget.flipped) {
      widget.onTap?.call();
    } else if (widget.enablePopover) {
      _openPopover();
    }
  }

  /// 这张牌当前在屏幕上的位置（全局坐标），放大飞行用。
  Rect? _globalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _openPopover() {
    final rect = _globalRect();
    if (rect == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HoloPopover(
        front: widget.front,
        back: widget.back,
        rarity: widget.rarity,
        artWindow: widget.artWindow,
        radius: widget.radius,
        srcRect: rect,
        srcRectNow: _globalRect,
        onClose: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final totalX = _rotateX.value + _flip.value;
        final frontVisible =
            math.cos(totalX * math.pi / 180) *
                math.cos(_rotateY.value * math.pi / 180) >=
            0;
        final face = frontVisible
            ? widget.front
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateX(math.pi),
                child: widget.back,
              );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Listener(
            onPointerDown: (e) => _interact(e.localPosition),
            onPointerMove: (e) {
              if (e.buttons != 0) _interact(e.localPosition);
            },
            onPointerHover: (e) => _interact(e.localPosition),
            onPointerUp: (_) => _endInteract(),
            onPointerCancel: (_) => _endInteract(),
            child: GestureDetector(
              onTap: _handleTap,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(_rotateY.value * math.pi / 180)
                  ..rotateX(totalX * math.pi / 180),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      face,
                      if (frontVisible)
                        _holoOverlay(
                          rarity: widget.rarity,
                          bgX: _bgX.value,
                          bgY: _bgY.value,
                          glareX: _glareX.value,
                          glareY: _glareY.value,
                          opacity: _glareO.value,
                          size: _size,
                          artWindow: widget.artWindow,
                          radius: widget.radius,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 飞向中央的放大层：牌从小牌原位出发，边飞边转边放大到屏幕中央；
/// 点按再转一圈；关闭时转着飞回原位。牌面始终按小牌原始尺寸排版、
/// 整牌等比缩放，所以排版与光层位置永远和原位的小牌一致。
class _HoloPopover extends StatefulWidget {
  const _HoloPopover({
    required this.front,
    required this.back,
    required this.rarity,
    required this.artWindow,
    required this.radius,
    required this.srcRect,
    required this.srcRectNow,
    required this.onClose,
  });

  final Widget front;
  final Widget back;
  final HoloRarity rarity;
  final Rect? artWindow;
  final double radius;

  /// 打开瞬间小牌在屏幕上的位置（全局坐标），飞行从这里开始。
  final Rect srcRect;

  /// 关闭时重新读取小牌位置（聊天列表可能已经滚动），飞回落点用。
  final Rect? Function() srcRectNow;
  final VoidCallback onClose;

  @override
  State<_HoloPopover> createState() => _HoloPopoverState();
}

class _HoloPopoverState extends State<_HoloPopover>
    with SingleTickerProviderStateMixin {
  final _spin = _Spring1(0);
  final _rotateX = _Spring1(0);
  final _rotateY = _Spring1(0);
  final _glareX = _Spring1(50);
  final _glareY = _Spring1(50);
  final _glareO = _Spring1(0);
  final _bgX = _Spring1(50);
  final _bgY = _Spring1(50);
  final _scale = _Spring1(1);
  final _scrim = _Spring1(0);
  late final _Spring1 _cx;
  late final _Spring1 _cy;

  late final Ticker _ticker;
  Timer? _failsafe;
  bool _closing = false;
  bool _removed = false;
  DateTime _lastInteract = DateTime.now();
  double _showR = 0;
  Size _cardSize = Size.zero;

  List<_Spring1> get _springs => [
    _spin,
    _rotateX,
    _rotateY,
    _glareX,
    _glareY,
    _glareO,
    _bgX,
    _bgY,
    _scale,
    _scrim,
    _cx,
    _cy,
  ];

  @override
  void initState() {
    super.initState();
    _cx = _Spring1(widget.srcRect.center.dx);
    _cy = _Spring1(widget.srcRect.center.dy);
    _cardSize = widget.srcRect.size;
    // 从反面起飞：180→720（转 1.5 圈）后落在正面，挂在中央。
    // 注意：从 180 出发若只加 360 会仍停在反面。
    _spin.value = _spin.last = 180;
    _spin.set(720, k: 0.016, d: 0.30);
    _ticker = createTicker(_onTick)..start();
    _NoiseTex.ensure(() {
      if (mounted) setState(() {});
    });
    // 下一帧拿到屏幕尺寸后设定飞行终点：屏幕中央 + 目标放大倍数
    // （与演示版同参的位移/缩放弹簧 0.028 / 0.42）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      final screen = MediaQuery.of(context).size;
      var target =
          math.min(
            math.min(widget.srcRect.width * 2.1, screen.width * 0.74),
            330.0,
          ) /
          widget.srcRect.width;
      final maxByHeight = screen.height * 0.78 / widget.srcRect.height;
      if (target > maxByHeight) target = maxByHeight;
      _cx.set(screen.width / 2, k: 0.028, d: 0.42);
      _cy.set(screen.height / 2, k: 0.028, d: 0.42);
      _scale.set(target, k: 0.028, d: 0.42);
      _scrim.set(1, k: 0.05, d: 0.30);
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    // 空闲超过 1.2 秒：牌面挂住不动，只让金光/闪膜继续绕行。
    if (DateTime.now().difference(_lastInteract).inMilliseconds > 1200 &&
        !_closing) {
      _showR += 0.009;
      _rotateX.set(0, k: 0.05, d: 0.30);
      _rotateY.set(0, k: 0.05, d: 0.30);
      _glareX.set(55 + math.sin(_showR) * 55, k: 0.015, d: 0.5);
      _glareY.set(55 + math.cos(_showR) * 55, k: 0.015, d: 0.5);
      _glareO.set(0.8, k: 0.015, d: 0.5);
      _bgX.set(20 + math.sin(_showR) * 20, k: 0.015, d: 0.5);
      _bgY.set(20 + math.cos(_showR) * 20, k: 0.015, d: 0.5);
    }
    for (final s in _springs) {
      s.tick();
    }
    if (!mounted) return;
    // 关闭飞行落位完成（位置与缩放都到家）就摘掉浮层，
    // 底下原位的小牌无缝接棒，视觉上没有任何跳变。
    if (_closing &&
        !_removed &&
        (_cx.target - _cx.value).abs() < 2 &&
        (_cy.target - _cy.value).abs() < 2 &&
        (_scale.target - _scale.value).abs() < 0.02) {
      _remove();
      return;
    }
    setState(() {});
  }

  void _remove() {
    _removed = true;
    widget.onClose();
  }

  void _interact(Offset local) {
    if (_cardSize.width <= 0 || _closing) return;
    _lastInteract = DateTime.now();
    final px = _clampD(local.dx / _cardSize.width * 100, 0, 100);
    final py = _clampD(local.dy / _cardSize.height * 100, 0, 100);
    _bgX.set(37 + px * 0.26, k: 0.05, d: 0.24);
    _bgY.set(33 + py * 0.34, k: 0.05, d: 0.24);
    _rotateY.set(-((px - 50) / 3.5), k: 0.042, d: 0.21);
    _rotateX.set((py - 50) / 3.5, k: 0.042, d: 0.21);
    _glareX.set(px, k: 0.05, d: 0.24);
    _glareY.set(py, k: 0.05, d: 0.24);
    _glareO.set(1, k: 0.05, d: 0.24);
  }

  void _spinAgain() {
    if (_closing) return;
    _lastInteract = DateTime.now();
    _spin.set(_spin.target + 360, k: 0.016, d: 0.30);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _lastInteract = DateTime.now();
    _spin.set(_spin.target + 360, k: 0.016, d: 0.30);
    final home = widget.srcRectNow() ?? widget.srcRect;
    _cx.set(home.center.dx, k: 0.028, d: 0.42);
    _cy.set(home.center.dy, k: 0.028, d: 0.42);
    _scale.set(1, k: 0.028, d: 0.42);
    _scrim.set(0, k: 0.05, d: 0.30);
    _rotateX.set(0, k: 0.05, d: 0.24);
    _rotateY.set(0, k: 0.05, d: 0.24);
    // 兜底：弹簧万一没落位，3.2 秒后强制摘层
    _failsafe = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && !_removed) _remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final srcW = widget.srcRect.width;
    final srcH = widget.srcRect.height;
    final totalY = _spin.value + _rotateY.value;
    final frontVisible =
        math.cos(totalY * math.pi / 180) *
            math.cos(_rotateX.value * math.pi / 180) >=
        0;
    final face = frontVisible
        ? widget.front
        : Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: widget.back,
          );
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.72 * _clampD(_scrim.value, 0, 1),
                ),
              ),
            ),
          ),
          // 牌面按原始尺寸排版，靠位移 + 整牌缩放飞到中央
          Positioned(
            left: _cx.value - srcW / 2,
            top: _cy.value - srcH / 2,
            width: srcW,
            height: srcH,
            child: Listener(
              onPointerDown: (e) => _interact(e.localPosition),
              onPointerMove: (e) {
                if (e.buttons != 0) _interact(e.localPosition);
              },
              child: GestureDetector(
                onTap: _spinAgain,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..scaleByDouble(_scale.value, _scale.value, _scale.value, 1)
                    ..rotateY(totalY * math.pi / 180)
                    ..rotateX(_rotateX.value * math.pi / 180),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          face,
                          if (frontVisible)
                            _holoOverlay(
                              rarity: widget.rarity,
                              bgX: _bgX.value,
                              bgY: _bgY.value,
                              glareX: _glareX.value,
                              glareY: _glareY.value,
                              opacity: _glareO.value,
                              size: Size(srcW, srcH),
                              artWindow: widget.artWindow,
                              radius: widget.radius,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
