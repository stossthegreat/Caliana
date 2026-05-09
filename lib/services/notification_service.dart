import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'user_profile_service.dart';

/// Daily retention pings — Caliana hits the user with a cheeky British
/// line at the times they picked during onboarding (lunch / dinner /
/// late-night). One push per slot, max three a day. Lines rotate so
/// the same nudge never appears twice in a row.
///
/// Uses flutter_local_notifications, scheduled locally on-device — no
/// server, no Firebase Cloud Messaging required. Each scheduled
/// notification is a `matchDateTimeComponents: DateTimeComponents.time`
/// so it auto-repeats every day at the same wall-clock time.
///
/// Permissions:
///   • iOS: requests Alert + Sound + Badge on first init. Granted /
///     denied is captured by the OS prompt — we don't gate on the
///     answer (denial just means schedule() is a no-op).
///   • Android: notification permission is requested via
///     requestNotificationsPermission() (Android 13+).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'caliana_daily';
  static const _channelName = 'Caliana check-ins';
  static const _channelDesc =
      'A cheeky one-liner from Caliana once or twice a day.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// One-shot init. Call from main.dart after services load. No-ops if
  /// the platform doesn't support local notifications (e.g. web).
  Future<void> init() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();

      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android, iOS: ios);

      await _plugin.initialize(settings);

      // Android 13+ runtime permission.
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      _ready = true;
    } catch (e) {
      debugPrint('🔔 notification init failed: $e');
    }
  }

  /// Cancel + reschedule the daily pings based on the user's profile.
  /// Called whenever the user updates their notification preferences in
  /// onboarding or settings, and once on app boot to keep the schedule
  /// current after the user changes them out-of-band.
  Future<void> rescheduleDaily() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final profile = UserProfileService.instance.profile;
      final hours = profile.notificationHours;
      if (hours.isEmpty) return;

      final tone = profile.tone;
      final firstName = profile.name.trim().split(RegExp(r'\s+')).first;
      final addr = firstName.isEmpty ? '' : ', $firstName';

      // Each notification slot gets its own stable id (= the hour).
      // Auto-repeats daily via matchDateTimeComponents.time.
      for (final hour in hours) {
        final body = _pickLine(slot: _slotForHour(hour), tone: tone, addr: addr);
        await _plugin.zonedSchedule(
          hour, // notification id = hour-of-day
          'Caliana',
          body,
          _nextInstanceOfHour(hour),
          NotificationDetails(
            android: const AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('🔔 reschedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {/* no-op */}
  }

  // ---- helpers --------------------------------------------------------

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  String _slotForHour(int hour) {
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 21) return 'dinner';
    return 'late';
  }

  /// Random rotation. Caller passes slot + tone + addr; we pick from
  /// the matching pool. Pools are intentionally short (3-5 each) so
  /// we can hand-tune voice without lookups feeling templated.
  String _pickLine({
    required String slot,
    required String tone,
    required String addr,
  }) {
    final pool = _pools[slot]?[tone] ?? _pools[slot]?['cheeky'] ?? const [];
    if (pool.isEmpty) {
      return 'Caliana here. Today\'s the day, $addr.';
    }
    final i = Random().nextInt(pool.length);
    return pool[i].replaceAll('{addr}', addr);
  }

  // British, in-character, three tones × four slots. Anti-repetition
  // is just length × randomness — not the same line twice in a row in
  // practice once you have 4+ per pool.
  static const _pools = <String, Map<String, List<String>>>{
    'breakfast': {
      'polite': [
        'Morning{addr}. Breakfast in the diary?',
        'Morning{addr}. Don\'t skip the first one — it sets the day.',
        'Morning{addr}. A small protein, even just an egg.',
      ],
      'cheeky': [
        'Morning{addr}. Coffee doesn\'t count, you know.',
        'Morning{addr}. Tell me you\'ve eaten, properly this time.',
        'Morning{addr}. Eggs? Toast? Anything? I\'m not picky.',
      ],
      'savage': [
        'Morning{addr}. Coffee is a vibe, not a meal. Sort it.',
        'Morning{addr}. The committee is convening. Eat something.',
        'Morning{addr}. We are not skipping breakfast again, are we.',
      ],
    },
    'lunch': {
      'polite': [
        'Lunch{addr}. Whatever\'s in reach is fine, just log it.',
        'Lunch{addr}. Tap the camera if you can\'t describe it.',
        'Lunch{addr}. Half-decent plate, half-decent afternoon.',
      ],
      'cheeky': [
        'Lunch{addr}. Snap it, log it, get on with the day.',
        'Lunch{addr}. Tell me it\'s not just a flapjack.',
        'Lunch{addr}. The maths waits for no one.',
      ],
      'savage': [
        'Lunch{addr}. A meal-deal sandwich is not a meal. Log it anyway.',
        'Lunch{addr}. The audacity to skip this. Eat something real.',
        'Lunch{addr}. I\'m watching. The numbers are watching.',
      ],
    },
    'dinner': {
      'polite': [
        'Evening{addr}. Want me to suggest a dinner that fits?',
        'Evening{addr}. Tap "Fix my day" — I\'ll size it for you.',
        'Evening{addr}. One snap and we\'ll close the day.',
      ],
      'cheeky': [
        'Evening{addr}. What are we eating? I want details.',
        'Evening{addr}. Tap Fix my day. Two seconds, sorted.',
        'Evening{addr}. Don\'t freestyle dinner, let me help.',
      ],
      'savage': [
        'Evening{addr}. If it\'s another beige plate, I will know.',
        'Evening{addr}. We are NOT doing pasta + garlic bread again.',
        'Evening{addr}. Dinner, log it, no creative accounting.',
      ],
    },
    'late': {
      'polite': [
        'Quick check{addr} — anything since dinner?',
        'Bed soon{addr}? Log a snack if you had one.',
      ],
      'cheeky': [
        'Late-night raid{addr}? Tell me before tomorrow does.',
        'Cheeky biscuit{addr}? Honesty is a love language.',
      ],
      'savage': [
        'Late-night raid{addr}? Cereal at midnight is a hate crime.',
        'It\'s 11pm{addr}. Crisps are not a meal. We log them anyway.',
      ],
    },
  };
}
