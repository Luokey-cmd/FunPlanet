import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_tab_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/support_chat_provider.dart';
import 'providers/xiaodou_chat_provider.dart';
import 'providers/starwish_profile_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_catalog_provider.dart';
import 'providers/user_provider.dart';
import 'screens/first_entry_intro_gate.dart';
import 'theme/app_theme.dart';
import 'utils/app_stability.dart';
import 'utils/app_log.dart';
import 'widgets/click_effect/click_effect.dart';

void main() {
  AppStability.runGuarded(() async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    // 多商品页切 Tab 时尽量保住已解码图片，减少重复解码与空白闪一下。
    // 商品图原图较大（1254×1254），原缓存（300 张 / 120MB）装不下几个
    // 页面的图，先前页面的图被挤掉后切回来要重新整张解码、造成卡顿，
    // 故把条数与总字节都放大（2026-11-24）。
    PaintingBinding.instance.imageCache.maximumSize = 600;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20;
    AppLog.info('系统', 'App 启动');
    runApp(const FunPlanetApp());
  });
}

class FunPlanetApp extends StatelessWidget {
  const FunPlanetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductCatalogProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AppTabProvider()),
        ChangeNotifierProvider(create: (_) => XiaodouChatProvider()),
        ChangeNotifierProvider(create: (_) => StarwishProfileProvider()),
        ChangeNotifierProvider(create: (_) => SupportChatProvider()),
      ],
      child: MaterialApp(
        title: '趣玩星球',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // 全 App 中文化（2026-11-23 hx 报）：以前没挂语言包，
        // Flutter 自带控件的文案全是英文——最明显的是任何输入框
        // 长按弹出的「Paste / Select all」。挂上官方中文语言包并
        // 锁定中文后，这些自带菜单全变中文（粘贴/全选/剪切/复制），
        // 所有页面一起生效。配套：pubspec 要加 flutter_localizations。
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Theme(
            data: AppTheme.withReadableType(Theme.of(context)),
            child: DefaultTextStyle.merge(
              style: AppTheme.baseText,
              child: wrapWithClickEffect(context, child),
            ),
          );
        },
        home: const FirstEntryIntroGate(),
      ),
    );
  }
}
