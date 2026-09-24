import 'package:flutter/material.dart';

class QrScannerOverlay extends StatefulWidget {
  final double scanAreaSize;
  final Color cornerColor;
  final Color laserColor;

  const QrScannerOverlay({
    super.key,
    this.scanAreaSize = 260.0,
    this.cornerColor = Colors.teal,
    this.laserColor = Colors.tealAccent,
  });

  @override
  State<QrScannerOverlay> createState() => _QrScannerOverlayState();
}

class _QrScannerOverlayState extends State<QrScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _laserAnimation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerPainter(
            scanAreaSize: widget.scanAreaSize,
            cornerColor: widget.cornerColor,
            laserColor: widget.laserColor,
            laserProgress: _laserAnimation.value,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double scanAreaSize;
  final Color cornerColor;
  final Color laserColor;
  final double laserProgress;

  _ScannerPainter({
    required this.scanAreaSize,
    required this.cornerColor,
    required this.laserColor,
    required this.laserProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanWindowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));

    final cutOutPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanWindowPath,
    );

    canvas.drawPath(
      cutOutPath,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), cornerPaint);

    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), cornerPaint);

    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLength), cornerPaint);

    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLength), cornerPaint);

    final laserY = rect.top + (rect.height * laserProgress);
    final laserStart = Offset(rect.left + 8, laserY);
    final laserEnd = Offset(rect.right - 8, laserY);

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          laserColor.withValues(alpha: 0.0),
          laserColor.withValues(alpha: 0.5),
          laserColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(laserStart, laserEnd))
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(laserStart, laserEnd, glowPaint);

    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(laserStart, laserEnd, corePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress ||
        oldDelegate.cornerColor != cornerColor ||
        oldDelegate.laserColor != laserColor;
  }
}

