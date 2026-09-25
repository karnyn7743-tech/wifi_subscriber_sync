import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/subscriber_model.dart';
import '../../models/sync_diff_report.dart';
import '../../models/sync_qr_payload.dart';
import '../../network/direct_backup_service.dart';
import '../admin/widgets/sync_summary_bottom_sheet.dart';
import 'scanner_feedback_service.dart';
import 'widgets/qr_scanner_overlay.dart';

class SyncQrScannerScreen extends StatefulWidget {
  final List<Subscriber> currentList;
  final Function(List<Subscriber>) onSyncComplete;

  const SyncQrScannerScreen({
    super.key,
    required this.currentList,
    required this.onSyncComplete,
  });

  @override
  State<SyncQrScannerScreen> createState() => _SyncQrScannerScreenState();
}

class _SyncQrScannerScreenState extends State<SyncQrScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late final AnimationController _flashAnimController;
  late final Animation<double> _flashAnimation;

  bool _isProcessing = false;
  String? _lastScannedPayload;
  DateTime? _lastScanTimestamp;

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  double _currentZoom = 0.0;
  double _baseZoom = 0.0;
  bool _hasHitMaxZoom = false;
  bool _hasHitMinZoom = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _flashAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 0.75).animate(
      CurvedAnimation(parent: _flashAnimController, curve: Curves.easeOutQuad),
    );
  }

  Future<void> _loadSettings() async {
    await ScannerFeedbackService.init();
    if (mounted) {
      setState(() {
        _soundEnabled = ScannerFeedbackService.isSoundEnabled;
        _vibrationEnabled = ScannerFeedbackService.isVibrationEnabled;
      });
    }
  }

  @override
  void dispose() {
    _flashAnimController.dispose();
    ScannerFeedbackService.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setZoom(double value) {
    if (value >= 1.0) {
      if (!_hasHitMaxZoom) {
        HapticFeedback.lightImpact();
        _hasHitMaxZoom = true;
      }
    } else {
      _hasHitMaxZoom = false;
    }

    if (value <= 0.0) {
      if (!_hasHitMinZoom) {
        HapticFeedback.lightImpact();
        _hasHitMinZoom = true;
      }
    } else {
      _hasHitMinZoom = false;
    }

    final clamped = value.clamp(0.0, 1.0);
    setState(() => _currentZoom = clamped);
    _controller.setZoomScale(clamped);
  }

  void _handleDoubleTapZoom() {
    if (_isProcessing) return;
    final targetZoom = _currentZoom < 0.2 ? 0.35 : 0.0;
    _setZoom(targetZoom);
    HapticFeedback.selectionClick();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
    _hasHitMaxZoom = _currentZoom >= 1.0;
    _hasHitMinZoom = _currentZoom <= 0.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isProcessing) return;
    final newZoom = (_baseZoom + (details.scale - 1.0) * 0.5).clamp(0.0, 1.0);
    _setZoom(newZoom);
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    if (_lastScanTimestamp != null &&
        now.difference(_lastScanTimestamp!) < const Duration(milliseconds: 1200)) {
      return;
    }

    final validBarcodes = capture.barcodes.where((b) {
      return b.rawValue != null && b.rawValue!.contains('DIRECT_SYNC_PAYLOAD');
    }).toList();

    if (validBarcodes.isEmpty) return;

    final chosenBarcode = validBarcodes.length == 1
        ? validBarcodes.first
        : _findClosestToCenter(validBarcodes, MediaQuery.of(context).size);

    final rawPayload = chosenBarcode.rawValue!;
    if (_lastScannedPayload == rawPayload) return;

    ScannerFeedbackService.triggerScanFeedback();

    _flashAnimController.forward().then((_) {
      if (mounted) _flashAnimController.reverse();
    });

    await _controller.stop();

    setState(() {
      _isProcessing = true;
      _lastScannedPayload = rawPayload;
      _lastScanTimestamp = now;
    });

    final payload = SyncQrPayload.fromJsonString(rawPayload);
    if (payload == null) {
      _resetScannerState();
      return;
    }

    try {
      final incomingSubscribers = await DirectBackupReceiver.fetchRawSubscribersWithPin(
        senderIp: payload.ip,
        port: payload.port,
        pin: payload.pin,
      );

      if (!mounted) return;

      if (incomingSubscribers != null) {
        final diffReport = SyncDiffReport.compute(
          localList: widget.currentList,
          incomingList: incomingSubscribers,
        );

        final bool? isConfirmed = await SyncSummaryBottomSheet.show(
          context,
          report: diffReport,
        );

        if (!mounted) return;

        if (isConfirmed == true) {
          widget.onSyncComplete(diffReport.finalMergedList);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم اعتماد الدمج بنجاح! (+${diffReport.newSubscribers.length} جديد، ${diffReport.updatedSubscribers.length} معدل)',
              ),
              backgroundColor: Colors.teal,
            ),
          );
        } else {
          _resetScannerState();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red),
        );
        _resetScannerState();
      }
    }
  }

  Barcode _findClosestToCenter(List<Barcode> barcodes, Size screenSize) {
    final screenCenter = Point(screenSize.width / 2, screenSize.height / 2);
    Barcode closest = barcodes.first;
    double minDistance = double.infinity;

    for (final barcode in barcodes) {
      final corners = barcode.corners;
      if (corners.isNotEmpty) {
        double sumX = 0, sumY = 0;
        for (final pt in corners) {
          sumX += pt.dx;
          sumY += pt.dy;
        }
        final center = Point(sumX / corners.length, sumY / corners.length);
        final distance = center.distanceTo(screenCenter);

        if (distance < minDistance) {
          minDistance = distance;
          closest = barcode;
        }
      }
    }
    return closest;
  }

  void _resetScannerState() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _lastScannedPayload = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسح رمز مزامنة المشتركين'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _handleDoubleTapZoom,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          if (!_isProcessing)
            const IgnorePointer(
              child: QrScannerOverlay(
                scanAreaSize: 260.0,
                cornerColor: Colors.teal,
                laserColor: Colors.tealAccent,
              ),
            ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, _) {
                if (_flashAnimation.value == 0.0) return const SizedBox.shrink();
                return Container(
                  color: Colors.white.withValues(alpha: _flashAnimation.value),
                );
              },
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, _) {
                        final isTorchOn = state.torchState == TorchState.on;
                        return _buildControlCircle(
                          icon: isTorchOn ? Icons.flash_on : Icons.flash_off,
                          isActive: isTorchOn,
                          tooltip: 'تشغيل/إيقاف الفلاش',
                          onTap: () => _controller.toggleTorch(),
                        );
                      },
                    ),
                    _buildControlCircle(
                      icon: Icons.flip_camera_ios,
                      isActive: false,
                      tooltip: 'تبديل الكاميرا',
                      onTap: () => _controller.switchCamera(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildControlCircle(
                      icon: _soundEnabled ? Icons.volume_up : Icons.volume_off,
                      isActive: _soundEnabled,
                      tooltip: _soundEnabled ? 'كتم صوت الصافرة' : 'تفعيل صوت الصافرة',
                      onTap: () async {
                        final newState = !_soundEnabled;
                        await ScannerFeedbackService.toggleSound(newState);
                        setState(() => _soundEnabled = newState);
                      },
                    ),
                    _buildControlCircle(
                      icon: _vibrationEnabled ? Icons.vibration : Icons.mobile_off,
                      isActive: _vibrationEnabled,
                      tooltip: _vibrationEnabled ? 'تعطيل الاهتزاز' : 'تفعيل الاهتزاز',
                      onTap: () async {
                        final newState = !_vibrationEnabled;
                        await ScannerFeedbackService.toggleVibration(newState);
                        setState(() => _vibrationEnabled = newState);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isProcessing)
            Positioned(
              bottom: 95,
              left: 0,
              right: 0,
              child: _buildZoomControl(),
            ),
          const Positioned(
            bottom: 35,
            left: 20,
            right: 20,
            child: Text(
              'استخدم إصبعين للتكبير أو انقر مرتين للتقريب • وجّه العدسة نحو QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade400, width: 1.5),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.tealAccent),
                      SizedBox(height: 16),
                      Text(
                        'تم قراءة الرمز بنجاح',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'جاري فك التشفير ومقارنة السجلات...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.tealAccent : Colors.white24,
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.tealAccent : Colors.white54, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildZoomControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          _buildZoomPresetButton(label: '1x', targetZoom: 0.0),
          const SizedBox(width: 4),
          _buildZoomPresetButton(label: '2x', targetZoom: 0.35),
          const SizedBox(width: 4),
          _buildZoomPresetButton(label: '3x', targetZoom: 0.70),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: Colors.tealAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.tealAccent,
              ),
              child: Slider(
                value: _currentZoom,
                min: 0.0,
                max: 1.0,
                onChanged: _isProcessing ? null : (val) => _setZoom(val),
              ),
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
        ],
      ),
    );
  }

  Widget _buildZoomPresetButton({required String label, required double targetZoom}) {
    final isSelected = (_currentZoom - targetZoom).abs() < 0.08;
    return InkWell(
      onTap: _isProcessing ? null : () => _setZoom(targetZoom),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
