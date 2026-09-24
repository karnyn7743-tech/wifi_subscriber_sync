import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedIpRecord {
  final String ip;
  final DateTime blockedAt;
  final DateTime expiresAt;
  final String reason;

  BlockedIpRecord({
    required this.ip,
    required this.blockedAt,
    required this.expiresAt,
    required this.reason,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'blockedAt': blockedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'reason': reason,
      };

  factory BlockedIpRecord.fromMap(Map<String, dynamic> map) => BlockedIpRecord(
        ip: map['ip'] as String,
        blockedAt: DateTime.parse(map['blockedAt'] as String),
        expiresAt: DateTime.parse(map['expiresAt'] as String),
        reason: map['reason'] as String,
      );
}

class PersistentIpBlockManager {
  static const String _storageKey = 'persistent_blocked_ips_list';
  static const Map<String, int> _failedAttempts = {};

  static Future<List<BlockedIpRecord>> getBlockedIps() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_storageKey);
    if (rawJson == null) return [];

    try {
      final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
      return list
          .map((item) => BlockedIpRecord.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isIpBlocked(String ip) async {
    final list = await getBlockedIps();
    final now = DateTime.now();

    for (final record in list) {
      if (record.ip == ip && record.expiresAt.isAfter(now)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> recordFailedAttempt({
    required String ip,
    required Function() onBreach,
  }) async {
    final attempts = (_failedAttempts[ip] ?? 0) + 1;
    _failedAttempts[ip] = attempts;

    if (attempts >= 3) {
      await blockIp(
        ip: ip,
        duration: const Duration(minutes: 15),
        reason: 'تجاوز حد تخمين رمز PIN المشفر (3 محاولات خاطئة)',
      );
      _failedAttempts.remove(ip);
      onBreach();
    }
  }

  static Future<void> blockIp({
    required String ip,
    required Duration duration,
    required String reason,
  }) async {
    final list = await getBlockedIps();
    final now = DateTime.now();
    list.removeWhere((r) => r.ip == ip);

    list.add(BlockedIpRecord(
      ip: ip,
      blockedAt: now,
      expiresAt: now.add(duration),
      reason: reason,
    ));

    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, data);
  }

  static Future<void> unblockIp(String ip) async {
    final list = await getBlockedIps();
    list.removeWhere((r) => r.ip == ip);

    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, data);
  }
}

