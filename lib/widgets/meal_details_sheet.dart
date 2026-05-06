import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meal_idea.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that shows the full single-portion recipe — image
/// hero, name + kcal/macros, ingredients, steps, "I ate this" commit
/// button, and an "Open recipe" link if we have a real source URL.
/// Used from both the Plan tab (tap a planned meal) and the Home
/// chat (tap a meal-suggest card title row). The optional slotLabel
/// shows the slot tag when called from Plan.
class MealDetailsSheet extends StatelessWidget {
  final MealIdea idea;
  final String? slotLabel;
  final VoidCallback? onCommit;

  const MealDetailsSheet({
    super.key,
    required this.idea,
    this.slotLabel,
    this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                if (idea.imageUrl != null && idea.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Image.network(
                        idea.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          child: const Center(
                            child: Icon(Icons.restaurant_rounded,
                                color: AppColors.primary, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (slotLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            slotLabel!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        idea.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${idea.calories}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.6,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kcal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (idea.totalTimeMin != null &&
                              idea.totalTimeMin! > 0) ...[
                            Icon(Icons.schedule_rounded,
                                size: 13,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              '${idea.totalTimeMin} min',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _macroDot(
                              'P', idea.protein, AppColors.macroProtein),
                          _macroDot('C', idea.carbs, AppColors.macroCarbs),
                          _macroDot('F', idea.fat, AppColors.macroFat),
                        ],
                      ),
                      if (idea.ingredients.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionHeader(
                          idea.originalServings != null &&
                                  idea.originalServings! > 1
                              ? 'INGREDIENTS · 1 PORTION'
                              : 'INGREDIENTS',
                          idea.originalServings != null &&
                                  idea.originalServings! > 1
                              ? 'scaled from ${idea.originalServings}'
                              : null,
                        ),
                        const SizedBox(height: 6),
                        ...idea.ingredients.map(_bulletLine),
                      ],
                      if (idea.steps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionHeader('STEPS', null),
                        const SizedBox(height: 6),
                        ...List.generate(idea.steps.length, (i) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${i + 1}.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    idea.steps[i],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (idea.link != null && idea.link!.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _openRecipe(idea),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Sticky footer with the commit button.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                        color: AppColors.surfaceBorder, width: 0.6),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: SizedBox(
                      height: 52,
                      child: GestureDetector(
                        onTap: onCommit == null
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                onCommit?.call();
                                Navigator.pop(ctx);
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: onCommit == null
                                ? null
                                : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF5A8AFF),
                                      Color(0xFF2F6BFF),
                                    ],
                                  ),
                            color: onCommit == null
                                ? Colors.grey.shade300
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: onCommit == null
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.30),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: const Center(
                            child: Text(
                              'I ate this',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Drag handle on top-centre.
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _sectionHeader(String label, String? trailing) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.4,
            ),
          ),
      ],
    );
  }

  Widget _bulletLine(String line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
                fontSize: 13.5,
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

  Widget _openRecipe(MealIdea idea) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final uri = Uri.tryParse(idea.link!);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                idea.source != null
                    ? 'Open on ${idea.source}'
                    : 'Open full recipe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
