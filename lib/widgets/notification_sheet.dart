import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../widgets/feature_page_scaffold.dart';
import '../pages/support_chat_page.dart';

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
        TextButton(
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
            itemCount: user.notifications.length,
            separatorBuilder: (_, _) => Divider(color: AppColors.border, height: AppScale.s(16)),
            itemBuilder: (context, index) {
              final n = user.notifications[index];
              return InkWell(
                onTap: () {
                  user.markNotificationRead(n.id);
                  if (n.type == NotificationType.support) {
                    Navigator.pop(context);
                    SupportChatPage.openGeneral(context);
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
