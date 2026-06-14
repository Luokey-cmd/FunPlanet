import 'dart:convert';

import 'api_client.dart';

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.orderId,
    required this.content,
    required this.rating,
    required this.imagePaths,
    required this.createdAt,
    required this.userNickname,
    this.userAvatarPath = '',
  });

  final String id;
  final String productId;
  final String orderId;
  final String content;
  final int rating;
  final List<String> imagePaths;
  final String createdAt;
  final String userNickname;
  final String userAvatarPath;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id'] as String,
      productId: json['productId'] as String,
      orderId: json['orderId'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int? ?? 5,
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      createdAt: json['createdAt'] as String,
      userNickname: json['userNickname'] as String? ?? '趣玩用户',
      userAvatarPath: json['userAvatarPath'] as String? ?? '',
    );
  }
}

class ReviewApiService {
  ReviewApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<ProductReview>> fetchProductReviews(String productId) async {
    final data = await _client.get('/api/reviews/products/$productId');
    return (data['reviews'] as List<dynamic>)
        .map((e) => ProductReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductReview> fetchMyOrderReview({
    required String orderId,
    required String productId,
  }) async {
    final data = await _client.get('/api/reviews/orders/$orderId/products/$productId', auth: true);
    return ProductReview.fromJson(data['review'] as Map<String, dynamic>);
  }

  Future<String> uploadImage(List<int> bytes, String mimeType) async {
    final data = await _client.post('/api/reviews/upload', {
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    }, auth: true);
    return data['imagePath'] as String;
  }

  Future<ProductReview> submitReview({
    required String orderId,
    required String productId,
    required String content,
    int rating = 5,
    List<String> imagePaths = const [],
  }) async {
    final data = await _client.post('/api/reviews', {
      'orderId': orderId,
      'productId': productId,
      'content': content,
      'rating': rating,
      'imagePaths': imagePaths,
    }, auth: true);
    return ProductReview.fromJson(data['review'] as Map<String, dynamic>);
  }
}
