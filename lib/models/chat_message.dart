import '../data/product_data.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
    this.products = const [],
  });

  final ChatRole role;
  final String content;
  final bool isLoading;
  final List<Product> products;

  bool get hasProducts => products.isNotEmpty;

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    List<Product>? products,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
    );
  }
}
