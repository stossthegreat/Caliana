import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planned_meal.dart';

/// Persists Caliana's planned meals, keyed by yyyy-mm-dd. The Plan tab
/// reads/writes through here; the Today screen reads to surface
/// "tomorrow's plan" style indicators.
class PlanService extends ChangeNotifier {
  PlanService._();
  static final PlanService _instance = PlanService._();
  static PlanService get instance => _instance;

  static const _indexKey = 'caliana_plan_index_v1';
  static const _dayKeyPrefix = 'caliana_plan_';

  final Map<String, List<PlannedMeal>> _byDate = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        for (final dateKey in list) {
          final stored = prefs.getString('$_dayKeyPrefix$dateKey');
          if (stored == null || stored.isEmpty) continue;
          try {
            final arr = jsonDecode(stored) as List;
            _byDate[dateKey] = arr
                .map((e) =>
                    PlannedMeal.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<PlannedMeal> forDay(DateTime day) {
    return List.unmodifiable(_byDate[keyFor(day)] ?? const []);
  }

  /// All upcoming meals (today + future), ordered by date then slot.
  List<PlannedMeal> get upcoming {
    final now = DateTime.now();
    final todayKey = keyFor(now);
    final keys = _byDate.keys.where((k) => k.compareTo(todayKey) >= 0).toList()
      ..sort();
    final out = <PlannedMeal>[];
    for (final k in keys) {
      final list = _byDate[k] ?? const [];
      final sorted = [...list]..sort(
          (a, b) => kMealSlots.indexOf(a.slot).compareTo(kMealSlots.indexOf(b.slot)),
        );
      out.addAll(sorted);
    }
    return out;
  }

  Future<void> setDayPlan(DateTime day, List<PlannedMeal> meals) async {
    final key = keyFor(day);
    _byDate[key] = List.unmodifiable(meals);
    await _persistDay(key);
    await _persistIndex();
    notifyListeners();
  }

  Future<void> swapMeal(DateTime day, PlannedMeal updated) async {
    final key = keyFor(day);
    final list = [...(_byDate[key] ?? const <PlannedMeal>[])];
    final idx = list.indexWhere((m) => m.id == updated.id);
    if (idx == -1) {
      list.add(updated);
    } else {
      list[idx] = updated;
    }
    _byDate[key] = List.unmodifiable(list);
    await _persistDay(key);
    notifyListeners();
  }

  Future<void> markCommitted(DateTime day, String mealId) async {
    final key = keyFor(day);
    final list = [...(_byDate[key] ?? const <PlannedMeal>[])];
    final idx = list.indexWhere((m) => m.id == mealId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(committed: true);
    _byDate[key] = List.unmodifiable(list);
    await _persistDay(key);
    notifyListeners();
  }

  Future<void> deleteMeal(DateTime day, String mealId) async {
    final key = keyFor(day);
    final list = (_byDate[key] ?? const <PlannedMeal>[])
        .where((m) => m.id != mealId)
        .toList();
    if (list.isEmpty) {
      _byDate.remove(key);
    } else {
      _byDate[key] = List.unmodifiable(list);
    }
    await _persistDay(key);
    await _persistIndex();
    notifyListeners();
  }

  Future<void> _persistDay(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _byDate[key];
      if (list == null || list.isEmpty) {
        await prefs.remove('$_dayKeyPrefix$key');
      } else {
        await prefs.setString(
          '$_dayKeyPrefix$key',
          jsonEncode(list.map((m) => m.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<void> _persistIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_indexKey, jsonEncode(_byDate.keys.toList()));
    } catch (_) {}
  }
}
