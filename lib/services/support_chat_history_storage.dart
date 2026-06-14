import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/support_message.dart';

class SupportChatHistoryStorage {
  static String storageKey(String? userKey, String sessionKey) =>
      'support_chat_v1_${userKey ?? 'guest'}_$sessionKey';

  Future<({SupportConversation conversation, List<SupportMessage> messages})?> load(
    String? userKey,
    String sessionKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey(userKey, sessionKey));
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final conversation = SupportConversation.fromJson(data['conversation'] as Map<String, dynamic>);
      final messages = (data['messages'] as List<dynamic>)
          .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return (conversation: conversation, messages: messages);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String? userKey,
    String sessionKey,
    SupportConversation conversation,
    List<SupportMessage> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'conversation': conversation.toJson(),
      'messages': messages.map((m) => m.toJson()).toList(),
    });
    await prefs.setString(storageKey(userKey, sessionKey), payload);
  }

  Future<void> clearUser(String? userKey) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'support_chat_v1_${userKey ?? 'guest'}_';
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }
}
