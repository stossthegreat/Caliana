import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'app_settings_service.dart';

/// Records audio with the device mic, uploads it to the backend's
/// /api/transcribe endpoint which proxies to OpenAI Whisper, and
/// returns the transcribed text.
class TranscribeService {
  TranscribeService._();
  static final TranscribeService instance = TranscribeService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  bool get isRecording => _currentPath != null;

  /// Start recording to a temp file. Returns true on success.
  Future<bool> startRecording() async {
    if (!(await _recorder.hasPermission())) {
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    final isIos = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // iOS AAC produces a container Whisper can't decode.
    // Use WAV on iOS (universally supported), AAC on Android (smaller).
    final ext = isIos ? 'wav' : 'm4a';
    final encoder = isIos ? AudioEncoder.wav : AudioEncoder.aacLc;
    final path =
        '${tempDir.path}/gobly_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _currentPath = path;
    return true;
  }

  /// Stop recording and return the file path, or null if nothing was recorded.
  Future<String?> stopRecording() async {
    if (_currentPath == null) return null;
    final path = await _recorder.stop();
    _currentPath = null;
    return path;
  }

  /// Cancel recording and delete the file.
  Future<void> cancelRecording() async {
    if (_currentPath == null) return;
    try {
      await _recorder.stop();
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    _currentPath = null;
  }

  /// Upload an audio file to the backend and get the transcribed text.
  /// Deletes the file after upload to keep temp storage clean.
  Future<String> transcribeFile(String path) async {
    final backendUrl = AppSettingsService.instance.backendUrl;
    if (backendUrl.isEmpty) {
      throw Exception('Backend URL not set');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Audio file missing');
    }

    try {
      final uri = Uri.parse('$backendUrl/api/transcribe');
      final request = http.MultipartRequest('POST', uri);
      // Use the actual file extension so Whisper knows the format
      final filename = path.endsWith('.wav') ? 'audio.wav' : 'audio.m4a';
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          path,
          filename: filename,
        ),
      );

      final streamed = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception(
          'Transcription failed (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['text'] as String? ?? '';
      return text.trim();
    } finally {
      // Clean up temp file
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Full flow helper: stop recording and transcribe in one call.
  Future<String> stopAndTranscribe() async {
    final path = await stopRecording();
    if (path == null) {
      throw Exception('No recording in progress');
    }
    return transcribeFile(path);
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
