import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
      ),
      dividerColor: AppColors.border,
      fontFamily: 'Roboto',
    );
  }
}
