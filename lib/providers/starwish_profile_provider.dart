import 'package:flutter/foundation.dart';

import '../models/starwish_profile.dart';
import '../services/starwish_profile_storage.dart';

class StarwishProfileProvider extends ChangeNotifier {
  StarwishProfileProvider({StarwishProfileStorage? storage}) : _storage = storage ?? StarwishProfileStorage() {
    _load();
  }

  final StarwishProfileStorage _storage;
  String? _userKey;
  StarwishProfile _profile = const StarwishProfile();

  StarwishProfile get profile => _profile;
  bool get isComplete => _profile.isComplete;

  Future<void> bindUser(String? userId) async {
    if (_userKey == userId) return;
    _userKey = userId;
    await _load();
  }

  Future<void> _load() async {
    _profile = await _storage.load(_userKey);
    notifyListeners();
  }

  Future<void> update(StarwishProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _storage.save(_userKey, profile);
  }
}
