class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.nickname,
    required this.userId,
  });

  final String id;
  final String phone;
  final String nickname;
  final String userId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      nickname: json['nickname'] as String,
      userId: json['userId'] as String,
    );
  }
}
