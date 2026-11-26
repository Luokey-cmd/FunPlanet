import 'package:flutter/foundation.dart';

import '../models/starwish_profile.dart';
import '../services/starwish_profile_storage.dart';

class StarwishProfileProvider extends ChangeNotifier {
  StarwishProfileProvider({StarwishProfileStorage? storage}) : _storage = storage ?? StarwishProfileStorage() {
    _load();
  }

  final StarwishProfileStorage _storage;
  String? _userKey;
  StarwishProfile _profile = const StarwishProfile();

  StarwishProfile get profile => _profile;

  /// 小豆有没有记住任何一条偏好
  bool get hasMemory => !_profile.isEmpty;

  Future<void> bindUser(String? userId) async {
    if (_userKey == userId) return;
    _userKey = userId;
    await _load();
  }

  Future<void> _load() async {
    _profile = await _storage.load(_userKey);
    notifyListeners();
  }

  Future<void> update(StarwishProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _storage.save(_userKey, profile);
  }

  /// 清空小豆记住的全部偏好（弹层里「全部清空」保存后调用 update 即可，
  /// 这里单独留一个口子给以后一键遗忘用）。
  Future<void> clearAll() => update(const StarwishProfile());

  // 从挑礼物分组问答的点选里沉淀记忆（hx 2026-11-27 定版的核心来源）。
  // 输入：组标签 -> 选项原话，如 {送给谁: 送对象, 预算: 50到100元}。
  // 只认「送给谁 / 预算 / 类型 / 系列」四组，其余标签忽略；
  // 预算按区间上限记（50到100元记 100），200元以上与预算不限记 0（不限）；
  // 类型与系列新的顶到最前、去重、最多留 3 个。
  Future<void> rememberFromOptions(Map<String, String> byLabel) async {
    var next = _profile;
    final who = byLabel['送给谁'];
    if (who != null && who.isNotEmpty) {
      next = who == '自己用'
          ? next.copyWith(purpose: 'self', recipient: '')
          : next.copyWith(purpose: 'gift', recipient: who);
    }
    final budgetText = byLabel['预算'];
    if (budgetText != null && budgetText.isNotEmpty) {
      final budget = switch (budgetText) {
        '50元以内' => 50,
        '50到100元' => 100,
        '100到200元' => 200,
        _ => 0,
      };
      next = next.copyWith(budget: budget);
    }
    final category = byLabel['类型'];
    if (category != null && category.isNotEmpty) {
      next = next.copyWith(favoriteCategories: _prependUnique(next.favoriteCategories, category));
    }
    final series = byLabel['系列'];
    if (series != null && series.isNotEmpty) {
      next = next.copyWith(favoriteSeries: _prependUnique(next.favoriteSeries, series));
    }
    if (!identical(next, _profile)) await update(next);
  }

  static List<String> _prependUnique(List<String> list, String value) {
    final next = [value, ...list.where((e) => e != value)];
    return next.take(3).toList();
  }
}
