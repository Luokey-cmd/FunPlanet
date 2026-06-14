import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../pages/search_page.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'category_chip_bar.dart';
import 'drift_bottle_backdrop.dart';
import 'notification_sheet.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppScale.s(16), top + AppScale.s(8), AppScale.s(16), AppScale.s(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        appLogoPath,
                        height: AppScale.s(83.2),
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        filterQuality: FilterQuality.high,
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      _NotifyButton(onTap: () => NotificationSheet.show(context)),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: AppScale.s(-8),
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, AppScale.s(18)),
                        child: FractionalTranslation(
                          translation: const Offset(0.35, -0.20),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              DriftBottleBackdrop(bottleHeight: 156.4),
                              Transform.rotate(
                                angle: 15 * pi / 180,
                                child: Image.asset(
                                  driftBottlePath,
                                  height: AppScale.s(156.4),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppScale.s(12)),
              GestureDetector(
                onTap: () => SearchPage.open(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(10)),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppScale.s(999)),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: AppScale.s(18), color: AppColors.mutedForeground),
                      SizedBox(width: AppScale.s(8)),
                      Text(
                        '搜索商品 / 角色 / 周边',
                        style: TextStyle(fontSize: AppScale.s(13), color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppScale.s(6)),
              CategoryChipBar(
                activeId: '',
                compact: true,
                highlightActive: false,
                padding: EdgeInsets.zero,
                chipHorizontalPadding: 18.5,
                chipVerticalPadding: 3.9,
                barHeight: 33.8,
                onSelected: (cat) => SearchPage.open(context, initialQuery: cat.name),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotifyButton extends StatelessWidget {
  const _NotifyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, user, _) {
        final unread = user.unreadNotificationCount;
        const iconSize = 26.0;
        const padding = 10.0;
        final buttonSize = AppScale.s(padding * 2 + iconSize);
        return Transform.translate(
          offset: Offset(-buttonSize * 0.3, buttonSize * 0.1),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppScale.s(999)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(AppScale.s(padding)),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Icon(Icons.notifications_outlined, size: AppScale.s(iconSize), color: AppColors.foreground),
                ),
                if (unread > 0)
                  Positioned(
                    top: AppScale.s(3),
                    right: AppScale.s(3),
                    child: Container(
                      width: AppScale.s(9),
                      height: AppScale.s(9),
                      decoration: const BoxDecoration(color: AppColors.priceRed, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
