import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Singleton that owns Caliana's user profile.
class UserProfileService extends ChangeNotifier {
  UserProfileService._();
  static final UserProfileService _instance = UserProfileService._();
  static UserProfileService get instance => _instance;

  static const _storageKey = 'caliana_user_profile_v1';

  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _profile = UserProfile.fromJsonString(jsonStr);
      }
    } catch (_) {
      _profile = const UserProfile();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(UserProfile next) async {
    _profile = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _profile.toJsonString());
    } catch (_) {}
  }

  Future<void> reset() async {
    _profile = const UserProfile();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
