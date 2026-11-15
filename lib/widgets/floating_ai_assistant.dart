import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../theme/app_scale.dart';

enum _DockSide { left, right }

class FloatingAiAssistant extends StatefulWidget {
  const FloatingAiAssistant({super.key, this.onOpenChat});

  final VoidCallback? onOpenChat;

  static const assetFull = 'assets/images/小豆.png';
  static const assetLeft = 'assets/images/小豆左边.png';
  static const assetRight = 'assets/images/小豆右边.png';

  static double get displaySize => AppScale.s(90);
  static double get hitSize => AppScale.s(96);
  static double get peekOutset => AppScale.s(18);

  @override
  State<FloatingAiAssistant> createState() => _FloatingAiAssistantState();
}

class _FloatingAiAssistantState extends State<FloatingAiAssistant> with SingleTickerProviderStateMixin {
  _DockSide _side = _DockSide.right;
  bool _hovering = false;
  bool _dragging = false;
  bool _isSnapping = false;
  bool _layoutReady = false;
  bool _showFull = false;

  double _maxLeft = 0;
  double _minTop = 0;
  double _maxTop = 0;
  double _snapFromLeft = 0;
  double _snapToLeft = 0;
  Offset? _pointerDownGlobal;
  Timer? _collapseTimer;

  final ValueNotifier<Offset> _position = ValueNotifier(Offset.zero);
  late final AnimationController _snapController;

