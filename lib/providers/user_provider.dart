import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/product_data.dart';
import '../services/ai_community_service.dart';
import '../services/api_client.dart';
import '../services/user_cloud_api_service.dart';
import '../widgets/user_avatar_image.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({UserCloudApiService? cloudApi, AiCommunityService? communityApi})
      : _cloudApi = cloudApi ?? UserCloudApiService(),
        _communityApi = communityApi ?? AiCommunityService() {
    applyFreshInitialState(keepNickname: true, keepUserId: true);
    unawaited(_restoreLocalAvatarCache());
  }

  static const _avatarCacheKey = 'user_avatar_path';

  final UserCloudApiService _cloudApi;
  // 社区未读回复数走社区自己的服务（未读/已读两口都在 ai-community 路由下）。
  final AiCommunityService _communityApi;
  bool _cloudSync = false;

  String nickname = 'Luca123';
  String userId = '1000';
  String avatarPath = profileAvatarPath;
  // 性别存服务端原值（male/female，空 = 未设置），生日为 yyyy-MM-dd，简介纯文本。
  String gender = '';
  String birthday = '';
  String bio = '';
  // 成长值与会员到期：服务端资料接口早就返回（growthPoints / vipExpireAt），
  // App 以前没接；到期存 ISO 原串、空 = 未设置，展示时再格式化成日期。
  int growthPoints = 0;
  String vipExpireAt = '';
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
  // 每日/每周任务扩展（2026-11-26）：Done 是服务端行为埋点记的进度、
  // Claimed 是已领奖；今日已赚由服务端按当天流水汇总下发。
  bool dailyFavoriteDone = false;
  bool dailyFavoriteClaimed = false;
  bool dailyCartDone = false;
  bool dailyCartClaimed = false;
  bool dailyChatDone = false;
  bool dailyChatClaimed = false;
  bool dailyCommunityDone = false;
  bool dailyCommunityClaimed = false;
  int checkInStreak = 0;
  int dailyEarnedPoints = 0;
  int dailyEarnedCoins = 0;
  int weeklyCheckInDays = 0;
  bool weeklyCheckInClaimed = false;
  bool weeklyOrderDone = false;
  bool weeklyOrderClaimed = false;
  bool weeklyReviewDone = false;
  bool weeklyReviewClaimed = false;
  bool memberMonthlyCouponClaimed = false;
  // 会员每日礼包今日是否已领：以服务端券状态接口下发的为准（按中国日期
  // 判断），本地不自己算日期，防手机时区/改时间把口径弄乱。
  bool memberDailyGiftClaimedToday = false;
  // AI 社区未读回复数：我的帖子收到、且晚于上次进社区页时间的他人评论条数
  // （口径在服务端，本地只存数字）。消息页社区行角标与底部导航消息角标都读它。
  int communityUnreadReplies = 0;

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
    dailyFavoriteDone = json['dailyFavoriteDone'] as bool? ?? dailyFavoriteDone;
    dailyFavoriteClaimed = json['dailyFavoriteClaimed'] as bool? ?? dailyFavoriteClaimed;
    dailyCartDone = json['dailyCartDone'] as bool? ?? dailyCartDone;
    dailyCartClaimed = json['dailyCartClaimed'] as bool? ?? dailyCartClaimed;
    dailyChatDone = json['dailyChatDone'] as bool? ?? dailyChatDone;
    dailyChatClaimed = json['dailyChatClaimed'] as bool? ?? dailyChatClaimed;
    dailyCommunityDone = json['dailyCommunityDone'] as bool? ?? dailyCommunityDone;
    dailyCommunityClaimed = json['dailyCommunityClaimed'] as bool? ?? dailyCommunityClaimed;
    checkInStreak = json['checkInStreak'] as int? ?? checkInStreak;
    dailyEarnedPoints = json['dailyEarnedPoints'] as int? ?? dailyEarnedPoints;
    dailyEarnedCoins = json['dailyEarnedCoins'] as int? ?? dailyEarnedCoins;
    weeklyCheckInDays = json['weeklyCheckInDays'] as int? ?? weeklyCheckInDays;
    weeklyCheckInClaimed = json['weeklyCheckInClaimed'] as bool? ?? weeklyCheckInClaimed;
    weeklyOrderDone = json['weeklyOrderDone'] as bool? ?? weeklyOrderDone;
    weeklyOrderClaimed = json['weeklyOrderClaimed'] as bool? ?? weeklyOrderClaimed;
    weeklyReviewDone = json['weeklyReviewDone'] as bool? ?? weeklyReviewDone;
    weeklyReviewClaimed = json['weeklyReviewClaimed'] as bool? ?? weeklyReviewClaimed;
    pushEnabled = json['pushEnabled'] as bool? ?? pushEnabled;
    gender = json['gender'] as String? ?? gender;
    birthday = json['birthday'] as String? ?? birthday;
    bio = json['bio'] as String? ?? bio;
    growthPoints = json['growthPoints'] as int? ?? growthPoints;
    vipExpireAt = json['vipExpireAt'] as String? ?? vipExpireAt;
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
    if (!keepUserId) userId = '1000';
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
    dailyFavoriteDone = false;
    dailyFavoriteClaimed = false;
    dailyCartDone = false;
    dailyCartClaimed = false;
    dailyChatDone = false;
    dailyChatClaimed = false;
    dailyCommunityDone = false;
    dailyCommunityClaimed = false;
    checkInStreak = 0;
    dailyEarnedPoints = 0;
    dailyEarnedCoins = 0;
    weeklyCheckInDays = 0;
    weeklyCheckInClaimed = false;
    weeklyOrderDone = false;
    weeklyOrderClaimed = false;
    weeklyReviewDone = false;
    weeklyReviewClaimed = false;
    memberMonthlyCouponClaimed = false;
    memberDailyGiftClaimedToday = false;
    communityUnreadReplies = 0;
    gender = '';
    birthday = '';
    bio = '';
    growthPoints = 0;
    vipExpireAt = '';
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
      memberDailyGiftClaimedToday = couponData.memberDailyGiftClaimedToday;
      couponCount = _coupons.length;
      // 社区未读跟着全量刷新一起对齐（notify 交给本函数末尾这次，不重复弹）。
      await refreshCommunityUnread(notify: false);
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

  // 刷新社区未读回复数：拉不到就保留旧值（角标宁可慢一拍，不能闪没）。
  // 挂载点：loadFromRemote 全量刷新 + 12 秒会话轮询（refreshSessionData），
  // 所以停在任何页面底部导航角标都能自己更新，不必非进消息页。
  Future<void> refreshCommunityUnread({bool notify = true}) async {
    if (!_cloudSync) return;
    try {
      communityUnreadReplies = await _communityApi.fetchUnreadReplyCount();
      if (notify) notifyListeners();
    } catch (_) {
      // 保留已有未读数
    }
  }

  // 进社区页时标已读：本地先置 0 让角标立刻消（不等网络往返），再调服务端
  // 把已读标记推到当前时间；服务端失败也只影响下次刷新的数字，不回滚本地，
  // 下次 refreshCommunityUnread 会把真实未读重新拉回来。
  Future<void> markCommunityRepliesRead() async {
    if (communityUnreadReplies != 0) {
      communityUnreadReplies = 0;
      notifyListeners();
    }
    if (!_cloudSync) return;
    try {
      await _communityApi.markRepliesRead();
    } catch (_) {}
  }

  Future<String?> saveProfile({
    String? nickname,
    String? avatarPath,
    List<int>? avatarBytes,
    String? avatarMimeType,
    // 性别/生日/简介：不传就不动，传了就一起存（空字符串 = 清空）。
    String? gender,
    String? birthday,
    String? bio,
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
          gender: gender,
          birthday: birthday,
          bio: bio,
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
    if (gender != null) this.gender = gender;
    if (birthday != null) this.birthday = birthday;
    if (bio != null) this.bio = bio;
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
      // 每日收藏任务的本地进度先亮起来（云端模式服务端也会记，
      // 下次拉资料时以服务端为准覆盖）
      dailyFavoriteDone = true;
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
    // 本地模式没有服务端的上次签到日期可比，连签天数先顺延 +1 展示，
    // 云端模式以服务端返回为准
    checkInStreak += 1;
    if (weeklyCheckInDays < 7) weeklyCheckInDays += 1;
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

  bool claimDailyFavoriteReward() {
    if (!dailyFavoriteDone || dailyFavoriteClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-favorite-reward'));
      return true;
    }
    dailyFavoriteClaimed = true;
    funCoins += 15;
    notifyListeners();
    return true;
  }

  bool claimDailyCartReward() {
    if (!dailyCartDone || dailyCartClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-cart-reward'));
      return true;
    }
    dailyCartClaimed = true;
    funCoins += 15;
    notifyListeners();
    return true;
  }

  bool claimDailyChatReward() {
    if (!dailyChatDone || dailyChatClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-chat-reward'));
      return true;
    }
    dailyChatClaimed = true;
    points += 20;
    notifyListeners();
    return true;
  }

  bool claimDailyCommunityReward() {
    if (!dailyCommunityDone || dailyCommunityClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('daily-community-reward'));
      return true;
    }
    dailyCommunityClaimed = true;
    points += 20;
    notifyListeners();
    return true;
  }

  bool claimWeeklyCheckInReward() {
    if (weeklyCheckInClaimed || weeklyCheckInDays < 5) return false;
    if (_cloudSync) {
      unawaited(_profileAction('weekly-checkin-reward'));
      return true;
    }
    weeklyCheckInClaimed = true;
    points += 100;
    notifyListeners();
    return true;
  }

  bool claimWeeklyOrderReward() {
    if (!weeklyOrderDone || weeklyOrderClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('weekly-order-reward'));
      return true;
    }
    weeklyOrderClaimed = true;
    funCoins += 50;
    notifyListeners();
    return true;
  }

  bool claimWeeklyReviewReward() {
    if (!weeklyReviewDone || weeklyReviewClaimed) return false;
    if (_cloudSync) {
      unawaited(_profileAction('weekly-review-reward'));
      return true;
    }
    weeklyReviewClaimed = true;
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

  // 趣玩币充值（模拟支付）：输入是档位（id 只用来告诉服务端选了哪一档）；
  // 输出 null=成功、字符串=失败原因。云端模式到账币数以服务端查表为准，
  // 成功后用返回的 profile 刷新余额；本地模式按同一张档位表直接加币。
  Future<String?> rechargeCoins(CoinRechargePackage pack) async {
    if (!_cloudSync) {
      funCoins += pack.coins;
      notifyListeners();
      return null;
    }
    try {
      final profile = await _cloudApi.profileAction('recharge-coins', body: {'packageId': pack.id});
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
        condition: '满88可用',
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

  // 会员每日礼包领取：输入无，输出 true=已受理领取。
  // 门槛（VIP2、今日未领）先在本地挡一道，服务端还会再判一遍并以它为准；
  // 云端模式下三件奖励（积分 +10、趣玩币 +5、礼包券）全是服务端发的，
  // 本地不预加，领完整表刷新一次把余额、券包、已领状态一起对齐。
  // 本地（未接云）模式按同一口径在本地发：数值与服务端常量保持一致。
  bool claimMemberDailyGift() {
    if (vipLevel < memberTargetVipLevel) return false;
    if (memberDailyGiftClaimedToday) return false;
    if (_cloudSync) {
      unawaited(_claimMemberDailyGiftRemote());
      return true;
    }
    memberDailyGiftClaimedToday = true;
    points += 10;
    funCoins += 5;
    couponCount += 1;
    _coupons.insert(
      0,
      const Coupon(
        id: 'c9',
        title: '会员每日礼包券',
        discount: 5,
        condition: '满30可用',
        expire: '2026-12-31',
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> _claimMemberDailyGiftRemote() async {
    try {
      await _cloudApi.claimMemberDailyGift();
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

  // 领券中心单张券领取（满200减40 c8 / 满300减80 c3 共用）：
  // 输入是券模板 id 与本地兜底用的券面信息；输出 true=已受理领取。
  // 坑：云端模式下真正的入账以服务端为准，这里只发请求再整表刷新，
  // 不要在本地先塞一张假券，否则服务端失败时用户会看到一张用不了的券。
  bool claimCouponCenterSingle({
    required String couponId,
    required String title,
    required double discount,
    required String condition,
  }) {
    if (_coupons.any((c) => c.id == couponId)) return false;
    if (_cloudSync) {
      unawaited(_claimCenterSingleRemote(couponId));
      return true;
    }
    couponCount += 1;
    _coupons.insert(
      0,
      Coupon(
        id: couponId,
        title: title,
        discount: discount,
        condition: condition,
        expire: '2026-12-31',
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> _claimCenterSingleRemote(String couponId) async {
    try {
      if (couponId == 'c8') {
        await _cloudApi.claimCenter200();
      } else if (couponId == 'c3') {
        await _cloudApi.claimCenter300();
      } else {
        return;
      }
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
