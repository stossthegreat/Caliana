import 'dart:convert';
import 'food_entry.dart';
import 'meal_idea.dart';

/// A single message in Caliana's chat stream.
/// User messages, Caliana's replies, proactive interjections, food-log cards,
/// recipe-suggestion cards, plan cards, and recap cards all live here as a
/// unified timeline.
class ChatMessage {
  final String id;
  final DateTime timestamp;

  /// 'user' or 'caliana'.
  final String role;

  /// 'text' (default), 'foodLog' (attached entry), 'mealSuggest' (recipe
  /// cards), 'plan' (rebuild card), 'recap' (weekly card), 'system' (silent).
  final String type;

  final String text;

  /// Set when type == 'foodLog' — the entry this message represents.
  final FoodEntry? foodEntry;

  /// Set when type == 'mealSuggest' — the recipe ideas Caliana pulled.
  final List<MealIdea> mealIdeas;

  /// True when Caliana spoke first (proactive), not in response to user.
  final bool isInterjection;

  /// Optional inline action chips ("Yes", "Roast me first", "Plan it").
  final List<String> actionChips;

  /// Local file path of TTS audio, if Caliana has voiced this line.
  final String? audioPath;

  const ChatMessage({
    required this.id,
    required this.timestamp,
    required this.role,
    this.type = 'text',
    required this.text,
    this.foodEntry,
    this.mealIdeas = const [],
    this.isInterjection = false,
    this.actionChips = const [],
    this.audioPath,
  });

  bool get isUser => role == 'user';
  bool get isCaliana => role == 'caliana';

  ChatMessage copyWith({
    String? text,
    String? audioPath,
    List<String>? actionChips,
    List<MealIdea>? mealIdeas,
  }) {
    return ChatMessage(
      id: id,
      timestamp: timestamp,
      role: role,
      type: type,
      text: text ?? this.text,
      foodEntry: foodEntry,
      mealIdeas: mealIdeas ?? this.mealIdeas,
      isInterjection: isInterjection,
      actionChips: actionChips ?? this.actionChips,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'role': role,
        'type': type,
        'text': text,
        'foodEntry': foodEntry?.toJson(),
        'mealIdeas': mealIdeas.map((m) => m.toJson()).toList(),
        'isInterjection': isInterjection,
        'actionChips': actionChips,
        'audioPath': audioPath,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        role: json['role'] as String,
        type: json['type'] as String? ?? 'text',
        text: json['text'] as String? ?? '',
        foodEntry: json['foodEntry'] == null
            ? null
            : FoodEntry.fromJson(
                json['foodEntry'] as Map<String, dynamic>,
              ),
        mealIdeas: (json['mealIdeas'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MealIdea.fromJson)
            .toList(),
        isInterjection: json['isInterjection'] as bool? ?? false,
        actionChips:
            List<String>.from(json['actionChips'] as List? ?? const []),
        audioPath: json['audioPath'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
}
