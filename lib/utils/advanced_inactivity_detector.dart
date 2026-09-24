import 'dart:async';
import 'package:flutter/material.dart';
import '../core/security/biometric_auth_service.dart';

class AdvancedInactivityDetector extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const AdvancedInactivityDetector({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
  });

  @override
  State<AdvancedInactivityDetector> createState() => _AdvancedInactivityDetectorState();
}

class _AdvancedInactivityDetectorState extends State<AdvancedInactivityDetector> {
  Timer? _inactivityTimer;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    if (_isLocked) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.timeout, _lockSession);
  }

  void _lockSession() {
    setState(() => _isLocked = true);
  }

  Future<void> _unlockSession() async {
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'تم قفل الجلسة لعدم النشاط، يرجى تأكيد البصمة للمتابعة',
    );

    if (authenticated && mounted) {
      setState(() {
        _isLocked = false;
      });
      _resetTimer();
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: Stack(
        children: [
          widget.child,
          if (_isLocked)
            Material(
              color: Colors.black.withValues(alpha: 0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, size: 72, color: Colors.tealAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'تم قفل الجلسة تلقائياً',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'لحماية سرية بيانات المشتركين تم قفل التطبيق بسبب الخمول.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('إلغاء القفل بالبصمة'),
                        onPressed: _unlockSession,
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
}

