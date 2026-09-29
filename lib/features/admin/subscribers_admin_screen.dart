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
          expiryDate: '2026-10-25',
        ),
        Subscriber(
          deviceId: 'dev_11a8b9423dff',
          fullName: 'سعيد عبد الرحمن',
          isPaid: false,
          expiryDate: '2026-09-23',
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

  // 1. حذف مشترك نهائياً
  Future<void> _deleteSubscriber(int index) async {
    final deletedItem = _subscribers[index];
    final updatedList = List<Subscriber>.from(_subscribers)..removeAt(index);
    await _saveSubscribers(updatedList);

    await SyncAuditLogger.log(
      eventType: 'SUBSCRIBER_DELETED',
      targetIp: 'LocalAdmin',
      details: 'تم حذف المشترك: ${deletedItem.fullName} (${deletedItem.deviceId})',
      isSuccess: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف "${deletedItem.fullName}" نهائياً من قاعدة البيانات'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // 2. تبديل حالة التفعيل / السداد مباشرة
  Future<void> _togglePaidStatus(int index) async {
    final sub = _subscribers[index];
    final updatedSub = Subscriber(
      deviceId: sub.deviceId,
      fullName: sub.fullName,
      isPaid: !sub.isPaid,
      expiryDate: sub.expiryDate,
      notes: sub.notes,
    );

    final updatedList = List<Subscriber>.from(_subscribers);
    updatedList[index] = updatedSub;
    await _saveSubscribers(updatedList);
  }

  // 3. نافذة إضافة مشترك جديد يدوياً
  void _showAddSubscriberDialog() {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة جهاز مشترك جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المشترك',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'معرف الجهاز (Device ID)',
                prefixIcon: Icon(Icons.perm_identity),
                hintText: 'dev_...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (nameController.text.isNotEmpty && idController.text.isNotEmpty) {
                final newSub = Subscriber(
                  deviceId: idController.text.trim(),
                  fullName: nameController.text.trim(),
                  isPaid: true,
                  expiryDate: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first,
                );
                _saveSubscribers([..._subscribers, newSub]);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة وتفعيل'),
          ),
        ],
      ),
    );
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: _showAddSubscriberDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة مشترك'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.teal.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي المشتركين: ${_subscribers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('مشاركة', style: TextStyle(fontSize: 12)),
                            onPressed: _openSecureSharing,
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 14),
                            label: const Text('مسح QR', style: TextStyle(fontSize: 12)),
                            onPressed: _openScanner,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _subscribers.isEmpty
                      ? const Center(
                          child: Text(
                            'لا يوجد أي مشتركين مسجلين حالياً.\nاضغط على "إضافة مشترك" بالأسفل.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _subscribers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sub = _subscribers[index];
                            return Dismissible(
                              key: Key(sub.deviceId),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.red,
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_forever, color: Colors.white, size: 28),
                                    SizedBox(width: 8),
                                    Text('حذف نهائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('تأكيد الحذف النهائي'),
                                    content: Text('هل تريد بالتأكيد إزالة المشترك "${sub.fullName}" نهائياً من الشبكة؟'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) => _deleteSubscriber(index),
                              child: ListTile(
                                leading: InkWell(
                                  onTap: () => _togglePaidStatus(index),
                                  child: CircleAvatar(
                                    backgroundColor: sub.isPaid ? Colors.green.shade100 : Colors.red.shade100,
                                    child: Icon(
                                      sub.isPaid ? Icons.check : Icons.close,
                                      color: sub.isPaid ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                                title: Text(sub.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('معرف: ${sub.deviceId}\nالحالة: ${sub.isPaid ? 'مسموح بالاتصال' : 'معطل ومرفوض'}'),
                                isThreeLine: true,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      sub.expiryDate.split('T').first,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      tooltip: 'حذف المشترك',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('حذف المشترك'),
                                            content: Text('حذف "${sub.fullName}"؟'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('تأكيد الحذف'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          _deleteSubscriber(index);
                                        }
                                      },
                                    ),
                                  ],
                                ),
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
