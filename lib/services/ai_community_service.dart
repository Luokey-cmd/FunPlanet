import 'dart:convert';

import 'api_client.dart';
import '../models/ai_community.dart';

class AiCommunityService {
  AiCommunityService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<AiCommunityPost>> fetchFeed({int limit = 30}) async {
    final data = await _client.get('/api/ai-community/feed?limit=$limit', auth: true);
    final rows = data['posts'];
    if (rows is! List) return [];
    return rows.map((item) => AiCommunityPost.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AiCommunityPost> fetchPost(String id) async {
    final data = await _client.get('/api/ai-community/posts/$id', auth: true);
    return AiCommunityPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<AiCommunityPost> createPost({
    required String content,
    String imagePath = '',
    List<String> imagePaths = const [],
  }) async {
    final paths = [
      ...imagePaths.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (imagePath.trim().isNotEmpty) imagePath.trim(),
    ];
    final unique = <String>[];
    for (final p in paths) {
      if (!unique.contains(p)) unique.add(p);
    }
    final data = await _client.post('/api/ai-community/posts', {
      'content': content,
      if (unique.isNotEmpty) 'imagePath': unique.first,
      if (unique.isNotEmpty) 'imagePaths': unique.take(9).toList(),
    }, auth: true);
    return AiCommunityPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<String> uploadImage(List<int> bytes, String mimeType) async {
    final data = await _client.post('/api/ai-community/upload', {
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    }, auth: true);
    return data['imagePath'] as String;
  }

  Future<AiCommunityPost> toggleLike(String postId) async {
    final data = await _client.post('/api/ai-community/posts/$postId/like', {}, auth: true);
    return AiCommunityPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<AiCommunityPost> addComment(String postId, String content, {String parentId = '0'}) async {
    final data = await _client.post('/api/ai-community/posts/$postId/comments', {
      'content': content,
      'parentId': parentId,
    }, auth: true);
    return AiCommunityPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    await _client.delete('/api/ai-community/posts/$postId', auth: true);
  }

  /// 我的帖子未读回复数（消息页 AI 社区行与底部导航角标用）。
  /// 口径在服务端：只算评论不算点赞、排除本人评论；首次查询服务端会先立
  /// 已读标记再返 0，不会把历史回复倒灌成未读。解析不出数字时按 0 处理，
  /// 角标宁可不亮也不能乱亮。
  Future<int> fetchUnreadReplyCount() async {
    final data = await _client.get('/api/ai-community/unread-replies', auth: true);
    final count = data['unreadCount'];
    return count is int ? count : 0;
  }

  /// 标已读：进社区页时调，服务端把已读标记推到当前时间并返回 0。
  Future<int> markRepliesRead() async {
    final data = await _client.post('/api/ai-community/unread-replies/read', {}, auth: true);
    final count = data['unreadCount'];
    return count is int ? count : 0;
  }
}
