import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'click_effect/app_buttons.dart';

/// 统一空态（参考 peduliAI placeholder 模式）。
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppScale.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppScale.s(48), color: AppColors.mutedForeground),
            SizedBox(height: AppScale.s(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppScale.t(14), color: AppColors.mutedForeground),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: AppScale.s(16)),
              AppFilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统一错误态 + 重试。
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.message = '加载失败，请稍后重试',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      icon: Icons.error_outline_rounded,
      message: message,
      actionLabel: onRetry == null ? null : '重试',
      onAction: onRetry,
    );
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.4),
          if (label != null) ...[
            SizedBox(height: AppScale.s(12)),
            Text(label!, style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground)),
          ],
        ],
      ),
    );
  }
}

/// 空列表仍可下拉刷新。
class AppRefreshableEmpty extends StatelessWidget {
  const AppRefreshableEmpty({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          child,
        ],
      ),
    );
  }
}
