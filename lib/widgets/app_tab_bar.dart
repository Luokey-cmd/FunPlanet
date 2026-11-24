import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/support_chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';

import '../widgets/click_effect/app_pressable.dart';

// 顺序即底部导航从左到右的顺序，也是 main_screen 里 _pages 的下标顺序，
// 两边必须一一对应；「消息」固定在正中间（hx 2026-11-23 拍板）。
enum AppTab { home, mall, message, cart, profile }

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
      AppTab.message,
      '消息',
      'assets/images/icon_nav_message_off.png',
      'assets/images/icon_nav_message.png',
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
    // 消息角标 = 消息页三行角标之和（hx 2026-11-23 定：内外必须一致）：
    // 未读通知 + 客服未读 + 小豆盘点事项数（待付款笔数 + 快到期券张数）。
    // 小豆事项办完/过期后盘点自然归零，角标跟着消，不会赖着不走。
    final messageCount = context.watch<UserProvider>().unreadNotificationCount +
        context.watch<SupportChatProvider>().supportUnreadTotal +
        context.watch<XiaodouChatProvider>().briefingMatters.length;

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
          // 角标数按格子分开算：购物车数件数、消息数三行之和，其余格子不挂。
          final badgeCount = tab.$1 == AppTab.cart
              ? totalCount
              : tab.$1 == AppTab.message
                  ? messageCount
                  : 0;
          final showBadge = badgeCount > 0;
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
                                badgeCount > 99 ? '99+' : '$badgeCount',
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
