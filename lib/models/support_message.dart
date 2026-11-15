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
  });

  final String id;
  final SupportSenderRole senderRole;
  final SupportMessageType messageType;
  final String? senderName;
  final String content;
  final String? mediaUrl;
  final String? stickerId;
  final DateTime createdAt;

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
  });

  final String id;
  final String status;
  final String? subject;
  final String? productId;
  final String? productName;
  final int unreadUser;

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'open',
      subject: json['subject'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      unreadUser: json['unreadUser'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        if (subject != null) 'subject': subject,
        if (productId != null) 'productId': productId,
        if (productName != null) 'productName': productName,
        'unreadUser': unreadUser,
      };
}
