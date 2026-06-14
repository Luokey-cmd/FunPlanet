import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

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

    late http.Response response;
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

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('服务器响应格式错误', statusCode: response.statusCode);
    }

    if (response.statusCode >= 400) {
      final message = json['message'] as String? ?? '请求失败 (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode, code: json['code'] as int?);
    }

    if (json.containsKey('code') && json['code'] != 0) {
      throw ApiException(json['message'] as String? ?? '请求失败', code: json['code'] as int?);
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return json;
  }
}
