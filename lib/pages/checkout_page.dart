import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/coupon_utils.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/feature_page_scaffold.dart';
import '../widgets/product_thumbnail.dart';
import 'coupon_picker_page.dart';
import 'user_feature_sheets.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.items,
    this.fromCart = false,
  });

  final List<CartItem> items;
  final bool fromCart;

  static void openFromCart(BuildContext context) {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          items: List<CartItem>.from(cart.items),
          fromCart: true,
        ),
      ),
    );
  }

  static void openBuyNow(BuildContext context, Product product) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          items: [
            CartItem(product: product, quantity: 1, spec: product.spec),
          ],
        ),
      ),
    );
  }

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _submitting = false;
  String? _selectedCouponId;
  String? _selectedAddressId;

  double get _subtotal =>
      widget.items.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  Coupon? _selectedCoupon(UserProvider user) {
    if (_selectedCouponId == null) return null;
    for (final c in user.coupons) {
      if (c.id == _selectedCouponId) return c;
    }
    return null;
  }

  Address? _selectedAddress(UserProvider user) {
    if (_selectedAddressId != null) {
      for (final a in user.addresses) {
        if (a.id == _selectedAddressId) return a;
      }
    }
    return user.defaultAddress;
  }

  Future<void> _pickCoupon(UserProvider user) async {
    final eligible = eligibleCoupons(user.coupons, _subtotal);
    final selected = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CouponPickerPage(
          eligible: eligible,
          selectedCouponId: _selectedCouponId,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedCouponId = selected.isEmpty ? null : selected);
  }

  Future<void> _submit(BuildContext context, UserProvider user) async {
    if (_submitting || widget.items.isEmpty) return;

    final addressId = _selectedAddressId ?? user.defaultAddress?.id;
    if (user.isCloudSync && (addressId == null || addressId.isEmpty)) {
      showTopSnackBar(
        context,
        content: Text('请先添加收货地址', style: FeaturePageStyle.bodyBold()),
      );
      return;
    }

    setState(() => _submitting = true);
    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();

    try {
      final Order order;
      if (widget.fromCart) {
        order = await orderProvider.checkoutFromCart(
          cart,
          couponTemplateId: _selectedCouponId,
          addressId: addressId,
        );
        cart.clearCart();
      } else {
        order = await orderProvider.checkoutDirect(
          widget.items,
          couponTemplateId: _selectedCouponId,
          addressId: addressId,
        );
        for (final item in widget.items) {
          if (cart.quantityFor(item.product.id) > 0) {
            cart.removeItem(item.product.id);
          }
        }
      }

      if (user.isCloudSync) {
        await user.loadFromRemote();
        await cart.loadFromRemote();
      } else {
        user.recordOrder(order.total);
      }

      if (!mounted) return;
      setState(() => _selectedCouponId = null);
      showTopSnackBar(
        context,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下单成功！预计2-3天送达', style: FeaturePageStyle.bodyBold()),
            Text('订单号：${order.orderNo}', style: FeaturePageStyle.secondary()),
            if (order.discount > 0)
              Text('已优惠 ¥${order.discount.toStringAsFixed(2)}', style: FeaturePageStyle.secondary()),
          ],
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text(e.message, style: FeaturePageStyle.bodyBold()),
      );
    } catch (_) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text('下单失败，请稍后重试', style: FeaturePageStyle.bodyBold()),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final coupon = _selectedCoupon(user);
    if (coupon != null && !eligibleCoupons(user.coupons, _subtotal).any((c) => c.id == coupon.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCouponId = null);
      });
    }
    final payable = estimatedPayable(_subtotal, coupon);
    final address = _selectedAddress(user);

    return FeaturePageScaffold(
      title: '确认订单',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('商品清单', style: FeaturePageStyle.sectionTitle()),
          SizedBox(height: FeaturePageStyle.s(10)),
          ...widget.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: AppScale.s(10)),
              child: _CheckoutItemTile(item: item),
            ),
          ),
          SizedBox(height: AppScale.s(8)),
          _CheckoutOptionTile(
            icon: Icons.location_on_outlined,
            title: address?.detail ?? '请添加收货地址',
            subtitle: address != null ? '${address.name} ${address.phone}' : '点击管理地址',
            onTap: () => UserFeatureSheets.showAddresses(context),
          ),
          SizedBox(height: AppScale.s(8)),
          _CheckoutOptionTile(
            icon: Icons.local_offer_outlined,
            title: coupon?.title ?? '选择优惠券',
            subtitle: coupon != null
                ? '减 ¥${coupon.discount.toStringAsFixed(0)}'
                : '${eligibleCoupons(user.coupons, _subtotal).length} 张可用',
            onTap: () => _pickCoupon(user),
          ),
          SizedBox(height: AppScale.s(16)),
          Row(
            children: [
              Text('合计', style: FeaturePageStyle.secondary()),
              SizedBox(width: FeaturePageStyle.s(4)),
              if (coupon != null) ...[
                Text(
                  '¥${_subtotal.toStringAsFixed(2)}',
                  style: FeaturePageStyle.secondary().copyWith(decoration: TextDecoration.lineThrough),
                ),
                SizedBox(width: FeaturePageStyle.s(6)),
              ],
              Text('¥${payable.toStringAsFixed(2)}', style: FeaturePageStyle.priceLarge()),
            ],
          ),
          SizedBox(height: FeaturePageStyle.s(16)),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(FeaturePageStyle.s(999)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submitting ? null : () => _submit(context, user),
                  borderRadius: BorderRadius.circular(FeaturePageStyle.s(999)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: FeaturePageStyle.s(14)),
                    child: Text(
                      _submitting ? '提交中...' : '提交订单',
                      textAlign: TextAlign.center,
                      style: FeaturePageStyle.buttonLabel(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemTile extends StatelessWidget {
  const _CheckoutItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: FeaturePageStyle.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          ProductThumbnail(product: item.product, width: FeaturePageStyle.thumbSize, height: FeaturePageStyle.thumbSize),
          SizedBox(width: FeaturePageStyle.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FeaturePageStyle.bodyBold(),
                ),
                if (item.spec != null) Text(item.spec!, style: FeaturePageStyle.secondary()),
                SizedBox(height: FeaturePageStyle.s(6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('¥${item.product.price.toStringAsFixed(2)}', style: FeaturePageStyle.price()),
                    Text('x${item.quantity}', style: FeaturePageStyle.secondary()),
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

class _CheckoutOptionTile extends StatelessWidget {
  const _CheckoutOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.muted,
      borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(14), vertical: FeaturePageStyle.s(12)),
          child: Row(
            children: [
              Icon(icon, size: FeaturePageStyle.iconSize, color: AppColors.primary),
              SizedBox(width: FeaturePageStyle.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FeaturePageStyle.bodyBold()),
                    Text(subtitle, style: FeaturePageStyle.secondary()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: FeaturePageStyle.chevronSize, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
