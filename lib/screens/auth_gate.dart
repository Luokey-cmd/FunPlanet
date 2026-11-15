import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_catalog_provider.dart';
import '../screens/main_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../pages/login_page.dart';
import '../utils/user_session_sync.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(
            width: AppScale.s(32),
            height: AppScale.s(32),
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
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
