import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/xiaodou_chat_session.dart';

class XiaodouChatHistoryStorage {
  static String storageKey(String? userKey) => 'xiaodou_chat_v1_${userKey ?? 'guest'}';

  Future<List<XiaodouChatSession>> load(String? userKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey(userKey));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => XiaodouChatSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String? userKey, List<XiaodouChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(storageKey(userKey), payload);
  }
}
