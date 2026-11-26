import 'api_client.dart';
import '../models/ai_artwork.dart';

class AiPaintService {
  AiPaintService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AiPaintQuota> fetchQuota() async {
    final data = await _client.get('/api/ai/quota', auth: true);
    return AiPaintQuota.fromJson(data);
  }

  Future<List<AiArtwork>> fetchArtworks({int limit = 30}) async {
    final data = await _client.get('/api/ai/artworks?limit=$limit', auth: true);
    final rows = data['artworks'];
    if (rows is! List) return [];
    return rows.map((item) => AiArtwork.fromJson(item as Map<String, dynamic>)).toList();
  }

  // 生成一至两张候选图。
  // 输入：拼好风格前缀的提示词、风格 key、画幅尺寸（aiRatioPresets 的 size）、张数 1～2；
  // 输出：本批成图列表（第一张是主图）与今日剩余张数。
  // 坑：老服务端只回单张 artwork 字段、新服务端回 artworks 数组，两种都要认，不能只认一种。
  Future<({List<AiArtwork> artworks, int remainingToday})> generate({
    required String prompt,
    String style = '',
    String size = '1280*1280',
    int count = 1,
  }) async {
    final data = await _client.post(
      '/api/ai/draw',
      {
        'prompt': prompt,
        if (style.isNotEmpty) 'style': style,
        'size': size,
        'count': count,
      },
      auth: true,
      timeout: const Duration(seconds: 180),
    );
    final rows = data['artworks'];
    if (rows is List && rows.isNotEmpty) {
      return (
        artworks: rows.map((item) => AiArtwork.fromJson(item as Map<String, dynamic>)).toList(),
        remainingToday: (data['remainingToday'] as num?)?.toInt() ?? 0,
      );
    }
    final artworkJson = data['artwork'];
    if (artworkJson is! Map<String, dynamic>) {
      throw ApiException('服务器返回数据异常');
    }
    return (
      artworks: [AiArtwork.fromJson(artworkJson)],
      remainingToday: (data['remainingToday'] as num?)?.toInt() ?? 0,
    );
  }
}
