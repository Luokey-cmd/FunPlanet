import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';

import '../widgets/click_effect/app_pressable.dart';

enum AppTab { home, mall, cart, profile }

class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.active, required this.onChange});

  final AppTab active;
  final ValueChanged<AppTab> onChange;

  // 图标顺序：未选中（灰版珐琅） / 选中（彩色珐琅）。
  static const _tabs = [
    (
      AppTab.home,
      '首页',
      'assets/images/icon_nav_home_off.png',
      'assets/images/icon_nav_home.png',
    ),
    (
      AppTab.mall,
      '商城',
      'assets/images/icon_nav_mall_off.png',
      'assets/images/icon_nav_mall.png',
    ),
    (
      AppTab.cart,
      '购物车',
      'assets/images/icon_nav_cart_off.png',
      'assets/images/icon_nav_cart.png',
    ),
    (
      AppTab.profile,
      '我的',
      'assets/images/icon_nav_profile_off.png',
      'assets/images/icon_nav_profile.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final totalCount = context.watch<CartProvider>().totalCount;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        top: AppScale.s(2),
        bottom: MediaQuery.paddingOf(context).bottom + AppScale.s(8),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final isActive = active == tab.$1;
          final showBadge = tab.$1 == AppTab.cart && totalCount > 0;
          return Expanded(
            child: AppInkWell(
              onTap: () => onChange(tab.$1),
              enablePressScale: true,
              enableParticle: true,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          isActive ? tab.$4 : tab.$3,
                          width: AppScale.s(40),
                          height: AppScale.s(40),
                        ),
                        if (showBadge)
                          Positioned(
                            top: AppScale.s(-4),
                            right: AppScale.s(-10),
                            child: Container(
                              constraints: BoxConstraints(
                                minWidth: AppScale.s(18),
                                minHeight: AppScale.s(18),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: AppScale.s(5),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppScale.s(999),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                totalCount > 99 ? '99+' : '$totalCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppScale.t(11),
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: AppScale.s(4)),
                    Text(
                      tab.$2,
                      style: AppTheme.baseText.copyWith(
                        fontSize: AppScale.t(16),
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
