import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/navigation_service.dart';
import 'core/security/app_license_service.dart';
import 'features/admin/subscribers_admin_screen.dart';
import 'features/auth/activation_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قناة الإشعارات المحلية التفاعلية
  await LocalNotificationService.init();

  // التحقق التراكمي من حالة ترخيص وتنشيط التطبيق لهذا الجهاز
  final bool isActivated = await AppLicenseService.isAppActivated();

  runApp(WifiSubscriberSyncApp(isActivated: isActivated));
}

class WifiSubscriberSyncApp extends StatelessWidget {
  final bool isActivated;

  const WifiSubscriberSyncApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام مزامنة المشتركين المحلي',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      locale: const Locale('ar', 'AE'),
      home: isActivated ? const SubscribersAdminScreen() : const ActivationLockScreen(),
    );
  }
}
