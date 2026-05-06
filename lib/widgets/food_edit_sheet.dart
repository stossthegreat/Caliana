import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_entry.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for adjusting a logged food entry. Opens when the user
/// taps a food card in chat — the most common reason is correcting an
/// AI estimate that came in low or high.
class FoodEditSheet extends StatefulWidget {
  final FoodEntry entry;
  final Future<void> Function(FoodEntry updated) onSave;
  final Future<void> Function() onDelete;

  const FoodEditSheet({
    super.key,
    required this.entry,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<FoodEditSheet> createState() => _FoodEditSheetState();
}

class _FoodEditSheetState extends State<FoodEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _kcal;
  late final TextEditingController _p;
  late final TextEditingController _c;
  late final TextEditingController _f;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry.name);
    _kcal = TextEditingController(text: '${widget.entry.calories}');
    _p = TextEditingController(text: '${widget.entry.proteinGrams}');
    _c = TextEditingController(text: '${widget.entry.carbsGrams}');
    _f = TextEditingController(text: '${widget.entry.fatGrams}');
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _p.dispose();
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c, int fallback) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < 0 ? fallback : v;
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final updated = widget.entry.copyWith(
      name: _name.text.trim().isEmpty ? widget.entry.name : _name.text.trim(),
      calories: _parseInt(_kcal, widget.entry.calories),
      proteinGrams: _parseInt(_p, widget.entry.proteinGrams),
      carbsGrams: _parseInt(_c, widget.entry.carbsGrams),
      fatGrams: _parseInt(_f, widget.entry.fatGrams),
      // User just hand-corrected this; mark it confident so the badge
      // disappears next render.
      confidence: 'high',
    );
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Text(
                'Adjust this entry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Caliana's estimate. Edit anything that looks off.",
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _label('Name'),
              const SizedBox(height: 6),
              _field(_name, hint: 'e.g. Chicken caesar salad'),
              const SizedBox(height: 14),
              _label('Calories'),
              const SizedBox(height: 6),
              _field(
                _kcal,
                hint: 'kcal',
                keyboardType: TextInputType.number,
                isLarge: true,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _macroField(
                      'Protein (g)',
                      _p,
                      AppColors.macroProtein,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroField(
                      'Carbs (g)',
                      _c,
                      AppColors.macroCarbs,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroField(
                      'Fat (g)',
                      _f,
                      AppColors.macroFat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        await widget.onDelete();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.warning.withValues(alpha: 0.10),
                        foregroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        color: AppColors.textHint,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    bool isLarge = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: TextStyle(
        fontSize: isLarge ? 20 : 15,
        fontWeight: isLarge ? FontWeight.w900 : FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: isLarge ? -0.4 : 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textHint,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _macroField(
    String label,
    TextEditingController controller,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: color.withValues(alpha: 0.08),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
