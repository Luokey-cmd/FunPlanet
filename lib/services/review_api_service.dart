import 'dart:convert';

import 'api_client.dart';

class ProductReviewComment {
  const ProductReviewComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.userNickname,
    this.userAvatarPath = '',
    this.parentId = '0',
    this.rootId = '0',
    this.replyToUserId = '',
    this.replyToUserName = '',
    this.userId = '',
  });

  final String id;
  final String content;
  final String createdAt;
  final String userNickname;
  final String userAvatarPath;
  final String parentId;
  final String rootId;
  final String replyToUserId;
  final String replyToUserName;
  final String userId;

  bool get isRoot => parentId == '0' || parentId.isEmpty;

  String get threadRootId {
    if (isRoot) return id;
    if (rootId.isEmpty || rootId == '0') return parentId;
    return rootId;
  }

  factory ProductReviewComment.fromJson(Map<String, dynamic> json) {
    return ProductReviewComment(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      userNickname: json['userNickname'] as String? ?? '趣玩用户',
      userAvatarPath: json['userAvatarPath'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '0',
      rootId: json['rootId'] as String? ?? '0',
      replyToUserId: json['replyToUserId'] as String? ?? '',
      replyToUserName: json['replyToUserName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
    );
  }
}

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
    this.comments = const [],
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
  final List<ProductReviewComment> comments;

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
      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((e) => ProductReviewComment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ProductReview copyWith({List<ProductReviewComment>? comments}) {
    return ProductReview(
      id: id,
      productId: productId,
      orderId: orderId,
      content: content,
      rating: rating,
      imagePaths: imagePaths,
      createdAt: createdAt,
      userNickname: userNickname,
      userAvatarPath: userAvatarPath,
      comments: comments ?? this.comments,
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

  Future<ProductReview> addReviewComment({
    required String reviewId,
    required String content,
    String parentId = '0',
  }) async {
    final data = await _client.post('/api/reviews/$reviewId/comments', {
      'content': content,
      'parentId': parentId,
    }, auth: true);
    return ProductReview.fromJson(data['review'] as Map<String, dynamic>);
  }
}
