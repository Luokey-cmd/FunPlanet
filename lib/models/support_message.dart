enum SupportSenderRole { user, admin }

enum SupportMessageType { text, image, sticker }

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.messageType = SupportMessageType.text,
    this.mediaUrl,
    this.stickerId,
    this.recalledAt,
  });

  final String id;
  final SupportSenderRole senderRole;
  final SupportMessageType messageType;
  final String? senderName;
  final String content;
  final String? mediaUrl;
  final String? stickerId;
  final DateTime createdAt;

  // 撤回时间：服务端 SupportMessage.recalled_at，非空表示这条已被撤回，
  // 原文服务端不再下发，界面只显示「XX撤回了一条消息」占位。
  final DateTime? recalledAt;

  bool get isRecalled => recalledAt != null;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      senderRole: json['senderRole'] == 'admin' ? SupportSenderRole.admin : SupportSenderRole.user,
      messageType: _parseMessageType(json['messageType'] as String?),
      senderName: json['senderName'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      stickerId: json['stickerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      // 老服务端/老缓存没有这个字段：解析不出就当没撤回，不能炸。
      recalledAt: DateTime.tryParse(json['recalledAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderRole': senderRole == SupportSenderRole.admin ? 'admin' : 'user',
        'messageType': messageType.name,
        if (senderName != null) 'senderName': senderName,
        'content': content,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (stickerId != null) 'stickerId': stickerId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (recalledAt != null) 'recalledAt': recalledAt!.toUtc().toIso8601String(),
      };

  static SupportMessageType _parseMessageType(String? raw) {
    switch (raw) {
      case 'image':
        return SupportMessageType.image;
      case 'sticker':
        return SupportMessageType.sticker;
      default:
        return SupportMessageType.text;
    }
  }
}

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.status,
    required this.subject,
    this.productId,
    this.productName,
    this.unreadUser = 0,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String status;
  final String? subject;
  final String? productId;
  final String? productName;
  final int unreadUser;

  // 最后一条消息预览与时间：服务端 serializeConversation 一直有下发，
  // 此前 App 侧没接。消息中心「客服中心」行靠它显示副标题，不用为了一行
  // 预览去打开会话。老缓存里没有这两个字段，解析时按空处理（不炸）。
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'open',
      subject: json['subject'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      unreadUser: json['unreadUser'] as int? ?? 0,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        if (subject != null) 'subject': subject,
        if (productId != null) 'productId': productId,
        if (productName != null) 'productName': productName,
        'unreadUser': unreadUser,
        if (lastMessagePreview != null) 'lastMessagePreview': lastMessagePreview,
        if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toUtc().toIso8601String(),
      };
}
