import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/order_provider.dart';
import '../services/order_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../utils/user_session_sync.dart';
import '../widgets/feature_page_scaffold.dart';
import 'after_sales_page.dart';
import 'order_review_page.dart';
import 'order_review_detail_page.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/app_state_views.dart';

class OrdersSheet {
  static void show(BuildContext context, {String? filterLabel}) {
    unawaited(refreshSessionData(context));
    // 「售后/退款」以前只能看已取消订单；现在服务端有真正的售后申请了，
    // 这个入口改到售后记录页，取消订单仍可在「全部订单」里看到。
    if (filterLabel == '售后/退款') {
      AfterSalesPage.open(context);
      return;
    }
    OrderFilter filter = OrderFilter.all;
    if (filterLabel == '待付款') filter = OrderFilter.unpaid;
    if (filterLabel == '待发货') filter = OrderFilter.toShip;
    if (filterLabel == '待收货') filter = OrderFilter.shipping;
    if (filterLabel == '已完成') filter = OrderFilter.completed;
    if (filterLabel == '待评价') filter = OrderFilter.review;
    if (filterLabel == '我的评价') filter = OrderFilter.reviewed;

    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _OrdersPage(filter: filter, title: filterLabel ?? '我的订单')),
    );
  }
}

class _OrdersPage extends StatefulWidget {
  const _OrdersPage({required this.filter, required this.title});

  final OrderFilter filter;
  final String title;

  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<OrderProvider>().loadFromRemote());
    });
  }

  Future<void> _onRefresh() => context.read<OrderProvider>().loadFromRemote();

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: widget.title,
      scrollable: false,
      child: Consumer<OrderProvider>(
        builder: (context, orders, _) {
          final list = orders.filtered(widget.filter);
          if (list.isEmpty) {
            return AppRefreshableEmpty(
              onRefresh: _onRefresh,
              child: AppEmptyView(
                icon: Icons.receipt_long_outlined,
                message: orders.lastError == null ? '暂无订单' : '订单加载失败\n${orders.lastError}',
                actionLabel: orders.lastError == null ? null : '重试',
                onAction: orders.lastError == null ? null : () => unawaited(_onRefresh()),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => SizedBox(height: AppScale.s(12)),
              itemBuilder: (context, index) {
                final order = list[index];
                final cfg = orderStatusConfig(order.status);
                return Container(
                padding: FeaturePageStyle.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.orderNo, style: FeaturePageStyle.caption()),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
                          decoration: BoxDecoration(
                            color: cfg.background,
                            borderRadius: BorderRadius.circular(AppScale.s(999)),
                          ),
                          child: Text(cfg.label, style: FeaturePageStyle.badge(color: cfg.color)),
                        ),
                      ],
                    ),
                    SizedBox(height: AppScale.s(10)),
                    ...order.items.map(
                      (item) {
                        if (item.productId == null || order.status != OrderStatus.completed) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: AppScale.s(4)),
                            child: Text('${item.name} x${item.quantity}', style: FeaturePageStyle.body()),
                          );
                        }
                        final reviewed = order.isProductReviewed(item.productId);
                        return Padding(
                          padding: EdgeInsets.only(bottom: AppScale.s(4)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text('${item.name} x${item.quantity}', style: FeaturePageStyle.body()),
                              ),
                              SizedBox(width: AppScale.s(8)),
                              _ReviewChip(
                                order: order,
                                item: item,
                                viewMode: reviewed,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // 物流信息：后台发货时填了快递单号才有，老订单没有就不显示这一行。
                    if (order.hasTracking) ...[
                      SizedBox(height: AppScale.s(8)),
                      Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: AppScale.s(15), color: AppColors.primary),
                          SizedBox(width: AppScale.s(6)),
                          Expanded(
                            child: Text(
                              '${order.shippingCompany ?? '快递'} ${order.trackingNo}',
                              style: FeaturePageStyle.body(),
                            ),
                          ),
                          if (order.shippedAt != null)
                            Text(_formatTime(order.shippedAt!), style: FeaturePageStyle.secondary()),
                        ],
                      ),
                    ],
                    if (order.remark != null && order.remark!.isNotEmpty) ...[
                      SizedBox(height: AppScale.s(6)),
                      Text('备注：${order.remark}', style: FeaturePageStyle.secondary()),
                    ],
                    SizedBox(height: AppScale.s(10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.time, style: FeaturePageStyle.secondary()),
                        Text('¥${order.total.toStringAsFixed(2)}', style: FeaturePageStyle.priceLarge()),
                      ],
                    ),
                    // 待付款订单在这里补上「去支付」：以前列表里没有支付入口，
                    // 用户从「我的-待付款」进来也付不了款，只能干看着。
                    if (order.status == OrderStatus.pending) ...[
                      SizedBox(height: AppScale.s(10)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _PayButton(order: order),
                      ),
                    ],
                    // 已付款/已发货/已完成的订单可以申请售后（和服务端允许的状态一致），
                    // 提交后到「售后/退款」页看进度，后台处理。
                    if (order.status == OrderStatus.paid ||
                        order.status == OrderStatus.shipping ||
                        order.status == OrderStatus.completed) ...[
                      SizedBox(height: AppScale.s(10)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _AfterSaleButton(order: order),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  const _ReviewChip({
    required this.order,
    required this.item,
    required this.viewMode,
  });

  final Order order;
  final OrderItem item;
  final bool viewMode;

  void _onTap(BuildContext context) {
    if (item.productId == null) return;
    if (viewMode) {
      OrderReviewDetailPage.open(
        context,
        orderId: order.id,
        productId: item.productId!,
        productName: item.name,
      );
      return;
    }
    OrderReviewPage.open(
      context,
      orderId: order.id,
      productId: item.productId!,
      productName: item.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = viewMode ? '查看评价' : '去评价';
    final color = viewMode ? const Color(0xFF16A34A) : AppColors.primary;
    final background = viewMode ? const Color(0xFFF0FDF4) : AppColors.primary.withValues(alpha: 0.12);

    return AppGestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
        ),
        child: Text(label, style: FeaturePageStyle.badge(color: color)),
      ),
    );
  }
}

