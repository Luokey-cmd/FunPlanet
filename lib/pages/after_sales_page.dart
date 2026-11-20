import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../services/order_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../widgets/app_state_views.dart';
import '../widgets/feature_page_scaffold.dart';

// 「我的售后」页：展示用户提交过的售后申请和处理进度。
// 入口在「我的」页的「售后/退款」格子（OrdersSheet.show 按这个标题转到本页）。
// 数据来自服务端 GET /api/orders/after-sales，处理动作在管理后台完成，
// 这里只读：状态、类型、原因，以及后台填写的处理备注。
class AfterSalesPage extends StatefulWidget {
  const AfterSalesPage({super.key});

  static void open(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AfterSalesPage()),
    );
  }

  @override
  State<AfterSalesPage> createState() => _AfterSalesPageState();
}

class _AfterSalesPageState extends State<AfterSalesPage> {
  final _api = OrderApiService();
  late Future<List<AfterSaleRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchMyAfterSales();
  }

  Future<void> _reload() async {
    setState(() => _future = _api.fetchMyAfterSales());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '售后/退款',
      scrollable: false,
      child: FutureBuilder<List<AfterSaleRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return AppRefreshableEmpty(
              onRefresh: _reload,
              child: AppEmptyView(
                icon: Icons.assignment_return_outlined,
                message: '售后记录加载失败',
                actionLabel: '重试',
                onAction: () {
                  _reload();
                },
              ),
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return AppRefreshableEmpty(
              onRefresh: _reload,
              child: const AppEmptyView(
                icon: Icons.assignment_return_outlined,
                message: '暂无售后记录\n在订单上点「申请售后」后，进度会显示在这里',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: AppColors.primary,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => SizedBox(height: AppScale.s(12)),
              itemBuilder: (context, index) => _AfterSaleCard(request: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AfterSaleCard extends StatelessWidget {
  const _AfterSaleCard({required this.request});

  final AfterSaleRequest request;

  // 状态配色：待处理橙、已同意蓝、已完成绿、已拒绝红灰。
  ({Color color, Color background}) get _statusCfg => switch (request.status) {
        'approved' => (color: const Color(0xFF2563EB), background: const Color(0xFFEFF6FF)),
        'completed' => (color: const Color(0xFF16A34A), background: const Color(0xFFF0FDF4)),
        'rejected' => (color: const Color(0xFFDC2626), background: const Color(0xFFFEF2F2)),
        _ => (color: const Color(0xFFD97706), background: const Color(0xFFFFFBEB)),
      };

  @override
  Widget build(BuildContext context) {
    final cfg = _statusCfg;
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
              Text(request.orderNo, style: FeaturePageStyle.caption()),
              Container(
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
                decoration: BoxDecoration(
                  color: cfg.background,
                  borderRadius: BorderRadius.circular(AppScale.s(999)),
                ),
                child: Text(request.statusLabel, style: FeaturePageStyle.badge(color: cfg.color)),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(8)),
          Text('${request.typeLabel} · ${request.reason}', style: FeaturePageStyle.body()),
          if (request.description != null && request.description!.isNotEmpty) ...[
            SizedBox(height: AppScale.s(4)),
            Text(request.description!, style: FeaturePageStyle.secondary()),
          ],
          if (request.amount != null) ...[
            SizedBox(height: AppScale.s(4)),
            Text('申请金额 ¥${request.amount!.toStringAsFixed(2)}', style: FeaturePageStyle.secondary()),
          ],
          if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
            SizedBox(height: AppScale.s(6)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(8)),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppScale.s(8)),
              ),
              child: Text('商家回复：${request.adminNote}', style: FeaturePageStyle.secondary()),
            ),
          ],
          SizedBox(height: AppScale.s(8)),
          Text(_formatTime(request.createdAt), style: FeaturePageStyle.secondary()),
        ],
      ),
    );
  }
}

// 服务端给的是 ISO 时间字符串，展示成 2026-11-20 14:30 这种常见格式。
String _formatTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
