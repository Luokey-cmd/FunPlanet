import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../utils/user_session_sync.dart';
import '../widgets/feature_page_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static TextStyle get _itemTitle => FeaturePageStyle.title();

  static TextStyle get _itemSubtitle => FeaturePageStyle.body(color: AppColors.mutedForeground);

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '设置',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('消息推送', style: _itemTitle),
                value: user.pushEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: user.setPushEnabled,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('关于趣玩星球', style: _itemTitle),
                subtitle: Text('版本 1.0.0', style: _itemSubtitle),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('该APP作品由 黄恒鑫  个人开发完成！', style: _itemTitle),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('退出登录', style: _itemTitle.copyWith(color: AppColors.priceRed)),
                onTap: () async {
                  clearUserSession(context);
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
