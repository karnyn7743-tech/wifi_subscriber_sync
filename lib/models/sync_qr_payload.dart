import 'dart:convert';

class SyncQrPayload {
  final String ip;
  final int port;
  final String pin;
  final int validSeconds;

  SyncQrPayload({
    required this.ip,
    required this.port,
    required this.pin,
    required this.validSeconds,
  });

  String toJsonString() {
    return jsonEncode({
      'type': 'DIRECT_SYNC_PAYLOAD',
      'ip': ip,
      'port': port,
      'pin': pin,
      'expires_in': validSeconds,
    });
  }

  static SyncQrPayload? fromJsonString(String raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] == 'DIRECT_SYNC_PAYLOAD') {
        return SyncQrPayload(
          ip: data['ip'] as String,
          port: data['port'] as int? ?? 9090,
          pin: data['pin'] as String,
          validSeconds: data['expires_in'] as int? ?? 60,
        );
      }
    } catch (_) {}
    return null;
  }
}

