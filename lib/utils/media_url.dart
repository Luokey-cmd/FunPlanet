import '../config/api_config.dart';

Future<String> resolveRemoteMediaUrl(String? mediaUrl) async {
  final raw = mediaUrl?.trim() ?? '';
  if (raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final base = await ApiConfig.baseUrl();
  final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
  final encodedPath = normalized.split('/').map(Uri.encodeComponent).join('/');
  return '$base/$encodedPath';
}