  bool get _isInteractive => _showFull || _dragging || _isSnapping;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addListener(_onSnapTick);
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isSnapping) {
        _onSnapComplete();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in [
      FloatingAiAssistant.assetFull,
      FloatingAiAssistant.assetLeft,
      FloatingAiAssistant.assetRight,
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _snapController.removeListener(_onSnapTick);
    _snapController.dispose();
    _position.dispose();
    super.dispose();
  }

  void _initLayoutIfNeeded() {
    if (_layoutReady) return;
    _position.value = Offset(_dockLeft(_side), (_maxTop - _minTop) * 0.55 + _minTop);
    _layoutReady = true;
  }

  double _dockLeft(_DockSide side) =>
      side == _DockSide.left ? -FloatingAiAssistant.peekOutset : _maxLeft + FloatingAiAssistant.peekOutset;

  void _syncToEdge() {
    _position.value = Offset(
      _dockLeft(_side),
      _position.value.dy.clamp(_minTop, _maxTop),
    );
  }

  String get _peekAsset =>
      _side == _DockSide.left ? FloatingAiAssistant.assetLeft : FloatingAiAssistant.assetRight;

  double _visualLeft(double currentLeft) {
    if (_isInteractive) return currentLeft;
    return _dockLeft(_side);
  }

  void _cancelCollapseTimer() => _collapseTimer?.cancel();

  void _collapseToPeek() {
    if (!mounted) return;
    setState(() => _showFull = false);
    _syncToEdge();
  }

  void _scheduleCollapse(Duration delay) {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(delay, () {
      if (!mounted || _hovering || _dragging || _isSnapping) return;
      _collapseToPeek();
    });
  }

  void _setExpanded(bool value) {
    _cancelCollapseTimer();
    if (_showFull != value) setState(() => _showFull = value);
  }

  void _onHoverEnter() {
    if (_hovering) return;
    _hovering = true;
    if (!_dragging && !_isSnapping) {
      _position.value = Offset(
        _position.value.dx.clamp(0, _maxLeft),
        _position.value.dy,
      );
    }
    _setExpanded(true);
  }

  void _onHoverExit() {
    _hovering = false;
    if (!_dragging && !_isSnapping) {
      _scheduleCollapse(const Duration(seconds: 1));
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isSnapping) {
      _snapController.stop();
      _isSnapping = false;
      _position.value = Offset(
        lerpDouble(
          _snapFromLeft,
          _snapToLeft,
          Curves.easeOutCubic.transform(_snapController.value),
        )!,
        _position.value.dy,
      );
    }

    _pointerDownGlobal = event.position;
    _dragging = false;
    _cancelCollapseTimer();

    final freeLeft = _position.value.dx.clamp(0, _maxLeft).toDouble();
    _position.value = Offset(freeLeft, _position.value.dy);
    _setExpanded(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownGlobal == null) return;

    if (!_dragging) {
      if ((event.position - _pointerDownGlobal!).distance < 4) return;
      _dragging = true;
      _cancelCollapseTimer();
      setState(() {});
    }

    _position.value = Offset(
      (_position.value.dx + event.delta.dx).clamp(0, _maxLeft),
      (_position.value.dy + event.delta.dy).clamp(_minTop, _maxTop),
    );
  }

  void _onPointerUp() {
    final wasDragging = _dragging;
    _pointerDownGlobal = null;
    _dragging = false;

    if (wasDragging) {
      _startSnapToEdge();
    } else {
      widget.onOpenChat?.call();
      _scheduleCollapse(const Duration(seconds: 2));
    }
  }

  void _onPointerCancel() {
    _pointerDownGlobal = null;
    if (_dragging) {
      _dragging = false;
      _startSnapToEdge();
    } else if (!_hovering && !_isSnapping) {
      _scheduleCollapse(const Duration(seconds: 1));
    }
  }

  void _startSnapToEdge() {
    final centerX = _position.value.dx + FloatingAiAssistant.hitSize / 2;
    final screenCenterX = _maxLeft / 2 + FloatingAiAssistant.hitSize / 2;
    final targetSide = centerX < screenCenterX ? _DockSide.left : _DockSide.right;

    _snapFromLeft = _position.value.dx;
    _snapToLeft = _dockLeft(targetSide);
    _isSnapping = true;
    setState(() {});
    _snapController.forward(from: 0);
  }

  void _onSnapTick() {
    if (!_isSnapping) return;
    final t = Curves.easeOutCubic.transform(_snapController.value);
    _position.value = Offset(
      lerpDouble(_snapFromLeft, _snapToLeft, t)!,
      _position.value.dy,
    );
  }

  void _onSnapComplete() {
    if (!mounted) return;
    final targetSide = _snapToLeft <= _maxLeft / 2 ? _DockSide.left : _DockSide.right;
    setState(() {
      _isSnapping = false;
      _side = targetSide;
    });
    _position.value = Offset(_dockLeft(_side), _position.value.dy.clamp(_minTop, _maxTop));
    if (!_hovering) {
      _scheduleCollapse(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final imageSize = FloatingAiAssistant.displaySize;
    final hitSize = FloatingAiAssistant.hitSize;
    final dpr = mq.devicePixelRatio;

    _maxLeft = screenSize.width - hitSize;
    _minTop = mq.padding.top + AppScale.s(8);
    _maxTop = screenSize.height - AppScale.s(56) - mq.padding.bottom - hitSize - AppScale.s(8);

    _initLayoutIfNeeded();

    final showFull = _isInteractive;
    final showPeek = !showFull;

    return IgnorePointer(
      ignoring: false,
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ValueListenableBuilder<Offset>(
              valueListenable: _position,
              builder: (context, pos, child) {
                final top = pos.dy.clamp(_minTop, _maxTop).toDouble();
                final left = _visualLeft(pos.dx);
                return Transform.translate(
                  offset: Offset(left, top),
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: _AssistantBody(
                  hitSize: hitSize,
                  imageSize: imageSize,
                  dpr: dpr,
                  showFull: showFull,
                  showPeek: showPeek,
                  peekAsset: _peekAsset,
                  onHoverEnter: _onHoverEnter,
                  onHoverExit: _onHoverExit,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBody extends StatelessWidget {
  const _AssistantBody({
    required this.hitSize,
    required this.imageSize,
    required this.dpr,
    required this.showFull,
    required this.showPeek,
    required this.peekAsset,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final double hitSize;
  final double imageSize;
  final double dpr;
  final bool showFull;
  final bool showPeek;
  final String peekAsset;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final cache = (imageSize * dpr).round();

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      opaque: true,
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: (_) => onPointerUp(),
        onPointerCancel: (_) => onPointerCancel(),
        child: SizedBox(
          width: hitSize,
          height: hitSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (showPeek)
                _AssistantImage(
                  asset: peekAsset,
                  size: imageSize,
                  cache: cache,
                ),
              if (showFull)
                _AssistantImage(
                  asset: FloatingAiAssistant.assetFull,
                  size: imageSize,
                  cache: cache,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantImage extends StatelessWidget {
  const _AssistantImage({
    required this.asset,
    required this.size,
    required this.cache,
  });

  final String asset;
  final double size;
  final int cache;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        cacheWidth: cache,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.smart_toy_outlined,
          size: size * 0.6,
          color: const Color(0xFF3B82F6),
        ),
      ),
    );
  }
}
