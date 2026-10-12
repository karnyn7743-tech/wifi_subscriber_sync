import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging/sync_audit_logger.dart';
import '../../models/subscriber_model.dart';

enum RouterBrand {
  tpLink,
  tenda,
  genericHttp,
}

abstract class RouterDriver {
  Future<bool> testConnection();
  Future<bool> allowDevice(String macAddress, {String? label});
  Future<bool> blockDevice(String macAddress);
  Future<bool> removeDevice(String macAddress);
  Future<List<String>> getConnectedMacAddresses();
}

/// محرك التحكم بأجهزة TP-Link (سواء راوتر رئيسي أو أنتينا)
class TpLinkDriver implements RouterDriver {
  final String ip;
  final String username;
  final String password;
  String? _sessionToken;

  TpLinkDriver({
    required this.ip,
    required this.username,
    required this.password,
  });

  String get _baseUrl => 'http://$ip';

  Future<bool> _login() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/login'));
      
      final authPayload = base64Encode(utf8.encode('$username:$password'));
      request.headers.set('Authorization', 'Basic $authPayload');
      request.headers.contentType = ContentType.json;

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        _sessionToken = json['token'] as String? ?? 'authenticated';
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> testConnection() async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> allowDevice(String macAddress, {String? label}) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/admin/mac_filter/add'));
      
      request.headers.set('X-Token', _sessionToken ?? '');
      request.headers.contentType = ContentType.json;
      
      request.write(jsonEncode({
        'mac': normalized,
        'action': 'allow',
        'description': label ?? 'Authorized_Subscriber',
      }));

      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> blockDevice(String macAddress) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/admin/mac_filter/block'));
      
      request.headers.set('X-Token', _sessionToken ?? '');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'mac': normalized}));

      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeDevice(String macAddress) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.deleteUrl(Uri.parse('$_baseUrl/admin/mac_filter?mac=$normalized'));
      
      request.headers.set('X-Token', _sessionToken ?? '');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getConnectedMacAddresses() async {
    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('$_baseUrl/admin/wireless_clients'));
      request.headers.set('X-Token', _sessionToken ?? '');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final clients = json['clients'] as List<dynamic>? ?? [];
        return clients.map((c) => c['mac'].toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}

/// محرك التحكم بأجهزة Tenda (أنتينات ونقاط وصول)
class TendaDriver implements RouterDriver {
  final String ip;
  final String password;
  String? _cookie;

  TendaDriver({
    required this.ip,
    required this.password,
  });

  String get _baseUrl => 'http://$ip';

  Future<bool> _login() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/login/Auth'));
      request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');

      final body = 'password=${Uri.encodeComponent(password)}';
      request.write(body);

      final response = await request.close();
      if (response.statusCode == 200) {
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          _cookie = cookies.first.split(';').first;
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> testConnection() async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> allowDevice(String macAddress, {String? label}) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/goform/wifiFilterSet'));
      
      if (_cookie != null) request.headers.set('Cookie', _cookie!);
      request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
      
      request.write('action=add&filterType=white&mac=$normalized');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> blockDevice(String macAddress) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/goform/wifiFilterSet'));
      
      if (_cookie != null) request.headers.set('Cookie', _cookie!);
      request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
      
      request.write('action=add&filterType=black&mac=$normalized');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeDevice(String macAddress) async {
    final normalized = Subscriber.normalizeMac(macAddress);
    if (normalized == null) return false;

    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(Uri.parse('$_baseUrl/goform/wifiFilterSet'));
      
      if (_cookie != null) request.headers.set('Cookie', _cookie!);
      request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
      
      request.write('action=del&mac=$normalized');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getConnectedMacAddresses() async {
    try {
      await _login();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('$_baseUrl/goform/getOnlineList'));
      if (_cookie != null) request.headers.set('Cookie', _cookie!);

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as List<dynamic>? ?? [];
        return json.map((e) => e['mac'].toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}

/// مدير التنسيق العام والوسيط بين واجهات التطبيق وأجهزة الشبكة
class UnifiedRouterManager {
  static const String _prefRouterIpKey = 'router_cfg_ip';
  static const String _prefRouterUserKey = 'router_cfg_user';
  static const String _prefRouterPassKey = 'router_cfg_pass';
  static const String _prefRouterBrandKey = 'router_cfg_brand';
  static const String _prefRouterSyncEnabledKey = 'router_cfg_sync_enabled';

  static RouterDriver? _currentDriver;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isSyncEnabled = prefs.getBool(_prefRouterSyncEnabledKey) ?? false;
    if (!isSyncEnabled) return;

    final ip = prefs.getString(_prefRouterIpKey) ?? '192.168.0.1';
    final user = prefs.getString(_prefRouterUserKey) ?? 'admin';
    final pass = prefs.getString(_prefRouterPassKey) ?? 'admin';
    final brandIndex = prefs.getInt(_prefRouterBrandKey) ?? 0;
    final brand = RouterBrand.values[brandIndex.clamp(0, RouterBrand.values.length - 1)];

    switch (brand) {
      case RouterBrand.tpLink:
        _currentDriver = TpLinkDriver(ip: ip, username: user, password: pass);
        break;
      case RouterBrand.tenda:
      case RouterBrand.genericHttp:
        _currentDriver = TendaDriver(ip: ip, password: pass);
        break;
    }
  }

  static Future<void> saveSettings({
    required String ip,
    required String username,
    required String password,
    required RouterBrand brand,
    required bool isSyncEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRouterIpKey, ip.trim());
    await prefs.setString(_prefRouterUserKey, username.trim());
    await prefs.setString(_prefRouterPassKey, password.trim());
    await prefs.setInt(_prefRouterBrandKey, brand.index);
    await prefs.setBool(_prefRouterSyncEnabledKey, isSyncEnabled);

    await init();
  }

  /// تطبيق التغيير على الراوتر تلقائياً عند تعديل المشترك
  static Future<void> syncSubscriberStatus(Subscriber subscriber) async {
    if (_currentDriver == null || subscriber.macAddress == null) return;

    final mac = subscriber.macAddress!;
    if (subscriber.isPaid) {
      final success = await _currentDriver!.allowDevice(mac, label: subscriber.fullName);
      await SyncAuditLogger.log(
        eventType: 'ROUTER_SYNC_ALLOW',
        targetIp: mac,
        details: 'تم تفريغ السماح بالماك في الراوتر لـ ${subscriber.fullName}',
        isSuccess: success,
      );
    } else {
      final success = await _currentDriver!.blockDevice(mac);
      await SyncAuditLogger.log(
        eventType: 'ROUTER_SYNC_BLOCK',
        targetIp: mac,
        details: 'تم حظر الماك في الراوتر لـ ${subscriber.fullName}',
        isSuccess: success,
      );
    }
  }

  /// حذف الماك من الراوتر نهائياً عند حذف المشترك
  static Future<void> removeSubscriberMac(String? macAddress) async {
    if (_currentDriver == null || macAddress == null) return;
    await _currentDriver!.removeDevice(macAddress);
  }

  /// اختبار الاتصال الحالي بالبوابة المحددة
  static Future<bool> testCurrentConnection() async {
    if (_currentDriver == null) return false;
    return await _currentDriver!.testConnection();
  }
}
