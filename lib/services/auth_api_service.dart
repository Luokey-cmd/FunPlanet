import '../models/auth_user.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthApiService {
  AuthApiService({ApiClient? client, TokenStorage? tokenStorage})
      : _client = client ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  Future<({String token, AuthUser user})> login({
    required String phone,
    required String password,
  }) async {
    final data = await _client.post('/api/auth/login', {
      'phone': phone,
      'password': password,
    });
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _tokenStorage.saveToken(token);
    return (token: token, user: user);
  }

  Future<({String token, AuthUser user})> register({
    required String phone,
    required String password,
    required String confirmPassword,
    required String nickname,
  }) async {
    final data = await _client.post('/api/auth/register', {
      'phone': phone,
      'password': password,
      'confirmPassword': confirmPassword,
      'nickname': nickname,
    });
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _tokenStorage.saveToken(token);
    return (token: token, user: user);
  }

  Future<AuthUser?> me() async {
    final token = await _tokenStorage.loadToken();
    if (token == null || token.isEmpty) return null;
    final data = await _client.get('/api/auth/me', auth: true);
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => _tokenStorage.saveToken(null);
}
