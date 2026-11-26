import 'dart:convert';
import 'dart:typed_data';

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

  /// 落盘单条消息时图片字段的字节上限（约 900KB）：会话记录整表
  /// 存在 SharedPreferences 的一份 JSON 里，一张图撑大的是整个
  /// 文件、每次存档都全量重写。provider 发图时已先压到最长边 512，
  /// 正常只有几十 KB，这道线只兜底「内存里还是原图字节」的漏网
  /// 情形——宁可这一张不落盘，也不能让整份记录变巨无霸拖慢读写。
  static const int _maxStoredImageBytes = 900 * 1024;

  static Map<String, dynamic> _messageToJson(ChatMessage m) => {
        'role': m.role.name,
        'content': m.content,
        // 用户发的照片：以前只活在内存里，会话一重载（新建/切换
        // 对话、退出重进、重启）就丢。这里跟消息一起落盘，存的是
        // provider 换上的压缩副本（最长边 512），不是原图；老存档
        // 没有这个字段，读取端按没有处理、照常打开。
        if (m.imageBytes != null &&
            m.imageBytes!.isNotEmpty &&
            m.imageBytes!.length <= _maxStoredImageBytes)
          'imageBase64': base64Encode(m.imageBytes!),
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
        // 提问选项：没点的要留着，重进聊天还能接着点；点过的靠
        // optionsUsed 标记，重进也不会再冒出来。
        if (m.options.isNotEmpty) 'options': m.options,
        if (m.optionsUsed) 'optionsUsed': true,
        // 可领券清单：跟消息一起落本地，重进聊天卡片还在、领过的状态也在
        if (m.couponChoices.isNotEmpty)
          'couponChoices': m.couponChoices.map((c) => c.toJson()).toList(),
      };

  static ChatMessage _messageFromJson(Map<String, dynamic> json) {
    final products = (json['products'] as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    List<Product> parseProducts(dynamic raw) => (raw as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    // 照片还原：老存档没有 imageBase64 字段 → 按没图处理（向后
    // 兼容）；字段在但解码坏了也不能让整段对话打不开，静默当没图。
    Uint8List? storedImage;
    final rawImage = json['imageBase64'];
    if (rawImage is String && rawImage.isNotEmpty) {
      try {
        storedImage = base64Decode(rawImage);
      } catch (_) {
        storedImage = null;
      }
    }
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: json['content'] as String? ?? '',
      imageBytes: storedImage,
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
      couponChoices: (json['couponChoices'] as List<dynamic>? ?? [])
          .map((e) => CouponChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      fateIndex: json['fateIndex'] as int? ?? 0,
      fateTotal: json['fateTotal'] as int? ?? 0,
      fateHasMore: json['fateHasMore'] as bool? ?? false,
      drawArgs: (json['drawArgs'] as Map<String, dynamic>?) ?? const {},
      traits: (json['traits'] as Map<dynamic, dynamic>? ?? {})
          .map((key, value) => MapEntry('$key', '$value')),
      options: (json['options'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      optionsUsed: json['optionsUsed'] as bool? ?? false,
    );
  }
}
