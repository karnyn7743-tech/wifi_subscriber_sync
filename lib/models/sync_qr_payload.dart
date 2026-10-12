import 'dart:convert';
import 'subscriber_model.dart';

class SyncQrPayload {
  static const String prefix = 'DIRECT_SYNC_PAYLOAD';

  final String ip;
  final int port;
  final String pin;
  final String? deviceId;
  final String? macAddress;
  final String? fullName;

  SyncQrPayload({
    required this.ip,
    required this.port,
    required this.pin,
    this.deviceId,
    this.macAddress,
    this.fullName,
  });

  Map<String, dynamic> toMap() {
    return {
      'ip': ip,
      'port': port,
      'pin': pin,
      'deviceId': deviceId,
      'macAddress': Subscriber.normalizeMac(macAddress),
      'fullName': fullName,
    };
  }

  String toJsonString() {
    return '$prefix:${jsonEncode(toMap())}';
  }

  static SyncQrPayload? fromJsonString(String raw) {
    if (!raw.startsWith(prefix)) return null;
    try {
      final jsonPart = raw.substring(prefix.length + 1);
      final map = jsonDecode(jsonPart) as Map<String, dynamic>;
      return SyncQrPayload(
        ip: map['ip'] as String,
        port: map['port'] as int,
        pin: map['pin'] as String,
        deviceId: map['deviceId'] as String?,
        macAddress: Subscriber.normalizeMac(map['macAddress'] as String?),
        fullName: map['fullName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
