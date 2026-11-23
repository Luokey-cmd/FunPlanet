import 'chat_message.dart';
import '../data/product_data.dart';
import 'agent_records.dart';

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

  static Map<String, dynamic> _productToJson(Product p) => {
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
      };

  static Map<String, dynamic> _messageToJson(ChatMessage m) => {
        'role': m.role.name,
        'content': m.content,
        if (m.starRoles.isNotEmpty) 'starRoles': m.starRoles,
        if (m.giftNote != null && m.giftNote!.isNotEmpty) 'giftNote': m.giftNote,
        if (m.products.isNotEmpty) 'products': m.products.map(_productToJson).toList(),
        // 办事清单与功课段：跟消息一起落本地，重进聊天还能看到当时的账
        if (m.actions.isNotEmpty) 'actions': m.actions.map((a) => a.toJson()).toList(),
        if (m.homework.isNotEmpty) 'homework': m.homework.map((h) => h.toJson()).toList(),
        // 亮牌批次历史：看过的批次要原样留着，上一批翻回去还是那三张
        if (m.fateBatches.isNotEmpty)
          'fateBatches': m.fateBatches.map((b) => b.map(_productToJson).toList()).toList(),
        if (m.fateRolesBatches.isNotEmpty) 'fateRolesBatches': m.fateRolesBatches,
        if (m.fateIndex != 0) 'fateIndex': m.fateIndex,
        if (m.fateTotal != 0) 'fateTotal': m.fateTotal,
        if (m.fateHasMore) 'fateHasMore': true,
        if (m.drawArgs.isNotEmpty) 'drawArgs': m.drawArgs,
        if (m.traits.isNotEmpty) 'traits': m.traits,
      };

  static ChatMessage _messageFromJson(Map<String, dynamic> json) {
    final products = (json['products'] as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    List<Product> parseProducts(dynamic raw) => (raw as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: json['content'] as String? ?? '',
      products: products,
      starRoles: (json['starRoles'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      giftNote: json['giftNote'] as String?,
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((e) => AgentAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      homework: (json['homework'] as List<dynamic>? ?? [])
          .map((e) => HomeworkEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      fateBatches: (json['fateBatches'] as List<dynamic>? ?? [])
          .map((b) => parseProducts(b))
          .toList(),
      fateRolesBatches: (json['fateRolesBatches'] as List<dynamic>? ?? [])
          .map((b) => (b as List<dynamic>).map((e) => '$e').toList())
          .toList(),
      fateIndex: json['fateIndex'] as int? ?? 0,
      fateTotal: json['fateTotal'] as int? ?? 0,
      fateHasMore: json['fateHasMore'] as bool? ?? false,
      drawArgs: (json['drawArgs'] as Map<String, dynamic>?) ?? const {},
      traits: (json['traits'] as Map<dynamic, dynamic>? ?? {})
          .map((key, value) => MapEntry('$key', '$value')),
    );
  }
}
