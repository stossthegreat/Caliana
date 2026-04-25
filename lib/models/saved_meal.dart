import 'dart:convert';

/// A meal Caliana suggested (or the user starred) for later reference.
class SavedMeal {
  final String id;
  final DateTime savedAt;
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;

  /// Ingredients with quantities, one per line.
  final List<String> ingredients;

  /// Short imperative steps.
  final List<String> steps;

  /// Optional URL to the original recipe (Serper top hit).
  final String? recipeLink;

  /// Optional source title ("BBC Good Food — Greek Salad").
  final String? recipeSource;

  /// 'caliana_suggestion' (she pulled it) or 'user_starred' (user liked their own log).
  final String source;

  /// Optional note ("Sunday dinner pick", "Caliana's fridge fix").
  final String note;

  const SavedMeal({
    required this.id,
    required this.savedAt,
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.ingredients = const [],
    this.steps = const [],
    this.recipeLink,
    this.recipeSource,
    this.source = 'caliana_suggestion',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'name': name,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'ingredients': ingredients,
        'steps': steps,
        if (recipeLink != null) 'recipeLink': recipeLink,
        if (recipeSource != null) 'recipeSource': recipeSource,
        'source': source,
        'note': note,
      };

  factory SavedMeal.fromJson(Map<String, dynamic> json) => SavedMeal(
        id: json['id'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
        name: json['name'] as String,
        calories: json['calories'] as int,
        proteinGrams: json['proteinGrams'] as int? ?? 0,
        carbsGrams: json['carbsGrams'] as int? ?? 0,
        fatGrams: json['fatGrams'] as int? ?? 0,
        ingredients: _stringList(json['ingredients']),
        steps: _stringList(json['steps']),
        recipeLink: json['recipeLink'] as String?,
        recipeSource: json['recipeSource'] as String?,
        source: json['source'] as String? ?? 'caliana_suggestion',
        note: json['note'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
