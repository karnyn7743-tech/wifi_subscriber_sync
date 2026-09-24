import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/security/crypto_auth_service.dart';
import '../../core/storage/device_id_service.dart';

class DeviceQrView extends StatefulWidget {
  final String subscriberName;
  final bool isPaid;
  final String expiryDate;

  const DeviceQrView({
    super.key,
    required this.subscriberName,
    required this.isPaid,
    required this.expiryDate,
  });

  @override
  State<DeviceQrView> createState() => _DeviceQrViewState();
}

class _DeviceQrViewState extends State<DeviceQrView> {
  String? _qrPayload;
  String _deviceId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateDeviceLicense();
  }

  Future<void> _generateDeviceLicense() async {
    final id = await DeviceIdService.getPermanentDeviceId();
    final signedData = CryptoAuthService.generateSignedSubscriberQr(
      deviceId: id,
      fullName: widget.subscriberName,
      isPaid: widget.isPaid,
      expiryDate: widget.expiryDate,
    );

    if (mounted) {
      setState(() {
        _deviceId = id;
        _qrPayload = signedData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بطاقة هوية واشتراك الجهاز'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: _qrPayload!,
                        version: QrVersions.auto,
                        size: 240.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.subscriberName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isPaid ? Icons.check_circle : Icons.cancel,
                          color: widget.isPaid ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isPaid ? 'الاشتراك مفعل وساري' : 'الاشتراك غير مسدد',
                          style: TextStyle(
                            color: widget.isPaid ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'معرف الجهاز الثابت:\n$_deviceId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

