import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SecurityAlertService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlaying = false;

  static Future<void> triggerContinuousAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setSource(AssetSource('sounds/security_alarm.mp3'));
      await _audioPlayer.resume();
    } catch (_) {}

    final hasVib = await Vibration.hasVibrator();
    if (hasVib ?? false) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 1000],
        repeat: 0,
      );
    }
  }

  static Future<void> stopAlert() async {
    _isPlaying = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    Vibration.cancel();
  }
}

