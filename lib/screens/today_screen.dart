import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/food_entry.dart';
import '../services/user_profile_service.dart';
import '../services/day_log_service.dart';
import '../services/caliana_service.dart';
import '../services/saved_meals_service.dart';
import '../services/usage_service.dart';
import '../services/transcribe_service.dart';
import '../models/meal_idea.dart';
import '../models/saved_meal.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/mini_macro_ring.dart';
import '../widgets/date_strip.dart';
import '../widgets/caliana_bubble.dart';
import '../widgets/caliana_character.dart';
import '../widgets/input_dock.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/recipes_sheet.dart';
import '../widgets/food_edit_sheet.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

const _kFirstWelcomeKey = 'caliana_first_welcome_played_v1';

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
  final AudioPlayer _voicePlayer = AudioPlayer();
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // First app launch after onboarding plays the recorded welcome audio.
      await _maybePlayFirstWelcome();
      // Then check if we should drop a proactive meal-slot interjection
      // (Duo-style soft ping when she hasn't heard from you).
      await _maybeInterject();
    });
  }

  Future<void> _maybePlayFirstWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kFirstWelcomeKey) ?? false) return;
      await prefs.setBool(_kFirstWelcomeKey, true);
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource('audio/welcome.mp3'));
    } catch (_) {
      // No audio file dropped in yet — silent no-op.
    }
  }

  // Determine the current meal slot from local hour, or null if outside.
  String? _mealSlot(int hour) {
    if (hour >= 6 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 15) return 'lunch';
    if (hour >= 17 && hour < 22) return 'dinner';
    return null;
  }

  /// Proactive ping: if it's currently a meal time and the user hasn't
  /// logged anything in this slot today AND we haven't already pinged
  /// for this slot, Caliana drops a soft interjection.
  ///
  /// One per slot per day, tone-aware. This is the soul-friend touch —
  /// she notices when you've gone quiet.
  Future<void> _maybeInterject() async {
    final now = DateTime.now();
    final slot = _mealSlot(now.hour);
    if (slot == null) return;

    final today = DayLogService.instance.today;
    final loggedInSlot = today.entries.any((e) {
      final h = e.timestamp.hour;
      return _mealSlot(h) == slot;
    });
    if (loggedInSlot) return;

    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final flagKey = 'caliana_interjected_${dateKey}_$slot';
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (prefs.getBool(flagKey) ?? false) return;
    await prefs.setBool(flagKey, true);
    if (!mounted) return;

    final profile = UserProfileService.instance.profile;
    final firstName = profile.name.trim().split(RegExp(r'\s+')).first;
    final addr = firstName.isEmpty ? '' : ', $firstName';

    final text = _interjectionLine(slot, profile.tone, addr);
    final chips = slot == 'dinner'
        ? const <String>['Suggest dinner', 'Snap food']
        : const <String>['Log meal', 'Snap food'];

    await DayLogService.instance.addMessage(
      now,
      ChatMessage(
        id: 'm_${now.millisecondsSinceEpoch}_int',
        timestamp: now,
        role: 'caliana',
        text: text,
        actionChips: chips,
        isInterjection: true,
      ),
    );
    unawaited(_speak(text));
    _scrollToBottom();
  }

  String _interjectionLine(String slot, String tone, String addr) {
    final pools = {
      'breakfast': {
        'polite': [
          "Morning$addr. Breakfast in the diary?",
          "Morning$addr. Don't skip the first one.",
        ],
        'cheeky': [
          "Morning$addr. Tell me you've eaten.",
          "Morning$addr. Coffee doesn't count.",
          "Morning$addr. Eggs? Toast? Anything?",
        ],
        'savage': [
          "Morning$addr. The fasting era continues, then?",
          "Morning$addr. Eight AM, no breakfast. Bold.",
        ],
      },
      'lunch': {
        'polite': [
          "Lunchtime$addr. Anything in mind?",
          "Lunchtime$addr. Quick log when you can.",
        ],
        'cheeky': [
          "Oi$addr. Lunch?",
          "Lunchtime$addr. What's gone in?",
          "Lunchtime$addr. Don't make me guess.",
        ],
        'savage': [
          "Lunchtime$addr. Or are we doing this dance again.",
          "Lunchtime$addr. The silence is loud.",
        ],
      },
      'dinner': {
        'polite': [
          "Evening$addr. Dinner sorted?",
          "Evening$addr. Want a few options?",
        ],
        'cheeky': [
          "Evening$addr. Dinner plans, or shall I pick?",
          "Evening$addr. Fancy a suggestion?",
        ],
        'savage': [
          "Evening$addr. Eight PM. The dinner question grows urgent.",
          "Evening$addr. Cereal again, or shall we be adults?",
        ],
      },
    };
    final t = (tone == 'polite' || tone == 'savage') ? tone : 'cheeky';
    final list = pools[slot]![t]!;
    return list[DateTime.now().millisecondsSinceEpoch % list.length];
  }

  @override
  void dispose() {
    DayLogService.instance.removeListener(_onDataChange);
    UserProfileService.instance.removeListener(_onDataChange);
    UsageService.instance.removeListener(_onDataChange);
    _textController.dispose();
    _textFocus.dispose();
    _scrollController.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  bool _voiceErrorShown = false;

  // Fire-and-forget: synthesize Caliana's reply via ElevenLabs and play it.
  // Silently no-ops if the backend's voice route or API key isn't ready —
  // but the FIRST failure each session surfaces a SnackBar so the user
  // knows voice is silent and can tap into Settings -> Test voice for a
  // full diagnostic instead of wondering why nothing's happening.
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final path = await CalianaService.instance.synthesizeVoice(text);
      if (!mounted) return;
      if (path == null) {
        _maybeShowVoiceErrorSnackbar();
        return;
      }
      await _voicePlayer.stop();
      await _voicePlayer.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('Caliana speak error: $e');
      _maybeShowVoiceErrorSnackbar();
    }
  }

  // Surface a snackbar when a food-log call fails. Stops the silent
  // "350 kcal Caesar salad" fake estimate from before — now the user
  // sees clearly that the photo / text didn't go through.
  void _showFoodLogError() {
    if (!mounted) return;
    final err = CalianaService.instance.lastFoodLogError;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 4),
        content: Text(
          err ?? 'Caliana couldn\'t analyse that — try again.',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _maybeShowVoiceErrorSnackbar() {
    if (_voiceErrorShown || !mounted) return;
    _voiceErrorShown = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 4),
        content: const Text(
          "Voice off — text reply still works.",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _onDataChange() {
    if (mounted) setState(() {});
  }

  void _seedWelcomeIfEmpty() {
    final today = DayLogService.instance.today;
    if (today.messages.isNotEmpty) return;
    final hour = DateTime.now().hour;
    final profile = UserProfileService.instance.profile;
    final name = profile.name.trim();
    final hi = name.isEmpty ? 'love' : name;

    // Narrator-style time-of-day opener. Distinct from chat replies (which
    // are short reactions) so the two never collide visually.
    final line = hour < 5
        ? "Up at this hour, $hi? Brave. Tell me what we're working with."
        : hour < 12
            ? "Morning, $hi. Right then — show me the opening act."
            : hour < 17
                ? "Afternoon, $hi. Reader, what's gone in so far?"
                : hour < 21
                    ? "Evening, $hi. Let's tally up before dinner gets ambitious."
                    : "Late one, $hi. Quick log and I'll keep tomorrow gentle.";

    final msg = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      role: 'caliana',
      text: line,
      isInterjection: true,
      actionChips: const ['Snap food', 'Snap fridge', 'Fix my day'],
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
    final streak = DayLogService.instance.loggingStreak;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (streak >= 2) _streakChip(streak),
          if (streak >= 2) const SizedBox(height: 6),
          Row(
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
        ],
      ),
    );
  }

  // Visible memory: a small flame chip showing how many days in a row
  // the user has logged. Makes Caliana's "I remember you" pattern
  // recognition tangible — the user sees the number they're protecting.
  Widget _streakChip(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? '' : 's'} in a row',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: -0.1,
            ),
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
  // Chat area — Caliana hero portrait centered behind the conversation.
  // Chat bubbles scroll above her transparent silhouette; she's NOT a button.
  // ---------------------------------------------------------------------------
  Widget _buildChatArea(dayLog) {
    return Stack(
      children: [
        // Caliana — anchored bottom-left, smaller. She used to dominate
        // the centre at 240pt; now she's a 140pt presence to the side
        // so the chat thread can breathe and the user reads messages,
        // not the back of her head.
        Positioned(
          left: 8,
          bottom: 0,
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                stops: [0.0, 0.22],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: const CalianaCharacter(size: 140, floating: true),
            ),
          ),
        ),
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
        _onFixMyDay();
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
  /// recipe cards, and saves each to the Recipes Sheet so the user can find
  /// them later. Falls back to a chat reply if the agent returns nothing.
  Future<void> _suggestRecipes({
    required String ask,
    required String intro,
  }) async {
    if (_isThinking) return;
    setState(() => _isThinking = true);
    final ideas = await CalianaService.instance.suggestMeals(ask);
    if (!mounted) return;

    if (ideas.isEmpty) {
      setState(() => _isThinking = false);
      await _talkTo("Suggest $ask.");
      return;
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

    for (final idea in ideas) {
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
    }

    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
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

  Future<void> _onFixTheWeek() async {
    HapticFeedback.mediumImpact();
    final profile = UserProfileService.instance.profile;
    await _suggestRecipes(
      ask:
          'three light, high-protein meals to rebuild from being over budget today, around 400 kcal each',
      intro: "Three to rebuild from. Pick what works.",
    );
    // ignore: unused_local_variable
    final _ = profile;
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
    unawaited(_speak(reply.text));
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

    // Natural-language meal asks route to the Serper recipe pipeline,
    // not chat. Otherwise the user types "what should I eat" and gets a
    // dry persona quip with no actual meals.
    if (_looksLikeMealAsk(text)) {
      await _suggestFromAsk(text);
      return;
    }

    setState(() => _isThinking = true);

    if (_looksLikeFoodLog(text)) {
      // If "log it" with no food name in this message, find the food
      // in the previous user message instead. Stops the "log it →
      // 'log it then' → user has to repeat" loop.
      final parseInput = _resolveLogTarget(text);
      final entry = await CalianaService.instance
          .parseFoodFromText(parseInput, inputMethod: 'text');
      if (entry != null) {
        await DayLogService.instance.addEntry(entry);
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
      } else {
        _showFoodLogError();
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
    unawaited(_speak(reply.text));
    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  // Detect "what should I eat" / "give me dinner" / "suggest a meal" / etc.
  // so we hit the Serper recipe pipeline instead of the chat endpoint.
  bool _looksLikeMealAsk(String text) {
    final t = text.toLowerCase();
    if (t.length > 200) return false;
    const askPatterns = [
      'suggest', 'recommend', 'give me', 'what should i eat',
      'what can i eat', 'what should i have', 'what to eat',
      'dinner ideas', 'lunch ideas', 'breakfast ideas', 'meal ideas',
      'recipe', 'recipes',
    ];
    return askPatterns.any(t.contains);
  }

  // Pick the right kcal target from the user's day, then fire _suggestRecipes.
  Future<void> _suggestFromAsk(String userText) async {
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;
    final remaining =
        (profile.dailyCalorieGoal - today.totalCalories).clamp(150, 4000);

    final lower = userText.toLowerCase();
    final mealHint = lower.contains('breakfast')
        ? 'breakfast'
        : lower.contains('lunch')
            ? 'lunch'
            : lower.contains('snack')
                ? 'snack'
                : 'dinner';

    final intro = mealHint == 'snack'
        ? "$remaining left. Snack ideas — pick one."
        : "$remaining left. ${mealHint[0].toUpperCase()}${mealHint.substring(1)} options — pick one.";

    await _suggestRecipes(
      ask:
          '$mealHint ideas around $remaining kcal that fit my macros and dietary preferences',
      intro: intro,
    );
  }

  // True only when the message clearly LOGS food. We require a logging
  // verb anchored near the start AND a food noun, OR an explicit quantity
  // ("400 kcal", "3 burgers"). This stops rants like "I had a terrible
  // day, three burgers and a meltdown" from being parsed as a meal.
  bool _looksLikeFoodLog(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return false;
    if (t.length > 200) return false; // Long rants aren't food logs.

    // 1. Explicit log commands always win — "log it", "track that", etc.
    //    The user is begging us to log; never make them ask twice.
    const logCommands = [
      'log it', 'log this', 'log that', 'log them',
      'log my', 'log the', 'log a ', 'log an ',
      'track it', 'track this', 'track that',
      'add it', 'add that', 'add this',
      'yes log', 'just log', 'please log',
    ];
    if (logCommands.any(t.contains)) return true;

    // 2. Logging verbs anywhere in the message — covers the long tail
    //    of dishes ("roast dinner", "biryani", "fry-up", "kebab")
    //    without us maintaining a dish dictionary the user can't see.
    const verbs = [
      'i ate ', 'i had ', 'i drank ', 'i snacked',
      'just ate', 'just had', 'just drank', 'just snacked',
      'ate ', 'had ', 'drank ', 'snacked',
      'eating ', 'having ', 'drinking ',
      'for breakfast', 'for lunch', 'for dinner', 'for tea',
      'for brunch', 'for pudding', 'as a snack',
    ];
    if (verbs.any(t.contains)) return true;

    // 3. Explicit quantity ("400 kcal", "200g rice", "500ml beer").
    if (RegExp(r'\b\d+\s?(kcal|cal|calories|g|ml|oz|lbs?)\b').hasMatch(t)) {
      return true;
    }

    // 4. Bare meal-name fall-through for phrases that name a dish
    //    without a verb ("roast dinner", "six cheesecakes", "kebab").
    //    Tight length cap so a long rant about cheesecakes doesn't fire.
    const foodWords = [
      // Mains
      'roast dinner', 'sunday roast', 'fry up', 'fry-up', 'full english',
      'kebab', 'biryani', 'curry', 'stew', 'casserole',
      'stir fry', 'stir-fry', 'lasagna', 'lasagne', 'shepherds pie',
      'cottage pie', 'fish and chips', 'pad thai', 'tikka', 'masala',
      'salad', 'pizza', 'burger', 'sandwich', 'wrap', 'bowl',
      'pasta', 'noodles', 'ramen', 'sushi', 'taco', 'burrito',
      'rice', 'risotto', 'paella', 'omelette', 'omelet', 'frittata',
      'soup', 'broth', 'chowder', 'porridge', 'oats', 'oatmeal',
      'toast', 'bagel', 'pancake', 'waffle', 'crepe',
      'chicken', 'steak', 'salmon', 'tuna', 'fish',
      // Snacks / desserts
      'cheesecake', 'cake', 'doughnut', 'donut', 'croissant',
      'cookie', 'biscuit', 'brownie', 'muffin', 'scone',
      'chocolate', 'crisps', 'chips', 'fries', 'nuts',
      'apple', 'banana', 'orange', 'berries', 'grapes', 'fruit',
      // Drinks
      'coffee', 'latte', 'cappuccino', 'espresso', 'flat white',
      'tea', 'smoothie', 'juice', 'beer', 'wine', 'lager',
      'pint', 'gin', 'vodka', 'whisky', 'cocktail',
    ];
    if (t.length < 80 && foodWords.any(t.contains)) return true;

    // 5. Number + noun: "6 cheesecakes", "two burgers", "3 coffees".
    //    Catches the common shorthand that has no verb but is clearly
    //    a log ("six cheesecakes", "2 pints").
    final hasCount = RegExp(
      r'\b(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|few|several)\s+\w',
    ).hasMatch(t);
    if (hasCount && t.length < 80 && foodWords.any(t.contains)) return true;

    return false;
  }

  // When the user fires "log it" / "log that" with no food name in
  // the same message, walk back through today's chat for the most
  // recent user message that named a food and use THAT for parsing.
  String _resolveLogTarget(String currentText) {
    final t = currentText.toLowerCase().trim();
    final stripped = t
        .replaceAll(RegExp(r'\b(yes|please|just|now)\b'), '')
        .replaceAll(
            RegExp(r'\blog\s+(it|this|that|them|my|the|a|an)\b'), '')
        .replaceAll(RegExp(r'\btrack\s+(it|this|that)\b'), '')
        .trim();
    if (stripped.length >= 8) return currentText;

    final messages = DayLogService.instance.today.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isUser) continue;
      if (m.text.toLowerCase().trim() == t) continue;
      final mLower = m.text.toLowerCase();
      final isJustCommand = mLower.length < 22 &&
          (mLower.contains('log ') || mLower.contains('track '));
      if (isJustCommand) continue;
      return m.text;
    }
    return currentText;
  }

  /// Bottom sheet that lets the user pick whether to shoot a fresh photo
  /// or pick one from the library. Returns null if dismissed.
  Future<ImageSource?> _pickPhotoSource({
    required String title,
    required String cameraLabel,
    required String gallerySubtitle,
  }) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
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
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                _photoSourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: cameraLabel,
                  subtitle: 'Open the camera now',
                  onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                _photoSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from library',
                  subtitle: gallerySubtitle,
                  onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCameraTap() async {
    if (!UsageService.instance.canSnapPhoto) {
      _openPaywall(trigger: 'photo_limit');
      return;
    }
    final source = await _pickPhotoSource(
      title: 'Log this meal',
      cameraLabel: 'Take a photo',
      gallerySubtitle: 'Pick an existing meal photo',
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
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
    final source = await _pickPhotoSource(
      title: 'Show me your fridge',
      cameraLabel: 'Take a photo',
      gallerySubtitle: 'Pick a fridge photo from your library',
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
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
      unawaited(_speak(reply.text));
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
    // ALWAYS show the food card with the photo. If GPT couldn't read it
    // (network, timeout, dud response), we still drop a card with the
    // photo + 0 kcal + low confidence so the user sees something they
    // can tap-to-edit, not a silent disappearance.
    final FoodEntry rendered = entry ??
        FoodEntry(
          id: 'fe_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          name: 'Snapped meal',
          calories: 0,
          proteinGrams: 0,
          carbsGrams: 0,
          fatGrams: 0,
          inputMethod: 'photo',
          photoPath: path,
          confidence: 'low',
          notes: "Couldn't read the photo. Tap to fill in.",
        );
    await DayLogService.instance.addEntry(rendered);
    await DayLogService.instance.addMessage(
      DateTime.now(),
      ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}_log',
        timestamp: DateTime.now(),
        role: 'caliana',
        type: 'foodLog',
        text: rendered.name,
        foodEntry: rendered,
      ),
    );
    if (entry == null) _showFoodLogError();
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
    unawaited(_speak(reply.text));
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
        final parseInput = _resolveLogTarget(text);
        final entry = await CalianaService.instance
            .parseFoodFromText(parseInput, inputMethod: 'voice');
        if (entry != null) {
          await DayLogService.instance.addEntry(entry);
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
        } else {
          _showFoodLogError();
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
      unawaited(_speak(reply.text));
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
    // Route well-known chip labels to real actions so taps deliver actual
    // meal suggestions / fixes — never just a follow-up chat reply.
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
      case 'fix my day':
      case 'fix the day':
        _onFixMyDay();
        return;
      case 'suggest dinner':
      case 'dinner ideas':
        _onSuggestDinner();
        return;
      case 'fix the week':
      case 'rebuild week':
      case 'rebuild the week':
        _onFixTheWeek();
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

  void _onMessageTap(ChatMessage msg) {
    if (msg.foodEntry != null) {
      _openFoodEditSheet(msg.foodEntry!);
    }
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
            await DayLogService.instance.updateEntry(entry.timestamp, updated);
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
