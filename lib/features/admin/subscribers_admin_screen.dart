import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging/sync_audit_logger.dart';
import '../../core/notifications/security_alert_service.dart';
import '../../models/subscriber_model.dart';
import '../../network/network_service.dart';
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

  // سيرفر الوساطة والترحيل المركزي وقائمة الأجهزة المتصلة حياً
  late final CentralRelayServer _relayServer;
  List<ConnectedClientInfo> _liveConnectedDevices = [];

  @override
  void initState() {
    super.initState();
    _initRelayServerAndData();
  }

  Future<void> _initRelayServerAndData() async {
    _relayServer = CentralRelayServer(
      onClientsChanged: (clients) {
        if (mounted) {
          setState(() => _liveConnectedDevices = clients);
        }
      },
    );

    await _loadSubscribers();
    // تشغيل السيرفر المركزي وتزويده بقائمة المشتركين المسموح لهم فور الإقلاع
    await _relayServer.startServer(_subscribers);
  }

  @override
  void dispose() {
    _relayServer.stopServer();
    super.dispose();
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
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSubscribers(List<Subscriber> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((s) => s.toMap()).toList());
    await prefs.setString(_storageKey, raw);
    
    if (mounted) {
      setState(() => _subscribers = list);
    }

    // إشعار سيرفر الوساطة فوراً بالقائمة المحدثة لقطع اتصال أي جهاز تم حذفه أو تعطيله
    _relayServer.updateAllowedSubscribers(list);
  }

  // 1. حذف المشترك نهائياً وفصل اتصاله الفوري إذا كان متصلاً
  Future<void> _deleteSubscriber(int index) async {
    final deletedItem = _subscribers[index];
    final updatedList = List<Subscriber>.from(_subscribers)..removeAt(index);
    await _saveSubscribers(updatedList);

    // قطع اتصال المقبس للجهاز المحذوف لحظياً
    _relayServer.disconnectClient(deletedItem.deviceId, reason: 'تم حذف حسابك من الشبكة');

    await SyncAuditLogger.log(
      eventType: 'SUBSCRIBER_DELETED',
      targetIp: 'LocalAdmin',
      details: 'تم حذف المشترك نهائياً: ${deletedItem.fullName} (${deletedItem.deviceId})',
      isSuccess: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف "${deletedItem.fullName}" وقطع اتصاله بالشبكة فوراً'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // 2. تبديل حالة السداد والتفعيل
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty && idController.text.trim().isNotEmpty) {
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

  // 4. نافذة استعراض الأجهزة المتصلة حياً بالسيرفر المركزي
  void _showLiveConnectedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.sensors, color: Colors.teal),
                const SizedBox(width: 8),
                Text('المتصلون الآن (${_liveConnectedDevices.length})'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _liveConnectedDevices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'لا توجد أجهزة متصلة بالسيرفر حالياً.\nتمر الاتصالات عبر المنفذ 8088 فور اتصال المشتركين.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _liveConnectedDevices.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final client = _liveConnectedDevices[idx];
                        final sub = _subscribers.firstWhere(
                          (s) => s.deviceId == client.deviceId,
                          orElse: () => Subscriber(deviceId: client.deviceId, fullName: 'جهاز غير معروف', isPaid: true, expiryDate: ''),
                        );
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 16,
                            child: Icon(Icons.phone_android, color: Colors.white, size: 18),
                          ),
                          title: Text(sub.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            'المعرف: ${client.deviceId}\nمتصل منذ: ${client.connectedAt.toString().split('.').first.split(' ').last}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.red),
                            tooltip: 'طرد وفصل الاتصال الآن',
                            onPressed: () {
                              _relayServer.disconnectClient(client.deviceId, reason: 'تم قطع اتصالك يدوياً من المشرف');
                              setDialogState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
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
          // عداد حي بالأجهزة المتصلة بالسيرفر الوسيط
          IconButton(
            icon: Badge(
              label: Text('${_liveConnectedDevices.length}'),
              backgroundColor: _liveConnectedDevices.isNotEmpty ? Colors.greenAccent.shade700 : Colors.grey,
              child: const Icon(Icons.sensors),
            ),
            tooltip: 'الأجهزة المتصلة حياً بالسيرفر',
            onPressed: _showLiveConnectedDialog,
          ),
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
                            final isDeviceOnline = _liveConnectedDevices.any((d) => d.deviceId == sub.deviceId);

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
                                return await showDialog<bool>(
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
                                leading: Stack(
                                  children: [
                                    InkWell(
                                      onTap: () => _togglePaidStatus(index),
                                      child: CircleAvatar(
                                        backgroundColor: sub.isPaid ? Colors.green.shade100 : Colors.red.shade100,
                                        child: Icon(
                                          sub.isPaid ? Icons.check : Icons.close,
                                          color: sub.isPaid ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                    if (isDeviceOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent.shade700,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(sub.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  'معرف: ${sub.deviceId}\nالحالة: ${sub.isPaid ? 'مسموح بالاتصال' : 'معطل ومرفوض'} ${isDeviceOnline ? '• متصل الآن 🟢' : ''}',
                                ),
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
                                            content: Text('حذف "${sub.fullName}" نهائياً؟'),
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
