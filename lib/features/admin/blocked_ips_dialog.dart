import 'package:flutter/material.dart';
import '../../core/security/biometric_auth_service.dart';
import '../../core/storage/persistent_ip_block_manager.dart';

class BlockedIpsDialog extends StatefulWidget {
  const BlockedIpsDialog({super.key});

  @override
  State<BlockedIpsDialog> createState() => _BlockedIpsDialogState();
}

class _BlockedIpsDialogState extends State<BlockedIpsDialog> {
  List<BlockedIpRecord> _blockedList = [];
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verifyBiometrics();
  }

  Future<void> _verifyBiometrics() async {
    final success = await BiometricAuthService.authenticate(
      reason: 'يرجى تأكيد البصمة لفتح قائمة العناوين المحظورة وإدارتها',
    );

    if (success) {
      final list = await PersistentIpBlockManager.getBlockedIps();
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _blockedList = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الوصول لعدم تأكيد الهوية')),
        );
      }
    }
  }

  Future<void> _unblock(String ip) async {
    await PersistentIpBlockManager.unblockIp(ip);
    final updated = await PersistentIpBlockManager.getBlockedIps();
    setState(() => _blockedList = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isAuthenticated) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gpp_bad, color: Colors.red),
          SizedBox(width: 8),
          Text('قائمة الأجهزة المحظورة'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _blockedList.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('لا توجد عناوين IP محظورة حالياً.', textAlign: TextAlign.center),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _blockedList.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _blockedList[index];
                  final isExpired = item.isExpired;
                  return ListTile(
                    dense: true,
                    title: Text(item.ip, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    subtitle: Text('${item.reason}\nالحظر حتى: ${item.expiresAt.toString().split('.').first}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.lock_open, color: Colors.teal),
                      tooltip: 'فك الحظر الآن',
                      onPressed: () => _unblock(item.ip),
                    ),
                    leading: Icon(
                      isExpired ? Icons.history : Icons.block,
                      color: isExpired ? Colors.grey : Colors.red,
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

