import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoAuthService {
  // مفتاح توقيع داخلي ثابت للنظام للتحقق من سلامة الأكواد المصدرة
  static const String _appSecretHmacKey = 'WIFI_SYNC_SECURE_HMAC_MASTER_KEY_2026';

  /// توقيع حمولة نصية بـ HMAC-SHA256
  static String signPayload(String payload) {
    final hmac = Hmac(sha256, utf8.encode(_appSecretHmacKey));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  /// إنشاء رمز QR موثوق للمشترك يحتوي على بياناته وتوقيعه الرقمي
  static String generateSignedSubscriberQr({
    required String deviceId,
    required String fullName,
    required bool isPaid,
    required String expiryDate,
  }) {
    final rawData = '$deviceId|$fullName|$isPaid|$expiryDate';
    final signature = signPayload(rawData);
    
    return jsonEncode({
      'type': 'SUBSCRIBER_LICENSE',
      'device_id': deviceId,
      'name': fullName,
      'is_paid': isPaid,
      'expiry': expiryDate,
      'sig': signature,
    });
  }

  /// التحقق من صحة ومصداقية الرمز والتأكد من عدم تزويره
  static bool verifySubscriberQr(String qrJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(qrJson) as Map<String, dynamic>;
      if (data['type'] != 'SUBSCRIBER_LICENSE') return false;

      final deviceId = data['device_id'] as String;
      final name = data['name'] as String;
      final isPaid = data['is_paid'] as bool;
      final expiry = data['expiry'] as String;
      final providedSig = data['sig'] as String;

      final rawData = '$deviceId|$name|$isPaid|$expiry';
      final expectedSig = signPayload(rawData);

      return providedSig == expectedSig;
    } catch (_) {
      return false;
    }
  }
}

