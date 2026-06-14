import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../utils/user_session_sync.dart';
import '../widgets/auth_widgets.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: kReleaseMode ? '' : '13800138000');
    _passwordController = TextEditingController(text: kReleaseMode ? '' : '123456');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.login(
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      showTopSnackBar(
        context,
        content: Text(error, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }

    final user = auth.currentUser;
    if (user != null) {
      await syncUserSession(
        context,
        nickname: user.nickname,
        userId: user.userId,
        phone: user.phone,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      contentVerticalBias: -0.3,
      child: AuthPageShell(
        title: '趣玩星球',
        subtitle: '开启惊喜 · 收集快乐',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormField(
              label: '手机号',
              controller: _phoneController,
              hint: '请输入手机号',
              keyboardType: TextInputType.phone,
              maxLength: 11,
            ),
            SizedBox(height: AppScale.s(16)),
            AuthFormField(
              label: '密码',
              controller: _passwordController,
              hint: '请输入密码',
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.mutedForeground,
                  size: authText(20),
                ),
              ),
            ),
            SizedBox(height: AppScale.s(10)),
            if (!kReleaseMode)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '演示账号：13800138000 / 123456',
                  style: TextStyle(fontSize: authText(11), color: AppColors.mutedForeground),
                ),
              ),
            if (!kReleaseMode) SizedBox(height: AppScale.s(10)),
            SizedBox(height: AppScale.s(20)),
            AuthPrimaryButton(label: '登录', loading: _loading, onPressed: _submit),
            SizedBox(height: AppScale.s(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('还没有账号？', style: TextStyle(fontSize: authText(13), color: AppColors.mutedForeground)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                  child: Text('立即注册', style: TextStyle(fontSize: authText(13), fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
