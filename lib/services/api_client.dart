import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';
import '../utils/app_log.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({TokenStorage? tokenStorage, http.Client? client})
      : _tokenStorage = tokenStorage ?? TokenStorage(),
        _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<Map<String, dynamic>> get(String path, {bool auth = false, Duration? timeout}) async {
    return _request('GET', path, auth: auth, timeout: timeout);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = false, Duration? timeout}) async {
    return _request('POST', path, body: body, auth: auth, timeout: timeout);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    return _request('PUT', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    return _request('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    return _request('DELETE', path, auth: auth);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    Duration? timeout,
  }) async {
    final base = await ApiConfig.baseUrl();
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await _tokenStorage.loadToken();
      if (token == null || token.isEmpty) {
        throw ApiException('未登录');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final requestTimeout = timeout ?? const Duration(seconds: 15);
    // 每个接口请求都留一行中文日志：调了什么、成没成、耗时多少。
    // 只打路径不打请求内容（内容里可能有密码等隐私）。
    final stopwatch = Stopwatch()..start();

    late http.Response response;
    try {
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(requestTimeout);
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: headers).timeout(requestTimeout);
      } else if (method == 'PUT') {
        response = await _client.put(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(requestTimeout);
      } else if (method == 'PATCH') {
        response = await _client.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(requestTimeout);
      } else {
        response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(requestTimeout);
      }
    } on TimeoutException {
      AppLog.error('网络', '$method $path 超时，等了 ${requestTimeout.inSeconds} 秒服务器没回应');
      throw ApiException('网络超时，请稍后重试');
    } on http.ClientException catch (e) {
      AppLog.error('网络', '$method $path 网络异常', e);
      throw ApiException('网络异常：${e.message}');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      AppLog.error('网络', '$method $path 服务器返回的不是正常数据（状态码 ${response.statusCode}）');
      throw ApiException('服务器响应格式错误', statusCode: response.statusCode);
    }

    if (response.statusCode >= 400) {
      final message = json['message'] as String? ?? '请求失败 (${response.statusCode})';
      AppLog.error('网络', '$method $path 没成功（${response.statusCode}）：$message');
      throw ApiException(message, statusCode: response.statusCode, code: json['code'] as int?);
    }

    if (json.containsKey('code') && json['code'] != 0) {
      AppLog.error('网络', '$method $path 业务没成功：${json['message']}');
      throw ApiException(json['message'] as String? ?? '请求失败', code: json['code'] as int?);
    }

    AppLog.info('网络', '$method $path 成功 · ${response.statusCode} · ${stopwatch.elapsedMilliseconds}ms');

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return json;
  }
}
