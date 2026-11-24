import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../data/products_catalog.dart';
import '../services/product_api_service.dart';
import '../services/product_cache_service.dart';
import '../utils/page_memory_cache.dart';

class _CatalogSnapshot {
  const _CatalogSnapshot({required this.products, required this.banners, required this.fromDiskCache});

  final List<Product> products;
  final List<BannerItem> banners;

  // 这份快照的数据是不是来自手机本地缓存（断网时顶上的上次数据）。
  final bool fromDiskCache;
}

class ProductCatalogProvider extends ChangeNotifier {
  ProductCatalogProvider({ProductApiService? api, ProductCacheService? cache})
      : _api = api ?? ProductApiService(),
        _cache = cache ?? ProductCacheService();

  final ProductApiService _api;
  final ProductCacheService _cache;

  bool isLoading = false;
  bool loadedFromRemote = false;

  // 当前屏上数据来自手机本地缓存（上次成功拉到的清单），不是这次现拉的。
  bool fromDiskCache = false;
  String? lastError;

  // 是否该给用户看「未连上服务端，显示上次数据」的提示：
  // 屏上是本地缓存、且这次现拉确实失败了才算数；还在拉的时候不提示。
  bool get showStaleHint => fromDiskCache && lastError != null;

  Future<void> load() async {
    if (isLoading) return;

    final cached = PageMemoryCache.read<_CatalogSnapshot>(PageMemoryCache.products);
    final hasCache = cached != null && cached.products.isNotEmpty;
    if (hasCache) {
      replaceProducts(List<Product>.from(cached.products));
      if (cached.banners.isNotEmpty) {
        replaceBanners(List<BannerItem>.from(cached.banners));
      }
      fromDiskCache = cached.fromDiskCache;
      loadedFromRemote = !cached.fromDiskCache;
      notifyListeners();
    } else {
      // 内存里没有，再看手机本地缓存：有就先顶上——它是上次成功拉到的
      // 清单，基本等于最新，不要一上来就掉回打包内置的老清单。
      final disk = await _cache.read();
      if (disk.products.isNotEmpty) {
        replaceProducts(disk.products);
        if (disk.banners.isNotEmpty) {
          replaceBanners(disk.banners);
        }
        fromDiskCache = true;
        notifyListeners();
      } else {
        isLoading = true;
        notifyListeners();
        _ensureLocalFallback();
      }
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
        fromDiskCache = false;
      }
      if (remoteBanners.isNotEmpty) {
        replaceBanners(remoteBanners);
      }
      PageMemoryCache.write(
        PageMemoryCache.products,
        _CatalogSnapshot(
          products: List<Product>.from(products),
          banners: List<BannerItem>.from(appBanners),
          fromDiskCache: fromDiskCache,
        ),
      );
      // 现拉成功才回写本地缓存：把这份清单存进手机，下次断网时顶上。
      // 接口返回空列表时屏上仍是旧缓存，就不写，避免拿空数据把好缓存冲掉。
      if (remoteProducts.isNotEmpty) {
        await _cache.save(products: products, banners: appBanners);
      }
      lastError = null;
    } catch (e) {
      lastError = '$e';
      // 内存、本地缓存都没有时，才退回打包内置清单（原有兜底，不变）。
      if (!hasCache && !fromDiskCache) {
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
