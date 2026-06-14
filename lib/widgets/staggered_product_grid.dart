import 'package:flutter/material.dart';
import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'product_card.dart';

class StaggeredProductGrid extends StatelessWidget {
  const StaggeredProductGrid({super.key, required this.products, this.scale = 1.0});

  final List<Product> products;
  final double scale;

  double _s(double value) => AppScale.s(value * scale);

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Text('暂无推荐商品', style: TextStyle(fontSize: _s(13), color: AppColors.mutedForeground));
    }

    final left = <Product>[];
    final right = <Product>[];
    for (var i = 0; i < products.length; i++) {
      (i.isEven ? left : right).add(products[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: left.map((p) {
              return Padding(
                padding: EdgeInsets.only(bottom: _s(10)),
                child: ProductCard(
                  product: p,
                  layout: ProductCardLayout.staggered,
                  scale: scale,
                  imageHeight: p.id.hashCode.isEven ? _s(130) : _s(160),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(width: _s(10)),
        Expanded(
          child: Column(
            children: right.map((p) {
              return Padding(
                padding: EdgeInsets.only(bottom: _s(10)),
                child: ProductCard(
                  product: p,
                  layout: ProductCardLayout.staggered,
                  scale: scale,
                  imageHeight: p.id.hashCode.isOdd ? _s(130) : _s(160),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
