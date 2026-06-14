import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/auth_user.dart';
import '../services/api_client.dart';
import '../services/auth_api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthApiService? api}) : _api = api ?? AuthApiService();

  final AuthApiService _api;

  bool isInitialized = false;
  bool isLoggedIn = false;
  AuthUser? currentUser;
  String? lastError;

  Future<void> init() async {
    try {
      final user = await _api.me();
      if (user != null) {
        currentUser = user;
        isLoggedIn = true;
      }
    } on ApiException catch (e) {
      lastError = e.message;
      await _api.logout();
    } catch (_) {
      // 后端不可达时保持未登录，商品仍可用本地缓存数据
    }
    isInitialized = true;
    notifyListeners();
  }

  String? validatePhone(String phone) {
    final value = phone.trim();
    if (value.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1\d{10}$').hasMatch(value)) return '请输入正确的 11 位手机号';
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return '请输入密码';
    if (password.length < 6) return '密码至少 6 位';
    return null;
  }

  String? validateNickname(String nickname) {
    final value = nickname.trim();
    if (value.isEmpty) return '请输入昵称';
    if (value.length < 2) return '昵称至少 2 个字';
    if (value.length > 16) return '昵称最多 16 个字';
    return null;
  }

  String _connectionErrorMessage() {
    final detail = ApiConfig.lastError;
    final urls = ApiConfig.lastUsedUrl ??
        ApiConfig.lastTriedUrl ??
        (() {
          try {
            return ApiConfig.candidateUrls.join('、');
          } catch (_) {
            return '未配置';
          }
        })();
    if (kReleaseMode) {
      return '无法连接服务器（$urls）'
          '${detail != null ? "；$detail" : ""}。请确认线上 API 已部署并可访问。';
    }
    return '无法连接服务器（已试 $urls）'
        '；请先运行 scripts/adb-reverse.ps1（模拟器/真机 USB 调试）'
        '；真机 WiFi 还需管理员运行 scripts/allow-api-firewall.ps1'
        '${detail != null ? "（$detail）" : ""}';
  }

  Future<String?> login({required String phone, required String password}) async {
    final phoneError = validatePhone(phone);
    if (phoneError != null) return phoneError;
    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;

    try {
      ApiConfig.reset();
      final result = await _api.login(phone: phone.trim(), password: password);
      currentUser = result.user;
      isLoggedIn = true;
      lastError = null;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return _connectionErrorMessage();
    }
  }

  Future<String?> register({
    required String phone,
    required String password,
    required String confirmPassword,
    required String nickname,
  }) async {
    final phoneError = validatePhone(phone);
    if (phoneError != null) return phoneError;
    final nicknameError = validateNickname(nickname);
    if (nicknameError != null) return nicknameError;
    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;
    if (password != confirmPassword) return '两次输入的密码不一致';

    try {
      ApiConfig.reset();
      final result = await _api.register(
        phone: phone.trim(),
        password: password,
        confirmPassword: confirmPassword,
        nickname: nickname.trim(),
      );
      currentUser = result.user;
      isLoggedIn = true;
      lastError = null;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return _connectionErrorMessage();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    currentUser = null;
    isLoggedIn = false;
    notifyListeners();
  }
}
