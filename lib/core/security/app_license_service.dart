import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLicenseService {
  // المفتاح السري الثابت الخاص بك لتوليد التراخيص المشفرة
  static const String _secretMasterKey = 'Admin_Net_Controller_MasterSecret_@2026_Yemen!';
  static const String _prefIsActivatedKey = 'sys_app_licensed_status';
  static const String _prefStoredKey = 'sys_app_activation_key';

  /// الحصول على معرّف الجهاز الثابت والفريد (Fingerprint)
  /// يعتمد على ANDROID_ID في أجهزة أندرويد ليبقى ثابتاً مهما تكرر تثبيت التطبيق
  static Future<String> getDeviceFingerprint() async {
    String rawId = 'GENERIC_DEV_ID';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        rawId = androidInfo.id;
      } else {
        rawId = Platform.localHostname;
      }
    } catch (_) {
      rawId = 'DEV_FALLBACK_DEFAULT';
    }

    final hash = sha256.convert(utf8.encode(rawId)).toString().toUpperCase();
    return 'NET-${hash.substring(0, 4)}-${hash.substring(4, 8)}';
  }

  /// خوارزمية HMAC-SHA256 لتوليد مفتاح التنشيط المطابق للمعرّف
  static String generateActivationKey(String deviceFingerprint) {
    final cleanFingerprint = deviceFingerprint.trim().toUpperCase();
    final hmac = Hmac(sha256, utf8.encode(_secretMasterKey));
    final digest = hmac.convert(utf8.encode(cleanFingerprint)).toString().toUpperCase();

    return 'ACT-${digest.substring(0, 4)}-${digest.substring(8, 12)}-${digest.substring(16, 20)}';
  }

  /// فحص وتفعيل التطبيق عند إدخال المفتاح
  static Future<bool> activateApp(String inputKey) async {
    final currentFingerprint = await getDeviceFingerprint();
    final expectedKey = generateActivationKey(currentFingerprint);

    final cleanInput = inputKey.trim().toUpperCase();

    if (cleanInput == expectedKey) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsActivatedKey, true);
      await prefs.setString(_prefStoredKey, cleanInput);
      return true;
    }
    return false;
  }

  /// التحقق من حالة تفعيل التطبيق مع إعادة مطابقة أمنية صامتة
  static Future<bool> isAppActivated() async {
    final prefs = await SharedPreferences.getInstance();
    final isActivated = prefs.getBool(_prefIsActivatedKey) ?? false;
    final storedKey = prefs.getString(_prefStoredKey) ?? '';

    if (!isActivated || storedKey.isEmpty) return false;

    final currentFingerprint = await getDeviceFingerprint();
    final expectedKey = generateActivationKey(currentFingerprint);

    return storedKey == expectedKey;
  }
}
