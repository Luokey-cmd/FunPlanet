import '../data/product_data.dart';
import 'api_client.dart';

class OrderApiService {
  OrderApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Order>> fetchOrders() async {
    final data = await _client.get('/api/orders', auth: true);
    return (data['orders'] as List<dynamic>)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> createFromCart({String? addressId, String? couponTemplateId, bool payNow = true}) async {
    final body = <String, dynamic>{'payNow': payNow};
    if (addressId != null && addressId.isNotEmpty) body['addressId'] = addressId;
    if (couponTemplateId != null && couponTemplateId.isNotEmpty) {
      body['couponTemplateId'] = couponTemplateId;
    }
    final data = await _client.post('/api/orders', body, auth: true);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<Order> createDirect({
    required List<CartItem> items,
    String? addressId,
    String? couponTemplateId,
    bool payNow = true,
  }) async {
    final body = <String, dynamic>{
      'payNow': payNow,
      'lineItems': items
          .map((item) => {
                'productId': item.product.id,
                'quantity': item.quantity,
              })
          .toList(),
    };
    if (addressId != null && addressId.isNotEmpty) body['addressId'] = addressId;
    if (couponTemplateId != null && couponTemplateId.isNotEmpty) {
      body['couponTemplateId'] = couponTemplateId;
    }
    final data = await _client.post('/api/orders', body, auth: true);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<Order> payOrder(String orderId) async {
    final data = await _client.post('/api/orders/$orderId/pay', {}, auth: true);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(String orderId) async {
    final data = await _client.put('/api/orders/$orderId/cancel', auth: true);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<Order> confirmOrder(String orderId) async {
    final data = await _client.put('/api/orders/$orderId/confirm', auth: true);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }
}
