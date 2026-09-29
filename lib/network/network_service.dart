import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/logging/sync_audit_logger.dart';
import '../models/subscriber_model.dart';

class ConnectedClientInfo {
  final WebSocket socket;
  final String deviceId;
  final String ip;
  final DateTime connectedAt;

  ConnectedClientInfo({
    required this.socket,
    required this.deviceId,
    required this.ip,
    required this.connectedAt,
  });
}

class CentralRelayServer {
  HttpServer? _server;
  final int port;

  // خارطة الأجهزة المتصلة حياً بالخادم: Key = deviceId
  final Map<String, ConnectedClientInfo> _activeClients = {};

  // قائمة المشتركين المخزنة في النظام
  List<Subscriber> _allowedSubscribers = [];

  // إشعار الواجهة عند تغير حالة الأجهزة المتصلة
  final Function(List<ConnectedClientInfo>) onClientsChanged;

  CentralRelayServer({
    this.port = 8088,
    required this.onClientsChanged,
  });

  /// تحديث قائمة المشتركين المسموحين المعتمدة لدى السيرفر
  void updateAllowedSubscribers(List<Subscriber> subscribers) {
    _allowedSubscribers = subscribers;
    _validateConnectedClients();
  }

  /// فحص الأجهزة المتصلة حالياً وقطع اتصال من تم حذفه أو إلغاء تفعيله
  void _validateConnectedClients() {
    final toDisconnect = <String>[];
    for (final entry in _activeClients.entries) {
      final sub = _allowedSubscribers.firstWhere(
        (s) => s.deviceId == entry.key,
        orElse: () => Subscriber(deviceId: '', fullName: '', isPaid: false, expiryDate: ''),
      );

      if (sub.deviceId.isEmpty || !sub.isPaid) {
        toDisconnect.add(entry.key);
      }
    }

    for (final id in toDisconnect) {
      disconnectClient(id, reason: 'تم إلغاء صلاحية الجهاز من قبل المشرف');
    }
  }

  /// تشغيل سيرفر الوساطة المركزي
  Future<void> startServer(List<Subscriber> initialSubscribers) async {
    await stopServer();
    _allowedSubscribers = initialSubscribers;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_handleClientConnection);
  }

  void _handleClientConnection(WebSocket clientSocket) {
    String? currentDeviceId;
    final clientIp = 'Unknown';

    clientSocket.listen(
      (data) async {
        try {
          final payload = jsonDecode(data.toString()) as Map<String, dynamic>;
          final messageType = payload['type'] as String?;

          // 1. مرحلة المصافحة والتحقق من هوية الجهاز
          if (messageType == 'HANDSHAKE') {
            final deviceId = payload['device_id'] as String? ?? '';
            final clientSub = _allowedSubscribers.firstWhere(
              (s) => s.deviceId == deviceId,
              orElse: () => Subscriber(deviceId: '', fullName: '', isPaid: false, expiryDate: ''),
            );

            if (clientSub.deviceId.isNotEmpty && clientSub.isPaid) {
              currentDeviceId = deviceId;
              _activeClients[deviceId] = ConnectedClientInfo(
                socket: clientSocket,
                deviceId: deviceId,
                ip: clientIp,
                connectedAt: DateTime.now(),
              );

              clientSocket.add(jsonEncode({
                'type': 'HANDSHAKE_RESPONSE',
                'status': 'AUTHORIZED',
                'message': 'تم ربطك بالوسيط المركزي بنجاح',
              }));

              onClientsChanged(_activeClients.values.toList());

              await SyncAuditLogger.log(
                eventType: 'DEVICE_CONNECTED',
                targetIp: clientIp,
                details: 'اتصال الجهاز المسموح: $deviceId',
                isSuccess: true,
              );
            } else {
              clientSocket.add(jsonEncode({
                'type': 'HANDSHAKE_RESPONSE',
                'status': 'REJECTED',
                'message': 'غير مسموح لك بالاتصال بالشبكة',
              }));
              await clientSocket.close(WebSocketStatus.normalClosure, 'Unauthorized');
            }
            return;
          }

          // 2. مرحلة تمرير وتوجيه الرسائل بين الأجهزة (Routing Relay)
          if (messageType == 'RELAY_PACKET') {
            if (currentDeviceId == null || !_activeClients.containsKey(currentDeviceId)) {
              await clientSocket.close(WebSocketStatus.normalClosure, 'Session Invalid');
              return;
            }

            final targetDeviceId = payload['target_device_id'] as String?;
            final messageBody = payload['data'];

            if (targetDeviceId != null && _activeClients.containsKey(targetDeviceId)) {
              final targetSocket = _activeClients[targetDeviceId]!.socket;

              // تمرير الحزمة حصراً للهدف
              targetSocket.add(jsonEncode({
                'type': 'RELAY_PACKET',
                'from_device_id': currentDeviceId,
                'data': messageBody,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }));
            } else {
              // الرد للمرسل بأن الطرف الآخر غير متصل
              clientSocket.add(jsonEncode({
                'type': 'DELIVERY_ERROR',
                'reason': 'الجهاز الهدف غير متصل بالوسيط حالياً',
              }));
            }
          }
        } catch (_) {
          // خطأ بروتوكول
        }
      },
      onDone: () {
        if (currentDeviceId != null) {
          _activeClients.remove(currentDeviceId);
          onClientsChanged(_activeClients.values.toList());
        }
      },
      onError: (_) {
        if (currentDeviceId != null) {
          _activeClients.remove(currentDeviceId);
          onClientsChanged(_activeClients.values.toList());
        }
      },
    );
  }

  /// قطع اتصال جهاز معين وطرده من السيرفر
  void disconnectClient(String deviceId, {String reason = 'قطع الاتصال من الإدارة'}) {
    final client = _activeClients.remove(deviceId);
    if (client != null) {
      client.socket.add(jsonEncode({
        'type': 'DISCONNECTED_BY_SERVER',
        'reason': reason,
      }));
      client.socket.close(WebSocketStatus.normalClosure, reason);
      onClientsChanged(_activeClients.values.toList());
    }
  }

  List<ConnectedClientInfo> get connectedClients => _activeClients.values.toList();

  Future<void> stopServer() async {
    for (final client in _activeClients.values) {
      await client.socket.close();
    }
    _activeClients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
