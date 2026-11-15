import '../data/product_data.dart';
import 'api_client.dart';

class ProductApiService {
  ProductApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Product>> fetchProducts({String? category, String? keyword}) async {
    final query = <String, String>{};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;

    final data = await _client.get('/api/products${_toQuery(query)}');
    final list = data['products'] as List<dynamic>;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BannerItem>> fetchBanners() async {
    final data = await _client.get('/api/banners');
    final list = data['banners'] as List<dynamic>;
    return list.map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _toQuery(Map<String, String> query) {
    if (query.isEmpty) return '';
    return '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }
}
