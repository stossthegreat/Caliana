import 'dart:convert';

/// A single logged food. Lives inside a DayLog and is referenced by chat messages.
class FoodEntry {
  final String id;
  final DateTime timestamp;
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;

  /// 'photo', 'text', 'voice', 'barcode', 'fridge'
  final String inputMethod;

  /// Local file path of the snap, if any.
  final String? photoPath;

  /// 'low', 'medium', 'high' — Caliana's confidence in the estimate.
  final String confidence;

  /// Optional notes / clarifying answers (e.g. "cooked in 1 tbsp olive oil").
  final String notes;

  const FoodEntry({
    required this.id,
    required this.timestamp,
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.inputMethod,
    this.photoPath,
    this.confidence = 'medium',
    this.notes = '',
  });

  FoodEntry copyWith({
    String? name,
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    String? confidence,
    String? notes,
  }) {
    return FoodEntry(
      id: id,
      timestamp: timestamp,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      inputMethod: inputMethod,
      photoPath: photoPath,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'name': name,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'inputMethod': inputMethod,
        'photoPath': photoPath,
        'confidence': confidence,
        'notes': notes,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        name: json['name'] as String,
        calories: json['calories'] as int,
        proteinGrams: json['proteinGrams'] as int,
        carbsGrams: json['carbsGrams'] as int,
        fatGrams: json['fatGrams'] as int,
        inputMethod: json['inputMethod'] as String? ?? 'text',
        photoPath: json['photoPath'] as String?,
        confidence: json['confidence'] as String? ?? 'medium',
        notes: json['notes'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());
}
