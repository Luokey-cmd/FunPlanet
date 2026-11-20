import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../data/product_data.dart';
import '../models/chat_message.dart';
import 'token_storage.dart';

enum XiaodouStreamKind { text, products, fate, cart, appraisal, giftNote }

class XiaodouStreamEvent {
  const XiaodouStreamEvent._({
    required this.kind,
    this.content = '',
    this.products = const [],
    this.pendingCart = const [],
    this.roles = const [],
    this.vision,
  });

  factory XiaodouStreamEvent.text(String content) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.text, content: content);

  factory XiaodouStreamEvent.products(List<Product> products) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.products, products: products);

  factory XiaodouStreamEvent.fate(List<Product> products, List<String> roles) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.fate, products: products, roles: roles);

  factory XiaodouStreamEvent.cartConfirm(List<Product> pendingCart) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.cart, pendingCart: pendingCart);

  factory XiaodouStreamEvent.appraisal(String content, Map<String, String>? vision) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.appraisal, content: content, vision: vision);

  factory XiaodouStreamEvent.giftNote(String content) =>
      XiaodouStreamEvent._(kind: XiaodouStreamKind.giftNote, content: content);

  final XiaodouStreamKind kind;
  final String content;
  final List<Product> products;
  final List<Product> pendingCart;
  final List<String> roles;
  final Map<String, String>? vision;
}

// 云端会话摘要（服务端 AiChatConversation）：和手机本地记录是两套，
// 本地记录能改能删，云端这份是服务端在聊天时自动存的备份，换手机登录也能看。
class CloudChatConversation {
  const CloudChatConversation({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int messageCount;
  final String updatedAt;

  factory CloudChatConversation.fromJson(Map<String, dynamic> json) {
    return CloudChatConversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? '新对话',
      messageCount: json['messageCount'] as int? ?? 0,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class CloudChatMessage {
  const CloudChatMessage({required this.role, required this.content});

  final String role; // user / assistant
  final String content;

  bool get isUser => role == 'user';

  factory CloudChatMessage.fromJson(Map<String, dynamic> json) {
    return CloudChatMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
    );
  }
}

class XiaodouChatService {
  XiaodouChatService({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  // 拉云端会话列表（最近 30 个，服务端按最后更新时间倒序）。
  Future<List<CloudChatConversation>> fetchCloudConversations() async {
    final json = await _getJson('/api/chat/conversations');
    final list = json['conversations'] as List<dynamic>? ?? [];
    return list
        .map((e) => CloudChatConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 拉某个云端会话的全部消息（只读展示用）。
  Future<List<CloudChatMessage>> fetchCloudConversation(String id) async {
    final json = await _getJson('/api/chat/conversations/$id');
    final conversation = json['conversation'] as Map<String, dynamic>? ?? {};
    final list = conversation['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => CloudChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 云端历史接口的统一 GET：带登录 token，拆掉 {code,message,data} 外壳只回 data。
  Future<Map<String, dynamic>> _getJson(String path) async {
    final base = await ApiConfig.baseUrl();
    final token = await _tokenStorage.loadToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录后再查看云端记录');
    }
    final response = await _client.get(
      Uri.parse('$base$path'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(decoded['message'] as String? ?? '加载失败 (${response.statusCode})');
    }
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  Stream<XiaodouStreamEvent> sendMessageStream(
    List<ChatMessage> history, {
    String? imageBase64,
    String? mimeType,
    Map<String, dynamic>? starwish,
    Map<String, String>? vision,
  }) async* {
    final base = await ApiConfig.baseUrl();
    final token = await _tokenStorage.loadToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录后再使用小豆');
    }

    final payload = history
        .where((m) => !m.isLoading && m.content.trim().isNotEmpty)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
              if (m.products.isNotEmpty) 'productIds': m.products.map((p) => p.id).toList(),
            })
        .toList();

    final request = http.Request('POST', Uri.parse('$base/api/chat/stream'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Authorization'] = 'Bearer $token';
    request.body = jsonEncode({
      'messages': payload,
      if (imageBase64 != null && imageBase64.isNotEmpty) 'imageBase64': imageBase64,
      if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
      if (starwish != null && starwish.isNotEmpty) 'starwish': starwish,
      if (vision != null && vision.isNotEmpty) 'vision': vision,
    });

    final response = await _client.send(request).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception(_parseError(body) ?? '发送失败 (${response.statusCode})');
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final separator = buffer.indexOf('\n\n');
        if (separator < 0) break;

        final event = buffer.substring(0, separator);
        buffer = buffer.substring(separator + 2);

        for (final line in event.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;

          final json = jsonDecode(data) as Map<String, dynamic>;
          final error = json['error'] as String?;
          if (error != null && error.isNotEmpty) {
            throw Exception(error);
          }

          final type = json['type'] as String?;
          if (type == 'products' || type == 'fate_cards' || type == 'cart_confirm') {
            final list = (json['products'] as List<dynamic>? ?? [])
                .map((item) => Product.fromJson(item as Map<String, dynamic>))
                .toList();
            if (list.isEmpty) continue;
            if (type == 'cart_confirm') {
              yield XiaodouStreamEvent.cartConfirm(list);
            } else if (type == 'fate_cards') {
              final roles = (json['roles'] as List<dynamic>? ?? []).map((e) => '$e').toList();
              yield XiaodouStreamEvent.fate(list, roles);
            } else {
              yield XiaodouStreamEvent.products(list);
            }
            continue;
          }

          if (type == 'appraisal') {
            yield XiaodouStreamEvent.appraisal(
              json['content'] as String? ?? '',
              _stringMap(json['vision']),
            );
            continue;
          }

          if (type == 'gift_note') {
            final note = json['content'] as String? ?? '';
            if (note.isNotEmpty) yield XiaodouStreamEvent.giftNote(note);
            continue;
          }

          final content = json['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield XiaodouStreamEvent.text(content);
          }
        }
      }
    }
  }

  Map<String, String>? _stringMap(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) return;
      out['$key'] = '$value';
    });
    return out.isEmpty ? null : out;
  }

  String? _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['message'] ?? data['error']) as String?;
    } catch (_) {
      return null;
    }
  }
}
