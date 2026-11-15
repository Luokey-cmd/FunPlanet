import 'dart:convert';
import 'dart:io';

import '../data/product_data.dart';
import 'api_client.dart';

class UserCloudApiService {
  UserCloudApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<String>> fetchFavoriteIds() async {
    final data = await _client.get('/api/favorites', auth: true);
    return (data['productIds'] as List<dynamic>).cast<String>();
  }

  Future<bool> toggleFavorite(String productId) async {
    final data = await _client.post('/api/favorites/toggle', {'productId': productId}, auth: true);
    return data['favorited'] as bool;
  }

  Future<List<String>> fetchBrowseHistory() async {
    final data = await _client.get('/api/browse-history', auth: true);
    return (data['productIds'] as List<dynamic>).cast<String>();
  }

  Future<void> addBrowseRecord(String productId) async {
    await _client.post('/api/browse-history', {'productId': productId}, auth: true);
  }

  Future<({List<Coupon> coupons, bool newcomerClaimed, bool memberMonthlyCouponClaimed})> fetchCoupons() async {
    final data = await _client.get('/api/coupons', auth: true);
    final list = (data['coupons'] as List<dynamic>)
        .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      coupons: list,
      newcomerClaimed: data['newcomerClaimed'] as bool? ?? false,
      memberMonthlyCouponClaimed: data['memberMonthlyCouponClaimed'] as bool? ?? false,
    );
  }

  Future<List<Coupon>> claimNewcomer() async {
    final data = await _client.post('/api/coupons/claim/newcomer', {}, auth: true);
    return _parseCoupons(data['coupons'] as List<dynamic>);
  }

  Future<List<Coupon>> claimMemberMonthly() async {
    final data = await _client.post('/api/coupons/claim/member-monthly', {}, auth: true);
    return _parseCoupons(data['coupons'] as List<dynamic>);
  }

  Future<List<Coupon>> claimCenter() async {
    final data = await _client.post('/api/coupons/claim/center', {}, auth: true);
    return _parseCoupons(data['coupons'] as List<dynamic>);
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final data = await _client.get('/api/notifications', auth: true);
    return (data['notifications'] as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.put('/api/notifications/$id/read', auth: true);
  }

  Future<void> markAllNotificationsRead() async {
    await _client.put('/api/notifications/read-all', auth: true);
  }

  Future<List<Address>> fetchAddresses() async {
    final data = await _client.get('/api/addresses', auth: true);
    return (data['addresses'] as List<dynamic>)
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setDefaultAddress(String addressId) async {
    await _client.put('/api/addresses/$addressId/default', auth: true);
  }

  Future<Address> createAddress({
    required String name,
    required String phone,
    required String detail,
    bool isDefault = false,
  }) async {
    final data = await _client.post('/api/addresses', {
      'name': name,
      'phone': phone,
      'detail': detail,
      'isDefault': isDefault,
    }, auth: true);
    return Address.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<Address> updateAddress({
    required String id,
    required String name,
    required String phone,
    required String detail,
    bool isDefault = false,
  }) async {
    final data = await _client.put('/api/addresses/$id', body: {
      'name': name,
      'phone': phone,
      'detail': detail,
      'isDefault': isDefault,
    }, auth: true);
    return Address.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _client.delete('/api/addresses/$id', auth: true);
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final data = await _client.get('/api/profile', auth: true);
    return data['profile'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatarPath,
    bool? pushEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatarPath != null) body['avatarPath'] = avatarPath;
    if (pushEnabled != null) body['pushEnabled'] = pushEnabled;
    final data = await _client.patch('/api/profile', body: body, auth: true);
    return data['profile'] as Map<String, dynamic>;
  }

  Future<String> uploadAvatar(List<int> bytes, String mimeType) async {
    final data = await _client.post('/api/profile/avatar', {
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    }, auth: true);
    return data['avatarPath'] as String;
  }

  Future<Map<String, dynamic>> profileAction(String action) async {
    final data = await _client.post('/api/profile/actions/$action', {}, auth: true);
    return data['profile'] as Map<String, dynamic>;
  }

  Future<List<WalletLedgerEntry>> fetchLedger(String type) async {
    final data = await _client.get('/api/profile/ledger?type=$type', auth: true);
    return (data['entries'] as List<dynamic>)
        .map((e) => WalletLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> resetAccount() async {
    final data = await _client.post('/api/profile/reset', {}, auth: true);
    return data['profile'] as Map<String, dynamic>;
  }

  List<Coupon> _parseCoupons(List<dynamic> list) {
    return list.map((e) => Coupon.fromJson(e as Map<String, dynamic>)).toList();
  }
}
