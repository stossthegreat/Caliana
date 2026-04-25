import 'dart:convert';
import 'food_entry.dart';
import 'chat_message.dart';

/// Everything that happened on a single day: foods logged, chat with Caliana,
/// optional weight/water/steps. Persisted per-day, keyed by yyyy-mm-dd.
class DayLog {
  /// yyyy-mm-dd in user local time.
  final String date;
  final List<FoodEntry> entries;
  final List<ChatMessage> messages;

  /// Optional metrics (0 = not logged today).
  final double weightKg;
  final int waterMl;
  final int steps;

  const DayLog({
    required this.date,
    this.entries = const [],
    this.messages = const [],
    this.weightKg = 0,
    this.waterMl = 0,
    this.steps = 0,
  });

  factory DayLog.empty(DateTime day) => DayLog(date: keyFor(day));

  /// Canonical key — yyyy-mm-dd, padded.
  static String keyFor(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  // ---------------------------------------------------------------------------
  // Aggregates
  // ---------------------------------------------------------------------------

  int get totalCalories =>
      entries.fold(0, (sum, e) => sum + e.calories);

  int get totalProtein =>
      entries.fold(0, (sum, e) => sum + e.proteinGrams);

  int get totalCarbs =>
      entries.fold(0, (sum, e) => sum + e.carbsGrams);

  int get totalFat =>
      entries.fold(0, (sum, e) => sum + e.fatGrams);

  /// True if any food was actually logged today.
  bool get hasEntries => entries.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Mutations (return new instances — DayLog is immutable)
  // ---------------------------------------------------------------------------

  DayLog addEntry(FoodEntry entry) =>
      copyWith(entries: [...entries, entry]);

  DayLog removeEntry(String entryId) => copyWith(
        entries: entries.where((e) => e.id != entryId).toList(),
      );

  DayLog updateEntry(FoodEntry updated) => copyWith(
        entries: entries
            .map((e) => e.id == updated.id ? updated : e)
            .toList(),
      );

  DayLog addMessage(ChatMessage msg) =>
      copyWith(messages: [...messages, msg]);

  DayLog copyWith({
    List<FoodEntry>? entries,
    List<ChatMessage>? messages,
    double? weightKg,
    int? waterMl,
    int? steps,
  }) {
    return DayLog(
      date: date,
      entries: entries ?? this.entries,
      messages: messages ?? this.messages,
      weightKg: weightKg ?? this.weightKg,
      waterMl: waterMl ?? this.waterMl,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'entries': entries.map((e) => e.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'weightKg': weightKg,
        'waterMl': waterMl,
        'steps': steps,
      };

  factory DayLog.fromJson(Map<String, dynamic> json) => DayLog(
        date: json['date'] as String,
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        messages: ((json['messages'] as List?) ?? const [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        waterMl: json['waterMl'] as int? ?? 0,
        steps: json['steps'] as int? ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
}
