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

  static const _tabs = [
    (AppTab.home, '首页', Icons.home_outlined, Icons.home),
    (AppTab.mall, '商城', Icons.storefront_outlined, Icons.storefront),
    (AppTab.cart, '购物车', Icons.shopping_cart_outlined, Icons.shopping_cart),
    (AppTab.profile, '我的', Icons.person_outline, Icons.person),
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
        top: AppScale.s(4),
        bottom: MediaQuery.paddingOf(context).bottom + AppScale.s(16),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final isActive = active == tab.$1;
          final showBadge = tab.$1 == AppTab.cart && totalCount > 0;
          return Expanded(
            child: AppInkWell(
              onTap: () => onChange(tab.$1),
              splashColor: AppColors.primary.withValues(alpha: 0.12),
              highlightColor: AppColors.primary.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedScale(
                          scale: isActive ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isActive ? tab.$4 : tab.$3,
                              key: ValueKey('${tab.$1}_$isActive'),
                              size: AppScale.s(32),
                              color: isActive ? AppColors.primary : AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        if (showBadge)
                          Positioned(
                            top: AppScale.s(-4),
                            right: AppScale.s(-10),
                            child: Container(
                              constraints: BoxConstraints(minWidth: AppScale.s(18), minHeight: AppScale.s(18)),
                              padding: EdgeInsets.symmetric(horizontal: AppScale.s(5)),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(AppScale.s(999)),
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
                    SizedBox(height: AppScale.s(6)),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: AppTheme.baseText.copyWith(
                        fontSize: AppScale.t(16),
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? AppColors.primary : AppColors.mutedForeground,
                      ),
                      child: Text(tab.$2),
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
