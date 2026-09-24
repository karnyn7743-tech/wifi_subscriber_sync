import 'dart:convert';

class Subscriber {
  final String deviceId;
  final String fullName;
  final bool isPaid;
  final String expiryDate;
  final String notes;

  Subscriber({
    required this.deviceId,
    required this.fullName,
    required this.isPaid,
    required this.expiryDate,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'fullName': fullName,
      'isPaid': isPaid,
      'expiryDate': expiryDate,
      'notes': notes,
    };
  }

  factory Subscriber.fromMap(Map<String, dynamic> map) {
    return Subscriber(
      deviceId: map['deviceId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      isPaid: map['isPaid'] as bool? ?? false,
      expiryDate: map['expiryDate'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Subscriber.fromJson(String source) =>
      Subscriber.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

