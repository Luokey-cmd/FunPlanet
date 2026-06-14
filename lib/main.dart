import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_tab_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/support_chat_provider.dart';
import 'providers/xiaodou_chat_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_catalog_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FunPlanetApp());
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
        ChangeNotifierProvider(create: (_) => SupportChatProvider()),
      ],
      child: MaterialApp(
        title: '趣玩星球',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
