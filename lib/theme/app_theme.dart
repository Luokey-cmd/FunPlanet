import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  /// 全 App 正文字体：Noto Serif SC（思源宋体简体），宋体风格，含常规与粗体。
  static const fontFamily = 'NotoSerifSC';

  /// 英文 / 数字回退：Nunito。
  static const latinFamily = 'Nunito';

  static const fontFallbacks = [latinFamily, 'serif', 'sans-serif'];

  /// 在已经本地化的主题上统一字体与拉丁回退，
  /// 并给主题字号整体 +2：对话框、菜单这类走主题默认字号的文字，
  /// 与 AppScale.t 放大后的正文（约 +15%）保持接近的手感。
  static ThemeData withReadableType(ThemeData theme) {
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSizeDelta: 2,
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSizeDelta: 2,
      ),
    );
  }

  /// 全 App 默认文字样式（main.dart 里套在最外层）。
  static const TextStyle baseText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    height: 1.28,
  );

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.foreground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      dividerColor: AppColors.border,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: baseText.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: baseText.copyWith(
          fontSize: 14,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
