import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../widgets/feature_page_scaffold.dart';

class CouponPickerPage extends StatelessWidget {
  const CouponPickerPage({
    super.key,
    required this.eligible,
    required this.selectedCouponId,
  });

  final List<Coupon> eligible;
  final String? selectedCouponId;

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '选择优惠券',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('不使用优惠券', style: FeaturePageStyle.bodyBold()),
            trailing: selectedCouponId == null ? Icon(Icons.check_circle, color: AppColors.primary, size: FeaturePageStyle.iconSize) : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          ...eligible.map((coupon) {
            final selected = selectedCouponId == coupon.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(coupon.title, style: FeaturePageStyle.bodyBold()),
              subtitle: Text(
                '${coupon.condition} · 减 ¥${coupon.discount.toStringAsFixed(0)}',
                style: FeaturePageStyle.secondary(),
              ),
              trailing: selected ? Icon(Icons.check_circle, color: AppColors.primary, size: FeaturePageStyle.iconSize) : null,
              onTap: () => Navigator.pop(context, coupon.id),
            );
          }),
          if (eligible.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: FeaturePageStyle.s(16)),
              child: Text('暂无可用优惠券', style: FeaturePageStyle.empty()),
            ),
        ],
      ),
    );
  }
}
