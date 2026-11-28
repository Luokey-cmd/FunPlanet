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

  // 生成一张图（2026-11-28 起去掉两张候选：一次只出一张，不再让用户选张数）。
  // 输入：拼好风格前缀的提示词、风格 key、画幅尺寸（aiRatioPresets 的 size）；
  // 输出：本批成图列表（恒 1 张）与今日剩余张数。
  // 坑：老服务端只回单张 artwork 字段、新服务端回 artworks 数组，两种都要认，不能只认一种。
  Future<({List<AiArtwork> artworks, int remainingToday})> generate({
    required String prompt,
    String style = '',
    String size = '1280*1280',
  }) async {
    final data = await _client.post(
      '/api/ai/draw',
      {
        'prompt': prompt,
        if (style.isNotEmpty) 'style': style,
        'size': size,
        'count': 1,
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

  // 批量删除自己的作品（我的作品多选用）。
  // 输入：作品 id 列表；输出：服务端实际删掉的张数（对不上时页面会重拉列表对齐）。
  // 坑：服务端按当前登录用户过滤，只能删自己的，混进别人的 id 会被跳过不报错。
  Future<int> deleteArtworks(List<String> ids) async {
    final data = await _client.post(
      '/api/ai/artworks/delete',
      {'ids': ids},
      auth: true,
    );
    return (data['deleted'] as num?)?.toInt() ?? 0;
  }
}
