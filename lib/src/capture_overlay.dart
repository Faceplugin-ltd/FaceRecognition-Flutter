import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'capture_logic.dart';
import 'face_box.dart';

/// Capture overlay animation / guide modes (Android `CaptureView` / RN `CaptureOverlay`).
enum CaptureViewMode {
  noFacePrepare,
  repeatNoFacePrepare,
  toFaceCircle,
  faceCircleToNoFace,
  faceCircle,
  faceCapturePrepare,
  faceCaptureDone,
}

/// Android `CaptureView` / RN `CaptureOverlay` — oval guide, tick marks, pose guides.
class CaptureOverlay extends StatelessWidget {
  const CaptureOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.frame,
    required this.mirror,
    required this.viewMode,
    required this.scale,
    this.mirrorCapturedPreview = false,
    this.faceBox,
    this.capturedUri,
  });

  final double width;
  final double height;
  final FrameSize frame;
  /// Pose-guide yaw mirror (front camera on Flutter preview).
  final bool mirror;
  final CaptureViewMode viewMode;
  final double scale;
  /// Horizontal flip for the done-state face circle only (display).
  final bool mirrorCapturedPreview;
  final FaceBox? faceBox;
  final String? capturedUri;

  static const _onTertiary = Color(0xFF492532);

  @override
  Widget build(BuildContext context) {
    final safeFrame =
        frame.w > 0 && frame.h > 0 ? frame : const FrameSize(720, 1280);
    final roi = mapRoiToView(safeFrame, width, height);
    final done = viewMode == CaptureViewMode.faceCaptureDone;
    final doneLift =
        done ? (width / 5 - roi.top) * scale.clamp(0.0, 1.0) : 0.0;
    final doneScale = done ? 0.8 : 1.0;
    final doneSize = roi.width * doneScale;

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: _CaptureOverlayPainter(
            frame: safeFrame,
            mirror: mirror,
            viewMode: viewMode,
            scale: scale,
            faceBox: faceBox,
          ),
        ),
        if (done && capturedUri != null && capturedUri!.isNotEmpty)
          Positioned(
            left: roi.centerX - doneSize / 2,
            top: roi.centerY - doneSize / 2 + doneLift,
            width: doneSize,
            height: doneSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _onTertiary, width: 8),
                color: Colors.black,
              ),
              child: ClipOval(
                child: Transform(
                  alignment: Alignment.center,
                  transform: mirrorCapturedPreview
                      ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
                      : Matrix4.identity(),
                  child: _CapturedImage(uri: capturedUri!),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CapturedImage extends StatelessWidget {
  const _CapturedImage({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    if (uri.startsWith('file://') || uri.startsWith('/')) {
      final path =
          uri.startsWith('file://') ? Uri.parse(uri).toFilePath() : uri;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return Image.network(
      uri,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}

class _CaptureOverlayPainter extends CustomPainter {
  _CaptureOverlayPainter({
    required this.frame,
    required this.mirror,
    required this.viewMode,
    required this.scale,
    required this.faceBox,
  });

  final FrameSize frame;
  final bool mirror;
  final CaptureViewMode viewMode;
  final double scale;
  final FaceBox? faceBox;

  static const _onPrimary = Color(0xFFEADDFF);
  static const _onSurface = Color(0xFFE6E1E5);
  static const _onTertiary = Color(0xFF492532);

  bool get _showCorners =>
      viewMode == CaptureViewMode.noFacePrepare ||
      viewMode == CaptureViewMode.repeatNoFacePrepare ||
      viewMode == CaptureViewMode.toFaceCircle ||
      viewMode == CaptureViewMode.faceCircleToNoFace;

  bool get _showCircle =>
      viewMode == CaptureViewMode.faceCircle ||
      viewMode == CaptureViewMode.faceCapturePrepare ||
      viewMode == CaptureViewMode.faceCaptureDone ||
      (viewMode == CaptureViewMode.toFaceCircle && scale < 1) ||
      viewMode == CaptureViewMode.faceCircleToNoFace;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.w <= 0 || frame.h <= 0) return;
    final roi = mapRoiToView(frame, size.width, size.height);
    final cx = roi.centerX;
    final cy = roi.centerY;

    final cornerScale =
        viewMode == CaptureViewMode.noFacePrepare ||
                viewMode == CaptureViewMode.repeatNoFacePrepare ||
                (viewMode == CaptureViewMode.toFaceCircle && scale > 1)
            ? scale
            : 1.0;

    final rw = math.max(1.0, roi.width * cornerScale);
    final rh = math.max(1.0, roi.height * cornerScale);
    final left = cx - rw / 2;
    final top = cy - rh / 2;
    final right = cx + rw / 2;
    final bottom = cy + rh / 2;

    var lineWidth = rw / 5;
    var lineHeight = rh / 5;
    var lineWidthOffset = 0.0;
    var lineHeightOffset = 0.0;
    var quadR = math.max(8.0, rw / 12);
    if (viewMode == CaptureViewMode.faceCircle ||
        (viewMode == CaptureViewMode.toFaceCircle && scale < 1) ||
        viewMode == CaptureViewMode.faceCircleToNoFace) {
      final t = scale.clamp(0.0, 1.0);
      lineWidth *= t;
      lineHeight *= t;
      lineWidthOffset = (rw / 2) * (1 - t);
      lineHeightOffset = (rh / 2) * (1 - t);
      quadR = math.max(8.0, rw / 12 + (rw / 2 - rw / 12) * (1 - t) - 20);
    }

    final cornerAlpha =
        viewMode == CaptureViewMode.noFacePrepare ||
                (viewMode == CaptureViewMode.toFaceCircle && scale > 1)
            ? ((1.4 - scale) / 0.4).clamp(0.0, 1.0)
            : 1.0;

    final scrimAlpha = viewMode == CaptureViewMode.faceCircleToNoFace
        ? (1 - scale.clamp(0.0, 1.0))
        : (_showCircle ? 1.0 : 0.0);

    if (_showCircle && scrimAlpha > 0) {
      _paintScrim(canvas, size, cx, cy, roi, scrimAlpha);
    }

    if (_showCorners) {
      _paintCorners(
        canvas,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        lineWidth: lineWidth,
        lineHeight: lineHeight,
        lineWidthOffset: lineWidthOffset,
        lineHeightOffset: lineHeightOffset,
        quadR: quadR,
        alpha: cornerAlpha,
      );
    }

    if (viewMode == CaptureViewMode.faceCircle) {
      _paintTicks(canvas, roi);
      if (faceBox != null) {
        _paintPoseGuides(canvas, roi, faceBox!);
      }
    }

    if (viewMode == CaptureViewMode.faceCapturePrepare) {
      canvas.drawCircle(
        Offset(cx, cy),
        (roi.width / 2) * 1.04,
        Paint()..color = _onTertiary,
      );
    }
  }

  void _paintScrim(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    RoiRect roi,
    double scrimAlpha,
  ) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());

    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        const Color(0xFF1C1B1F).withValues(alpha: scrimAlpha),
        Colors.black.withValues(alpha: scrimAlpha),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);

    if (viewMode != CaptureViewMode.faceCaptureDone) {
      final holeRadius = _holeRadius(roi);
      canvas.drawCircle(
        Offset(cx, cy),
        math.max(1.0, holeRadius),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();
  }

  double _holeRadius(RoiRect roi) {
    if (viewMode == CaptureViewMode.faceCapturePrepare) {
      final prepareScale = math.max(0.01, 1 - scale.clamp(0.0, 1.0));
      return (roi.width / 2) * prepareScale;
    }
    if (viewMode == CaptureViewMode.toFaceCircle ||
        viewMode == CaptureViewMode.faceCircleToNoFace) {
      final start = (0.8 * roi.width * 0.5) / math.cos(45 * math.pi / 180);
      return (roi.width / 2) * (1 - scale) + start * scale;
    }
    return roi.width / 2;
  }

  void _paintCorners(
    Canvas canvas, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double lineWidth,
    required double lineHeight,
    required double lineWidthOffset,
    required double lineHeightOffset,
    required double quadR,
    required double alpha,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = _onPrimary.withValues(alpha: alpha);

    canvas.drawPath(
      Path()
        ..moveTo(left, top + lineHeight + lineHeightOffset)
        ..lineTo(left, top + quadR)
        ..arcToPoint(Offset(left + quadR, top), radius: Radius.circular(quadR))
        ..lineTo(left + lineWidth + lineWidthOffset, top),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right, top + lineHeight + lineHeightOffset)
        ..lineTo(right, top + quadR)
        ..arcToPoint(Offset(right - quadR, top),
            radius: Radius.circular(quadR), clockwise: false)
        ..lineTo(right - lineWidth - lineWidthOffset, top),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right, bottom - lineHeight - lineHeightOffset)
        ..lineTo(right, bottom - quadR)
        ..arcToPoint(Offset(right - quadR, bottom),
            radius: Radius.circular(quadR))
        ..lineTo(right - lineWidth - lineWidthOffset, bottom),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - lineHeight - lineHeightOffset)
        ..lineTo(left, bottom - quadR)
        ..arcToPoint(Offset(left + quadR, bottom),
            radius: Radius.circular(quadR), clockwise: false)
        ..lineTo(left + lineWidth + lineWidthOffset, bottom),
      paint,
    );
  }

  void _paintTicks(Canvas canvas, RoiRect roi) {
    final cx = roi.centerX;
    final cy = roi.centerY;
    final paint = Paint()
      ..strokeWidth = 8
      ..color = _onSurface;
    final a1 = roi.width / 2 + 10;
    final b1 = roi.height / 2 + 10;
    final a2 = roi.width / 2 + 40;
    final b2 = roi.height / 2 + 40;

    for (var i = 0; i < 360; i += 5) {
      final th = i * math.pi / 180;
      final tan = math.tan(th);
      final den1 = math.sqrt(b1 * b1 + a1 * a1 * tan * tan);
      final den2 = math.sqrt(b2 * b2 + a2 * a2 * tan * tan);
      if (!den1.isFinite || !den2.isFinite || den1 == 0 || den2 == 0) continue;

      var x1 = (a1 * b1) / den1;
      var x2 = (a2 * b2) / den2;
      final ratio = 1 - (x1 / a1) * (x1 / a1);
      if (ratio < 0 || !ratio.isFinite) continue;
      var y1 = math.sqrt(ratio) * b1;
      var y2 = math.sqrt(ratio) * b2;

      final mod = i % 360;
      if (mod > 90 && mod < 270) {
        x1 = -x1;
        x2 = -x2;
      }
      if (mod > 180 && mod < 360) {
        y1 = -y1;
        y2 = -y2;
      }
      if (![x1, y1, x2, y2].every((v) => v.isFinite)) continue;

      canvas.drawLine(
        Offset(cx + x1, cy - y1),
        Offset(cx + x2, cy - y2),
        paint,
      );
    }
  }

  void _paintPoseGuides(Canvas canvas, RoiRect roi, FaceBox box) {
    final yaw = mirror ? (box.yaw ?? 0) : -(box.yaw ?? 0);
    final pitch = -(box.pitch ?? 0);
    final cx = roi.centerX;
    final cy = roi.centerY;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = _onPrimary.withValues(alpha: 0.5);

    final yawPath = Path()
      ..moveTo(cx, roi.top)
      ..quadraticBezierTo(
        cx - roi.width * math.sin(yaw * math.pi / 180),
        cy,
        cx,
        roi.bottom,
      )
      ..quadraticBezierTo(
        cx - (roi.width * math.sin(yaw * math.pi / 180)) / 3,
        cy,
        cx,
        roi.top,
      );
    canvas.drawPath(yawPath, paint);

    final pitchPath = Path()
      ..moveTo(roi.left, cy)
      ..quadraticBezierTo(
        cx,
        cy + roi.width * math.sin(pitch * math.pi / 180),
        roi.right,
        cy,
      )
      ..quadraticBezierTo(
        cx,
        cy + (roi.width * math.sin(pitch * math.pi / 180)) / 3,
        roi.left,
        cy,
      );
    canvas.drawPath(pitchPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CaptureOverlayPainter oldDelegate) {
    return oldDelegate.viewMode != viewMode ||
        oldDelegate.scale != scale ||
        oldDelegate.faceBox != faceBox ||
        oldDelegate.frame.w != frame.w ||
        oldDelegate.frame.h != frame.h ||
        oldDelegate.mirror != mirror;
  }
}
