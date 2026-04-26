import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../models/meal_idea.dart';
import '../theme/app_theme.dart';
import 'caliana_avatar.dart';

/// Chat bubble for the white chat area.
/// Caliana: 28pt face circle + light blue tinted card with dark text. The
/// circle ring-pulses once when the bubble first appears (speaker presence).
/// User: dark navy bubble, white text, right-aligned.
class CalianaBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String>? onChipTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlayVoice;
  final ValueChanged<MealIdea>? onCommitMeal;
  final ValueChanged<MealIdea>? onSaveMeal;

  const CalianaBubble({
    super.key,
    required this.message,
    this.onChipTap,
    this.onLongPress,
    this.onTap,
    this.onPlayVoice,
    this.onCommitMeal,
    this.onSaveMeal,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == 'foodLog' && message.foodEntry != null) {
      return _foodLogCard();
    }
    if (message.type == 'mealSuggest' && message.mealIdeas.isNotEmpty) {
      return _mealSuggestStack();
    }
    return message.isUser ? _userBubble(context) : _calianaBubble();
  }

  Widget _mealSuggestStack() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpeakingAvatar(key: ValueKey('avatar_${message.id}')),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ...message.mealIdeas
                    .map((idea) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RecipeCard(
                            idea: idea,
                            onCommit: onCommitMeal == null
                                ? null
                                : () => onCommitMeal!(idea),
                            onSave: onSaveMeal == null
                                ? null
                                : () => onSaveMeal!(idea),
                          ),
                        ))
                    ,
              ],
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  /// Caliana's reply renders as plain black text on the chat surface
  /// (no card, no border) — ChatGPT/Claude style — so her voice reads
  /// like the agent talking to you, not yet another labelled bubble.
  /// Action chips sit just under the text; user messages stay as dark
  /// cards so the side-of-conversation is still obvious.
  Widget _calianaBubble() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpeakingAvatar(key: ValueKey('avatar_${message.id}')),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onLongPress?.call();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (message.actionChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.actionChips
                          .map((label) => _ActionChip(
                                label: label,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onChipTap?.call(label);
                                },
                              ))
                          .toList(),
                    ),
                  ],
                  if (message.audioPath != null) ...[
                    const SizedBox(height: 6),
                    _voiceButton(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _userBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Spacer(flex: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              // Cap user bubble at ~78% of screen so long rambles don't
              // span full width and read as centred. The Spacer pushes
              // anything shorter against the right edge.
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Clean food log card. Photo as hero (160pt) when present, then a
  /// tight info strip: name + big kcal on one line, three colour-dot
  /// macros on the next, "Tap to edit" at the bottom. No tile boxes.
  Widget _foodLogCard() {
    final entry = message.foodEntry!;
    final hasPhoto =
        entry.photoPath != null && entry.photoPath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.accent,
            size: 22,
          ),
        ),
        onDismissed: (_) {
          HapticFeedback.heavyImpact();
          onLongPress?.call();
        },
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap?.call();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasPhoto) _photoHero(entry.photoPath!),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            18, hasPhoto ? 14 : 18, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name + big calorie pair on one line.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _kcalBlock(entry.calories),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Single inline macro row with coloured dots
                            // — clean, premium, no tile boxes.
                            Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              children: [
                                _macroDot(
                                    'P', entry.proteinGrams,
                                    AppColors.macroProtein),
                                _macroDot(
                                    'C', entry.carbsGrams,
                                    AppColors.macroCarbs),
                                _macroDot(
                                    'F', entry.fatGrams,
                                    AppColors.macroFat),
                              ],
                            ),
                            // Footer strip: method tag + tap hint /
                            // confidence on the right.
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _methodTag(entry.inputMethod),
                                const Spacer(),
                                if (_confidenceLabel(entry.confidence) != null)
                                  _confidenceChip(entry.confidence)
                                else
                                  _editHint(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kcalBlock(int kcal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$kcal',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -1,
            height: 1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'kcal',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primary.withValues(alpha: 0.55),
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _macroDot(String label, int grams, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$grams',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: 'g $label',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editHint() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_rounded,
          size: 11,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 4),
        Text(
          'Tap to edit',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// Hero photo at the top of the food card when the entry was logged
  /// from a snap or library image. Keeps the receipt feeling: "this is
  /// what I ate, here are the numbers". Falls back to a placeholder if
  /// the local file is gone.
  Widget _photoHero(String path) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.primary.withValues(alpha: 0.06),
          child: const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 32,
              color: AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodTag(String method) {
    final (icon, label) = switch (method) {
      'photo' => (Icons.camera_alt_rounded, 'Photo'),
      'voice' => (Icons.mic_rounded, 'Voice'),
      'fridge' => (Icons.kitchen_rounded, 'Fridge'),
      'barcode' => (Icons.qr_code_rounded, 'Barcode'),
      _ => (Icons.edit_note_rounded, 'Text'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }


  String? _confidenceLabel(String c) {
    switch (c) {
      case 'low':
        return 'Rough est. — tap to fix';
      case 'high':
        return null; // No badge when we're confident; less visual noise.
      default:
        return null;
    }
  }

  Widget _confidenceChip(String confidence) {
    final label = _confidenceLabel(confidence);
    if (label == null) return const SizedBox.shrink();
    final color = AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceButton() {
    return GestureDetector(
      onTap: onPlayVoice,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Hear it',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 28pt face circle with a one-shot ring pulse on first appearance.
/// Reads as "Caliana just spoke" without the notification-badge feel of a
/// size pulse — it's the ring that grows + fades, not the avatar itself.
class _SpeakingAvatar extends StatefulWidget {
  const _SpeakingAvatar({super.key});

  @override
  State<_SpeakingAvatar> createState() => _SpeakingAvatarState();
}

class _SpeakingAvatarState extends State<_SpeakingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_ctrl.value);
              final spread = 1.0 + t * 8.0;
              final alpha = (0.55 * (1.0 - t)).clamp(0.0, 1.0);
              return Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: alpha),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: alpha * 0.6),
                      blurRadius: 8,
                      spreadRadius: spread,
                    ),
                  ],
                ),
              );
            },
          ),
          const CalianaAvatar(size: 28),
        ],
      ),
    );
  }
}

