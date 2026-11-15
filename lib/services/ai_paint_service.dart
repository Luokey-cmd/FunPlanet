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

  Future<({AiArtwork artwork, int remainingToday})> generate({
    required String prompt,
    String style = '',
  }) async {
    final data = await _client.post(
      '/api/ai/draw',
      {
        'prompt': prompt,
        if (style.isNotEmpty) 'style': style,
      },
      auth: true,
      timeout: const Duration(seconds: 180),
    );
    final artworkJson = data['artwork'];
    if (artworkJson is! Map<String, dynamic>) {
      throw ApiException('服务器返回数据异常');
    }
    return (
      artwork: AiArtwork.fromJson(artworkJson),
      remainingToday: (data['remainingToday'] as num?)?.toInt() ?? 0,
    );
  }
}
