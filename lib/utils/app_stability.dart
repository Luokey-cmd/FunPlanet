import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/click_effect/app_buttons.dart';

/// 参考 peduliAI 稳定性实践：Zone / FlutterError / 局部 ErrorWidget / 启动失败可恢复。
class AppStability {
  AppStability._();

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FunPlanet][FlutterError] ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[FunPlanet][PlatformError] $error\n$stack');
      return true;
    };

    ErrorWidget.builder = (details) {
      // 错误页必须自带阅读方向和文字样式。它经常插在 MaterialApp 之外，
      // 用 Icon / Material / SafeArea 会再抛错，错误页套错误页，首帧永远画不出来。
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: AppColors.muted,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.foreground,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '此处暂时出了点问题',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kReleaseMode ? '请返回重试，不影响其他功能' : details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };
  }

  static void runGuarded(Future<void> Function() body) {
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        install();
        try {
          await body();
        } catch (error, stack) {
          debugPrint('[FunPlanet][Startup] $error\n$stack');
          runApp(StartupErrorApp(error: error, onRetry: () => runGuarded(body)));
        }
      },
      (error, stack) {
        debugPrint('[FunPlanet][Zone] $error\n$stack');
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppScale.s(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined, size: AppScale.s(52), color: AppColors.primary),
                  SizedBox(height: AppScale.s(16)),
                  Text(
                    '启动失败',
                    style: TextStyle(fontSize: AppScale.t(20), fontWeight: FontWeight.bold, color: AppColors.foreground),
                  ),
                  SizedBox(height: AppScale.s(8)),
                  Text(
                    kReleaseMode ? '请检查网络后重试' : '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground),
                  ),
                  SizedBox(height: AppScale.s(24)),
                  AppFilledButton(
                    onPressed: onRetry,
                    child: const Text('重新启动'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
