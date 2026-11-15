import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../data/product_whispers.dart';
import '../pages/checkout_page.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_thumbnail.dart';

import '../widgets/click_effect/app_buttons.dart';
class XiaodouProductCard extends StatelessWidget {
  const XiaodouProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppScale.s(10)),
      padding: EdgeInsets.all(AppScale.s(10)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppScale.s(10)),
                child: ProductThumbnail(product: product, width: AppScale.s(72), height: AppScale.s(72)),
              ),
              SizedBox(width: AppScale.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppScale.t(13),
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: AppScale.s(6)),
                    Text(
                      '¥${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
                      style: TextStyle(
                        fontSize: AppScale.t(15),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: AppScale.s(4)),
                    Text(
                      whisperFor(product.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppScale.t(11),
                        height: 1.3,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(10)),
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  onPressed: () {
                    context.read<CartProvider>().addItem(product);
                    showTopSnackBar(
                      context,
                      content: Text(
                        '已加入购物车',
                        style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(8)),
                  ),
                  child: Text('加入购物车', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: AppScale.s(8)),
              Expanded(
                child: AppFilledButton(
                  onPressed: () => CheckoutPage.openBuyNow(context, product),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(8)),
                  ),
                  child: Text('立即购买', style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
