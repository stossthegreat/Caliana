import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/food_entry.dart';
import '../services/user_profile_service.dart';
import '../services/day_log_service.dart';
import '../services/caliana_service.dart';
import '../services/saved_meals_service.dart';
import '../services/review_prompt_service.dart';
import '../services/usage_service.dart';
import '../services/transcribe_service.dart';
import '../widgets/review_prompt_sheet.dart';
import '../models/meal_idea.dart';
import '../models/saved_meal.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/mini_macro_ring.dart';
import '../widgets/date_strip.dart';
import '../widgets/caliana_bubble.dart';
import '../widgets/food_edit_sheet.dart';
import '../widgets/input_dock.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/recipes_sheet.dart';
import 'paywall_screen.dart';
import 'main_tabs.dart';
import 'settings_screen.dart';

/// Caliana home — BLUE strip ONLY at top (top bar + date strip).
/// Below: white content with calorie ring + 3 macro circles, then chat
/// with Caliana fixed at the LEFT EDGE of the screen, then presets
/// then BLUE input dock.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime _selectedDate = DateTime.now();
  bool _isThinking = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    DayLogService.instance.addListener(_onDataChange);
    UserProfileService.instance.addListener(_onDataChange);
    UsageService.instance.addListener(_onDataChange);
    _seedWelcomeIfEmpty();
  }

  @override
  void dispose() {
    DayLogService.instance.removeListener(_onDataChange);
    UserProfileService.instance.removeListener(_onDataChange);
    UsageService.instance.removeListener(_onDataChange);
    _textController.dispose();
    _textFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataChange() {
    if (mounted) setState(() {});
  }

  /// Counts a food log as a "meaningful event" and pops the 5-star prompt
  /// once we've seen enough of them. Persists shown-state so the user is
  /// only ever asked once.
  Future<void> _maybeShowReviewPrompt() async {
    final shouldPrompt =
        await ReviewPromptService.instance.recordEventAndShouldPrompt();
    if (!shouldPrompt || !mounted) return;
    // Defer to the next frame so the chat finishes settling before the
    // sheet covers it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ReviewPromptSheet.show(context);
    });
  }

  void _seedWelcomeIfEmpty() {
    final today = DayLogService.instance.today;
    if (today.messages.isNotEmpty) return;
    final hour = DateTime.now().hour;
    final profile = UserProfileService.instance.profile;
    final name = profile.name.trim();
    final hi = name.isEmpty ? 'love' : name;

    // Sassy-warm British. Time-of-day framed. Lands on a clear ask so the
    // user has a next move, not a dead-end greeting.
    final line = hour < 5
        ? "Up at this hour, $hi? Bold. Tell me what we're working with today."
        : hour < 12
            ? "Morning, $hi. Right — show me the first meal and we'll plan from there."
            : hour < 17
                ? "Afternoon, $hi. What's gone in so far? Don't be shy, I've seen worse."
                : hour < 21
                    ? "Evening, $hi. Let's tally up the day before dinner gets ambitious."
                    : "Late one, $hi. Quick log and I'll keep tomorrow easy.";

    // No inline chips — the QuickActionsBar at the bottom of Today
    // already exposes Fix my day / High protein / Eat clean / Had junk
    // / Quick lunch, and the input dock surfaces Snap fridge + Snap food
    // as buttons. Dropping the chips here removes the duplicate row that
    // made the home feel cluttered.
    final msg = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      role: 'caliana',
      text: line,
      isInterjection: true,
    );
    DayLogService.instance.addMessage(DateTime.now(), msg);
  }

  String _dateString(DateTime d) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final wd = weekdays[(d.weekday - 1) % 7];
    return '$wd, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final dayLog = DayLogService.instance.forDay(_selectedDate);
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    final consumed = dayLog.totalCalories;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildBlueStrip(),
          const SizedBox(height: 8),
          _buildCounterRow(consumed, goal, dayLog, profile),
          Expanded(child: _buildChatArea(dayLog)),
          QuickActionsBar(onTap: _onQuickAction),
          const SizedBox(height: 4),
          InputDock(
            controller: _textController,
            onSend: _onSendText,
            onCamera: _onCameraTap,
            onFridge: _onFridgeTap,
            onMicTap: _onMicTap,
            onMicHoldStart: _onMicHoldStart,
            onMicHoldEnd: _onMicHoldEnd,
            isRecording: _isRecording,
            sendEnabled: !_isThinking,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BLUE STRIP — ONLY top bar + date strip. Ends at date strip.
  // ---------------------------------------------------------------------------
  Widget _buildBlueStrip() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3F7AFF),
            Color(0xFF2F6BFF),
            Color(0xFF1F4FE0),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: DateStrip(
                selected: _selectedDate,
                onSelect: (d) => setState(() => _selectedDate = d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // White counter row — calorie ring + 3 mini macros (light theme)
  // ---------------------------------------------------------------------------
  Widget _buildCounterRow(int consumed, int goal, dayLog, profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CalorieRing(
            consumed: consumed,
            goal: goal,
            label: '',
            size: 108,
            onLongPress: _openSettings,
          ),
          MiniMacroRing(
            letter: 'P',
            current: dayLog.totalProtein,
            target: profile.dailyProteinGrams,
            color: AppColors.macroProtein,
            size: 50,
          ),
          MiniMacroRing(
            letter: 'C',
            current: dayLog.totalCarbs,
            target: profile.dailyCarbsGrams,
            color: AppColors.macroCarbs,
            size: 50,
          ),
          MiniMacroRing(
            letter: 'F',
            current: dayLog.totalFat,
            target: profile.dailyFatGrams,
            color: AppColors.macroFat,
            size: 50,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar (sits inside the blue strip — needs visible-on-blue styling)
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topIconButton(Icons.bar_chart_rounded, onTap: _openTrendsSheet),
          GestureDetector(
            onTap: _openTrendsSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                _dateString(_selectedDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _proIconButton(),
              const SizedBox(width: 6),
              _topIconButton(
                Icons.menu_book_rounded,
                onTap: () => RecipesSheet.show(context),
              ),
              const SizedBox(width: 6),
              _topIconButton(Icons.settings_outlined, onTap: _openSettings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEFF4FF)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 17),
      ),
    );
  }

  Widget _proIconButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (UsageService.instance.isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Caliana Pro — active.")),
          );
        } else {
          _openPaywall(trigger: 'top_bar');
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEFF4FF)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.workspace_premium_rounded,
          color: AppColors.primary,
          size: 17,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Chat area — pure conversation. The big background portrait was
  // intentionally removed; Caliana's presence is the small avatar on
  // each bubble + the FAB at the bottom of the dock. Keeping the chat
  // surface clean lets recipe cards / hero photos breathe.
  // ---------------------------------------------------------------------------
  Widget _buildChatArea(dayLog) {
    return Stack(
      children: [
        Positioned.fill(
          child: dayLog.messages.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                  itemCount: dayLog.messages.length + (_isThinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == dayLog.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: _ThreeDotPulse(),
                      );
                    }
                    final msg = dayLog.messages[i];
                    return CalianaBubble(
                      message: msg,
                      onChipTap: (label) => _onActionChip(label, msg),
                      onLongPress: () => _onMessageLongPress(msg),
                      onTap: () => _onMessageTap(msg),
                      // Two actions on every recipe in chat:
                      //   • Save → keep the recipe in the Recipes Sheet
                      //   • I ate it → log the kcal/macros to today's
                      //     ring instantly. Tap once, calories are in.
                      onCommitMeal: _commitMealFromIdea,
                      onSaveMeal: _saveMealFromIdea,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------
  void _onQuickAction(String id) {
    switch (id) {
      case 'fix_my_day':
      case 'save_tonight': // legacy id from prior label
        _onFixMyDay();
        break;
      case 'fix_tomorrow':
      case 'plan_tomorrow':
        HapticFeedback.lightImpact();
        MainTabs.goToPlan();
        break;
      case 'log_meal':
        _textFocus.requestFocus();
        break;
      case 'high_protein':
        _suggestRecipes(
          ask:
              'high protein chicken or salmon dinner with at least 35g protein',
          intro: "High-protein options — 35g+ per serving.",
        );
        break;
      case 'eat_clean':
        _suggestRecipes(
          ask: 'light clean meals for the rest of today',
          intro: "Sorted. Light and clean — pick one.",
        );
        break;
      case 'had_junk':
        _talkTo("I had junk earlier. Tell me how you'll balance the day.");
        break;
      case 'quick_lunch':
        _suggestRecipes(
          ask: '10-minute lunch ideas that fit my macros',
          intro: "Ten-minute jobs. Fast and fair play.",
        );
        break;
    }
  }

  /// Asks the recipe agent for 2-3 ideas, drops them in chat as expandable
  /// recipe cards. NEVER falls back to a chat reply — if the recipe agent
  /// comes up empty we retry once with a simpler query, then a static
  /// recipe so the user always gets a meal card.
  Future<void> _suggestRecipes({
    required String ask,
    required String intro,
  }) async {
    if (_isThinking) return;
    setState(() => _isThinking = true);
    var ideas = await CalianaService.instance.suggestMeals(ask);
    if (!mounted) return;

    if (ideas.isEmpty) {
      ideas = await CalianaService.instance
          .suggestMeals('easy healthy dinner recipe');
      if (!mounted) return;
    }
    if (ideas.isEmpty) {
      ideas = [_fallbackMeal()];
    }

    final now = DateTime.now();
    await DayLogService.instance.addMessage(
      now,
      ChatMessage(
        id: 'm_${now.millisecondsSinceEpoch}_recipes',
        timestamp: now,
        role: 'caliana',
        type: 'mealSuggest',
        text: intro,
        mealIdeas: ideas,
        isInterjection: true,
      ),
    );

    // No auto-save. The user picks what to keep via Save on each card —
    // auto-save was filling Recipes with every passing suggestion.

    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  /// Hardcoded fallback recipe so "Fix my day" / "Suggest dinner" / etc
  /// always produce a card even when the recipe pipeline is unreachable.
  MealIdea _fallbackMeal() {
    return const MealIdea(
      name: 'Lemon-pepper chicken & greens',
      calories: 480,
      protein: 42,
      carbs: 28,
      fat: 18,
      ingredients: [
        '1 chicken breast (~180g)',
        '1 tbsp olive oil',
        '1 lemon (juice + zest)',
        '1 tsp cracked black pepper',
        '1 garlic clove, minced',
        '150g tenderstem broccoli',
        '100g baby spinach',
        'Salt to taste',
      ],
      steps: [
        'Butterfly the chicken breast and rub with olive oil, lemon zest, '
            'pepper, salt, and garlic.',
        'Sear in a hot pan 4 minutes a side until golden and cooked through.',
        'Steam the broccoli 3 minutes; wilt the spinach in the chicken pan.',
        'Plate the greens, slice the chicken on top, finish with lemon juice.',
      ],
      sourceDomain: 'caliana',
    );
  }

  Future<void> _onFixMyDay() async {
    HapticFeedback.mediumImpact();
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;
    final goal = profile.dailyCalorieGoal;
    final consumed = today.totalCalories;
    final remaining = goal - consumed;

    final String intro;
    final String ask;
    if (remaining < 0) {
      final over = -remaining;
      intro = "Over by $over. Sober dinner — pick one.";
      ask = 'lightest possible dinner under 300 kcal that still satisfies';
    } else if (remaining < 400) {
      intro = "Tight: $remaining left. Easy options.";
      ask = 'small dinner around $remaining kcal that fits my macros';
    } else {
      intro = "$remaining left. Proper dinner — pick one.";
      ask = 'satisfying dinner around $remaining kcal that fits my macros';
    }

    await _suggestRecipes(ask: ask, intro: intro);
  }

  Future<void> _onSuggestDinner() async {
    HapticFeedback.mediumImpact();
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;
    final remaining =
        (profile.dailyCalorieGoal - today.totalCalories).clamp(200, 4000);
    await _suggestRecipes(
      ask: 'dinner ideas around $remaining kcal that fit my goals',
      intro: "$remaining left for dinner. Pick one.",
    );
  }

  /// Caliana's chat replies often wrap the dish in persona language
  /// ("Salmon and greens. Sorted."). When the user taps "Get recipe"
  /// we feed the search a clean dish phrase, not the persona scaffolding.
  String _stripPersonaForSearch(String text) {
    var t = text.trim();
    final firstSentence = t.split(RegExp(r'[.!?]')).first.trim();
    if (firstSentence.length >= 3) t = firstSentence;
    t = t.replaceFirst(
      RegExp(
        r'^(right|sorted|behave|tidy|alright|okay|ok|so|well|listen|look)[\s,—-]+',
        caseSensitive: false,
      ),
      '',
    );
    if (t.contains(':')) {
      final after = t.split(':').sublist(1).join(':').trim();
      if (after.length >= 3) t = after;
    }
    return t.trim();
  }

  Future<void> _talkTo(String text, {bool hideUserMessage = false}) async {
    if (_isThinking) return;
    setState(() => _isThinking = true);
    if (!hideUserMessage) {
      await DayLogService.instance.addMessage(
        DateTime.now(),
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          role: 'user',
          text: text,
        ),
      );
    }
    final reply = await CalianaService.instance.chat(text);
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}_caliana',
        timestamp: DateTime.now(),
        role: 'caliana',
        text: reply.text,
        actionChips: reply.actionChips,
      ),
    );
    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Send / photo / voice
  // ---------------------------------------------------------------------------
  Future<void> _onSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isThinking) return;
    _textController.clear();
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        role: 'user',
        text: text,
      ),
    );
    setState(() => _isThinking = true);

    if (_looksLikeFoodLog(text)) {
      final entry = await CalianaService.instance
          .parseFoodFromText(text, inputMethod: 'text');
      if (entry != null) {
        await DayLogService.instance.addEntry(entry);
        _maybeShowReviewPrompt();
        await DayLogService.instance.addMessage(
          DateTime.now(),
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}_log',
            timestamp: DateTime.now(),
            role: 'caliana',
            type: 'foodLog',
            text: entry.name,
            foodEntry: entry,
          ),
        );
      }
    }

    final reply = await CalianaService.instance.chat(text);
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}_caliana',
        timestamp: DateTime.now(),
        role: 'caliana',
        text: reply.text,
        actionChips: reply.actionChips,
      ),
    );
    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  bool _looksLikeFoodLog(String text) {
    final t = text.toLowerCase();
    const verbs = ['ate', 'had', 'eating', 'just had', 'snacked', 'drank'];
    const nouns = [
      'salad', 'pizza', 'burger', 'rice', 'pasta', 'chicken', 'sandwich',
      'coffee', 'apple', 'banana', 'eggs', 'toast', 'soup', 'steak',
      'fries', 'chips', 'cookie', 'cake', 'biscuit', 'yogurt', 'smoothie',
      'protein', 'wrap', 'bowl', 'noodles', 'curry', 'fish', 'ramen',
    ];
    return verbs.any(t.contains) || nouns.any(t.contains);
  }

  Future<void> _onCameraTap() async {
    if (!UsageService.instance.canSnapPhoto) {
      _openPaywall(trigger: 'photo_limit');
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    await UsageService.instance.recordPhoto();
    await _processFoodPhoto(picked.path, hint: '');
  }

  Future<void> _onFridgeTap() async {
    if (!UsageService.instance.canSnapPhoto) {
      _openPaywall(trigger: 'fridge_limit');
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    await UsageService.instance.recordPhoto();

    setState(() => _isThinking = true);
    final now = DateTime.now();
    await DayLogService.instance.addMessage(
      now,
      ChatMessage(
        id: 'm_${now.millisecondsSinceEpoch}_user',
        timestamp: now,
        role: 'user',
        text: '📷 Fridge — what can I make?',
      ),
    );

    final ideas =
        await CalianaService.instance.fridgeSuggest(picked.path);

    if (!mounted) return;
    if (ideas.isEmpty) {
      // Vision returned nothing usable (fridge unclear, empty, or backend
      // hiccup). Fall back to a short Caliana reply so the chat doesn't
      // dead-end.
      final reply = await CalianaService.instance.chat(
        'I snapped my fridge but you saw nothing useful. Tell me what to do next.',
        trigger: 'fridge',
      );
      await DayLogService.instance.addMessage(
        DateTime.now(),
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}_caliana',
          timestamp: DateTime.now(),
          role: 'caliana',
          text: reply.text,
          actionChips: reply.actionChips,
        ),
      );
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
      return;
    }

    final cardNow = DateTime.now();
    await DayLogService.instance.addMessage(
      cardNow,
      ChatMessage(
        id: 'm_${cardNow.millisecondsSinceEpoch}_fridge',
        timestamp: cardNow,
        role: 'caliana',
        type: 'mealSuggest',
        text: 'Right, here\'s what your fridge can do.',
        mealIdeas: ideas,
        isInterjection: true,
      ),
    );

    for (final idea in ideas) {
      await SavedMealsService.instance.save(
        SavedMeal(
          id: 'sm_${cardNow.millisecondsSinceEpoch}_${idea.name.hashCode}',
          savedAt: cardNow,
          name: idea.name,
          calories: idea.calories,
          proteinGrams: idea.protein,
          carbsGrams: idea.carbs,
          fatGrams: idea.fat,
          ingredients: idea.ingredients,
          steps: idea.steps,
          recipeLink: idea.link,
          recipeSource: idea.source,
          note: 'Caliana\'s fridge fix',
        ),
      );
    }

    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  Future<void> _processFoodPhoto(String path, {String? hint}) async {
    setState(() => _isThinking = true);
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}_user',
        timestamp: DateTime.now(),
        role: 'user',
        text: '📷 Snapped a meal',
      ),
    );
    final entry = await CalianaService.instance
        .parseFoodFromPhoto(path, hint: hint);
    if (entry != null) {
      await DayLogService.instance.addEntry(entry);
      _maybeShowReviewPrompt();
      await DayLogService.instance.addMessage(
        DateTime.now(),
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}_log',
          timestamp: DateTime.now(),
          role: 'caliana',
          type: 'foodLog',
          text: entry.name,
          foodEntry: entry,
        ),
      );
    }
    final reply = await CalianaService.instance.chat(
      entry == null
          ? 'Snapped a meal — react.'
          : 'Just logged ${entry.name} (${entry.calories} kcal). React.',
      trigger: 'photo',
    );
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}_caliana',
        timestamp: DateTime.now(),
        role: 'caliana',
        text: reply.text,
        actionChips: reply.actionChips,
      ),
    );
    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  Future<void> _onMicTap() async {
    if (_isRecording) {
      await _stopRecordingAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _onMicHoldStart() async {
    if (!_isRecording) await _startRecording();
  }

  Future<void> _onMicHoldEnd() async {
    if (_isRecording) await _stopRecordingAndProcess();
  }

  Future<void> _startRecording() async {
    final ok = await TranscribeService.instance.startRecording();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic permission needed')),
      );
      return;
    }
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndProcess() async {
    setState(() {
      _isRecording = false;
      _isThinking = true;
    });
    try {
      final text = await TranscribeService.instance.stopAndTranscribe();
      if (text.isEmpty) {
        if (mounted) setState(() => _isThinking = false);
        return;
      }
      await DayLogService.instance.addMessage(
        DateTime.now(),
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}_user',
          timestamp: DateTime.now(),
          role: 'user',
          text: text,
        ),
      );
      if (_looksLikeFoodLog(text)) {
        final entry = await CalianaService.instance
            .parseFoodFromText(text, inputMethod: 'voice');
        if (entry != null) {
          await DayLogService.instance.addEntry(entry);
          _maybeShowReviewPrompt();
          await DayLogService.instance.addMessage(
            DateTime.now(),
            ChatMessage(
              id: 'm_${DateTime.now().millisecondsSinceEpoch}_log',
              timestamp: DateTime.now(),
              role: 'caliana',
              type: 'foodLog',
              text: entry.name,
              foodEntry: entry,
            ),
          );
        }
      }
      final reply = await CalianaService.instance.chat(text);
      await DayLogService.instance.addMessage(
        DateTime.now(),
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}_caliana',
          timestamp: DateTime.now(),
          role: 'caliana',
          text: reply.text,
          actionChips: reply.actionChips,
        ),
      );
    } catch (e) {
      debugPrint('voice error: $e');
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  // ---------------------------------------------------------------------------
  // Chat actions / long-press / nav
  // ---------------------------------------------------------------------------
  Future<void> _onActionChip(String label, ChatMessage source) async {
    // Route well-known chip labels to real actions. Future-fix chips
    // route to Plan; today-fix chips stay on Today and surface dinner
    // options. "Get recipe" turns Caliana's last suggestion text into
    // a real recipe pull.
    final l = label.toLowerCase().trim();
    switch (l) {
      case 'snap food':
      case 'snap a meal':
        _onCameraTap();
        return;
      case 'snap fridge':
      case 'snap my fridge':
        _onFridgeTap();
        return;
      // ── Future-fix chips → Plan tab ──────────────────────────
      case 'fix tomorrow':
      case 'plan tomorrow':
      case 'open plan':
      case 'fix the week':
      case 'rebuild week':
      case 'rebuild the week':
        HapticFeedback.lightImpact();
        MainTabs.goToPlan();
        return;
      // ── Today-fix chips → dinner suggestions on Today ────────
      case 'fix my day':
      case 'fix the day':
      case 'save tonight':
      case 'fix dinner':
      case 'fix my dinner':
        _onFixMyDay();
        return;
      // ── "Get recipe" — feeds Caliana's last suggestion into search ──
      case 'get recipe':
      case 'find recipe':
      case 'show me':
        HapticFeedback.lightImpact();
        final ask = _stripPersonaForSearch(source.text);
        if (ask.trim().isEmpty) {
          _onSuggestDinner();
        } else {
          _suggestRecipes(
            ask: '$ask recipe',
            intro: "Right — here's what I found.",
          );
        }
        return;
      case 'suggest dinner':
      case 'dinner ideas':
        _onSuggestDinner();
        return;
      case 'high protein':
      case 'high-protein':
        _suggestRecipes(
          ask:
              'high protein chicken or salmon dinner with at least 35g protein',
          intro: "High-protein options — 35g+ per serving.",
        );
        return;
      case 'eat clean':
      case 'clean meal':
        _suggestRecipes(
          ask: 'light clean meals for the rest of today',
          intro: "Light and clean. Pick one.",
        );
        return;
      case 'quick lunch':
      case '10-minute lunch':
        _suggestRecipes(
          ask: '10-minute lunch ideas that fit my macros',
          intro: "Ten-minute jobs. Fast.",
        );
        return;
    }
    await _talkTo(label);
  }

  void _onMessageLongPress(ChatMessage msg) {
    if (msg.foodEntry != null) {
      _confirmDeleteEntry(msg.foodEntry!);
    }
  }

  /// Tapping a food-log card in chat opens an edit sheet so the user
  /// can correct macros / delete a misread entry without long-pressing.
  void _onMessageTap(ChatMessage msg) {
    if (msg.foodEntry != null) {
      _openFoodEditSheet(msg.foodEntry!);
    }
  }

  /// Commit a chat-suggested meal as a real food entry on today.
  /// Triggered by the "I ate it" button on every recipe card. The
  /// calories land in today's ring instantly.
  Future<void> _commitMealFromIdea(MealIdea idea) async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final entry = FoodEntry(
      id: 'fe_${now.millisecondsSinceEpoch}',
      timestamp: now,
      name: idea.name,
      calories: idea.calories,
      proteinGrams: idea.protein,
      carbsGrams: idea.carbs,
      fatGrams: idea.fat,
      inputMethod: 'plan',
      photoPath: null,
      confidence: 'high',
      notes: 'From a meal suggestion',
    );
    await DayLogService.instance.addEntry(entry);
    await DayLogService.instance.addMessage(
      now,
      ChatMessage(
        id: 'm_${now.millisecondsSinceEpoch}_log',
        timestamp: now,
        role: 'caliana',
        type: 'foodLog',
        text: entry.name,
        foodEntry: entry,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF0F172A),
      duration: const Duration(seconds: 2),
      content: Text(
        'Logged: ${entry.name} (${entry.calories} kcal)',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ));
    _scrollToBottom();
  }

  /// Save a suggested meal into the user's Recipes Sheet. Triggered
  /// by the explicit Save button on each recipe card.
  Future<void> _saveMealFromIdea(MealIdea idea) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    await SavedMealsService.instance.save(
      SavedMeal(
        id: 'sm_${now.millisecondsSinceEpoch}_${idea.name.hashCode}',
        savedAt: now,
        name: idea.name,
        calories: idea.calories,
        proteinGrams: idea.protein,
        carbsGrams: idea.carbs,
        fatGrams: idea.fat,
        ingredients: idea.ingredients,
        steps: idea.steps,
        recipeLink: idea.link,
        recipeSource: idea.source,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF0F172A),
      duration: const Duration(seconds: 2),
      content: Text(
        'Saved ${idea.name} to your recipes.',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ));
  }

  void _openFoodEditSheet(FoodEntry entry) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: FoodEditSheet(
          entry: entry,
          onSave: (updated) async {
            await DayLogService.instance
                .updateEntry(entry.timestamp, updated);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          },
          onDelete: () async {
            await DayLogService.instance
                .removeEntry(entry.timestamp, entry.id);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          },
        ),
      ),
    );
  }

  void _confirmDeleteEntry(FoodEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                const SizedBox(height: 16),
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.calories} kcal · ${entry.proteinGrams}P / ${entry.carbsGrams}C / ${entry.fatGrams}F',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetButton(
                  Icons.delete_outline_rounded,
                  'Delete entry',
                  AppColors.accent,
                  () async {
                    Navigator.pop(sheetContext);
                    await DayLogService.instance
                        .removeEntry(_selectedDate, entry.id);
                    HapticFeedback.heavyImpact();
                  },
                ),
                const SizedBox(height: 8),
                _sheetButton(
                  Icons.close_rounded,
                  'Cancel',
                  AppColors.textSecondary,
                  () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPaywall({required String trigger}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(triggerText: _triggerCopy(trigger)),
        fullscreenDialog: true,
      ),
    );
  }

  String? _triggerCopy(String trigger) {
    return switch (trigger) {
      'photo_limit' => "Today's free snap is gone.",
      'fridge_limit' => "Free tier: one snap a day.",
      _ => null,
    };
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openTrendsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
                const Text(
                  'Trends',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 20),
                _trendsBars(),
                const SizedBox(height: 24),
                _trendsStat(
                  'Weekly intake',
                  '${DayLogService.instance.weeklyCalories} kcal',
                ),
                _trendsStat(
                  'Weekly target',
                  '${UserProfileService.instance.profile.weeklyCalorieGoal} kcal',
                ),
                _trendsStat(
                  'Days logged',
                  '${DayLogService.instance.loggedDates.length}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trendsBars() {
    final goal = UserProfileService.instance.profile.dailyCalorieGoal;
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - (6 - i)),
    );
    final maxKcal = days
        .map((d) => DayLogService.instance.forDay(d).totalCalories)
        .fold<int>(goal, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((d) {
          final kcal = DayLogService.instance.forDay(d).totalCalories;
          final h = maxKcal == 0 ? 0.0 : (kcal / maxKcal) * 110;
          final pct = goal == 0 ? 0.0 : kcal / goal;
          final color = pct < 0.85
              ? AppColors.success
              : pct <= 1.10
                  ? AppColors.warning
                  : AppColors.accent;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trendsStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDotPulse extends StatefulWidget {
  const _ThreeDotPulse();

  @override
  State<_ThreeDotPulse> createState() => _ThreeDotPulseState();
}

class _ThreeDotPulseState extends State<_ThreeDotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value + i * 0.2) % 1.0);
            final scale = 0.6 + (phase < 0.5 ? phase : 1 - phase) * 0.8;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
