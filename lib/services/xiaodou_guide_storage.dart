import 'package:shared_preferences/shared_preferences.dart';

class XiaodouGuideStorage {
  static String _key(String userId) => 'xiaodou_guide_v1_${userId.isEmpty ? 'guest' : userId}';

  Future<bool> hasSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  Future<void> markSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}
