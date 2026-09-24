import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredBeacon {
  final String ip;
  final int port;
  final String name;
  final DateTime lastSeen;

  DiscoveredBeacon({
    required this.ip,
    required this.port,
    required this.name,
    required this.lastSeen,
  });
}

class SyncBeaconListener {
  static const int beaconPort = 8889;
  RawDatagramSocket? _socket;
  final Map<String, DiscoveredBeacon> _discoveredServers = {};

  final Function(List<DiscoveredBeacon>) onServersUpdated;

  SyncBeaconListener({required this.onServersUpdated});

  /// بدء الاستماع لنبضات UDP واكتشاف الخوادم المحلية تلقائياً
  Future<void> startListening() async {
    await stop();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      beaconPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          _processDatagram(datagram);
        }
      }
    });
  }

  void _processDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final map = jsonDecode(text) as Map<String, dynamic>;

      if (map['protocol'] == 'WIFI_SYNC_BEACON') {
        final ip = map['ip'] as String? ?? datagram.address.address;
        final port = map['port'] as int? ?? 9090;
        final name = map['name'] as String? ?? 'خادم غير مسمى';

        final key = '$ip:$port';
        _discoveredServers[key] = DiscoveredBeacon(
          ip: ip,
          port: port,
          name: name,
          lastSeen: DateTime.now(),
        );

        // إزالة الخوادم المنقطعة التي تجاوزت 8 ثوانٍ دون إرسال نبضة
        final now = DateTime.now();
        _discoveredServers.removeWhere(
          (_, b) => now.difference(b.lastSeen).inSeconds > 8,
        );

        onServersUpdated(_discoveredServers.values.toList());
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _discoveredServers.clear();
  }
}

