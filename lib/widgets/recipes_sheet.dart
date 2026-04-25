import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/saved_meal.dart';
import '../services/saved_meals_service.dart';

/// Bottom-sheet view of every meal Caliana has suggested + user-starred meals.
/// Each card expands inline to show ingredients, steps, and a link to the
/// original recipe. Empty state encourages the user to ask Caliana for ideas.
class RecipesSheet extends StatelessWidget {
  const RecipesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RecipesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListenableBuilder(
          listenable: SavedMealsService.instance,
          builder: (context, _) {
            final meals = SavedMealsService.instance.all;
            return CustomScrollView(
              controller: sc,
              slivers: [
                SliverToBoxAdapter(child: _header()),
                if (meals.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  )
                else
                  SliverList.separated(
                    itemCount: meals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _RecipeRow(meal: meals[i]),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Recipes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: SavedMealsService.instance,
                builder: (_, __) {
                  final n = SavedMealsService.instance.count;
                  if (n == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Meals Caliana suggested + the ones you starred.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No meals saved yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When Caliana suggests a meal, it lands here. Ask her — '
            '"give me a 500-cal dinner" — and tap to save what you like.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

}

class _RecipeRow extends StatefulWidget {
  final SavedMeal meal;
  const _RecipeRow({required this.meal});

  @override
  State<_RecipeRow> createState() => _RecipeRowState();
}

class _RecipeRowState extends State<_RecipeRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final hasDetails =
        meal.ingredients.isNotEmpty || meal.steps.isNotEmpty || meal.recipeLink != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: hasDetails
            ? () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: GlassDecoration.card(opacity: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          meal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${meal.calories} kcal · ${meal.proteinGrams}P / ${meal.carbsGrams}C / ${meal.fatGrams}F',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDetails)
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textHint,
                      size: 22,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await SavedMealsService.instance.remove(meal.id);
                    },
                  ),
                ],
              ),
              if (_expanded && hasDetails) ...[
                const SizedBox(height: 12),
                if (meal.ingredients.isNotEmpty) ...[
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...meal.ingredients.map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6, right: 8),
                            child: SizedBox(
                              width: 4,
                              height: 4,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (meal.steps.isNotEmpty) ...[
                  const Text(
                    'Steps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(meal.steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              meal.steps[i],
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                if (meal.recipeLink != null && meal.recipeLink!.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final uri = Uri.tryParse(meal.recipeLink!);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              meal.recipeSource ?? 'Open recipe',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
