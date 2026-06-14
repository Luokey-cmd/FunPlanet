import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/sparkle_background.dart';
import 'checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasItems = cart.items.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;

    return SparkleBackground(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(AppScale.s(16), top + AppScale.s(16), AppScale.s(16), AppScale.s(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('购物车', style: TextStyle(fontSize: AppScale.s(20), fontWeight: FontWeight.bold)),
                Text(
                  hasItems ? '共 ${cart.totalCount} 件商品' : '购物车空空如也',
                  style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasItems
                ? ListView(
                    padding: EdgeInsets.all(AppScale.s(16)),
                    children: cart.items.map((item) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: AppScale.s(12)),
                        child: _CartItemTile(item: item),
                      );
                    }).toList(),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: AppScale.s(48), color: AppColors.mutedForeground),
                        SizedBox(height: AppScale.s(12)),
                        Text('去商城挑选心仪的潮玩吧', style: TextStyle(fontSize: AppScale.s(14), color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
          ),
          if (hasItems)
            Container(
              padding: EdgeInsets.all(AppScale.s(16)),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text('合计', style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground)),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '¥${cart.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: AppScale.s(20), fontWeight: FontWeight.bold, color: AppColors.priceRed),
                  ),
                  SizedBox(width: AppScale.s(16)),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppScale.s(999)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => CheckoutPage.openFromCart(context),
                          borderRadius: BorderRadius.circular(AppScale.s(999)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppScale.s(14)),
                            child: Text(
                              '去结算 · ${cart.totalCount}件',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: AppScale.s(16)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(16)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          ProductThumbnail(product: item.product, width: AppScale.s(64), height: AppScale.s(64)),
          SizedBox(width: AppScale.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.product.name, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: () => cart.removeItem(item.product.id),
                      child: Icon(Icons.delete_outline, size: AppScale.s(16), color: AppColors.mutedForeground),
                    ),
                  ],
                ),
                if (item.spec != null)
                  Text(item.spec!, style: TextStyle(fontSize: AppScale.s(11), color: AppColors.mutedForeground)),
                SizedBox(height: AppScale.s(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${(item.product.price * item.quantity).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppScale.s(14), color: AppColors.priceRed),
                    ),
                    Row(
                      children: [
                        _QtyButton(icon: Icons.remove, onTap: () => cart.updateQuantity(item.product.id, -1)),
                        SizedBox(
                          width: AppScale.s(24),
                          child: Text('${item.quantity}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        _QtyButton(icon: Icons.add, primary: true, onTap: () => cart.updateQuantity(item.product.id, 1)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap, this.primary = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primary : AppColors.muted,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppScale.s(28),
          height: AppScale.s(28),
          child: Icon(icon, size: AppScale.s(14), color: primary ? Colors.white : AppColors.foreground),
        ),
      ),
    );
  }
}
