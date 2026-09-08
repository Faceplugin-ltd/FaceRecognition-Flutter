import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/types.dart' show FaceBox;
import 'capture_logic.dart';

/// Oval coach view modes — FaceRecognitionSDK CaptureView / RN CaptureOverlay.
enum CaptureViewMode {
  noFacePrepare,
  repeatNoFacePrepare,
  toFaceCircle,
  faceCircleToNoFace,
  faceCircle,
  faceCapturePrepare,
  faceCaptureDone,
}

const _onPrimary = Color(0xFFEADDFF);
const _onSurface = Color(0xFFE6E1E5);
const _onTertiary = Color(0xFF492532);

/// Android CaptureView — oval guide, tick marks, pose guides, capture animations.
class CaptureOverlay extends StatefulWidget {
  const CaptureOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.frame,
    required this.mirror,
    required this.viewMode,
    required this.faceBox,
    this.capturedUri,
    this.onModeFinished,
  });

  final double width;
  final double height;
  final OvalMetrics frame;
  final bool mirror;
  final CaptureViewMode viewMode;
  final FaceBox? faceBox;
  final String? capturedUri;
  final ValueChanged<CaptureViewMode>? onModeFinished;

  @override
  State<CaptureOverlay> createState() => _CaptureOverlayState();
}

