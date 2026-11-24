import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/product_data.dart';

/// 缓存读回来的目录数据：商品、轮播图和存入时间。
class CachedCatalog {
  const CachedCatalog({required this.products, required this.banners, this.savedAt});

  final List<Product> products;
  final List<BannerItem> banners;
  final DateTime? savedAt;
}

/// 商品目录的手机本地缓存：把最近一次从服务端成功拉到的商品清单
/// 存进手机本地（SharedPreferences 落盘，杀进程、重启手机都还在）。
///
/// 输入：服务端现拉成功的商品/轮播图列表；输出：下次打开 App 时读回的同一份数据。
/// 坑：缓存是 JSON 字符串，解析失败（比如版本升级改了字段）时一律当没缓存，
/// 绝不能因为缓存坏了让 App 起不来——读写都包了 try/catch，坏了返回空。
class ProductCacheService {
  static const _productsKey = 'cached_catalog_products_v1';
  static const _bannersKey = 'cached_catalog_banners_v1';
  static const _savedAtKey = 'cached_catalog_saved_at_v1';

  /// 存入最近一次成功拉到的清单。空清单不存，避免把好缓存冲掉。
  Future<void> save({required List<Product> products, required List<BannerItem> banners}) async {
    if (products.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_productsKey, jsonEncode(products.map((e) => e.toJson()).toList()));
      await prefs.setString(_bannersKey, jsonEncode(banners.map((e) => e.toJson()).toList()));
      await prefs.setString(_savedAtKey, DateTime.now().toIso8601String());
    } catch (_) {
      // 存缓存失败不影响正常使用，忽略。
    }
  }

  /// 读回上次存的清单；没存过或内容损坏时返回空清单。
  Future<CachedCatalog> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_productsKey);
      if (raw == null || raw.isEmpty) {
        return const CachedCatalog(products: [], banners: []);
      }
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      var banners = <BannerItem>[];
      final rawBanners = prefs.getString(_bannersKey);
      if (rawBanners != null && rawBanners.isNotEmpty) {
        final bl = jsonDecode(rawBanners) as List<dynamic>;
        banners = bl.map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      final savedAtRaw = prefs.getString(_savedAtKey);
      return CachedCatalog(
        products: items,
        banners: banners,
        savedAt: savedAtRaw == null ? null : DateTime.tryParse(savedAtRaw),
      );
    } catch (_) {
      return const CachedCatalog(products: [], banners: []);
    }
  }
}
