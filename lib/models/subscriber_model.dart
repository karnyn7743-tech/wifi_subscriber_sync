import 'dart:convert';

class Subscriber {
  final String deviceId;
  final String? macAddress; // عنوان الماك لربطه بالراوتر أو الأنتينا
  final String fullName;
  final bool isPaid;
  final String expiryDate; // صيغة YYYY-MM-DD
  final String? notes;

  Subscriber({
    required this.deviceId,
    this.macAddress,
    required this.fullName,
    required this.isPaid,
    required this.expiryDate,
    this.notes,
  });

  /// التحقق من صحة صياغة الـ MAC Address
  static bool isValidMac(String? mac) {
    if (mac == null || mac.trim().isEmpty) return false;
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(mac.trim());
  }

  /// توحيد تنسيق الـ MAC Address إلى نمط موحد (AA:BB:CC:DD:EE:FF)
  static String? normalizeMac(String? mac) {
    if (mac == null || mac.trim().isEmpty) return null;
    final cleaned = mac.trim().replaceAll('-', ':').toUpperCase();
    return isValidMac(cleaned) ? cleaned : null;
  }

  /// تحويل الكائن إلى Map لتخزينه في التخزين المحلي أو نقله عبر الشبكة
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'macAddress': normalizeMac(macAddress),
      'fullName': fullName,
      'isPaid': isPaid,
      'expiryDate': expiryDate,
      'notes': notes,
    };
  }

  /// إنشاء كائن من Map مع التوافق العكسي للبيانات المخزنة سابقاً
  factory Subscriber.fromMap(Map<String, dynamic> map) {
    return Subscriber(
      deviceId: map['deviceId'] as String? ?? '',
      macAddress: normalizeMac(map['macAddress'] as String?),
      fullName: map['fullName'] as String? ?? '',
      isPaid: map['isPaid'] as bool? ?? false,
      expiryDate: map['expiryDate'] as String? ?? '',
      notes: map['notes'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Subscriber.fromJson(String source) =>
      Subscriber.fromMap(jsonDecode(source) as Map<String, dynamic>);

  Subscriber copyWith({
    String? deviceId,
    String? macAddress,
    String? fullName,
    bool? isPaid,
    String? expiryDate,
    String? notes,
  }) {
    return Subscriber(
      deviceId: deviceId ?? this.deviceId,
      macAddress: macAddress ?? this.macAddress,
      fullName: fullName ?? this.fullName,
      isPaid: isPaid ?? this.isPaid,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
    );
  }
}
