import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's consent to send their data to third-party AI services.
///
/// Apple App Store Review Guidelines 5.1.1(i) + 5.1.2(i) require apps that
/// share user data with third-party AI services to (a) disclose what data
/// is sent, (b) name who it's sent to, and (c) get explicit user permission
/// BEFORE sending. This service tracks that permission so the rest of the
/// app can gate AI-bound calls behind it.
///
/// The third parties Caliana shares data with:
///   - OpenAI (typed text, food photos, fridge photos, voice transcripts) —
///     used for chat replies, vision-based food/fridge identification,
///     and transcription via Whisper.
///   - ElevenLabs (Caliana's reply text) — used to synthesize her voice.
///
/// No raw audio leaves the device for ElevenLabs (only her reply text is
/// sent to be voiced). User audio for Whisper does leave the device.
class ConsentService extends ChangeNotifier {
  ConsentService._();
  static final ConsentService _instance = ConsentService._();
  static ConsentService get instance => _instance;

  static const _key = 'caliana_ai_consent_v1';

  bool _granted = false;
  bool _loaded = false;

  bool get granted => _granted;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _granted = prefs.getBool(_key) ?? false;
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> grant() async {
    _granted = true;
    notifyListeners();
    await _persist();
  }

  Future<void> revoke() async {
    _granted = false;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _granted);
    } catch (_) {}
  }
}
