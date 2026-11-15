import 'package:flutter/material.dart';
import 'app_scale.dart';

class AppColors {
  static const primary = Color(0xFFA389F4);
  static const primaryDark = Color(0xFF8B6FE0);
  static const primaryLight = Color(0xFFC4B0F7);
  static const accent = Color(0xFFFF8EC7);
  static const accentSoft = Color(0xFFFFE4F0);
  static const gold = Color(0xFFE8B84A);
  static const goldDark = Color(0xFFD4A017);

  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF2D2640);
  static const card = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF3E8FF);
  static const secondaryForeground = Color(0xFF6B5B95);
  static const muted = Color(0xFFF5F0FA);
  static const mutedForeground = Color(0xFF9B8FB0);
  static const border = Color(0xFFE8DFF5);
  static const tagNew = Color(0xFFFF6B9D);
  static const tagHot = Color(0xFFFF9F43);
  static const priceRed = Color(0xFFE85555);

  static const memberBenefitCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F2FF), Color(0xFFF3EBFF)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFECE2FF), Color(0xFFFFFFFF)],
    stops: [0.0, 0.55],
  );

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF9B7FE8), Color(0xFFB88FE8), Color(0xFFD48FE8)],
  );

  static const memberGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8B6FE0), Color(0xFFA389F4), Color(0xFFB99AF7)],
  );

  static const profileMemberGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8E54E9), Color(0xFF9B5FED), Color(0xFFAB69FF)],
  );

  static const profileCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB8D0), Color(0xFFFFCBA4), Color(0xFFFFE0B2)],
  );

  static const inviteGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFE4F0), Color(0xFFE8E0FF), Color(0xFFDCE8FF)],
  );

  static const couponGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF0E6FF), Color(0xFFE8DEFF)],
  );

  static const newcomerSectionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3E8FF), Color(0xFFFFE8F4), Color(0xFFEDE4FF)],
    stops: [0.0, 0.55, 1.0],
  );

  static const claimButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFB347), Color(0xFFFF8E53), Color(0xFFFF6B6B)],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF2D2640).withValues(alpha: 0.07),
          offset: Offset(0, AppScale.s(2)),
          blurRadius: AppScale.s(8),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.1),
          offset: Offset(0, AppScale.s(6)),
          blurRadius: AppScale.s(18),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF2D2640).withValues(alpha: 0.08),
          offset: Offset(0, AppScale.s(2)),
          blurRadius: AppScale.s(10),
        ),
      ];
}

TagStyle tagStyleFromKey(String? tagColor) {
  switch (tagColor) {
    case 'new':
      return const TagStyle(AppColors.tagNew, Colors.white);
    case 'hot':
      return const TagStyle(AppColors.tagHot, Colors.white);
    case 'gold':
      return const TagStyle(AppColors.gold, Colors.white);
    default:
      return const TagStyle(AppColors.primary, Colors.white);
  }
}

class TagStyle {
  const TagStyle(this.background, this.foreground);
  final Color background;
  final Color foreground;
}
