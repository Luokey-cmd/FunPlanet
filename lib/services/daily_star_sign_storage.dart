import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 今日星签的状态（存进本地记录的 state 字段）。
class DailyStarSignState {
  static const popped = 'popped'; // 已自动弹过，还没翻
  static const flipped = 'flipped'; // 已翻开
  static const dismissed = 'dismissed'; // 未翻就关了，当天不再自动弹
  static const done = 'done'; // 翻完走了「带走 / 再翻三张」
  static const skipped = 'skipped'; // 当天先让给小豆引导层，当天不自动弹
}

/// 今日星签的本地记录：哪一天、翻的是哪件商品、进行到哪一步。
class DailyStarSignRecord {
  const DailyStarSignRecord({
    required this.date,
    required this.state,
    this.productId,
  });

  final String date; // yyyy-MM-dd（本地日期）
  final String state;
  final String? productId;

  DailyStarSignRecord copyWith({String? state, String? productId}) {
    return DailyStarSignRecord(
      date: date,
      state: state ?? this.state,
      productId: productId ?? this.productId,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'state': state,
    'productId': productId,
  };

  factory DailyStarSignRecord.fromJson(Map<String, dynamic> json) {
    return DailyStarSignRecord(
      date: json['date'] as String? ?? '',
      state: json['state'] as String? ?? DailyStarSignState.popped,
      productId: json['productId'] as String?,
    );
  }
}

/// 今日星签的本地存储，写法仿 xiaodou_guide_storage（按 userId 分键，
/// 空 userId 记为 guest）。
class DailyStarSignStorage {
  /// 每次保存后自增，首页常驻条监听它刷新自己的文案。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String todayString([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  static String _key(String userId) =>
      'daily_star_sign_v1_${userId.isEmpty ? 'guest' : userId}';

  static String _recentKey(String userId) =>
      'daily_star_sign_recent_v1_${userId.isEmpty ? 'guest' : userId}';

  /// 读今天的记录；没有、或存的是昨天的，都返回 null（算新的一天）。
  Future<DailyStarSignRecord?> readToday(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      final record = DailyStarSignRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (record.date != todayString()) return null;
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String userId, DailyStarSignRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(record.toJson()));
    revision.value++;
  }

  /// 当天先让给小豆引导层时打个记号：星签当天不再自动弹，
  /// 但首页常驻条还能手动打开（打开时再现挑商品）。
  Future<void> markSkippedToday(String userId) async {
    if (await readToday(userId) != null) return;
    await save(
      userId,
      DailyStarSignRecord(
        date: todayString(),
        state: DailyStarSignState.skipped,
      ),
    );
  }

  /// 最近翻到过的商品 id（最新在前，最多 7 条），选牌去重用。
  Future<List<String>> recentProductIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey(userId)) ?? <String>[];
  }

  Future<void> pushRecent(String userId, String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey(userId)) ?? <String>[];
    list.remove(productId);
    list.insert(0, productId);
    await prefs.setStringList(_recentKey(userId), list.take(7).toList());
    revision.value++;
  }
}
