import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'auth_gate.dart';

/// 首次安装开场：先开屏图，再（仅第一次）播剧情视频，最后进 AuthGate。
///
/// 机制（hz 2026-11-20 定，顺序已改为开屏 → 剧情）：
/// - 每次打开：先全屏展示「一站式寻宝星球」开屏图约 1.8 秒。
/// - 安装后第一次：开屏结束后播一遍剧情视频，播完（或点「跳过剧情」）写下标记。
/// - 之后再打开：开屏结束后直接进 AuthGate，不再播剧情。
/// - 卸载重装：标记随私有存储清空，剧情会再播一遍。
///
/// 标记用 SharedPreferences（键 first_entry_intro_seen_v1）。
class FirstEntryIntroGate extends StatefulWidget {
  const FirstEntryIntroGate({super.key});

  @override
  State<FirstEntryIntroGate> createState() => _FirstEntryIntroGateState();
}

enum _Phase { splash, video, done }

class _FirstEntryIntroGateState extends State<FirstEntryIntroGate> {
  static const _seenKey = 'first_entry_intro_seen_v1';
  static const _assetPath = 'assets/videos/first_entry_intro.mp4';
  static const _splashAsset = 'assets/images/splash_launch.jpg';
  static const _splashMinMs = 1800;

  _Phase _phase = _Phase.splash;
  bool? _shouldPlayIntro;
  VideoPlayerController? _controller;
  bool _finished = false;
  Timer? _splashTimer;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _decide();
    _splashTimer = Timer(const Duration(milliseconds: _splashMinMs), _onSplashDone);
  }

  Future<void> _decide() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      seen = true;
    }
    if (!mounted) return;
    setState(() => _shouldPlayIntro = !seen);
    if (_phase == _Phase.splash && _splashTimer == null) {
      _onSplashDone();
    }
  }

  void _onSplashDone() {
    _splashTimer?.cancel();
    _splashTimer = null;
    if (!mounted || _phase != _Phase.splash) return;
    final shouldPlay = _shouldPlayIntro;
    if (shouldPlay == null) {
      _splashTimer = Timer(const Duration(milliseconds: 50), _onSplashDone);
      return;
    }
    if (shouldPlay) {
      setState(() => _phase = _Phase.video);
      _startVideo();
    } else {
      setState(() => _phase = _Phase.done);
    }
  }

  Future<void> _startVideo() async {
    final controller = VideoPlayerController.asset(_assetPath);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || _finished) return;
      controller.addListener(_onVideoTick);
      await controller.play();
      if (mounted) setState(() {});
      _safetyTimer = Timer(const Duration(seconds: 25), _finish);
    } catch (_) {
      _finish();
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _safetyTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      await controller.dispose();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _safetyTimer?.cancel();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) {
      return const AuthGate(skipSplash: true);
    }
    if (_phase == _Phase.splash) {
      return Scaffold(
        body: SizedBox.expand(
          child: Image.asset(
            _splashAsset,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final controller = _controller;
    final videoReady = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (videoReady)
            // contain：小屏完整显示整段剧情，宁可上下留黑边，不裁画面。
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? (9 / 16)
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            right: 10,
            child: TextButton(
              onPressed: _finish,
              child: const Text(
                '跳过剧情>>',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
