import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Three Calianas, three cards. Each tone is a real character study,
/// not a slider — so the selector shows you who you're picking.
///
/// Used in onboarding (light theme, tappable) and in Settings (same).
class CharacterCard extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const CharacterCard({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  static const _data = {
    'polite': _CharacterData(
      title: 'Soft',
      archetype: 'Yorkshire warmth',
      blurb:
          'Warm friend, gentle teases, "lovely" without irony. The one who texts you "you got this xx".',
      quotes: [
        '"Lovely. Light tea sorts you, love."',
        '"Cracking start. Pop a salmon in for tea."',
        '"Tomorrow\'s a fresh page, darling."',
      ],
      accent: Color(0xFFE9A47C), // soft peach
      bgTint: Color(0x1AE9A47C),
      icon: Icons.spa_rounded,
    ),
    'cheeky': _CharacterData(
      title: 'Cheeky',
      archetype: 'London bestie',
      blurb:
          'Sharp London woman who clocked your third coffee and finally said something. Roasts the choice, loves you.',
      quotes: [
        '"Pret salad. £8 of optimism."',
        '"Three coffees. Fair play, you menace."',
        '"Pizza with garlic bread. Iconic."',
      ],
      accent: Color(0xFFFF5A5F), // brand coral
      bgTint: Color(0x1AFF5A5F),
      icon: Icons.local_fire_department_rounded,
    ),
    'savage': _CharacterData(
      title: 'Savage',
      archetype: 'Drag judge',
      blurb:
          'Theatrical deadpan, raised eyebrow, mock-disgust at choices — never at you. Roasts come from love.',
      quotes: [
        '"Fourth coffee. Religious experience over there."',
        '"Doughnut at three. The audacity."',
        '"Crisps as a meal. Deeply concerning."',
      ],
      accent: Color(0xFFB04CC1), // deep magenta
      bgTint: Color(0x1AB04CC1),
      icon: Icons.theater_comedy_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final d = _data[value]!;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? d.accent
                : AppColors.surfaceBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: d.accent.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: d.bgTint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(d.icon, color: d.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            d.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: d.bgTint,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              d.archetype,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: d.accent,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.blurb,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? d.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? d.accent : AppColors.surfaceBorder,
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...d.quotes.map((q) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 2,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3, right: 8),
                        decoration: BoxDecoration(
                          color: d.accent.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CharacterData {
  final String title;
  final String archetype;
  final String blurb;
  final List<String> quotes;
  final Color accent;
  final Color bgTint;
  final IconData icon;

  const _CharacterData({
    required this.title,
    required this.archetype,
    required this.blurb,
    required this.quotes,
    required this.accent,
    required this.bgTint,
    required this.icon,
  });
}
