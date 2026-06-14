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
  }) async {
    final data = await _client.post('/api/ai-community/posts', {
      'content': content,
      if (imagePath.isNotEmpty) 'imagePath': imagePath,
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

  Future<AiCommunityPost> addComment(String postId, String content) async {
    final data = await _client.post('/api/ai-community/posts/$postId/comments', {
      'content': content,
    }, auth: true);
    return AiCommunityPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    await _client.delete('/api/ai-community/posts/$postId', auth: true);
  }
}
