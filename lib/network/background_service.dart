import 'dart:io';

class BackgroundServiceManager {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// تهيئة بيئة العمل لاستمرار تشغيل مقابس الشبكة في الخلفية
  static Future<void> startForegroundSyncService() async {
    if (_isRunning) return;

    if (Platform.isAndroid) {
      // الخدمة تعمل تحت مظلة Foreground Service عبر AndroidManifest
      _isRunning = true;
    }
  }

  static Future<void> stopForegroundSyncService() async {
    _isRunning = false;
  }
}

