import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores runtime app settings like the backend URL.
/// Kept separate from the user profile so dev settings don't pollute
/// the data we send to the agent.
class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();
  static final AppSettingsService _instance = AppSettingsService._();
  static AppSettingsService get instance => _instance;

  static const _backendUrlKey = 'gobly_backend_url_v1';

  /// Production Railway URL — always falls back to this if nothing else is set.
  /// Can be overridden at runtime (Settings) or at build time via
  /// --dart-define=BACKEND_URL=...
  static const String productionDefault =
      'https://recimobackend-production.up.railway.app';

  /// Compile-time override only — does NOT apply when empty.
  static const String _compileTimeOverride = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  // Start with the production default so we're never empty, even
  // before load() resolves. This guarantees the very first request
  // after app boot has a valid URL.
  String _backendUrl = productionDefault;
  String get backendUrl => _backendUrl;

  bool get hasBackend => _backendUrl.isNotEmpty;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Detect bad URLs from previous versions that should be ignored
  bool _isBadStored(String url) {
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') || // Android emulator loopback
        !lower.startsWith('http');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_backendUrlKey);

      if (stored != null && stored.isNotEmpty && !_isBadStored(stored)) {
        // User has a valid saved URL — use it
        _backendUrl = stored;
      } else if (_compileTimeOverride.isNotEmpty) {
        // Build-time override takes precedence over production default
        _backendUrl = _compileTimeOverride;
      } else {
        // Fall through to the production default, and if the stored
        // value was a known-bad URL, wipe it so it doesn't come back
        _backendUrl = productionDefault;
        if (stored != null && stored.isNotEmpty) {
          await prefs.remove(_backendUrlKey);
        }
      }
    } catch (_) {
      _backendUrl = productionDefault;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Reset to the production Railway URL
  Future<void> resetToDefault() async {
    _backendUrl = productionDefault;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backendUrlKey);
    } catch (_) {}
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = _normalize(url);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_backendUrl.isEmpty) {
        await prefs.remove(_backendUrlKey);
      } else {
        await prefs.setString(_backendUrlKey, _backendUrl);
      }
    } catch (_) {}
  }

  /// Clean up and validate a URL: trim, force https://, strip trailing slash.
  /// Rejects http:// because iOS App Transport Security blocks cleartext HTTP.
  String _normalize(String url) {
    var cleaned = url.trim();
    if (cleaned.isEmpty) return '';
    // Force HTTPS — iOS blocks http:// via ATS
    if (cleaned.startsWith('http://')) {
      cleaned = cleaned.replaceFirst('http://', 'https://');
    }
    if (!cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
