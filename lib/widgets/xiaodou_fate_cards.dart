import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../data/product_whispers.dart';
import '../pages/checkout_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/click_effect/app_buttons.dart';

class XiaodouFateBoard extends StatefulWidget {
  const XiaodouFateBoard({super.key, required this.products, required this.roles});

  final List<Product> products;
  final List<String> roles;

  @override
  State<XiaodouFateBoard> createState() => _XiaodouFateBoardState();
}

class _XiaodouFateBoardState extends State<XiaodouFateBoard> {
  final _flipped = <int>{};

  static const _labels = {
    'fate': '本命',
    'encounter': '遇见',
    'linger': '余韵',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppScale.s(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.products.length; i++) ...[
            if (i > 0) SizedBox(width: AppScale.s(8)),
            Expanded(
              child: _FateCard(
                product: widget.products[i],
                label: _labels[i < widget.roles.length ? widget.roles[i] : ''] ?? '星牌',
                flipped: _flipped.contains(i),
                onFlip: () => setState(() => _flipped.add(i)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FateCard extends StatelessWidget {
  const _FateCard({
    required this.product,
    required this.label,
    required this.flipped,
    required this.onFlip,
  });

  final Product product;
  final String label;
  final bool flipped;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flipped ? null : onFlip,
      child: flipped ? _front(context) : _back(),
    );
  }

  Widget _back() {
    return Container(
      height: AppScale.s(168),
      decoration: BoxDecoration(
        color: const Color(0xFF3D2B6B),
        borderRadius: BorderRadius.circular(AppScale.s(14)),
        border: Border.all(color: AppColors.primaryLight),
      ),
      padding: EdgeInsets.all(AppScale.s(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.gold, size: AppScale.s(22)),
          SizedBox(height: AppScale.s(8)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppScale.t(14),
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppScale.s(4)),
          Text('点开', style: TextStyle(fontSize: AppScale.t(11), color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _front(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppScale.s(8)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: AppScale.t(11), color: AppColors.primary, fontWeight: FontWeight.w700)),
          SizedBox(height: AppScale.s(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppScale.s(8)),
            child: ProductThumbnail(product: product, width: double.infinity, height: AppScale.s(72)),
          ),
          SizedBox(height: AppScale.s(6)),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppScale.t(11), fontWeight: FontWeight.w600, height: 1.25),
          ),
          Text(
            '¥${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
            style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          SizedBox(height: AppScale.s(4)),
          Text(
            whisperFor(product.id),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppScale.t(10), color: AppColors.mutedForeground, height: 1.3),
          ),
          SizedBox(height: AppScale.s(6)),
          AppFilledButton(
            onPressed: () => CheckoutPage.openBuyNow(context, product),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
              minimumSize: Size(0, AppScale.s(28)),
            ),
            child: Text('带走', style: TextStyle(fontSize: AppScale.t(11), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
