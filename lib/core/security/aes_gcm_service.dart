import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class AesGcmService {
  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static const int _pbkdf2Iterations = 10000;
  static const int _keyLength = 32;

  static Uint8List _deriveKey(String pin, Uint8List salt) {
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength);
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  static String encryptPayload({required String plainText, required String pin}) {
    final secureRandom = Random.secure();
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      salt[i] = secureRandom.nextInt(256);
    }

    final iv = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      iv[i] = secureRandom.nextInt(256);
    }

    final key = _deriveKey(pin, salt);
    final cipher = GCMBlockCipher(AESEngine());
    final aeadParams = AEADParameters(
      KeyParameter(key),
      _tagLength * 8,
      iv,
      Uint8List(0),
    );

    cipher.init(true, aeadParams);
    final plainBytes = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = cipher.process(plainBytes);

    final result = BytesBuilder()
      ..add(salt)
      ..add(iv)
      ..add(encryptedBytes);

    return base64Encode(result.toBytes());
  }

  static String decryptPayload({required String cipherTextBase64, required String pin}) {
    final data = base64Decode(cipherTextBase64);
    if (data.length < _saltLength + _ivLength + _tagLength) {
      throw Exception('Invalid ciphertext payload size.');
    }

    final salt = data.sublist(0, _saltLength);
    final iv = data.sublist(_saltLength, _saltLength + _ivLength);
    final encryptedData = data.sublist(_saltLength + _ivLength);

    final key = _deriveKey(pin, salt);
    final cipher = GCMBlockCipher(AESEngine());
    final aeadParams = AEADParameters(
      KeyParameter(key),
      _tagLength * 8,
      iv,
      Uint8List(0),
    );

    cipher.init(false, aeadParams);
    final decryptedBytes = cipher.process(encryptedData);
    return utf8.decode(decryptedBytes);
  }
}

