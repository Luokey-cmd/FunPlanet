import 'dart:typed_data';

import '../data/product_data.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
    this.products = const [],
    this.pendingCart = const [],
    this.imageBytes,
    this.starRoles = const [],
    this.giftNote,
    this.isAppraisal = false,
    this.visionPayload,
  });

  final ChatRole role;
  final String content;
  final bool isLoading;
  final List<Product> products;
  final List<Product> pendingCart;
  final Uint8List? imageBytes;
  final List<String> starRoles;
  final String? giftNote;
  final bool isAppraisal;
  final Map<String, String>? visionPayload;

  bool get hasProducts => products.isNotEmpty;
  bool get hasPendingCart => pendingCart.isNotEmpty;
  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
  bool get isFate => starRoles.length >= 2 && products.length >= 2;
  bool get awaitVisionChoice => isAppraisal && visionPayload != null;

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    List<Product>? products,
    List<Product>? pendingCart,
    Uint8List? imageBytes,
    List<String>? starRoles,
    String? giftNote,
    bool? isAppraisal,
    Map<String, String>? visionPayload,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      pendingCart: pendingCart ?? this.pendingCart,
      imageBytes: imageBytes ?? this.imageBytes,
      starRoles: starRoles ?? this.starRoles,
      giftNote: giftNote ?? this.giftNote,
      isAppraisal: isAppraisal ?? this.isAppraisal,
      visionPayload: visionPayload ?? this.visionPayload,
    );
  }
}
