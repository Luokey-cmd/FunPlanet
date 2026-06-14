import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/product_data.dart';
import '../services/api_client.dart';
import '../services/user_cloud_api_service.dart';
import '../widgets/user_avatar_image.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({UserCloudApiService? cloudApi}) : _cloudApi = cloudApi ?? UserCloudApiService() {
    applyFreshInitialState(keepNickname: true, keepUserId: true);
    unawaited(_restoreLocalAvatarCache());
  }

  static const _avatarCacheKey = 'user_avatar_path';

  final UserCloudApiService _cloudApi;
  bool _cloudSync = false;

  String nickname = 'Luca123';
  String userId = '1064453837';
  String avatarPath = profileAvatarPath;
  int vipLevel = 1;
  int points = 0;
  int funCoins = 0;
  int couponCount = 0;
  bool pushEnabled = true;
  bool newcomerClaimed = false;
  bool dailyCheckInDone = false;
  bool dailyShareDone = false;
  bool dailyBrowseRewardClaimed = false;
  int dailyBrowseCount = 0;
  bool memberMonthlyCouponClaimed = false;

  final Set<String> _favoriteIds = {};
  final List<String> _browseHistory = [];
  final List<Coupon> _coupons = [];
  List<Address> _addresses = [];
  List<AppNotification> _notifications = [];

  bool get isCloudSync => _cloudSync;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<String> get browseHistory => List.unmodifiable(_browseHistory);
  List<Coupon> get coupons => List.unmodifiable(_coupons);
  List<Address> get addresses => List.unmodifiable(_addresses);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get availableCouponCount => _coupons.where((c) => !c.used).length;
  int get unreadNotificationCount => _notifications.where((n) => !n.read).length;

  Address? get defaultAddress {
    for (final a in _addresses) {
      if (a.isDefault) return a;
    }
    return _addresses.isNotEmpty ? _addresses.first : null;
  }

  List<Product> get favoriteProducts =>
      products.where((p) => _favoriteIds.contains(p.id)).toList();

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  void _applyProfileJson(Map<String, dynamic> json) {
    nickname = json['nickname'] as String? ?? nickname;
    userId = json['userId'] as String? ?? userId;
    points = json['points'] as int? ?? points;
    funCoins = json['funCoins'] as int? ?? funCoins;
    vipLevel = json['vipLevel'] as int? ?? vipLevel;
    avatarPath = (json['avatarPath'] as String?)?.trim().isNotEmpty == true
        ? (json['avatarPath'] as String).trim()
        : avatarPath;
    newcomerClaimed = json['newcomerClaimed'] as bool? ?? newcomerClaimed;
    memberMonthlyCouponClaimed =
        json['memberMonthlyCouponClaimed'] as bool? ?? memberMonthlyCouponClaimed;
    dailyCheckInDone = json['dailyCheckInDone'] as bool? ?? dailyCheckInDone;
    dailyShareDone = json['dailyShareDone'] as bool? ?? dailyShareDone;
    dailyBrowseRewardClaimed =
        json['dailyBrowseRewardClaimed'] as bool? ?? dailyBrowseRewardClaimed;
    dailyBrowseCount = json['dailyBrowseCount'] as int? ?? dailyBrowseCount;
    pushEnabled = json['pushEnabled'] as bool? ?? pushEnabled;
    if (avatarPath.trim().isNotEmpty) {
      unawaited(_persistAvatar(avatarPath));
    }
  }

  Future<void> _restoreLocalAvatarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_avatarCacheKeyFor(userId))?.trim();
      if (cached != null && cached.isNotEmpty) {
        avatarPath = cached;
        notifyListeners();
      }
    } catch (_) {}
  }

  String _avatarCacheKeyFor(String id) {
    final uid = id.trim();
    if (uid.isEmpty) return _avatarCacheKey;
    return '${_avatarCacheKey}_$uid';
  }

  Future<void> _persistAvatar(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = path.trim();
      final key = _avatarCacheKeyFor(userId);
      if (trimmed.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, trimmed);
      }
    } catch (_) {}
  }

  Future<void> refreshProfileFromRemote() async {
    await _restoreLocalAvatarCache();
    try {
      final profile = await _cloudApi.fetchProfile();
      final cachedAvatar = avatarPath;
      _applyProfileJson(profile);
      if (avatarPath.trim().isEmpty && cachedAvatar.trim().isNotEmpty) {
        avatarPath = cachedAvatar;
      }
      _cloudSync = true;
      notifyListeners();
    } catch (_) {}
  }

  void applyFreshInitialState({bool keepNickname = false, bool keepUserId = false}) {
    if (!keepNickname) nickname = 'Luca123';
    if (!keepUserId) userId = '1064453837';
    avatarPath = profileAvatarPath;
    vipLevel = 1;
    points = 0;
    funCoins = 0;
    couponCount = 0;
    pushEnabled = true;
    newcomerClaimed = false;
    dailyCheckInDone = false;
    dailyShareDone = false;
    dailyBrowseRewardClaimed = false;
    dailyBrowseCount = 0;
    memberMonthlyCouponClaimed = false;
    _favoriteIds.clear();
    _browseHistory.clear();
    _coupons.clear();
    _addresses.clear();
    _notifications.clear();
  }

  Future<void> resetAccountRemote() async {
    final profile = await _cloudApi.resetAccount();
    applyFreshInitialState(keepNickname: true, keepUserId: true);
    _applyProfileJson(profile);
    couponCount = 0;
    notifyListeners();
  }

  Future<void> loadFromRemote() async {
    try {
      final profile = await _cloudApi.fetchProfile();
      _applyProfileJson(profile);
      _cloudSync = true;
    } catch (_) {}

    try {
      final favIds = await _cloudApi.fetchFavoriteIds();
      final history = await _cloudApi.fetchBrowseHistory();
      final couponData = await _cloudApi.fetchCoupons();
      final notes = await _cloudApi.fetchNotifications();
      final addresses = await _cloudApi.fetchAddresses();

      _favoriteIds
        ..clear()
        ..addAll(favIds);
      _browseHistory
        ..clear()
        ..addAll(history);
      _coupons
        ..clear()
        ..addAll(couponData.coupons);
      _notifications = List.from(notes);
      _addresses = List.from(addresses);
      newcomerClaimed = couponData.newcomerClaimed;
      memberMonthlyCouponClaimed = couponData.memberMonthlyCouponClaimed;
      couponCount = _coupons.length;
      notifyListeners();
    } catch (_) {
      await _restoreLocalAvatarCache();
    }
  }

  Future<void> refreshNotifications() async {
    if (!_cloudSync) return;
    try {
      final notes = await _cloudApi.fetchNotifications();
      _notifications = List.from(notes);
      notifyListeners();
    } catch (_) {
      // 保留已有通知
    }
  }

  Future<String?> saveProfile({
    String? nickname,
    String? avatarPath,
    List<int>? avatarBytes,
    String? avatarMimeType,
  }) async {
    if (_cloudSync) {
      try {
        String? patchAvatar;

        if (avatarBytes != null && avatarBytes.isNotEmpty) {
          patchAvatar = await _cloudApi.uploadAvatar(avatarBytes, avatarMimeType ?? 'image/jpeg');
        } else if (avatarPath != null && avatarPath.isNotEmpty) {
          if (isRemoteAvatarPath(avatarPath) || isAssetAvatarPath(avatarPath)) {
            patchAvatar = avatarPath;
          } else {
            final file = File(avatarPath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final lower = avatarPath.toLowerCase();
              final mimeType = lower.endsWith('.png')
                  ? 'image/png'
                  : lower.endsWith('.webp')
                      ? 'image/webp'
                      : lower.endsWith('.gif')
                          ? 'image/gif'
                          : 'image/jpeg';
              patchAvatar = await _cloudApi.uploadAvatar(bytes, mimeType);
            }
          }
        }

        final profile = await _cloudApi.updateProfile(
          nickname: nickname,
          avatarPath: patchAvatar,
        );
        _applyProfileJson(profile);
        notifyListeners();
        return null;
      } catch (e) {
        return e.toString();
      }
    }
    if (nickname != null) updateNickname(nickname);
    if (avatarPath != null) updateAvatar(avatarPath);
    return null;
  }

  Future<String?> saveAddress({
    String? id,
    required String name,
    required String phone,
    required String detail,
    bool isDefault = false,
  }) async {
    if (_cloudSync) {
      try {
        if (id == null) {
          await _cloudApi.createAddress(
            name: name,
            phone: phone,
            detail: detail,
            isDefault: isDefault,
          );
        } else {
          await _cloudApi.updateAddress(
            id: id,
            name: name,
            phone: phone,
            detail: detail,
            isDefault: isDefault,
          );
        }
        await loadFromRemote();
        return null;
      } catch (e) {
        return e.toString();
      }
    }
    return '未登录云端';
  }

  Future<String?> removeAddress(String id) async {
    if (_cloudSync) {
      try {
        await _cloudApi.deleteAddress(id);
        await loadFromRemote();
        return null;
      } catch (e) {
        return e.toString();
      }
    }
    _addresses.removeWhere((a) => a.id == id);
    notifyListeners();
    return null;
  }

  void toggleFavorite(String productId) {
    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    notifyListeners();
    if (_cloudSync) unawaited(_syncToggleFavorite(productId));
  }

  Future<void> _syncToggleFavorite(String productId) async {
    try {
      await _cloudApi.toggleFavorite(productId);
    } catch (_) {
      await loadFromRemote();
    }
  }

  void addBrowseRecord(String productId) {
    _browseHistory.remove(productId);
    _browseHistory.insert(0, productId);
    if (_browseHistory.length > 20) {
      _browseHistory.removeRange(20, _browseHistory.length);
    }
    notifyListeners();
    if (_cloudSync) {
      unawaited(_syncBrowseRecord(productId));
    } else {
      dailyBrowseCount += 1;
      notifyListeners();
    }
  }

  Future<void> _syncBrowseRecord(String productId) async {
    try {
      await _cloudApi.addBrowseRecord(productId);
      final profile = await _cloudApi.fetchProfile();
      _applyProfileJson(profile);
      notifyListeners();
    } catch (_) {}
  }

  bool dailyCheckIn() {
    if (dailyCheckInDone) return false;
    if (_cloudSync) {
      unawaited(_profileAction('check-in'));
      return true;
    }
    dailyCheckInDone = true;
    points += 50;
    notifyListeners();
    return true;
  }

  bool completeDailyShare() {
    if (dailyShareDone) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-share'));
      return true;
    }
    dailyShareDone = true;
    funCoins += 20;
    notifyListeners();
    return true;
  }

  bool claimDailyBrowseReward() {
    if (dailyBrowseRewardClaimed || dailyBrowseCount < 3) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-browse-reward'));
      return true;
    }
    dailyBrowseRewardClaimed = true;
    funCoins += 30;
    notifyListeners();
    return true;
  }

  Future<void> _profileAction(String action) async {
    try {
      final profile = await _cloudApi.profileAction(action);
      _applyProfileJson(profile);
      if (action == 'redeem-points-coupon') {
        await loadFromRemote();
      } else {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<List<WalletLedgerEntry>> fetchPointLedger() async {
    if (!_cloudSync) return [];
    try {
      return await _cloudApi.fetchLedger('points');
    } catch (_) {
      return [];
    }
  }

  Future<List<WalletLedgerEntry>> fetchCoinLedger() async {
    if (!_cloudSync) return [];
    try {
      return await _cloudApi.fetchLedger('coins');
    } catch (_) {
      return [];
    }
  }

  Future<String?> redeemPointsForCoupon() async {
    if (!_cloudSync) return '请先登录';
    try {
      final profile = await _cloudApi.profileAction('redeem-points-coupon');
      _applyProfileJson(profile);
      await loadFromRemote();
      notifyListeners();
      return null;
    } catch (e) {
      if (e is ApiException) return e.message;
      return e.toString();
    }
  }

  Future<String?> subscribeMember() async {
    if (vipLevel >= memberTargetVipLevel) return '您已是会员';
    if (!_cloudSync) {
      if (funCoins < memberSubscribeCoinPrice) {
        return '趣玩币不足，还差 ${memberSubscribeCoinPrice - funCoins}';
      }
      funCoins -= memberSubscribeCoinPrice;
      vipLevel = memberTargetVipLevel;
      notifyListeners();
      return null;
    }
    try {
      final profile = await _cloudApi.profileAction('subscribe-member');
      _applyProfileJson(profile);
      notifyListeners();
      return null;
    } catch (e) {
      if (e is ApiException) return e.message;
      return e.toString();
    }
  }

  bool claimMemberMonthlyCoupon() {
    if (vipLevel < memberTargetVipLevel) return false;
    if (memberMonthlyCouponClaimed) return false;
    if (_cloudSync) {
      unawaited(_claimMemberMonthlyRemote());
      return true;
    }
    memberMonthlyCouponClaimed = true;
    couponCount += 1;
    _coupons.insert(
      0,
      const Coupon(
        id: 'c5',
        title: '会员每月赠券',
        discount: 20,
        condition: '满99可用',
        expire: '2025-12-31',
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> _claimMemberMonthlyRemote() async {
    try {
      await _cloudApi.claimMemberMonthly();
      await loadFromRemote();
    } catch (_) {}
  }

  bool claimCouponCenterGift() {
    final hasGift = _coupons.any((c) => c.id == 'c6');
    if (hasGift) return false;
    if (_cloudSync) {
      unawaited(_claimCenterRemote());
      return true;
    }
    couponCount += 1;
    _coupons.insert(
      0,
      const Coupon(
        id: 'c6',
        title: '领券中心满120减25',
        discount: 25,
        condition: '满120可用',
        expire: '2025-10-31',
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> _claimCenterRemote() async {
    try {
      await _cloudApi.claimCenter();
      await loadFromRemote();
    } catch (_) {}
  }

  void recordOrder(double total) {
    if (_cloudSync) return;
    final earned = (total.floor()).clamp(1, 100);
    points += earned;
    funCoins += earned * 2;
    notifyListeners();
  }

  bool claimNewcomerCoupon() {
    if (newcomerClaimed) return false;
    if (_cloudSync) {
      unawaited(_claimNewcomerRemote());
      return true;
    }
    newcomerClaimed = true;
    couponCount += 2;
    _coupons.insert(
      0,
      const Coupon(
        id: 'c1',
        title: '新人满30减5',
        discount: 5,
        condition: '满30可用',
        expire: '2025-12-31',
      ),
    );
    _coupons.insert(
      1,
      const Coupon(
        id: 'c4',
        title: '新人满50减10',
        discount: 10,
        condition: '满50可用',
        expire: '2025-12-31',
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> _claimNewcomerRemote() async {
    try {
      await _cloudApi.claimNewcomer();
      await loadFromRemote();
    } catch (_) {}
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].read) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    notifyListeners();
    if (_cloudSync) unawaited(_cloudApi.markNotificationRead(id));
  }

  void markAllNotificationsRead() {
    var changed = false;
    _notifications = _notifications.map((n) {
      if (n.read) return n;
      changed = true;
      return n.copyWith(read: true);
    }).toList();
    if (changed) notifyListeners();
    if (_cloudSync && changed) unawaited(_cloudApi.markAllNotificationsRead());
  }

  void setDefaultAddress(String addressId) {
    _addresses = _addresses.map((a) => a.copyWith(isDefault: a.id == addressId)).toList();
    notifyListeners();
    if (_cloudSync) unawaited(_syncDefaultAddress(addressId));
  }

  Future<void> _syncDefaultAddress(String addressId) async {
    try {
      await _cloudApi.setDefaultAddress(addressId);
      await loadFromRemote();
    } catch (_) {}
  }

  void setPushEnabled(bool value) {
    pushEnabled = value;
    notifyListeners();
    if (_cloudSync) unawaited(_cloudApi.updateProfile(pushEnabled: value));
  }

  void updateNickname(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == nickname) return;
    nickname = trimmed;
    notifyListeners();
  }

  void updateAvatar(String path) {
    if (path == avatarPath) return;
    avatarPath = path;
    notifyListeners();
    unawaited(_persistAvatar(path));
  }

  void applyFromAuth({
    required String nickname,
    required String userId,
    required String phone,
    bool isNewUser = false,
  }) {
    this.nickname = nickname;
    this.userId = userId;
    if (isNewUser) {
      applyFreshInitialState(keepNickname: false, keepUserId: false);
      this.nickname = nickname;
      this.userId = userId;
    }
    unawaited(_restoreLocalAvatarCache());
    notifyListeners();
  }

  void resetForLogout() {
    _cloudSync = false;
    applyFreshInitialState(keepNickname: true, keepUserId: true);
    unawaited(_persistAvatar(''));
    notifyListeners();
  }
}
