import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class AuditLogEntry {
  final DateTime timestamp;
  final String eventType;
  final String targetIp;
  final String details;
  final bool isSuccess;

  AuditLogEntry({
    required this.timestamp,
    required this.eventType,
    required this.targetIp,
    required this.details,
    required this.isSuccess,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'targetIp': targetIp,
        'details': details,
        'isSuccess': isSuccess,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) => AuditLogEntry(
        timestamp: DateTime.parse(map['timestamp'] as String),
        eventType: map['eventType'] as String,
        targetIp: map['targetIp'] as String,
        details: map['details'] as String,
        isSuccess: map['isSuccess'] as bool,
      );
}

class SyncAuditLogger {
  static const String _storageKey = 'sync_audit_security_logs';

  static Future<void> log({
    required String eventType,
    required String targetIp,
    required String details,
    required bool isSuccess,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawLogs = prefs.getString(_storageKey);
    List<AuditLogEntry> logs = [];

    if (rawLogs != null) {
      try {
        final List<dynamic> list = jsonDecode(rawLogs) as List<dynamic>;
        logs = list.map((e) => AuditLogEntry.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    logs.insert(
      0,
      AuditLogEntry(
        timestamp: DateTime.now(),
        eventType: eventType,
        targetIp: targetIp,
        details: details,
        isSuccess: isSuccess,
      ),
    );

    if (logs.length > 500) {
      logs = logs.sublist(0, 500);
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(logs.map((e) => e.toMap()).toList()),
    );
  }

  static Future<List<AuditLogEntry>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLogs = prefs.getString(_storageKey);
    if (rawLogs == null) return [];

    try {
      final List<dynamic> list = jsonDecode(rawLogs) as List<dynamic>;
      return list.map((e) => AuditLogEntry.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> exportAndShareLogsCsv() async {
    final logs = await getLogs();
    final List<List<dynamic>> rows = [
      ['التاريخ والوقت', 'نوع العملية', 'عنوان IP', 'النتيجة', 'التفاصيل']
    ];

    for (final l in logs) {
      rows.add([
        l.timestamp.toIso8601String(),
        l.eventType,
        l.targetIp,
        l.isSuccess ? 'ناجح' : 'فشل/تحذير',
        l.details,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/security_audit_logs.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'سجل تدقيق الأمان والمزامنة');
  }
}

