import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/support_chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../services/xiaodou_chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../widgets/click_effect/app_pressable.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/xiaodou_agent_card.dart';
import 'orders_sheet.dart';
import 'support_chat_page.dart';
import 'xiaodou_chat_page.dart';

/// 聚合消息页（底部导航正中间，hx 2026-11-23 拍板）：把原本散在三处
/// 的消息收成一页——交易通知（原「我的」页铃铛）、客服会话、小豆盘点
/// 提醒，再加上全部通知的时间流。本页不造新数据：通知读 UserProvider、
/// 客服读 SupportChatProvider 的会话汇总、提醒读 XiaodouChatProvider
/// 的进门盘点（briefing），三处都拉不到就静默降级，不弹错。
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  @override
  void initState() {
    super.initState();
    // 进页刷新三路数据：通知走远程重拉、客服走会话汇总、小豆走重新盘点。
    // 注意：本页被 _KeepAlivePage 保活，initState 只跑一次；之后的新消息
    // 靠各 provider 自身的变化（登录绑定、聊完客服刷新汇总）带动重绘，
    // 这里只负责第一次进页时把数拉齐。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserProvider>().loadFromRemote();
      context.read<SupportChatProvider>().refreshConversationSummaries();
      context.read<XiaodouChatProvider>().refreshBriefing();
    });
  }

  /// 小豆提醒行的副标题：把盘点事项翻成人话，最多拼两件，多的用总数兜底。
  /// 输入：盘点事项列表；输出：一行展示文案。金额格式与小豆简报卡共用
  /// formatYuan，避免两处写出两种价格样子。
  String _xiaodouSummary(List<BriefingMatter> matters) {
    final parts = <String>[];
    for (final matter in matters.take(2)) {
      if (matter.isPendingOrder) {
        parts.add('有订单还没付款 · 应付 ${formatYuan(matter.total)}');
      } else {
        parts.add('『${matter.title}』快到期了');
      }
    }
    if (matters.length > 2) {
      parts.add('共 ${matters.length} 件事待办');
    }
    return parts.join('；');
  }

  /// 时间流单条点击：与原铃铛页行为完全一致（点即标已读、support 类
  /// 进客服、带 order 目标的进订单列表）。区别只有一条：本页是标签页
  /// 不是弹出的子页，跳转前不 pop。
  void _onNotificationTap(BuildContext context, AppNotification n) {
    context.read<UserProvider>().markNotificationRead(n.id);
    if (n.type == NotificationType.support) {
      SupportChatPage.openGeneral(context);
      return;
    }
    if (n.targetType == 'order') {
      OrdersSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final support = context.watch<SupportChatProvider>();
    final xiaodou = context.watch<XiaodouChatProvider>();
    final notifications = user.notifications;
    final matters = xiaodou.briefingMatters;
    final top = MediaQuery.paddingOf(context).top;

    return SparkleBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppScale.s(16),
              top + AppScale.s(16),
              AppScale.s(16),
              AppScale.s(12),
            ),
            child: Text('消息', style: FeaturePageStyle.pageTitle()),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppScale.s(16),
                AppScale.s(4),
                AppScale.s(16),
                AppScale.s(24),
              ),
              children: [
                _EntryRow(
                  icon: Icons.notifications_outlined,
                  title: '交易通知',
                  subtitle: notifications.isEmpty
                      ? '暂无新通知'
                      : (notifications.first.body.isNotEmpty
                          ? notifications.first.body
                          : notifications.first.title),
                  badgeCount: user.unreadNotificationCount,
                  onTap: () => NotificationSheet.show(context),
                ),
                SizedBox(height: AppScale.s(10)),
                _EntryRow(
                  icon: Icons.support_agent_outlined,
                  title: '客服中心',
                  subtitle: support.latestSupportPreview ?? '有问题随时找客服',
                  badgeCount: support.supportUnreadTotal,
                  onTap: () => SupportChatPage.openGeneral(context),
                ),
                // 小豆提醒是条件行：没有待办事项时整行不显示、不占位，
                // 角标就是事项数（与底部导航消息角标的口径一致）。
                if (matters.isNotEmpty) ...[
                  SizedBox(height: AppScale.s(10)),
                  _EntryRow(
                    icon: Icons.auto_awesome_outlined,
                    title: '小豆提醒',
                    subtitle: _xiaodouSummary(matters),
                    badgeCount: matters.length,
                    onTap: () => XiaodouChatPage.open(context),
                  ),
                ],
                SizedBox(height: AppScale.s(20)),
                Text('全部消息', style: FeaturePageStyle.sectionTitle()),
                SizedBox(height: AppScale.s(8)),
                if (notifications.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(24)),
                    child: Center(
                      child: Text('暂无消息', style: FeaturePageStyle.empty()),
                    ),
                  )
                else
                  for (var i = 0; i < notifications.length; i++) ...[
                    if (i > 0)
                      Divider(color: AppColors.border, height: AppScale.s(16)),
                    _NotificationTile(
                      notification: notifications[i],
                      onTap: () => _onNotificationTap(context, notifications[i]),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 固定入口行：图标 + 标题 + 一行预览副标题 + 数字角标。
/// 角标规则与底部导航一致：0 不显示（不占位），超过 99 显示 99+。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppScale.s(14)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppScale.s(14),
          vertical: AppScale.s(12),
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(14)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: AppScale.s(40),
              height: AppScale.s(40),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: AppScale.s(21)),
            ),
            SizedBox(width: AppScale.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FeaturePageStyle.bodyBold()),
                  SizedBox(height: AppScale.s(3)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FeaturePageStyle.secondary(),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              SizedBox(width: AppScale.s(8)),
              _CountBadge(count: badgeCount),
            ],
            SizedBox(width: AppScale.s(4)),
            Icon(
              Icons.chevron_right,
              color: AppColors.mutedForeground,
              size: AppScale.s(18),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数字角标（入口行与消息页内共用）：样式对齐底部导航角标，主色圆角条。
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: AppScale.s(20),
        minHeight: AppScale.s(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(6)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppScale.s(999)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: AppScale.t(11),
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

/// 时间流单条：照原铃铛页的渲染（未读小红点 + 标题/正文/时间），
/// 单条只用红点不用数字——数字角标只出现在入口行与底部导航。
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return AppInkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!n.read)
            Container(
              width: AppScale.s(10),
              height: AppScale.s(10),
              margin: EdgeInsets.only(top: AppScale.s(8), right: AppScale.s(10)),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            )
          else
            SizedBox(width: AppScale.s(20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: FeaturePageStyle.bodyBold()),
                SizedBox(height: AppScale.s(6)),
                Text(
                  n.body,
                  style: FeaturePageStyle.body(color: AppColors.mutedForeground),
                ),
                SizedBox(height: AppScale.s(6)),
                Text(n.time, style: FeaturePageStyle.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
