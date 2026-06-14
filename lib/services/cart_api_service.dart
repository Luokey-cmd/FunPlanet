import '../data/product_data.dart';
import 'api_client.dart';

class CartApiService {
  CartApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<CartItem>> fetchItems() async {
    final data = await _client.get('/api/cart', auth: true);
    final list = data['items'] as List<dynamic>;
    return list.map((e) => _parseItem(e as Map<String, dynamic>)).toList();
  }

  Future<void> addItem(String productId, {int quantity = 1}) async {
    await _client.post('/api/cart', {'productId': productId, 'quantity': quantity}, auth: true);
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    await _client.put('/api/cart/$productId', body: {'quantity': quantity}, auth: true);
  }

  Future<void> removeItem(String productId) async {
    await _client.delete('/api/cart/$productId', auth: true);
  }

  Future<void> clearCart() async {
    await _client.delete('/api/cart', auth: true);
  }

  CartItem _parseItem(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      spec: json['spec'] as String?,
    );
  }
}
