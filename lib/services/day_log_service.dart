import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_log.dart';
import '../models/food_entry.dart';
import '../models/chat_message.dart';

/// Per-day persistence of food entries + chat history.
/// Keyed by yyyy-mm-dd in local time.
///
/// Listeners are notified on every mutation so the home screen counter
/// re-renders live.
class DayLogService extends ChangeNotifier {
  DayLogService._();
  static final DayLogService _instance = DayLogService._();
  static DayLogService get instance => _instance;

  static const _indexKey = 'caliana_day_log_index_v1';
  static const _dayKeyPrefix = 'caliana_day_log_';

  final Map<String, DayLog> _byDate = {};
  final Set<String> _index = <String>{};

  bool _loaded = false;
  bool get loaded => _loaded;

  /// All dates we have data for (yyyy-mm-dd), most recent first.
  List<String> get loggedDates {
    final list = _index.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        _index.addAll(list);
        for (final dateKey in list) {
          final day = prefs.getString('$_dayKeyPrefix$dateKey');
          if (day != null && day.isNotEmpty) {
            try {
              _byDate[dateKey] = DayLog.fromJson(
                jsonDecode(day) as Map<String, dynamic>,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  DayLog forDay(DateTime day) {
    final key = DayLog.keyFor(day);
    return _byDate[key] ?? DayLog.empty(day);
  }

  DayLog get today => forDay(DateTime.now());

  /// Rolling-7 totals — what Caliana's weekly budget references.
  int get weeklyCalories {
    final now = DateTime.now();
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += forDay(now.subtract(Duration(days: i))).totalCalories;
    }
    return sum;
  }

  /// Consecutive days (ending today OR yesterday) with at least one
  /// entry. Today counts as part of the streak whether or not anything
  /// is logged yet — we don't want to "break" a streak just because
  /// they haven't eaten breakfast yet.
  int get loggingStreak {
    final now = DateTime.now();
    int streak = 0;
    final todayHasEntries = forDay(now).entries.isNotEmpty;
    final start = todayHasEntries ? 0 : 1;
    for (int i = start; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      if (forDay(d).entries.isEmpty) break;
      streak++;
    }
    // If today has no entries yet, surface yesterday's streak so the
    // user sees the number they're protecting.
    return streak;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> addEntry(FoodEntry entry) async {
    final key = DayLog.keyFor(entry.timestamp);
    final current = _byDate[key] ?? DayLog.empty(entry.timestamp);
    _byDate[key] = current.addEntry(entry);
    _index.add(key);
    notifyListeners();
    await _persist(key);
  }

  Future<void> removeEntry(DateTime day, String entryId) async {
    final key = DayLog.keyFor(day);
    final current = _byDate[key];
    if (current == null) return;
    _byDate[key] = current.removeEntry(entryId);
    notifyListeners();
    await _persist(key);
  }

  Future<void> updateEntry(DateTime day, FoodEntry updated) async {
    final key = DayLog.keyFor(day);
    final current = _byDate[key];
    if (current == null) return;
    _byDate[key] = current.updateEntry(updated);
    notifyListeners();
    await _persist(key);
  }

  Future<void> addMessage(DateTime day, ChatMessage msg) async {
    final key = DayLog.keyFor(day);
    final current = _byDate[key] ?? DayLog.empty(day);
    _byDate[key] = current.addMessage(msg);
    _index.add(key);
    notifyListeners();
    await _persist(key);
  }

  Future<void> setWeight(DateTime day, double kg) async {
    final key = DayLog.keyFor(day);
    final current = _byDate[key] ?? DayLog.empty(day);
    _byDate[key] = current.copyWith(weightKg: kg);
    _index.add(key);
    notifyListeners();
    await _persist(key);
  }

  Future<void> wipeAll() async {
    _byDate.clear();
    _index.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((k) => k.startsWith(_dayKeyPrefix) || k == _indexKey)
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<void> _persist(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = _byDate[dateKey];
      if (day != null) {
        await prefs.setString(
          '$_dayKeyPrefix$dateKey',
          jsonEncode(day.toJson()),
        );
      }
      await prefs.setString(_indexKey, jsonEncode(_index.toList()));
    } catch (_) {}
  }
}
