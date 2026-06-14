import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/order_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/user_session_sync.dart';
import '../widgets/feature_page_scaffold.dart';
import 'order_review_page.dart';
import 'order_review_detail_page.dart';

class OrdersSheet {
  static void show(BuildContext context, {String? filterLabel}) {
    unawaited(refreshSessionData(context));
    OrderFilter filter = OrderFilter.all;
    if (filterLabel == '待发货') filter = OrderFilter.pending;
    if (filterLabel == '待收货') filter = OrderFilter.shipping;
    if (filterLabel == '已完成') filter = OrderFilter.completed;
    if (filterLabel == '售后/退款') filter = OrderFilter.cancelled;

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
            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: AppScale.s(120)),
                  Center(child: Text('暂无订单', style: FeaturePageStyle.empty())),
                ],
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
                    SizedBox(height: AppScale.s(10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.time, style: FeaturePageStyle.secondary()),
                        Text('¥${order.total.toStringAsFixed(2)}', style: FeaturePageStyle.priceLarge()),
                      ],
                    ),
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

    return GestureDetector(
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
