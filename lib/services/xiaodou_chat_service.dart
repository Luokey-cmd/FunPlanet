import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../data/product_data.dart';
import '../models/chat_message.dart';
import 'token_storage.dart';

class XiaodouStreamEvent {
  const XiaodouStreamEvent.text(this.content) : products = const [];
  const XiaodouStreamEvent.products(this.products) : content = '';

  final String content;
  final List<Product> products;

  bool get isText => content.isNotEmpty;
  bool get isProducts => products.isNotEmpty;
}

class XiaodouChatService {
  XiaodouChatService({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  Stream<XiaodouStreamEvent> sendMessageStream(List<ChatMessage> history) async* {
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
            })
        .toList();

    final request = http.Request('POST', Uri.parse('$base/api/chat/stream'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Authorization'] = 'Bearer $token';
    request.body = jsonEncode({'messages': payload});

    final response = await _client.send(request).timeout(const Duration(seconds: 90));

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
          if (type == 'products') {
            final list = (json['products'] as List<dynamic>? ?? [])
                .map((item) => Product.fromJson(item as Map<String, dynamic>))
                .toList();
            if (list.isNotEmpty) {
              yield XiaodouStreamEvent.products(list);
            }
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

  String? _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['message'] ?? data['error']) as String?;
    } catch (_) {
      return null;
    }
  }
}
