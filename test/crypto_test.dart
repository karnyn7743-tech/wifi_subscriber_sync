import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_subscriber_sync/core/security/aes_gcm_service.dart';

void main() {
  group('اختبارات تشفير وفك تشفير AES-GCM و PBKDF2', () {
    test('تشفير وفك تشفير حمولة نصية بنجاح باستخدام نفس الـ PIN', () {
      const plainText = '{"subscribers":[{"name":"أحمد","isPaid":true}]}';
      const pin = '5829';

      final encrypted = AesGcmService.encryptPayload(plainText: plainText, pin: pin);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(plainText)));

      final decrypted = AesGcmService.decryptPayload(cipherTextBase64: encrypted, pin: pin);
      expect(decrypted, equals(plainText));
    });

    test('فشل فك التشفير ورمي استثناء عند إدخال PIN خاطئ', () {
      const plainText = 'بيانات سرية';
      const correctPin = '1234';
      const wrongPin = '9999';

      final encrypted = AesGcmService.encryptPayload(plainText: plainText, pin: correctPin);

      expect(
        () => AesGcmService.decryptPayload(cipherTextBase64: encrypted, pin: wrongPin),
        throwsA(isA<Exception>()),
      );
    });
  });
}

