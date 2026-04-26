import 'dart:convert';
import '../models/meal_idea.dart';

/// A meal Caliana has scheduled for a future day. Wraps a MealIdea
/// (so it carries image/macros/ingredients/etc.) plus the slot it
/// belongs to and whether the user has confirmed eating it.
class PlannedMeal {
  final String id;
  final DateTime date; // logical date the meal is scheduled for
  final String slot; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final MealIdea idea;
  final bool committed;

  const PlannedMeal({
    required this.id,
    required this.date,
    required this.slot,
    required this.idea,
    this.committed = false,
  });

  PlannedMeal copyWith({
    DateTime? date,
    String? slot,
    MealIdea? idea,
    bool? committed,
  }) {
    return PlannedMeal(
      id: id,
      date: date ?? this.date,
      slot: slot ?? this.slot,
      idea: idea ?? this.idea,
      committed: committed ?? this.committed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'slot': slot,
        'idea': idea.toJson(),
        'committed': committed,
      };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        slot: json['slot'] as String,
        idea: MealIdea.fromJson(json['idea'] as Map<String, dynamic>),
        committed: json['committed'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
}

/// The four canonical slots in a daily plan, in order.
const List<String> kMealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

String slotLabel(String slot) {
  switch (slot) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'dinner':
      return 'Dinner';
    case 'snack':
      return 'Snack';
    default:
      return slot[0].toUpperCase() + slot.substring(1);
  }
}