class _CaptureOverlayState extends State<CaptureOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _scale = 1.4;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, lowerBound: 0, upperBound: 2);
    _ctrl.addListener(() {
      if (mounted) setState(() => _scale = _ctrl.value);
    });
    _startForMode(widget.viewMode);
  }

  @override
  void didUpdateWidget(covariant CaptureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _startForMode(widget.viewMode);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() => widget.onModeFinished?.call(widget.viewMode);

  Future<void> _startForMode(CaptureViewMode mode) async {
    final gen = ++_gen;
    _ctrl.stop();
    switch (mode) {
      case CaptureViewMode.noFacePrepare:
        _ctrl.value = 1.4;
        await _ctrl.animateTo(
          0.88,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
        );
        if (mounted && gen == _gen && widget.viewMode == mode) _finish();
      case CaptureViewMode.repeatNoFacePrepare:
        _ctrl.value = 0.88;
        while (mounted &&
            gen == _gen &&
            widget.viewMode == CaptureViewMode.repeatNoFacePrepare) {
          await _ctrl.animateTo(
            0.92,
            duration: const Duration(milliseconds: 1300),
          );
          if (!mounted ||
              gen != _gen ||
              widget.viewMode != CaptureViewMode.repeatNoFacePrepare) {
            break;
          }
          await _ctrl.animateTo(
            0.88,
            duration: const Duration(milliseconds: 1300),
          );
        }
      case CaptureViewMode.toFaceCircle:
        _ctrl.value = 1.4;
        await _ctrl.animateTo(0, duration: const Duration(milliseconds: 800));
        if (mounted && gen == _gen && widget.viewMode == mode) _finish();
      case CaptureViewMode.faceCircleToNoFace:
        _ctrl.value = 0;
        await _ctrl.animateTo(1, duration: const Duration(milliseconds: 600));
        if (mounted && gen == _gen && widget.viewMode == mode) _finish();
      case CaptureViewMode.faceCapturePrepare:
        _ctrl.value = 0;
        await _ctrl.animateTo(1, duration: const Duration(milliseconds: 500));
        if (mounted && gen == _gen && widget.viewMode == mode) _finish();
      case CaptureViewMode.faceCaptureDone:
        _ctrl.value = 0;
        await _ctrl.animateTo(1, duration: const Duration(milliseconds: 500));
        if (mounted && gen == _gen && widget.viewMode == mode) _finish();
      case CaptureViewMode.faceCircle:
        _ctrl.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = widget.frame.width > 0 && widget.frame.height > 0
        ? widget.frame
        : const OvalMetrics(width: 720, height: 1280);
    final roi = mapRoiToView(safe, widget.width, widget.height);
    const doneCircleScale = 0.8;
    final doneLift = (widget.width / 5 - roi.top) * _scale;
    final doneW = roi.width * doneCircleScale;
    final doneH = roi.height * doneCircleScale;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _CaptureOverlayPainter(
              roi: roi,
              mirror: widget.mirror,
              viewMode: widget.viewMode,
              scale: _scale,
              faceBox: widget.faceBox,
            ),
          ),
          if (widget.viewMode == CaptureViewMode.faceCaptureDone &&
              (widget.capturedUri ?? '').isNotEmpty)
            Positioned(
              left: roi.centerX - doneW / 2,
              top: roi.centerY - doneH / 2 + doneLift,
              width: doneW,
              height: doneH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _onTertiary, width: 8),
                  color: Colors.black,
                ),
                child: ClipOval(
                  child: Transform.scale(
                    scaleX: widget.mirror ? -1.0 : 1.0,
                    child: _CapturedImage(uri: widget.capturedUri!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CapturedImage extends StatelessWidget {
  const _CapturedImage({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    if (uri.startsWith('data:image')) {
      try {
        final b64 = uri.contains(',') ? uri.split(',').last : uri;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover);
      } catch (_) {
        return const ColoredBox(color: Colors.black);
      }
    }
    final path = uri.startsWith('file:') ? Uri.parse(uri).toFilePath() : uri;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}

class _CaptureOverlayPainter extends CustomPainter {
  _CaptureOverlayPainter({
    required this.roi,
    required this.mirror,
    required this.viewMode,
    required this.scale,
    required this.faceBox,
  });

  final RoiRect roi;
  final bool mirror;
  final CaptureViewMode viewMode;
  final double scale;
  final FaceBox? faceBox;

  @override
  void paint(Canvas canvas, Size size) {
    final showCorners = viewMode == CaptureViewMode.noFacePrepare ||
        viewMode == CaptureViewMode.repeatNoFacePrepare ||
        viewMode == CaptureViewMode.toFaceCircle ||
        viewMode == CaptureViewMode.faceCircleToNoFace;

    final showCircle = viewMode == CaptureViewMode.faceCircle ||
        viewMode == CaptureViewMode.faceCapturePrepare ||
        viewMode == CaptureViewMode.faceCaptureDone ||
        (viewMode == CaptureViewMode.toFaceCircle && scale < 1) ||
        viewMode == CaptureViewMode.faceCircleToNoFace;

    final cornerScale = viewMode == CaptureViewMode.noFacePrepare ||
            viewMode == CaptureViewMode.repeatNoFacePrepare ||
            (viewMode == CaptureViewMode.toFaceCircle && scale > 1)
        ? scale
        : 1.0;

    final cx = roi.centerX;
    final cy = roi.centerY;
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

    final cornerAlpha = viewMode == CaptureViewMode.noFacePrepare ||
            (viewMode == CaptureViewMode.toFaceCircle && scale > 1)
        ? ((1.4 - scale) / 0.4).clamp(0.0, 1.0)
        : 1.0;

    final prepareScale = viewMode == CaptureViewMode.faceCapturePrepare
        ? math.max(0.01, 1 - scale)
        : 1.0;

    final scrimAlpha = viewMode == CaptureViewMode.faceCircleToNoFace
        ? 1 - scale
        : (showCircle ? 1.0 : 0.0);

    final holeRadius = () {
      if (viewMode == CaptureViewMode.faceCapturePrepare) {
        return (roi.width / 2) * prepareScale;
      }
      if (viewMode == CaptureViewMode.toFaceCircle ||
          viewMode == CaptureViewMode.faceCircleToNoFace) {
        final start = (0.8 * roi.width * 0.5) / math.cos((45 * math.pi) / 180);
        return (roi.width / 2) * (1 - scale) + start * scale;
      }
      return roi.width / 2;
    }();

    if (showCircle && scrimAlpha > 0.01) {
      final scrim = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(28, 27, 31, scrimAlpha),
            Color.fromRGBO(0, 0, 0, scrimAlpha),
          ],
        ).createShader(Offset.zero & size);
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawRect(Offset.zero & size, scrim);
      if (viewMode != CaptureViewMode.faceCaptureDone) {
        canvas.drawCircle(
          Offset(cx, cy),
          math.max(1.0, holeRadius),
          Paint()..blendMode = BlendMode.clear,
        );
      }
      canvas.restore();
    }

    if (showCorners) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = _onPrimary.withValues(alpha: cornerAlpha)
        ..strokeCap = StrokeCap.round;
      _corner(canvas, stroke, left, top, lineWidth + lineWidthOffset,
          lineHeight + lineHeightOffset, quadR, true, true);
      _corner(canvas, stroke, right, top, lineWidth + lineWidthOffset,
          lineHeight + lineHeightOffset, quadR, false, true);
      _corner(canvas, stroke, right, bottom, lineWidth + lineWidthOffset,
          lineHeight + lineHeightOffset, quadR, false, false);
      _corner(canvas, stroke, left, bottom, lineWidth + lineWidthOffset,
          lineHeight + lineHeightOffset, quadR, true, false);
    }

    if (viewMode == CaptureViewMode.faceCircle) {
      final tick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = _onSurface;
      final a1 = roi.width / 2 + 10;
      final b1 = roi.height / 2 + 10;
      final a2 = roi.width / 2 + 40;
      final b2 = roi.height / 2 + 40;
      for (var i = 0; i < 360; i += 5) {
        final th = (i * math.pi) / 180;
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
          tick,
        );
      }

      if (faceBox != null) {
        final yaw = mirror ? (faceBox!.yaw ?? 0) : -(faceBox!.yaw ?? 0);
        final pitch = -(faceBox!.pitch ?? 0);
        final fill = Paint()..color = _onPrimary.withValues(alpha: 0.5);
        final yawPath = Path()
          ..moveTo(cx, roi.top)
          ..quadraticBezierTo(
            cx - roi.width * math.sin((yaw * math.pi) / 180),
            cy,
            cx,
            roi.bottom,
          )
          ..quadraticBezierTo(
            cx - (roi.width * math.sin((yaw * math.pi) / 180)) / 3,
            cy,
            cx,
            roi.top,
          );
        canvas.drawPath(yawPath, fill);
        final pitchPath = Path()
          ..moveTo(roi.left, cy)
          ..quadraticBezierTo(
            cx,
            cy + roi.width * math.sin((pitch * math.pi) / 180),
            roi.right,
            cy,
          )
          ..quadraticBezierTo(
            cx,
            cy + (roi.width * math.sin((pitch * math.pi) / 180)) / 3,
            roi.left,
            cy,
          );
        canvas.drawPath(pitchPath, fill);
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

  void _corner(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double lineW,
    double lineH,
    double r,
    bool leftSide,
    bool topSide,
  ) {
    final path = Path();
    if (leftSide && topSide) {
      path
        ..moveTo(x, y + lineH)
        ..lineTo(x, y + r)
        ..arcToPoint(Offset(x + r, y), radius: Radius.circular(r))
        ..lineTo(x + lineW, y);
    } else if (!leftSide && topSide) {
      path
        ..moveTo(x, y + lineH)
        ..lineTo(x, y + r)
        ..arcToPoint(
          Offset(x - r, y),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(x - lineW, y);
    } else if (!leftSide && !topSide) {
      path
        ..moveTo(x, y - lineH)
        ..lineTo(x, y - r)
        ..arcToPoint(Offset(x - r, y), radius: Radius.circular(r))
        ..lineTo(x - lineW, y);
    } else {
      path
        ..moveTo(x, y - lineH)
        ..lineTo(x, y - r)
        ..arcToPoint(
          Offset(x + r, y),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(x + lineW, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CaptureOverlayPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.viewMode != viewMode ||
        oldDelegate.faceBox != faceBox ||
        oldDelegate.roi.left != roi.left ||
        oldDelegate.mirror != mirror;
  }
}
