import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../utils/user_session_sync.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreed = true;
  bool _loading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_agreed) {
      showTopSnackBar(
        context,
        content: Text('请先阅读并同意用户协议', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.register(
      phone: _phoneController.text,
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
      nickname: _nicknameController.text,
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
        isNewUser: true,
      );
    }

    if (!mounted) return;
    showTopSnackBar(
      context,
      content: Text('注册成功，欢迎加入趣玩星球', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      showBack: true,
      child: AuthPageShell(
        title: '创建账号',
        subtitle: '注册即享新人优惠券礼包',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormField(
              label: '昵称',
              controller: _nicknameController,
              hint: '给自己取个潮玩昵称',
              maxLength: 16,
            ),
            SizedBox(height: AppScale.s(16)),
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
              hint: '至少 6 位密码',
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
            SizedBox(height: AppScale.s(16)),
            AuthFormField(
              label: '确认密码',
              controller: _confirmController,
              hint: '再次输入密码',
              obscureText: _obscureConfirm,
              suffix: IconButton(
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.mutedForeground,
                  size: authText(20),
                ),
              ),
            ),
            SizedBox(height: AppScale.s(14)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppScale.s(24),
                  height: AppScale.s(24),
                  child: Checkbox(
                    value: _agreed,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(width: AppScale.s(6)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppScale.s(2)),
                    child: Text(
                      '我已阅读并同意《趣玩星球用户协议》和《隐私政策》',
                      style: TextStyle(fontSize: authText(12), color: AppColors.mutedForeground, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppScale.s(20)),
            AuthPrimaryButton(label: '注册', loading: _loading, onPressed: _submit),
            SizedBox(height: AppScale.s(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('已有账号？', style: TextStyle(fontSize: authText(13), color: AppColors.mutedForeground)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('去登录', style: TextStyle(fontSize: authText(13), fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
