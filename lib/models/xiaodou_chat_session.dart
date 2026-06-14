import 'chat_message.dart';
import '../data/product_data.dart';

class XiaodouChatSession {
  XiaodouChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
    required this.createdAt,
    this.pinned = false,
  });

  final String id;
  String title;
  List<ChatMessage> messages;
  DateTime updatedAt;
  final DateTime createdAt;
  bool pinned;

  int get messageCount => messages.where((m) => !m.isLoading && m.content.trim().isNotEmpty).length;

  String get preview {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.isLoading || m.content.trim().isEmpty) continue;
      final text = m.content.replaceAll('\n', ' ').trim();
      if (text.length <= 48) return text;
      return '${text.substring(0, 48)}…';
    }
    return '暂无消息';
  }

  static String titleFromMessages(List<ChatMessage> messages) {
    for (final m in messages) {
      if (m.role == ChatRole.user && m.content.trim().isNotEmpty) {
        final text = m.content.replaceAll('\n', ' ').trim();
        if (text.length <= 18) return text;
        return '${text.substring(0, 18)}…';
      }
    }
    return '新对话';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map(_messageToJson).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };

  factory XiaodouChatSession.fromJson(Map<String, dynamic> json) {
    return XiaodouChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '新对话',
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => _messageFromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      pinned: json['pinned'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _messageToJson(ChatMessage m) => {
        'role': m.role.name,
        'content': m.content,
        if (m.products.isNotEmpty)
          'products': m.products
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'nameEn': p.nameEn,
                  'price': p.price,
                  'originalPrice': p.originalPrice,
                  'category': p.category,
                  'subCategory': p.subCategory,
                  'majorCategory': p.majorCategory,
                  'tag': p.tag,
                  'tagColor': p.tagColor,
                  'description': p.description,
                  'purchaseNotes': p.purchaseNotes,
                  'rating': p.rating,
                  'sales': p.sales,
                  'spec': p.spec,
                  'imagePath': p.imagePath,
                },
              )
              .toList(),
      };

  static ChatMessage _messageFromJson(Map<String, dynamic> json) {
    final products = (json['products'] as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: json['content'] as String? ?? '',
      products: products,
    );
  }
}
