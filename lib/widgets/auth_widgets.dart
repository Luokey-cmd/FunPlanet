import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'auth_background.dart';

const _authTextScale = 1.25;

double authText(double size) => AppScale.s(size * _authTextScale);

class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.maxLength,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: authText(13), fontWeight: FontWeight.w600, color: AppColors.foreground)),
        SizedBox(height: AppScale.s(8)),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: authText(15), color: AppColors.mutedForeground),
            counterText: '',
            filled: true,
            fillColor: AppColors.muted,
            suffixIcon: suffix,
            contentPadding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(14)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppScale.s(14)),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppScale.s(14)),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppScale.s(14)),
              borderSide: BorderSide(color: AppColors.primary, width: AppScale.s(1.5)),
            ),
          ),
          style: TextStyle(fontSize: authText(15), color: AppColors.foreground),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppScale.s(999)),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
          child: SizedBox(
            width: double.infinity,
            height: AppScale.s(48),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: AppScale.s(22),
                      height: AppScale.s(22),
                      child: const CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(label, style: TextStyle(color: Colors.white, fontSize: authText(16), fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppScale.s(20)),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: AppScale.s(88),
            height: AppScale.s(88),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: AppScale.s(88),
              height: AppScale.s(88),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppScale.s(20)),
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: AppScale.s(40)),
            ),
          ),
        ),
        SizedBox(height: AppScale.s(16)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: authText(26), fontWeight: FontWeight.bold, color: AppColors.foreground),
        ),
        SizedBox(height: AppScale.s(6)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: authText(13), color: AppColors.mutedForeground),
        ),
        SizedBox(height: AppScale.s(24)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppScale.s(20)),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppScale.s(24)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: AppColors.cardShadow,
          ),
          child: child,
        ),
      ],
    );
  }
}

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.child,
    this.showBack = false,
    /// 相对垂直居中的偏移，-0.3 表示整体上移约 15% 屏高
    this.contentVerticalBias = 0,
  });

  final Widget child;
  final bool showBack;
  final double contentVerticalBias;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthBackground(
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(20), vertical: AppScale.s(12)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - AppScale.s(24)),
                    child: Align(
                      alignment: Alignment(0, contentVerticalBias),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: AppScale.s(420)),
                        child: child,
                      ),
                    ),
                    ),
                  );
                },
              ),
              if (showBack)
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: authText(22)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
