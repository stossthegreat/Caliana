import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_meal.dart';

/// Persists meals Caliana suggests + meals the user manually stars.
/// Surfaces in the Recipes sheet on the home screen.
class SavedMealsService extends ChangeNotifier {
  SavedMealsService._();
  static final SavedMealsService _instance = SavedMealsService._();
  static SavedMealsService get instance => _instance;

  static const _key = 'caliana_saved_meals_v1';

  final List<SavedMeal> _meals = [];
  bool _loaded = false;

  List<SavedMeal> get all {
    final list = List<SavedMeal>.from(_meals);
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  bool get isEmpty => _meals.isEmpty;
  int get count => _meals.length;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => SavedMeal.fromJson(e as Map<String, dynamic>))
            .toList();
        _meals
          ..clear()
          ..addAll(list);
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(SavedMeal meal) async {
    _meals.removeWhere((m) => m.id == meal.id);
    _meals.add(meal);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _meals.removeWhere((m) => m.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> wipe() async {
    _meals.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_meals.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }
}
