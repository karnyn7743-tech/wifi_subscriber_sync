import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/subscriber_model.dart';

class NetworkService {
  HttpServer? _wsServer;
  final List<WebSocket> _connectedSockets = [];
  final int port;

  final Function(String clientIp, String deviceId) onDeviceVerified;
  final Function(String clientIp) onDeviceDisconnected;

  NetworkService({
    this.port = 8088,
    required this.onDeviceVerified,
    required this.onDeviceDisconnected,
  });

  /// تشغيل خادم WebSocket لمراقبة حالة اتصال الأجهزة في الوقت الحقيقي
  Future<void> startWebSocketServer(List<Subscriber> validSubscribers) async {
    await stop();

    _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _wsServer!.transform(WebSocketTransformer()).listen((WebSocket ws) {
      _handleWebSocketClient(ws, validSubscribers);
    });
  }

  void _handleWebSocketClient(WebSocket ws, List<Subscriber> validSubscribers) {
    _connectedSockets.add(ws);
    String? verifiedDeviceId;
    String clientIp = 'unknown';

    ws.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'DEVICE_HANDSHAKE') {
            final deviceId = data['device_id'] as String;
            clientIp = data['client_ip'] as String? ?? 'client';

            // مطابقة معرّف الجهاز مع قائمة المشتركين المسددين
            final isValid = validSubscribers.any(
              (s) => s.deviceId == deviceId && s.isPaid,
            );

            if (isValid) {
              verifiedDeviceId = deviceId;
              ws.add(jsonEncode({'status': 'AUTHORIZED', 'device_id': deviceId}));
              onDeviceVerified(clientIp, deviceId);
            } else {
              ws.add(jsonEncode({'status': 'UNAUTHORIZED', 'reason': 'الاشتراك غير ساري'}));
              ws.close(WebSocketStatus.normalClosure, 'Unauthorized');
            }
          }
        } catch (_) {
          ws.close(WebSocketStatus.protocolError);
        }
      },
      onDone: () {
        _connectedSockets.remove(ws);
        if (verifiedDeviceId != null) {
          onDeviceDisconnected(clientIp);
        }
      },
      onError: (_) {
        _connectedSockets.remove(ws);
      },
    );
  }

  Future<void> broadcastMessage(Map<String, dynamic> message) async {
    final raw = jsonEncode(message);
    for (final ws in _connectedSockets) {
      if (ws.readyState == WebSocket.open) {
        ws.add(raw);
      }
    }
  }

  Future<void> stop() async {
    for (final ws in _connectedSockets) {
      await ws.close();
    }
    _connectedSockets.clear();
    await _wsServer?.close(force: true);
    _wsServer = null;
  }
}

