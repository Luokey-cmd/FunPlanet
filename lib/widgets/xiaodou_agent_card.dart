import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agent_records.dart';
import '../pages/orders_sheet.dart';
import '../pages/user_feature_sheets.dart';
import '../providers/app_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/click_effect/app_buttons.dart';

/// 清单条目点击后跳哪：聊天页与办事记录页共用一份，别两边各写一套。
/// target.page 的口径与服务端办事工具写死的一致：
/// cart / coupons / favorites / order / addresses。
void openAgentActionTarget(BuildContext context, AgentAction action) {
  final page = action.target['page'];
  switch (page) {
    case 'cart':
      // 小豆页是盖在主界面上的路由：先退回去，再切到购物车标签
      Navigator.of(context).maybePop();
      context.read<AppTabProvider>().goTo(AppTab.cart);
    case 'coupons':
      UserFeatureSheets.showCoupons(context);
    case 'favorites':
      UserFeatureSheets.showFavorites(context);
    case 'order':
      OrdersSheet.show(context);
    case 'addresses':
      UserFeatureSheets.showAddresses(context);
  }
}

String formatYuan(double value) =>
    '¥${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

/// 办事清单卡：跟在小豆气泡下方，上段是功课、下段是办成的事，
/// 涉及下单时卡尾多一道付款闸（账算清 + 确认下单按钮）。
/// 清单是快照：跳出去改完回来，这张卡不实时刷新（设计稿定版口径）。
class XiaodouAgentCard extends StatefulWidget {
  const XiaodouAgentCard({
    super.key,
    required this.homework,
    required this.actions,
    required this.onTarget,
    required this.onPay,
  });

  final List<HomeworkEntry> homework;
  final List<AgentAction> actions;
  final ValueChanged<AgentAction> onTarget;

  /// 点「确认下单」：返回 true 表示付款成功（卡片据此收起付款闸）。
  final Future<bool> Function(AgentAction action) onPay;

  @override
  State<XiaodouAgentCard> createState() => _XiaodouAgentCardState();
}

class _XiaodouAgentCardState extends State<XiaodouAgentCard> {
  final Set<int> _expandedHomework = {};
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.actions.where((a) => a.status == 'done').length;
    final savedTotal = widget.actions.fold<double>(0, (sum, a) => sum + a.saved);
    final pendingOrder = widget.actions.where((a) => a.isPendingOrder).firstOrNull;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: AppScale.s(10)),
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.homework.isNotEmpty) ...[
            _sectionTitle('先帮你做了这些功课'),
            SizedBox(height: AppScale.s(6)),
            for (var i = 0; i < widget.homework.length; i++) _homeworkRow(i, widget.homework[i]),
          ],
          if (widget.homework.isNotEmpty && widget.actions.isNotEmpty)
            Divider(height: AppScale.s(18), color: AppColors.border),
          if (widget.actions.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    pendingOrder != null
                        ? '已帮你办好 $doneCount 件事 · 1 件待付款'
                        : '已帮你办好 $doneCount 件事',
                  ),
                ),
                if (savedTotal > 0)
                  Text(
                    '共省 ${formatYuan(savedTotal)}',
                    style: TextStyle(
                      fontSize: AppScale.t(12),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppScale.s(4)),
            for (final action in widget.actions) _actionRow(action),
          ],
          if (pendingOrder != null) _paymentTail(pendingOrder),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppScale.t(12.5),
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      ),
    );
  }

  Widget _homeworkRow(int index, HomeworkEntry entry) {
    final expandable = entry.candidates.isNotEmpty;
    final expanded = _expandedHomework.contains(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: expandable
              ? () => setState(() {
                    if (expanded) {
                      _expandedHomework.remove(index);
                    } else {
                      _expandedHomework.add(index);
                    }
                  })
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppScale.s(3)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
                Expanded(
                  child: Text(
                    entry.text,
                    style: TextStyle(fontSize: AppScale.t(12), height: 1.4, color: AppColors.mutedForeground),
                  ),
                ),
                if (expandable)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: AppScale.s(16),
                    color: AppColors.mutedForeground,
                  ),
              ],
            ),
          ),
        ),
        if (expandable && expanded)
          Padding(
            padding: EdgeInsets.only(left: AppScale.s(10), bottom: AppScale.s(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in entry.candidates)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(1.5)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.foreground),
                          ),
                        ),
                        Text(
                          formatYuan(c.price),
                          style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionRow(AgentAction action) {
    final failed = action.status == 'failed';
    final pending = action.status == 'pending';
    final icon = failed
        ? Icons.cancel
        : pending
            ? Icons.schedule
            : Icons.check_circle;
    final iconColor = failed
        ? const Color(0xFFDC2626)
        : pending
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);
    final subtitle = failed ? (action.failReason ?? '') : action.detail;
    return InkWell(
      onTap: action.target.isEmpty ? null : () => widget.onTarget(action),
      borderRadius: BorderRadius.circular(AppScale.s(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppScale.s(5), horizontal: AppScale.s(2)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppScale.s(17), color: iconColor),
            SizedBox(width: AppScale.s(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppScale.t(11.5),
                        height: 1.35,
                        color: failed ? const Color(0xFFDC2626) : AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            if (action.target.isNotEmpty)
              Text(
                failed
                    ? ((action.failReason ?? '').contains('开通会员') ? '去开通' : '自己去办')
                    : '查看',
                style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  // 付款闸：账先算清（合计/用券/运费/应付）才给确认按钮；
  // 不点就停在待付款，不催单（设计稿定版口径）。
  Widget _paymentTail(AgentAction action) {
    final payment = action.payment!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: AppScale.s(18), color: AppColors.border),
        Text(
          '还差最后一步：确认下单',
          style: TextStyle(fontSize: AppScale.t(12.5), fontWeight: FontWeight.w700, color: AppColors.foreground),
        ),
        SizedBox(height: AppScale.s(6)),
        _moneyRow('商品合计', formatYuan(payment.subtotal)),
        if (payment.discount > 0)
          _moneyRow(
            '优惠券${payment.couponTitle != null ? '（${payment.couponTitle}）' : ''}',
            '-${formatYuan(payment.discount)}',
          ),
        _moneyRow('运费', payment.freight > 0 ? formatYuan(payment.freight) : '免运费'),
        SizedBox(height: AppScale.s(4)),
        Row(
          children: [
            Expanded(
              child: Text(
                '应付 ${formatYuan(payment.total)}',
                style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w800, color: AppColors.foreground),
              ),
            ),
            AppFilledButton(
              onPressed: _paying
                  ? null
                  : () async {
                      setState(() => _paying = true);
                      final ok = await widget.onPay(action);
                      if (mounted && !ok) setState(() => _paying = false);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(18), vertical: AppScale.s(9)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _paying
                  ? SizedBox(
                      width: AppScale.s(16),
                      height: AppScale.s(16),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('确认下单', style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moneyRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppScale.s(1.5)),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
          ),
          Text(value, style: TextStyle(fontSize: AppScale.t(12), color: AppColors.foreground)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
