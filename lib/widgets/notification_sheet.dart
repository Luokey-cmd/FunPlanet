import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../widgets/feature_page_scaffold.dart';
import '../pages/orders_sheet.dart';
import '../pages/support_chat_page.dart';
import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_buttons.dart';

class NotificationSheet {
  static void show(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const _NotificationPage()),
    );
  }
}

class _NotificationPage extends StatefulWidget {
  const _NotificationPage();

  @override
  State<_NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<_NotificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadFromRemote();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '消息通知',
      actions: [
        AppTextButton(
          onPressed: () => context.read<UserProvider>().markAllNotificationsRead(),
          child: Text('全部已读', style: FeaturePageStyle.action()),
        ),
      ],
      scrollable: false,
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          if (user.notifications.isEmpty) {
            return Center(child: Text('暂无消息', style: FeaturePageStyle.empty()));
          }
          return ListView.separated(
            // padding 显式归零：不写时 ListView 会自带一份顶部安全区
            // 留白，和页面外框的间距叠加，列表顶部会空出一大截
            // （与订单列表修过的同款毛病）。
            padding: EdgeInsets.zero,
            itemCount: user.notifications.length,
            separatorBuilder: (_, _) => Divider(color: AppColors.border, height: AppScale.s(16)),
            itemBuilder: (context, index) {
              final n = user.notifications[index];
              return AppInkWell(
                onTap: () {
                  user.markNotificationRead(n.id);
                  if (n.type == NotificationType.support) {
                    Navigator.pop(context);
                    SupportChatPage.openGeneral(context);
                    return;
                  }
                  // 带跳转目标的通知（目前只有订单类）：点开直达订单列表。
                  if (n.targetType == 'order') {
                    Navigator.pop(context);
                    OrdersSheet.show(context);
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!n.read)
                      Container(
                        width: AppScale.s(10),
                        height: AppScale.s(10),
                        margin: EdgeInsets.only(top: AppScale.s(8), right: AppScale.s(10)),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      )
                    else
                      SizedBox(width: AppScale.s(20)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: FeaturePageStyle.bodyBold()),
                          SizedBox(height: AppScale.s(6)),
                          Text(n.body, style: FeaturePageStyle.body(color: AppColors.mutedForeground)),
                          SizedBox(height: AppScale.s(6)),
                          Text(n.time, style: FeaturePageStyle.caption()),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
