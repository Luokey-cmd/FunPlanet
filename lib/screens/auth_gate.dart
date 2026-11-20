import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_catalog_provider.dart';
import '../screens/main_screen.dart';
import '../pages/login_page.dart';
import '../utils/user_session_sync.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.skipSplash = false});

  /// 上游已播过开屏图时跳过，避免「开屏 → 剧情 → 再开屏」重复。
  final bool skipSplash;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // 开屏页的最短展示时间：初始化再快，也不能让开屏图一闪而过。
  bool _minSplashElapsed = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    if (widget.skipSplash) {
      _minSplashElapsed = true;
    } else {
      _splashTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _minSplashElapsed = true);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final catalog = context.read<ProductCatalogProvider>();

      if (!auth.isInitialized) {
        await auth.init();
      }
      if (!catalog.loadedFromRemote && !catalog.isLoading) {
        await catalog.load();
      }

      if (!mounted) return;
      final user = auth.currentUser;
      if (user != null) {
        await syncUserSession(
          context,
          nickname: user.nickname,
          userId: user.userId,
          phone: user.phone,
        );
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 初始化未完成、或开屏最短展示时间未到。
    if (!auth.isInitialized || !_minSplashElapsed) {
      // 上游已播过开屏：只等鉴权，不再重复贴开屏图。
      if (widget.skipSplash) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
          ),
        );
      }
      return Scaffold(
        body: SizedBox.expand(
          child: Image.asset(
            'assets/images/splash_launch.jpg',
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginPage();
    }

    return const MainScreen();
  }
}
