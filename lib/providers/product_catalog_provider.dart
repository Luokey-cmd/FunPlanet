import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../data/products_catalog.dart';
import '../services/product_api_service.dart';

class ProductCatalogProvider extends ChangeNotifier {
  ProductCatalogProvider({ProductApiService? api}) : _api = api ?? ProductApiService();

  final ProductApiService _api;

  bool isLoading = false;
  bool loadedFromRemote = false;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    _ensureLocalFallback();

    try {
      final results = await Future.wait([
        _api.fetchProducts(),
        _api.fetchBanners(),
      ]);
      final products = results[0] as List<Product>;
      final banners = results[1] as List<BannerItem>;
      if (products.isNotEmpty) {
        replaceProducts(products);
        loadedFromRemote = true;
      }
      if (banners.isNotEmpty) {
        replaceBanners(banners);
      }
    } catch (_) {
    } finally {
      _ensureLocalFallback();
      isLoading = false;
      notifyListeners();
    }
  }

  void _ensureLocalFallback() {
    if (products.isEmpty) {
      replaceProducts(List<Product>.from(catalogProducts));
    }
    if (appBanners.isEmpty) {
      replaceBanners(List<BannerItem>.from(fallbackBanners));
    }
  }
}
