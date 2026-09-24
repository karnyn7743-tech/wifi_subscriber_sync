import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerFeedbackService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;

  static bool isSoundEnabled = true;
  static bool isVibrationEnabled = true;

  static const String _keySound = 'scanner_sound_enabled';
  static const String _keyVibration = 'scanner_vibration_enabled';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isSoundEnabled = prefs.getBool(_keySound) ?? true;
    isVibrationEnabled = prefs.getBool(_keyVibration) ?? true;

    if (!_isInitialized) {
      try {
        await _audioPlayer.setSource(AssetSource('sounds/scanner_beep.mp3'));
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
      _isInitialized = true;
    }
  }

  static Future<void> toggleSound(bool enabled) async {
    isSoundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, enabled);
  }

  static Future<void> toggleVibration(bool enabled) async {
    isVibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibration, enabled);
  }

  static Future<void> triggerScanFeedback() async {
    if (isVibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    if (isSoundEnabled) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.resume();
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    }
  }

  static void dispose() {
    _audioPlayer.dispose();
  }
}