// 服务端时间是 ISO 字符串，订单卡上只展示到分钟。
String _formatTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

// 「申请售后」按钮：点开底部表单，选类型、填原因后提交到服务端。
class _AfterSaleButton extends StatelessWidget {
  const _AfterSaleButton({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(18))),
          ),
          builder: (_) => _AfterSaleSheet(order: order),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(6)),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppScale.s(999)),
        ),
        child: Text('申请售后', style: FeaturePageStyle.badge(color: AppColors.primary)),
      ),
    );
  }
}

class _AfterSaleSheet extends StatefulWidget {
  const _AfterSaleSheet({required this.order});

  final Order order;

  @override
  State<_AfterSaleSheet> createState() => _AfterSaleSheetState();
}

class _AfterSaleSheetState extends State<_AfterSaleSheet> {
  final _api = OrderApiService();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'refund';
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      showTopSnackBar(
        context,
        content: Text('请先填写售后原因', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.applyAfterSale(
        widget.order.id,
        type: _type,
        reason: reason,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showTopSnackBar(
        context,
        content: Text('售后申请已提交，可在「售后/退款」里看进度', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showTopSnackBar(
        context,
        content: Text(e.toString(), style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  Widget _typeChip(String value, String label) {
    final selected = _type == value;
    return AppGestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(16), vertical: AppScale.s(8)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.secondary,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
        ),
        child: Text(
          label,
          style: FeaturePageStyle.badge(color: selected ? Colors.white : AppColors.foreground),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(18), AppScale.s(20), AppScale.s(18) + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('申请售后', style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.bold)),
          SizedBox(height: AppScale.s(4)),
          Text('订单 ${widget.order.orderNo}', style: FeaturePageStyle.secondary()),
          SizedBox(height: AppScale.s(14)),
          Row(
            children: [
              _typeChip('refund', '仅退款'),
              SizedBox(width: AppScale.s(10)),
              _typeChip('return', '退货退款'),
            ],
          ),
          SizedBox(height: AppScale.s(14)),
          AppTextField(
            controller: _reasonController,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: '售后原因（必填），如：商品有瑕疵',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            style: TextStyle(fontSize: AppScale.t(14)),
          ),
          SizedBox(height: AppScale.s(10)),
          AppTextField(
            controller: _descriptionController,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '补充说明（选填）',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            style: TextStyle(fontSize: AppScale.t(14)),
          ),
          SizedBox(height: AppScale.s(16)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
              ),
              child: Text(_submitting ? '提交中…' : '提交申请', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// 待付款订单的「去支付」按钮：样式与上面的评价小按钮保持一致。
// 支付走 OrderProvider.payOrder（服务端接口），成功后订单状态会变待发货、
// 列表自动刷新；失败只提示，不改本地状态，避免出现假已付订单。
class _PayButton extends StatelessWidget {
  const _PayButton({required this.order});

  final Order order;

  Future<void> _onTap(BuildContext context) async {
    try {
      await context.read<OrderProvider>().payOrder(order.id);
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        content: Text('支付成功，等待商家发货', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    } catch (_) {
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        content: Text('支付失败，请稍后重试', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(6)),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
        ),
        child: Text('去支付', style: FeaturePageStyle.badge(color: Colors.white)),
      ),
    );
  }
}
