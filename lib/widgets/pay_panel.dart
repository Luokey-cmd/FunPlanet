import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/order_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

/// 全 App 统一的支付面板（hx 2026-11-27 定形式，照参考图只学样子、
/// 数据全用咱们订单的真实值）：顶部 ¥ 圆图标＋「请完成支付」、大号
/// 金额、订单号、30 分钟剩余支付时间倒计时、微信/支付宝二选一
/// （默认微信）、底部整宽「确认支付」。
///
/// 入口只有这一处：小豆代买卡的「去支付」、订单列表与订单详情的
/// 「去支付」都调它，不许各页再自己拼支付界面。
/// 输入：待付款订单；onPaid 在模拟支付成功、面板关掉之后回调，
/// 带回支付后的最新订单（小豆那边据此回刷卡片并在对话里收尾）。
/// 关掉面板不付款：什么都不发生，订单保持待付款、之后照样能再付。
Future<void> showPayPanel(
  BuildContext context, {
  required Order order,
  ValueChanged<Order>? onPaid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(20))),
    ),
    builder: (_) => _PayPanel(order: order, onPaid: onPaid),
  );
}

class _PayPanel extends StatefulWidget {
  const _PayPanel({required this.order, this.onPaid});

  final Order order;
  final ValueChanged<Order>? onPaid;

  @override
  State<_PayPanel> createState() => _PayPanelState();
}

class _PayPanelState extends State<_PayPanel> {
  // 支付方式：wechat 默认选中（hx 定的口径），alipay 备选。
  String _method = 'wechat';
  bool _paying = false;
  String? _error;
  Timer? _timer;
  late final DateTime _deadline;

  @override
  void initState() {
    super.initState();
    // 倒计时锚点：订单创建时间＋30 分钟。订单的 time 是服务端按
    // 「2026-11-27 16:40」格式给的下单时间，能解析；老订单早就过了
    // 30 分钟的、或解析不出的，从打开面板起重新给满 30 分钟——
    // 服务端没有超时自动关单，卡着不让付反而是假规矩。
    final now = DateTime.now();
    final created = DateTime.tryParse(widget.order.time.replaceFirst(' ', 'T'));
    var deadline = created?.add(const Duration(minutes: 30));
    if (deadline == null || !deadline.isAfter(now)) {
      deadline = now.add(const Duration(minutes: 30));
    }
    _deadline = deadline;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    var left = _deadline.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _confirm() async {
    if (_paying) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final orders = context.read<OrderProvider>();
      await orders.payOrder(widget.order.id);
      final updated = orders.orders.firstWhere(
        (o) => o.id == widget.order.id,
        orElse: () => widget.order,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onPaid?.call(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = '支付失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(12), AppScale.s(20), AppScale.s(16) + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: _paying ? null : () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: AppScale.s(20), color: AppColors.mutedForeground),
              ),
            ],
          ),
          Container(
            width: AppScale.s(54),
            height: AppScale.s(54),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFF7A45), AppColors.priceRed]),
            ),
            child: Center(
              child: Text(
                '¥',
                style: TextStyle(fontSize: AppScale.t(26), fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: AppScale.s(10)),
          Text(
            '请完成支付',
            style: TextStyle(fontSize: AppScale.t(17), fontWeight: FontWeight.w700, color: AppColors.foreground),
          ),
          SizedBox(height: AppScale.s(6)),
          Text(
            '¥${widget.order.total.toStringAsFixed(2)}',
            style: TextStyle(fontSize: AppScale.t(34), fontWeight: FontWeight.w800, color: AppColors.priceRed),
          ),
          SizedBox(height: AppScale.s(14)),
          _infoRow('订单号', widget.order.orderNo),
          SizedBox(height: AppScale.s(6)),
          _infoRow('剩余支付时间', _countdown, valueColor: AppColors.priceRed),
          SizedBox(height: AppScale.s(18)),
          Row(
            children: [
              Expanded(child: _methodBox('wechat', '微信支付', const Color(0xFF07C160), '微')),
              SizedBox(width: AppScale.s(12)),
              Expanded(child: _methodBox('alipay', '支付宝', const Color(0xFF1677FF), '支')),
            ],
          ),
          if (_error != null) ...[
            SizedBox(height: AppScale.s(10)),
            Text(_error!, style: TextStyle(fontSize: AppScale.t(12.5), color: AppColors.priceRed)),
          ],
          SizedBox(height: AppScale.s(18)),
          GestureDetector(
            onTap: _paying ? null : _confirm,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: AppScale.s(14)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8A5FD6), AppColors.primary]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _paying ? '支付中…' : '确认支付',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground)),
        SizedBox(width: AppScale.s(8)),
        Text(
          value,
          style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600, color: valueColor ?? AppColors.foreground),
        ),
      ],
    );
  }

  Widget _methodBox(String method, String label, Color badgeColor, String badgeText) {
    final selected = _method == method;
    return GestureDetector(
      onTap: _paying ? null : () => setState(() => _method = method),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppScale.s(12), horizontal: AppScale.s(10)),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(AppScale.s(12)),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppScale.s(26),
              height: AppScale.s(26),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(AppScale.s(7))),
              child: Center(
                child: Text(badgeText, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            SizedBox(width: AppScale.s(8)),
            Text(
              label,
              style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600, color: AppColors.foreground),
            ),
            if (selected) ...[
              SizedBox(width: AppScale.s(4)),
              Icon(Icons.check_circle, size: AppScale.s(16), color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
