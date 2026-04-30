/// A single meal suggestion from Caliana — name, macros, ingredients, steps,
/// and an optional link to a real recipe online (Serper top hit).
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
  });

  factory MealIdea.fromJson(Map<String, dynamic> json) => MealIdea(
        name: (json['name'] as String?) ?? 'Meal',
        calories: (json['calories'] as num?)?.round() ?? 0,
        protein: (json['protein'] as num?)?.round() ?? 0,
        carbs: (json['carbs'] as num?)?.round() ?? 0,
        fat: (json['fat'] as num?)?.round() ?? 0,
        ingredients: _stringList(json['ingredients']),
        steps: _stringList(json['steps']),
        link: json['link'] as String?,
        source: json['source'] as String?,
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
