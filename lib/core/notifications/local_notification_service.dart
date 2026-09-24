import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import '../../features/admin/blocked_ips_dialog.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'OPEN_BLOCKED_IPS') {
          final context = NavigationService.navigatorKey.currentContext;
          if (context != null) {
            showDialog(
              context: context,
              builder: (ctx) => const BlockedIpsDialog(),
            );
          }
        }
      },
    );
  }

  static Future<void> showSecurityBreachNotification({
    required String ip,
    required String reason,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_channel_critical',
      'تنبيهات الأمان العاجلة',
      channelDescription: 'إشعارات محاولات الاختراق وحظر الأجهزة',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'تحذير أمني',
      color: Colors.red,
      fullScreenIntent: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      999,
      'تم حظر محاولة اتصال غير مصرح بها',
      'العنوان $ip حاول اختراق رمز الجلسة: $reason',
      notificationDetails,
      payload: 'OPEN_BLOCKED_IPS',
    );
  }
}

