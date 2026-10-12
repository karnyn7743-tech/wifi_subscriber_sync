import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../network/router/router_service.dart';

class RouterSettingsDialog extends StatefulWidget {
  const RouterSettingsDialog({super.key});

  @override
  State<RouterSettingsDialog> createState() => _RouterSettingsDialogState();
}

class _RouterSettingsDialogState extends State<RouterSettingsDialog> {
  static const String _prefRouterIpKey = 'router_cfg_ip';
  static const String _prefRouterUserKey = 'router_cfg_user';
  static const String _prefRouterPassKey = 'router_cfg_pass';
  static const String _prefRouterBrandKey = 'router_cfg_brand';
  static const String _prefRouterSyncEnabledKey = 'router_cfg_sync_enabled';

  final _ipController = TextEditingController(text: '192.168.0.1');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController(text: 'admin');

  RouterBrand _selectedBrand = RouterBrand.tpLink;
  bool _isSyncEnabled = false;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString(_prefRouterIpKey) ?? '192.168.0.1';
      _userController.text = prefs.getString(_prefRouterUserKey) ?? 'admin';
      _passController.text = prefs.getString(_prefRouterPassKey) ?? 'admin';
      _isSyncEnabled = prefs.getBool(_prefRouterSyncEnabledKey) ?? false;
      final brandIdx = prefs.getInt(_prefRouterBrandKey) ?? 0;
      _selectedBrand = RouterBrand.values[brandIdx.clamp(0, RouterBrand.values.length - 1)];
    });
  }

  Future<void> _saveSettings() async {
    await UnifiedRouterManager.saveSettings(
      ip: _ipController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text.trim(),
      brand: _selectedBrand,
      isSyncEnabled: _isSyncEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات الراوتر وتحديث وسيط الشبكة بنجاح'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // حفظ مؤقت لتجربة السائق المحدد
    await UnifiedRouterManager.saveSettings(
      ip: _ipController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text.trim(),
      brand: _selectedBrand,
      isSyncEnabled: true,
    );

    final ok = await UnifiedRouterManager.testCurrentConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = ok;
        _testResult = ok
            ? 'تم الاتصال بالبوابة (${_ipController.text}) بنجاح! الروتر يستجيب.'
            : 'فشل الاتصال: تأكد من عنوان الـ IP والاتصال بنفس شبكة الواي فاي.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.router, color: Colors.teal),
          SizedBox(width: 8),
          Text('إعدادات الراوتر الخارجي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل التحكم التلقائي بالراوتر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('مزامنة الحظر والسماح فورياً عبر MAC Address', style: TextStyle(fontSize: 12)),
              value: _isSyncEnabled,
              activeColor: Colors.teal,
              onChanged: (val) => setState(() => _isSyncEnabled = val),
            ),
            const Divider(),
            const SizedBox(height: 8),
            DropdownButtonFormField<RouterBrand>(
              value: _selectedBrand,
              decoration: const InputDecoration(
                labelText: 'نوع الراوتر / الأنتينا',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.device_hub),
              ),
              items: const [
                DropdownMenuItem(
                  value: RouterBrand.tpLink,
                  child: Text('TP-Link (Router / CPE / AP)'),
                ),
                DropdownMenuItem(
                  value: RouterBrand.tenda,
                  child: Text('Tenda (Router / Nova / O3 / AP)'),
                ),
                DropdownMenuItem(
                  value: RouterBrand.genericHttp,
                  child: Text('بوابة HTTP عامة'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedBrand = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'عنوان IP للبوابة (Gateway IP)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
                hintText: '192.168.0.1 أو 192.168.1.1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم (User)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة مرور لوحة التحكم',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: _isTesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check),
              label: Text(_isTesting ? 'جاري الفحص...' : 'اختبار الاتصال بالبوابة'),
              onPressed: _isTesting ? null : _testConnection,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _testSuccess == true ? Colors.green : Colors.red),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testSuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          onPressed: _saveSettings,
          child: const Text('حفظ الإعدادات'),
        ),
      ],
    );
  }
}
