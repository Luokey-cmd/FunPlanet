import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_scale.dart';

/// 功能子页统一字号与间距（对齐地址管理页）
class FeaturePageStyle {
  static double s(double value) => AppScale.s(value);

  static TextStyle pageTitle({Color? color}) => TextStyle(
        fontSize: s(20),
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.foreground,
      );

  static TextStyle sectionTitle({Color? color}) => TextStyle(
        fontSize: s(16),
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.foreground,
      );

  static TextStyle title({Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
        fontSize: s(18),
        fontWeight: weight,
        color: color ?? AppColors.foreground,
      );

  static TextStyle body({Color? color, double? height, bool bold = false}) => TextStyle(
        fontSize: s(16),
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: color ?? AppColors.foreground.withValues(alpha: bold ? 1 : 0.85),
        height: height ?? 1.45,
      );

  static TextStyle bodyBold({Color? color}) => body(color: color ?? AppColors.foreground, bold: true);

  static TextStyle secondary({Color? color}) => TextStyle(
        fontSize: s(14),
        color: color ?? AppColors.mutedForeground,
      );

  static TextStyle caption({Color? color, FontWeight? weight}) => TextStyle(
        fontSize: s(13),
        fontWeight: weight,
        color: color ?? AppColors.mutedForeground,
      );

  static TextStyle action({Color? color}) => TextStyle(
        fontSize: s(15),
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.primary,
      );

  static TextStyle empty() => TextStyle(
        fontSize: s(16),
        color: AppColors.mutedForeground,
      );

  static TextStyle price({Color? color}) => TextStyle(
        fontSize: s(16),
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.priceRed,
      );

  static TextStyle priceLarge({Color? color}) => TextStyle(
        fontSize: s(24),
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.priceRed,
      );

  static TextStyle display({Color? color}) => TextStyle(
        fontSize: s(26),
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.foreground,
      );

  static TextStyle badge({Color? color}) => TextStyle(
        fontSize: s(13),
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
      );

  static TextStyle buttonLabel({Color? color}) => TextStyle(
        fontSize: s(16),
        fontWeight: FontWeight.w600,
        color: color,
      );

  static EdgeInsets cardPadding = EdgeInsets.all(s(14));
  static double cardRadius = s(12);
  static double iconSize = s(24);
  static double chevronSize = s(22);
  static double buttonHeight = s(48);
  static double thumbSize = s(64);
}
