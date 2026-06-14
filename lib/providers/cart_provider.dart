import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../services/cart_api_service.dart';

class CartProvider extends ChangeNotifier {
  CartProvider({CartApiService? api}) : _api = api ?? CartApiService();

  final CartApiService _api;
  final List<CartItem> _items = [];
  bool _cloudSync = false;

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  void setCloudSync(bool enabled) {
    _cloudSync = enabled;
  }

  Future<void> loadFromRemote() async {
    try {
      final remote = await _api.fetchItems();
      _items
        ..clear()
        ..addAll(remote);
      _cloudSync = true;
      notifyListeners();
    } catch (_) {
      // 保持本地状态
    }
  }

  void addItem(Product product) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
    } else {
      _items.add(CartItem(product: product, quantity: 1, spec: product.spec));
    }
    notifyListeners();
    if (_cloudSync) unawaited(_syncAddItem(product.id));
  }

  Future<void> _syncAddItem(String productId) async {
    try {
      await _api.addItem(productId);
    } catch (_) {
      await loadFromRemote();
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
    if (_cloudSync) unawaited(_syncRemoveItem(productId));
  }

  Future<void> _syncRemoveItem(String productId) async {
    try {
      await _api.removeItem(productId);
    } catch (_) {
      await loadFromRemote();
    }
  }

  void updateQuantity(String productId, int delta) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    final newQty = _items[index].quantity + delta;
    if (newQty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQty);
    }
    notifyListeners();
    if (_cloudSync) {
      if (newQty <= 0) {
        unawaited(_syncRemoveItem(productId));
      } else {
        unawaited(_syncUpdateQuantity(productId, newQty));
      }
    }
  }

  Future<void> _syncUpdateQuantity(String productId, int quantity) async {
    try {
      await _api.updateQuantity(productId, quantity);
    } catch (_) {
      await loadFromRemote();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    if (_cloudSync) unawaited(_api.clearCart());
  }

  void resetLocal() {
    _cloudSync = false;
    _items.clear();
    notifyListeners();
  }

  int quantityFor(String productId) {
    for (final item in _items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }
}
