import 'package:flutter/material.dart';

import 'package:face_recognition_sdk/face_recognition_sdk.dart' hide livenessPassed, qualityText;
import '../../services/settings_service.dart';

/// Cyan track / green REAL / red SPOOF + landmarks + labels.
class FaceOverlay extends StatelessWidget {
  const FaceOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.frameW,
    required this.frameH,
    required this.mirror,
    required this.boxes,
    required this.settings,
  });

  final double width;
  final double height;
  final double frameW;
  final double frameH;
  final bool mirror;
  final List<FaceBox> boxes;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    if (frameW <= 0 || frameH <= 0) return const SizedBox.shrink();
    return CustomPaint(
      size: Size(width, height),
      painter: _FaceOverlayPainter(
        frameW: frameW,
        frameH: frameH,
        mirror: mirror,
        boxes: boxes,
        settings: settings,
      ),
    );
  }
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({
    required this.frameW,
    required this.frameH,
    required this.mirror,
    required this.boxes,
    required this.settings,
  });

  final double frameW;
  final double frameH;
  final bool mirror;
  final List<FaceBox> boxes;
  final AppSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final p1 = mapFramePoint(
        box.x1,
        box.y1,
        frameW,
        frameH,
        size.width,
        size.height,
        mirror,
      );
      final p2 = mapFramePoint(
        box.x2,
        box.y2,
        frameW,
        frameH,
        size.width,
        size.height,
        mirror,
      );
      final left = p1.x < p2.x ? p1.x : p2.x;
      final right = p1.x > p2.x ? p1.x : p2.x;
      final top = p1.y < p2.y ? p1.y : p2.y;
      final bottom = p1.y > p2.y ? p1.y : p2.y;
      final known = hasLiveness(box);
      final live = known &&
          livenessPassed(settings, box.liveness ?? 0, box.livenessLabel);
      final color = !known
          ? const Color(0xFF00FFFF)
          : live
              ? const Color(0xFF00FF00)
              : const Color(0xFFFF0000);

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color;
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), stroke);

      if (known) {
        final label = live ? 'REAL' : 'SPOOF';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(left, (top - tp.height - 4).clamp(0, size.height)));
      }

      final lm = box.landmarks ?? const <double>[];
      final n = (box.landmarkCount ?? (lm.length ~/ 2)).clamp(0, lm.length ~/ 2);
      final fill = Paint()..color = color;
      for (var i = 0; i < n; i++) {
        final pt = mapFramePoint(
          lm[i * 2],
          lm[i * 2 + 1],
          frameW,
          frameH,
          size.width,
          size.height,
          mirror,
        );
        canvas.drawCircle(Offset(pt.x, pt.y), 5, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.frameW != frameW ||
        oldDelegate.frameH != frameH ||
        oldDelegate.mirror != mirror;
  }
}
