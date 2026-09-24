import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging/sync_audit_logger.dart';
import '../../core/notifications/security_alert_service.dart';
import '../../models/subscriber_model.dart';
import '../scanner/qr_scanner_screen.dart';
import 'blocked_ips_dialog.dart';
import 'widgets/secure_sync_dialog.dart';

class SubscribersAdminScreen extends StatefulWidget {
  const SubscribersAdminScreen({super.key});

  @override
  State<SubscribersAdminScreen> createState() => _SubscribersAdminScreenState();
}

class _SubscribersAdminScreenState extends State<SubscribersAdminScreen> {
  static const String _storageKey = 'local_subscribers_database';
  List<Subscriber> _subscribers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _subscribers = list.map((e) => Subscriber.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    } else {
      _subscribers = [
        Subscriber(
          deviceId: 'dev_84f932a10c7e',
          fullName: 'محمد علي الحكيمي',
          isPaid: true,
          expiryDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        ),
        Subscriber(
          deviceId: 'dev_11a8b9423dff',
          fullName: 'سعيد عبد الرحمن',
          isPaid: false,
          expiryDate: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        ),
      ];
      await _saveSubscribers(_subscribers);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSubscribers(List<Subscriber> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((s) => s.toMap()).toList());
    await prefs.setString(_storageKey, raw);
    setState(() => _subscribers = list);
  }

  void _openSecureSharing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecureSyncDialog(
        subscribers: _subscribers,
        onSyncComplete: (updatedList) => _saveSubscribers(updatedList),
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SyncQrScannerScreen(
          currentList: _subscribers,
          onSyncComplete: (updatedList) => _saveSubscribers(updatedList),
        ),
      ),
    );
  }

  void _openBlockedIps() {
    SecurityAlertService.stopAlert();
    showDialog(
      context: context,
      builder: (ctx) => const BlockedIpsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة إدارة المشتركين والشبكة'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'قائمة الأجهزة المحظورة',
            onPressed: _openBlockedIps,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'تصدير سجل التدقيق CSV',
            onPressed: () => SyncAuditLogger.exportAndShareLogsCsv(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي المشتركين المسجلين: ${_subscribers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('مشاركة البيانات'),
                            onPressed: _openSecureSharing,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                            icon: const Icon(Icons.qr_code_scanner, size: 16),
                            label: const Text('مسح QR'),
                            onPressed: _openScanner,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _subscribers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sub = _subscribers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sub.isPaid ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            sub.isPaid ? Icons.check : Icons.close,
                            color: sub.isPaid ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(sub.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('معرف الجهاز: ${sub.deviceId}'),
                        trailing: Text(
                          sub.expiryDate.split('T').first,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

