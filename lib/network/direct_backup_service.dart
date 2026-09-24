import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../core/logging/sync_audit_logger.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/notifications/security_alert_service.dart';
import '../core/security/aes_gcm_service.dart';
import '../core/storage/persistent_ip_block_manager.dart';
import '../models/subscriber_model.dart';

class DirectBackupSender {
  static const int sessionTimeoutSeconds = 60;
  static const int port = 9090;

  HttpServer? _server;
  Timer? _sessionTimer;
  String? _activePin;
  String? _encryptedPayload;

  final VoidCallback onSuccess;
  final Function(String ip) onBreachDetected;
  final VoidCallback onSessionExpired;

  DirectBackupSender({
    required this.onSuccess,
    required this.onBreachDetected,
    required this.onSessionExpired,
  });

  Future<String> startSecureSharing({required List<Subscriber> subscribers}) async {
    await stop();

    final pin = (1000 + Random.secure().nextInt(9000)).toString();
    _activePin = pin;

    final rawJson = jsonEncode(subscribers.map((s) => s.toMap()).toList());
    _encryptedPayload = AesGcmService.encryptPayload(plainText: rawJson, pin: pin);

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleIncomingRequest);

    _sessionTimer = Timer(const Duration(seconds: sessionTimeoutSeconds), () {
      stop();
      onSessionExpired();
    });

    return pin;
  }

  void _handleIncomingRequest(HttpRequest request) async {
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    if (await PersistentIpBlockManager.isIpBlocked(clientIp)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('IP Blocked.')
        ..close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/sync') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content) as Map<String, dynamic>;
        final providedPin = body['pin'] as String?;

        if (providedPin == _activePin) {
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'payload': _encryptedPayload}))
            ..close();

          await SyncAuditLogger.log(
            eventType: 'SYNC_TRANSFER_SUCCESS',
            targetIp: clientIp,
            details: 'تم نقل المشتركين وتأكيد فك التشفير بنجاح',
            isSuccess: true,
          );

          onSuccess();
          stop();
        } else {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('Invalid PIN.')
            ..close();

          await PersistentIpBlockManager.recordFailedAttempt(
            ip: clientIp,
            onBreach: () async {
              await SecurityAlertService.triggerContinuousAlert();
              await LocalNotificationService.showSecurityBreachNotification(
                ip: clientIp,
                reason: '3 محاولات تخمين PIN خاطئة',
              );
              onBreachDetected(clientIp);
            },
          );

          await SyncAuditLogger.log(
            eventType: 'FAILED_PIN_ATTEMPT',
            targetIp: clientIp,
            details: 'محاولة إدخال PIN غير صحيح',
            isSuccess: false,
          );
        }
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..close();
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }

  Future<void> stop() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    await _server?.close(force: true);
    _server = null;
    _activePin = null;
    _encryptedPayload = null;
  }
}

class DirectBackupReceiver {
  static Future<List<Subscriber>?> fetchRawSubscribersWithPin({
    required String senderIp,
    required int port,
    required String pin,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.post(senderIp, port, '/sync');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'pin': pin}));

      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        final bodyString = await response.transform(utf8.decoder).join();
        final body = jsonDecode(bodyString) as Map<String, dynamic>;
        final encryptedPayload = body['payload'] as String;

        final decryptedJson = AesGcmService.decryptPayload(
          cipherTextBase64: encryptedPayload,
          pin: pin,
        );

        final List<dynamic> list = jsonDecode(decryptedJson) as List<dynamic>;
        return list.map((e) => Subscriber.fromMap(e as Map<String, dynamic>)).toList();
      } else if (response.statusCode == HttpStatus.unauthorized) {
        throw Exception('رمز PIN غير صحيح.');
      } else if (response.statusCode == HttpStatus.forbidden) {
        throw Exception('هذا الجهاز محظور من الاتصال بالخادم.');
      } else {
        throw Exception('فشل الخادم برمز: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}

