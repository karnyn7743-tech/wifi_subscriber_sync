import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/subscriber_model.dart';
import '../../../models/sync_qr_payload.dart';
import '../../../network/direct_backup_service.dart';

class SecureSyncDialog extends StatefulWidget {
  final List<Subscriber> subscribers;
  final Function(List<Subscriber>) onSyncComplete;

  const SecureSyncDialog({
    super.key,
    required this.subscribers,
    required this.onSyncComplete,
  });

  @override
  State<SecureSyncDialog> createState() => _SecureSyncDialogState();
}

class _SecureSyncDialogState extends State<SecureSyncDialog> {
  late final DirectBackupSender _sender;

  String? _generatedPin;
  bool _isSessionExpired = false;
  int _countdownSeconds = DirectBackupSender.sessionTimeoutSeconds;
  Timer? _tickerTimer;

  bool _showQrCode = true;
  String _localIp = '0.0.0.0';

  @override
  void initState() {
    super.initState();
    _fetchLocalIp();
    _initSender();
    _startOrRenewSession();
  }

  Future<void> _fetchLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        setState(() {
          _localIp = interfaces.first.addresses.first.address;
        });
      }
    } catch (_) {}
  }

  void _initSender() {
    _sender = DirectBackupSender(
      onSuccess: () {
        _stopCountdown();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اكتملت المزامنة بنجاح وتم إغلاق الخادم.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      },
      onBreachDetected: (ip) {
        _stopCountdown();
      },
      onSessionExpired: () async {
        _stopCountdown();
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();

        if (mounted) {
          setState(() {
            _isSessionExpired = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _stopCountdown();
    _sender.stop();
    super.dispose();
  }

  void _stopCountdown() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void _startCountdown() {
    _stopCountdown();
    setState(() {
      _countdownSeconds = DirectBackupSender.sessionTimeoutSeconds;
      _isSessionExpired = false;
    });

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _stopCountdown();
        }
      });
    });
  }

  Future<void> _startOrRenewSession() async {
    _startCountdown();
    final newPin = await _sender.startSecureSharing(subscribers: widget.subscribers);

    if (mounted) {
      setState(() {
        _generatedPin = newPin;
        _isSessionExpired = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi_tethering, color: Colors.teal),
          SizedBox(width: 8),
          Text('المزامنة المباشرة المؤمنة'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSessionExpired) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.timer_off_outlined, size: 48, color: Colors.orange.shade800),
                    const SizedBox(height: 8),
                    const Text('انتهت مهلة الجلسة (60 ثانية)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'تم إغلاق المنفذ لحماية الشبكة لعدم وجود اتصال.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('توليد رمز جديد وإعادة الفتح'),
                onPressed: _startOrRenewSession,
              ),
            ] else if (_generatedPin != null) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('رمز QR'), icon: Icon(Icons.qr_code)),
                  ButtonSegment(value: false, label: Text('رمز PIN'), icon: Icon(Icons.pin)),
                ],
                selected: {_showQrCode},
                onSelectionChanged: (set) => setState(() => _showQrCode = set.first),
              ),
              const SizedBox(height: 16),
              if (_showQrCode) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200, width: 2),
                  ),
                  child: QrImageView(
                    data: SyncQrPayload(
                      ip: _localIp,
                      port: DirectBackupSender.port,
                      pin: _generatedPin!,
                      validSeconds: _countdownSeconds,
                    ).toJsonString(),
                    version: QrVersions.auto,
                    size: 180.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('امسح الرمز بكاميرا الهاتف الآخر للربط', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal, width: 2),
                  ),
                  child: Text(
                    _generatedPin!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('عنوان IP: $_localIp', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_bottom, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'الوقت المتبقي: $_countdownSeconds ثانية',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _countdownSeconds <= 10 ? Colors.red : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _countdownSeconds / DirectBackupSender.sessionTimeoutSeconds,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _countdownSeconds <= 10 ? Colors.red : Colors.teal,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('تغيير الرمز وتمديد الوقت'),
                onPressed: _startOrRenewSession,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _sender.stop();
            Navigator.pop(context);
          },
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
