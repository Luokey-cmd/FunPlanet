import 'dart:convert';

import 'api_client.dart';
import '../models/support_message.dart';

class SupportChatService {
  SupportChatService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<({SupportConversation conversation, List<SupportMessage> messages})> openConversation({
    String? productId,
    String? productName,
    String? subject,
  }) async {
    final data = await _client.post('/api/support/conversations', {
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      if (subject != null) 'subject': subject,
    }, auth: true);

    final conversation = SupportConversation.fromJson(data['conversation'] as Map<String, dynamic>);
    final messages = (data['messages'] as List<dynamic>? ?? [])
        .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return (conversation: conversation, messages: messages);
  }

  Future<List<SupportMessage>> fetchMessages(String conversationId, {DateTime? after}) async {
    final qs = after != null ? '?after=${Uri.encodeComponent(after.toUtc().toIso8601String())}' : '';
    final data = await _client.get('/api/support/conversations/$conversationId/messages$qs', auth: true);
    return (data['messages'] as List<dynamic>)
        .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadImage(List<int> bytes, String mimeType) async {
    final data = await _client.post('/api/support/upload', {
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    }, auth: true);
    return data['mediaUrl'] as String;
  }

  Future<SupportMessage> sendMessage(
    String conversationId, {
    String content = '',
    SupportMessageType type = SupportMessageType.text,
    String? mediaUrl,
    String? stickerId,
  }) async {
    final body = <String, dynamic>{
      'messageType': type.name,
      if (content.isNotEmpty) 'content': content,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (stickerId != null) 'stickerId': stickerId,
    };
    final data = await _client.post('/api/support/conversations/$conversationId/messages', body, auth: true);
    return SupportMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId) async {
    await _client.post('/api/support/conversations/$conversationId/read', {}, auth: true);
  }
}
