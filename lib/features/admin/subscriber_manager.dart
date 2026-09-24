import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/subscriber_model.dart';

class SubscriberManager {
  static const String _storageKey = 'local_subscribers_database';

  /// استرجاع المشتركين من التخزين الدائم
  static Future<List<Subscriber>> getAllSubscribers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Subscriber.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// حفظ قائمة المشتركين
  static Future<void> saveAllSubscribers(List<Subscriber> subscribers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(subscribers.map((s) => s.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }

  /// إضافة أو تحديث مشترك بناءً على معرّف الجهاز
  static Future<void> upsertSubscriber(Subscriber subscriber) async {
    final list = await getAllSubscribers();
    final index = list.indexWhere((s) => s.deviceId == subscriber.deviceId);

    if (index >= 0) {
      list[index] = subscriber;
    } else {
      list.add(subscriber);
    }
    await saveAllSubscribers(list);
  }

  /// حذف مشترك
  static Future<void> deleteSubscriber(String deviceId) async {
    final list = await getAllSubscribers();
    list.removeWhere((s) => s.deviceId == deviceId);
    await saveAllSubscribers(list);
  }

  /// فحص حالة اشتراك جهاز معين
  static Future<bool> isDeviceAuthorized(String deviceId) async {
    final list = await getAllSubscribers();
    final now = DateTime.now();

    for (final s in list) {
      if (s.deviceId == deviceId && s.isPaid) {
        final expiry = DateTime.tryParse(s.expiryDate);
        if (expiry != null && expiry.isAfter(now)) {
          return true;
        }
      }
    }
    return false;
  }
}