/// Recipe card shown inline in chat. When Caliana scrapes a real recipe
/// (image + rating + cook time from JSON-LD), the card leads with a
/// 180pt hero photo and a kcal pill in the corner — same shape Gobly
/// shipped. When she's only got a GPT-generated idea, it falls back to
/// a slimmer text card.
class _RecipeCard extends StatefulWidget {
  final MealIdea idea;
  final VoidCallback? onCommit;
  final VoidCallback? onSave;
  const _RecipeCard({required this.idea, this.onCommit, this.onSave});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  String _ratingText(MealIdea idea) {
    if (idea.ratingValue == null) return '';
    final v = idea.ratingValue!.toStringAsFixed(1);
    if (idea.ratingCount != null && idea.ratingCount! > 0) {
      final c = _shortCount(idea.ratingCount!);
      return '$v ($c)';
    }
    return v;
  }

  String _shortCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idea.hasRichRecipe) _heroImage(idea),
            Padding(
              padding: idea.hasRichRecipe
                  ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                  : const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleRow(idea),
                  const SizedBox(height: 4),
                  _metaRow(idea),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    if (idea.ingredients.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _sectionHeader('Ingredients · 1 portion'),
                          const Spacer(),
                          if (idea.originalServings != null &&
                              idea.originalServings! > 1)
                            Text(
                              'scaled from ${idea.originalServings}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHint,
                                letterSpacing: 0.2,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...idea.ingredients.map(_bulletLine),
                      const SizedBox(height: 10),
                    ],
                    if (idea.steps.isNotEmpty) ...[
                      _sectionHeader('Steps'),
                      const SizedBox(height: 4),
                      ...List.generate(idea.steps.length, (i) =>
                          _numberedLine(i + 1, idea.steps[i])),
                      const SizedBox(height: 10),
                    ],
                    if (idea.link != null && idea.link!.isNotEmpty)
                      _openRecipeButton(idea),
                  ],
                  // Always-visible commit button so the user can fire
                  // "I ate this" without expanding the card.
                  if (widget.onCommit != null) ...[
                    const SizedBox(height: 10),
                    _commitButton(),
                  ],
                  // Save button — explicit opt-in to keep this recipe
                  // in the Recipes Sheet. We stopped auto-saving every
                  // suggestion because it filled the collection with
                  // ones the user didn't actually care about.
                  if (widget.onSave != null) ...[
                    const SizedBox(height: 8),
                    _saveButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroImage(MealIdea idea) {
    return Stack(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.network(
            idea.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFF1F3F8),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Top-bottom gradient so the kcal pill always reads on busy
        // food photography.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (idea.calories > 0)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${idea.calories}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: AppColors.primary,
          size: 36,
        ),
      ),
    );
  }

  Widget _titleRow(MealIdea idea) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            idea.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          _expanded
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          color: AppColors.textHint,
          size: 22,
        ),
      ],
    );
  }

  Widget _metaRow(MealIdea idea) {
    final parts = <Widget>[];
    final ratingText = _ratingText(idea);

    if (ratingText.isNotEmpty) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              size: 14, color: Color(0xFFFFB400)),
          const SizedBox(width: 2),
          Text(
            ratingText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ));
    }
    if (idea.totalTimeMin != null && idea.totalTimeMin! > 0) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            _formatTime(idea.totalTimeMin!),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ));
    }
    if (idea.calories > 0 && !idea.hasRichRecipe) {
      // Slim card path: surface kcal in the meta row instead of the pill.
      parts.add(Text(
        '${idea.calories} kcal',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ));
    }
    if (idea.source != null && idea.source!.isNotEmpty) {
      parts.add(Flexible(
        child: Text(
          idea.source!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
        ),
      ));
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    final spaced = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spaced.add(_dot());
      }
      spaced.add(parts[i]);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.textHint,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  String _formatTime(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final rem = min % 60;
    if (rem == 0) return '${h}h';
    return '${h}h ${rem}m';
  }

  Widget _sectionHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _bulletLine(String line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 9),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberedLine(int n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$n.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commitButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onCommit?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'I ate this',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSave?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.bookmark_border_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              'Save',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openRecipeButton(MealIdea idea) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final uri = Uri.tryParse(idea.link!);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                idea.source != null
                    ? 'Open on ${idea.source}'
                    : 'Open full recipe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
