import 'package:flutter/material.dart';

import '../services/review_api_service.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../widgets/feature_page_scaffold.dart';
import '../widgets/product_review_card.dart';

class OrderReviewDetailPage extends StatefulWidget {
  const OrderReviewDetailPage({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  final String orderId;
  final String productId;
  final String productName;

  static void open(
    BuildContext context, {
    required String orderId,
    required String productId,
    required String productName,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderReviewDetailPage(
          orderId: orderId,
          productId: productId,
          productName: productName,
        ),
      ),
    );
  }

  @override
  State<OrderReviewDetailPage> createState() => _OrderReviewDetailPageState();
}

class _OrderReviewDetailPageState extends State<OrderReviewDetailPage> {
  final _api = ReviewApiService();
  late Future<ProductReview> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchMyOrderReview(orderId: widget.orderId, productId: widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '我的评价',
      scrollable: true,
      child: FutureBuilder<ProductReview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text('评价加载失败', style: FeaturePageStyle.secondary()),
            );
          }

          final review = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.productName, style: FeaturePageStyle.body()),
              SizedBox(height: AppScale.s(12)),
              ProductReviewCard(review: review),
            ],
          );
        },
      ),
    );
  }
}
