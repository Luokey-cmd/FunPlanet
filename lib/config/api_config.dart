import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_api_host.dart';
import 'production_api_host.dart';

class ApiConfig {
  static String? _cached;
  static String? lastTriedUrl;
  static String? lastUsedUrl;
  static String? lastError;

  static List<String> get candidateUrls {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return [fromEnv];

    if (kIsWeb) return ['http://127.0.0.1:3000'];

    if (Platform.isAndroid) {
      if (kReleaseMode) {
        final production = kProductionApiBaseUrl.trim();
        if (production.isNotEmpty) return [production];
        throw StateError(
          'Release 包需配置 lib/config/production_api_host.dart 中的线上 API 地址，'
          '或打包时传入 --dart-define=API_BASE_URL=https://你的域名',
        );
      }

      final hosts = <String>[
        '127.0.0.1',
        '10.0.2.2',
        if (kLocalApiHostOverride.trim().isNotEmpty) kLocalApiHostOverride.trim(),
      ];
      final urls = hosts.map((h) => 'http://$h:3000').toList();
      final production = kProductionApiBaseUrl.trim();
      if (production.isNotEmpty && !urls.contains(production)) {
        urls.add(production);
      }
      return urls;
    }

    return ['http://127.0.0.1:3000'];
  }

  static Future<String> baseUrl() async {
    if (_cached != null) return _cached!;

    final urls = candidateUrls;
    if (urls.length == 1) {
      return _probe(urls.first);
    }

    final completer = Completer<String>();
    var pending = urls.length;
    String? lastErr;

    for (final url in urls) {
      unawaited(() async {
        try {
          await _probe(url, completeOnSuccess: (resolved) {
            if (!completer.isCompleted) completer.complete(resolved);
          });
        } catch (e) {
          lastErr = e.toString();
        } finally {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            lastError = lastErr;
            completer.completeError(
              StateError(
                '无法连接后端，已尝试: ${urls.join(", ")}'
                '${lastErr != null ? "；最后错误: $lastErr" : ""}',
              ),
            );
          }
        }
      }());
    }

    return completer.future;
  }

  static Future<String> _probe(String url, {void Function(String)? completeOnSuccess}) async {
    lastTriedUrl = url;
    final res = await http.get(Uri.parse('$url/api/health')).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      _cached = url;
      lastUsedUrl = url;
      lastError = null;
      completeOnSuccess?.call(url);
      return url;
    }
    lastError = 'HTTP ${res.statusCode} @ $url';
    throw StateError(lastError!);
  }

  static void reset() => _cached = null;

  static Future<String?> tryBaseUrl() async {
    try {
      return await baseUrl();
    } catch (_) {
      return null;
    }
  }
}
