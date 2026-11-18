import 'dart:math';

import '../data/product_data.dart';

/// 今日星签的选牌：程序定，AI 不参与。
///
/// 规则（设计稿第五节）：
/// 1. 质量门槛：只在销量前一半（且至少 10 件）里选；
/// 2. 偏好加权：浏览/收藏出现过的品类，权重 ×3；
/// 3. 每日定数：用「日期 + 用户 id」做稳定种子抽取，同人同天结果一致
///    （首次结果还会存进本地记录，之后直接读记录，双保险）；
/// 4. 去重：避开最近翻到过的商品，池子不够时放宽到只避开昨天那件。
class DailyStarSignPicker {
  static Product? pick({
    required List<Product> pool,
    required List<String> browseHistoryIds,
    required Set<String> favoriteIds,
    required List<String> recentProductIds,
    required String userId,
    required String dateStr,
  }) {
    if (pool.isEmpty) return null;
    final byId = {for (final p in pool) p.id: p};

    final preferredCategories = <String>{};
    for (final id in [...browseHistoryIds.take(10), ...favoriteIds]) {
      final p = byId[id];
      if (p != null) preferredCategories.add(p.majorCategory);
    }

    final sorted = List<Product>.from(pool)
      ..sort((a, b) => b.sales.compareTo(a.sales));
    final qualityCount = max(10, (sorted.length / 2).ceil());
    final quality = sorted.take(qualityCount).toList();

    var candidates = quality
        .where((p) => !recentProductIds.contains(p.id))
        .toList();
    if (candidates.isEmpty) {
      final yesterday = recentProductIds.isNotEmpty
          ? recentProductIds.first
          : null;
      candidates = quality.where((p) => p.id != yesterday).toList();
      if (candidates.isEmpty) candidates = quality;
    }

    int weightOf(Product p) =>
        preferredCategories.contains(p.majorCategory) ? 3 : 1;
    final totalWeight = candidates.fold<int>(0, (sum, p) => sum + weightOf(p));

    var seed = 17;
    for (final unit in '$dateStr|$userId'.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    var roll = Random(seed).nextInt(totalWeight);
    for (final p in candidates) {
      roll -= weightOf(p);
      if (roll < 0) return p;
    }
    return candidates.first;
  }
}
