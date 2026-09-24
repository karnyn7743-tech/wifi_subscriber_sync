import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'robust_secure_storage.dart';

class DeviceIdService {
  static const String _storageKey = 'permanent_unique_device_id';

  static Future<String> getPermanentDeviceId() async {
    final existingId = await RobustSecureStorage.read(key: _storageKey);
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final deviceInfo = DeviceInfoPlugin();
    String rawIdentifier = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      rawIdentifier = '${androidInfo.id}:${androidInfo.model}:${androidInfo.fingerprint}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      rawIdentifier = iosInfo.identifierForVendor ?? 'ios_unknown_uuid';
    } else {
      rawIdentifier = 'unsupported_platform_${DateTime.now().millisecondsSinceEpoch}';
    }

    final digest = sha256.convert(utf8.encode(rawIdentifier)).toString();
    await RobustSecureStorage.write(key: _storageKey, value: digest);
    return digest;
  }
}

