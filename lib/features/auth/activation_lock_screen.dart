import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/app_license_service.dart';
import '../admin/subscribers_admin_screen.dart';

class ActivationLockScreen extends StatefulWidget {
  const ActivationLockScreen({super.key});

  @override
  State<ActivationLockScreen> createState() => _ActivationLockScreenState();
}

class _ActivationLockScreenState extends State<ActivationLockScreen> {
  final _keyController = TextEditingController();
  String _fingerprint = 'جاري القراءة...';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFingerprint();
  }

  Future<void> _loadFingerprint() async {
    final fp = await AppLicenseService.getDeviceFingerprint();
    if (mounted) {
      setState(() {
        _fingerprint = fp;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAndActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال مفتاح التنشيط');
      return;
    }

    final success = await AppLicenseService.activateApp(key);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تنشيط التطبيق بنجاح!'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => const SubscribersAdminScreen()),
      );
    } else {
      setState(() {
        _errorMessage = 'مفتاح التنشيط غير صحيح لهذا الجهاز!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('تنشيط ترخيص التطبيق'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'نظام إدارة الشبكة والمشتركين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'هذا التطبيق مخصص لمشرفي الشبكات ومحمي برخصة استخدام. شارك معرّف جهازك للحصول على المفتاح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('معرف جهازك الدائم:', style: TextStyle(fontSize: 11, color: Colors.teal)),
                            const SizedBox(height: 4),
                            Text(
                              _fingerprint,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.teal),
                          tooltip: 'نسخ المعرف',
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: _fingerprint));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ المعرّف للحافظة')),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _keyController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      labelText: 'مفتاح التنشيط',
                      hintText: 'ACT-XXXX-XXXX-XXXX',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key),
                      errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _verifyAndActivate,
                    child: const Text('تنشيط التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
