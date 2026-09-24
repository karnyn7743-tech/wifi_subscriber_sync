import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SyncBeaconBroadcaster {
  static const int beaconPort = 8889;
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;

  /// بدء بث إشارات UDP الدورية للتعريف بوجود الخادم على الشبكة المحلية
  Future<void> startBroadcasting({
    required String serverIp,
    required int httpPort,
    required String serverName,
  }) async {
    await stop();

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    final beaconData = jsonEncode({
      'protocol': 'WIFI_SYNC_BEACON',
      'ip': serverIp,
      'port': httpPort,
      'name': serverName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(beaconData);

    // إرسال نبضة كل ثانيتين إلى عنوان البث العام
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        _socket?.send(
          bytes,
          InternetAddress('255.255.255.255'),
          beaconPort,
        );
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }
}

