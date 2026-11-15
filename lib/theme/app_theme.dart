import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_scale.dart';

class AppTheme {
  /// 中文：马善政楷书（字体已去掉拉丁字母，英文会走 Nunito）。
  static const fontFamily = 'MaShanZheng';

  /// 英文 / 数字：圆润清晰，避免楷书英文无法辨认。
  static const latinFamily = 'Nunito';

  static const fontFallbacks = [latinFamily, 'sans-serif'];

  /// 在已经本地化的主题上把正文字号加大。必须用 [Theme.of] 的结果，不能用未合并几何的 [light]。
  static ThemeData withReadableType(ThemeData theme) {
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSizeDelta: AppScale.fontBump,
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSizeDelta: AppScale.fontBump,
      ),
    );
  }

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
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      dividerColor: AppColors.border,
      fontFamily: fontFamily,
    );
    // textTheme 在这里还没有字号，字号要等 Theme.of 按语言合并几何后再加。
    // 此时传 fontSizeDelta 会在调试模式直接断言失败，启动停在 MaterialApp 之外。
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
          fontSize: 20 + AppScale.fontBump,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: baseText.copyWith(
          fontSize: 14 + AppScale.fontBump,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
