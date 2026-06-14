import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../services/order_api_service.dart';
import 'cart_provider.dart';

enum OrderFilter { all, pending, shipping, completed, cancelled }

class OrderProvider extends ChangeNotifier {
  OrderProvider({OrderApiService? api}) : _api = api ?? OrderApiService();

  final OrderApiService _api;
  final List<Order> _orders = [];
  bool _cloudSync = false;

  List<Order> get orders => List.unmodifiable(_orders);

  int get shippingCount => filtered(OrderFilter.shipping).length;

  int get pendingCount => filtered(OrderFilter.pending).length;

  bool get isCloudSync => _cloudSync;

  void setCloudSync(bool enabled) => _cloudSync = enabled;

  Future<void> loadFromRemote() async {
    try {
      final remote = await _api.fetchOrders();
      _orders
        ..clear()
        ..addAll(remote);
      _cloudSync = true;
      notifyListeners();
    } catch (_) {
      // 保留本地 mock / 已有数据
    }
  }

  List<Order> filtered(OrderFilter filter) {
    switch (filter) {
      case OrderFilter.all:
        return orders;
      case OrderFilter.pending:
        return orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.paid).toList();
      case OrderFilter.shipping:
        return orders.where((o) => o.status == OrderStatus.shipping).toList();
      case OrderFilter.completed:
        return orders.where((o) => o.status == OrderStatus.completed).toList();
      case OrderFilter.cancelled:
        return orders.where((o) => o.status == OrderStatus.cancelled).toList();
    }
  }

  Order? findById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<Order> checkoutFromCart(CartProvider cart, {String? couponTemplateId, String? addressId}) async {
    if (cart.items.isEmpty) throw StateError('empty cart');

    if (_cloudSync) {
      final order = await _api.createFromCart(
        couponTemplateId: couponTemplateId,
        addressId: addressId,
      );
      _orders.insert(0, order);
      notifyListeners();
      return order;
    }

    return addFromCart(cart.items, cart.totalPrice);
  }

  Future<Order> checkoutDirect(
    List<CartItem> items, {
    String? couponTemplateId,
    String? addressId,
  }) async {
    if (items.isEmpty) throw StateError('empty items');

    if (_cloudSync) {
      final order = await _api.createDirect(
        items: items,
        couponTemplateId: couponTemplateId,
        addressId: addressId,
      );
      _orders.insert(0, order);
      notifyListeners();
      return order;
    }

    final subtotal = items.fold(0.0, (sum, item) => sum + item.product.price * item.quantity);
    return addFromCart(items, subtotal);
  }

  Order addFromCart(List<CartItem> items, double total) {
    if (items.isEmpty) throw StateError('empty cart');
    final now = DateTime.now();
    final orderNo = 'QW${now.millisecondsSinceEpoch.toString().substring(5)}';
    final order = Order(
      id: 'o_${now.millisecondsSinceEpoch}',
      orderNo: orderNo,
      items: items
          .map((i) => OrderItem(name: i.product.name, quantity: i.quantity, spec: i.spec, productId: i.product.id))
          .toList(),
      total: total,
      subtotal: total,
      status: OrderStatus.paid,
      time: _formatTime(now),
    );
    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  Future<void> cancelOrder(String id) async {
    if (_cloudSync) {
      final updated = await _api.cancelOrder(id);
      _replaceOrder(updated);
      return;
    }
    _updateStatus(id, OrderStatus.cancelled);
  }

  Future<void> confirmReceive(String id) async {
    if (_cloudSync) {
      final updated = await _api.confirmOrder(id);
      _replaceOrder(updated);
      return;
    }
    _updateStatus(id, OrderStatus.completed);
  }

  void reorderToCart(Order order, CartProvider cart) {
    for (final item in order.items) {
      Product? product;
      if (item.productId != null) {
        product = productById(item.productId!);
      }
      if (product == null) {
        for (final p in products) {
          if (p.name == item.name) {
            product = p;
            break;
          }
        }
      }
      if (product == null) continue;
      for (var i = 0; i < item.quantity; i++) {
        cart.addItem(product);
      }
    }
  }

  void resetLocal() {
    _cloudSync = false;
    _orders.clear();
    notifyListeners();
  }

  void _replaceOrder(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders.insert(0, order);
    }
    notifyListeners();
  }

  void _updateStatus(String id, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index < 0) return;
    _orders[index] = _orders[index].copyWith(status: status);
    notifyListeners();
  }

  String _formatTime(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$m-$d $h:$min';
  }
}
