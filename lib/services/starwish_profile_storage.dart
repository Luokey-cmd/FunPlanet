import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/starwish_profile.dart';

class StarwishProfileStorage {
  static String _key(String? userKey) => 'starwish_profile_v1_${userKey ?? 'guest'}';

  Future<StarwishProfile> load(String? userKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userKey));
    if (raw == null || raw.isEmpty) return const StarwishProfile();
    try {
      return StarwishProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StarwishProfile();
    }
  }

  Future<void> save(String? userKey, StarwishProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userKey), jsonEncode(profile.toJson()));
  }
}
