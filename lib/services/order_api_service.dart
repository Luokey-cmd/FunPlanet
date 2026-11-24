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

  // 当前生效的满减档（结算页展示用）：只拿展示字段，真正减额由
  // 服务端在下单时复算，这份数据算错也不影响实付金额。
  Future<List<Map<String, dynamic>>> fetchActiveThresholds() async {
    final data = await _client.get('/api/promotions/active');
    return (data['thresholds'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
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

  // 申请售后：type 为 refund（仅退款）或 return（退货退款），reason 必填。
  // 同一订单有一条待处理申请时服务端会报错，错误信息由 ApiClient 原样带出。
  Future<void> applyAfterSale(
    String orderId, {
    required String type,
    required String reason,
    String? description,
  }) async {
    await _client.post('/api/orders/$orderId/after-sale', {
      'type': type,
      'reason': reason,
      if (description != null && description.isNotEmpty) 'description': description,
    }, auth: true);
  }

  Future<List<AfterSaleRequest>> fetchMyAfterSales() async {
    final data = await _client.get('/api/orders/after-sales', auth: true);
    return (data['requests'] as List<dynamic>)
        .map((e) => AfterSaleRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
