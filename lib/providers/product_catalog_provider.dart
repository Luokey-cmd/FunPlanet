import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../data/products_catalog.dart';
import '../services/product_api_service.dart';
import '../utils/page_memory_cache.dart';

class _CatalogSnapshot {
  const _CatalogSnapshot({required this.products, required this.banners});

  final List<Product> products;
  final List<BannerItem> banners;
}

class ProductCatalogProvider extends ChangeNotifier {
  ProductCatalogProvider({ProductApiService? api}) : _api = api ?? ProductApiService();

  final ProductApiService _api;

  bool isLoading = false;
  bool loadedFromRemote = false;
  String? lastError;

  Future<void> load() async {
    if (isLoading) return;

    final cached = PageMemoryCache.read<_CatalogSnapshot>(PageMemoryCache.products);
    final hasCache = cached != null && cached.products.isNotEmpty;
    if (hasCache) {
      replaceProducts(List<Product>.from(cached.products));
      if (cached.banners.isNotEmpty) {
        replaceBanners(List<BannerItem>.from(cached.banners));
      }
      loadedFromRemote = true;
      notifyListeners();
    } else {
      isLoading = true;
      notifyListeners();
      _ensureLocalFallback();
    }

    try {
      final results = await Future.wait([
        _api.fetchProducts(),
        _api.fetchBanners(),
      ]);
      final remoteProducts = results[0] as List<Product>;
      final remoteBanners = results[1] as List<BannerItem>;
      if (remoteProducts.isNotEmpty) {
        replaceProducts(remoteProducts);
        loadedFromRemote = true;
      }
      if (remoteBanners.isNotEmpty) {
        replaceBanners(remoteBanners);
      }
      PageMemoryCache.write(
        PageMemoryCache.products,
        _CatalogSnapshot(
          products: List<Product>.from(products),
          banners: List<BannerItem>.from(appBanners),
        ),
      );
      lastError = null;
    } catch (e) {
      lastError = '$e';
      if (!hasCache) {
        _ensureLocalFallback();
      }
    } finally {
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
