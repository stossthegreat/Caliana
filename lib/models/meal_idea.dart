/// A meal idea Caliana surfaces. Two flavours:
///   1. A REAL recipe pulled from the web (image, rating, time — preferred).
///   2. A GPT-generated fallback with name + macros only.
/// All the visual fields are nullable so the card can render either gracefully.
class MealIdea {
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final List<String> steps;
  final String? link;
  final String? source;

  // Rich JSON-LD fields — set when the backend scraped a real recipe.
  final String? imageUrl;
  final double? ratingValue;
  final int? ratingCount;
  final int? totalTimeMin;
  final String? description;
  final String? sourceDomain;
  // Always 1 — backend scales every recipe down to a single portion.
  final int? servings;
  final int? originalServings;

  const MealIdea({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.ingredients = const [],
    this.steps = const [],
    this.link,
    this.source,
    this.imageUrl,
    this.ratingValue,
    this.ratingCount,
    this.totalTimeMin,
    this.description,
    this.sourceDomain,
    this.servings,
    this.originalServings,
  });

  bool get hasRichRecipe =>
      imageUrl != null && imageUrl!.isNotEmpty;

  factory MealIdea.fromJson(Map<String, dynamic> json) => MealIdea(
        name: (json['name'] as String?) ?? 'Meal',
        calories: (json['calories'] as num?)?.round() ?? 0,
        protein: (json['protein'] as num?)?.round() ?? 0,
        carbs: (json['carbs'] as num?)?.round() ?? 0,
        fat: (json['fat'] as num?)?.round() ?? 0,
        ingredients: _stringList(json['ingredients']),
        steps: _stringList(json['steps']),
        link: (json['link'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['link'] as String?,
        source: (json['source'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['source'] as String?,
        imageUrl: (json['imageUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['imageUrl'] as String?,
        ratingValue: (json['ratingValue'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as num?)?.round(),
        totalTimeMin: (json['totalTimeMin'] as num?)?.round(),
        description: (json['description'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['description'] as String?,
        sourceDomain: (json['sourceDomain'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['sourceDomain'] as String?,
        servings: (json['servings'] as num?)?.round(),
        originalServings: (json['originalServings'] as num?)?.round(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'ingredients': ingredients,
        'steps': steps,
        if (link != null) 'link': link,
        if (source != null) 'source': source,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (ratingValue != null) 'ratingValue': ratingValue,
        if (ratingCount != null) 'ratingCount': ratingCount,
        if (totalTimeMin != null) 'totalTimeMin': totalTimeMin,
        if (description != null) 'description': description,
        if (sourceDomain != null) 'sourceDomain': sourceDomain,
        if (servings != null) 'servings': servings,
        if (originalServings != null) 'originalServings': originalServings,
      };

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
