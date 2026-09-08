import 'dart:math' as math;

import 'face_box.dart';
import 'models.dart';

/// Frame pixel size (VideoWorker / detector coordinate space).
class FrameSize {
  const FrameSize(this.w, this.h);

  final double w;
  final double h;
}

/// Face-gate state machine result (Android `CaptureActivity.checkFace`).
enum CaptureState {
  noFace,
  multipleFaces,
  fitInCircle,
  moveCloser,
  noFront,
  faceOccluded,
  eyeClosed,
  spoofedFace,
  captureOk,
}

/// Public alias for [CaptureState].
typedef FaceCaptureState = CaptureState;

/// Rectangular region of interest, optionally with a precomputed center.
class RoiRect {
  const RoiRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;
  final double centerX;
  final double centerY;
}

/// Oval guide geometry (view coordinates) used by the capture overlay.
class OvalMetrics {
  const OvalMetrics({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
  });

  final double centerX;
  final double centerY;
  final double radiusX;
  final double radiusY;
}

/// Android `CaptureView.getROIRect` — fit / size test region.
RoiRect getRoiRect(FrameSize frame) {
  final margin = frame.w / 6;
  final rectHeight = ((frame.w - 2 * margin) * 6) / 5;
  final top = (frame.h - rectHeight) / 2;
  final left = margin;
  final right = frame.w - margin;
  final bottom = top + rectHeight;
  return RoiRect(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: frame.w - 2 * margin,
    height: rectHeight,
    centerX: (left + right) / 2,
    centerY: (top + bottom) / 2,
  );
}

/// Android `CaptureView.getROIRect1` — circular guide region.
RoiRect getRoiRect1(FrameSize frame) {
  final margin = frame.w / 6;
  final rectHeight = frame.w - 2 * margin;
  final top = (frame.h - rectHeight) / 2;
  final left = margin;
  final right = frame.w - margin;
  final bottom = top + rectHeight;
  return RoiRect(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: right - left,
    height: bottom - top,
    centerX: (left + right) / 2,
    centerY: (top + bottom) / 2,
  );
}

/// Map frame ROI into view coords (Android `CaptureView.mapRoiToView`).
RoiRect mapRoiToView(FrameSize frame, double viewW, double viewH) {
  final roi = getRoiRect1(frame);
  final ratioView = viewW / viewH;
  final ratioFrame = frame.w / frame.h;
  final ratio = viewH / frame.h;
  var dx = 0.0;
  var dy = 0.0;
  if (ratioView < ratioFrame) {
    dx = (viewH * ratioFrame - viewW) / 2;
  } else {
    dy = (viewW / ratioFrame - viewH) / 2;
  }
  final left = roi.left * ratio - dx;
  final top = roi.top * ratio - dy;
  final right = roi.right * ratio - dx;
  final bottom = roi.bottom * ratio - dy;
  return RoiRect(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: right - left,
    height: bottom - top,
    centerX: (left + right) / 2,
    centerY: (top + bottom) / 2,
  );
}

/// Human-readable warning for a face-gate [state].
String warningFor(CaptureState state) {
  switch (state) {
    case CaptureState.multipleFaces:
      return 'Multiple face detected!';
    case CaptureState.fitInCircle:
      return 'Fit in circle!';
    case CaptureState.moveCloser:
      return 'Move closer!';
    case CaptureState.noFront:
      return 'Not fronted face!';
    case CaptureState.faceOccluded:
      return 'Face occluded!';
    case CaptureState.eyeClosed:
      return 'Eye closed!';
    case CaptureState.spoofedFace:
      return 'Spoof face';
    case CaptureState.noFace:
    case CaptureState.captureOk:
      return '';
  }
}

/// Android `CaptureActivity.checkFace` — decide the capture gate state.
CaptureState checkFace(
  List<FaceBox> boxes,
  CaptureSettings settings,
  FrameSize frame,
) {
  if (boxes.isEmpty) return CaptureState.noFace;
  if (boxes.length > 1) return CaptureState.multipleFaces;

  final faceBox = boxes.first;
  var faceLeft = double.maxFinite;
  var faceRight = 0.0;
  var faceBottom = 0.0;
  final lm = faceBox.landmarks ?? const <double>[];
  final nMarks = math.max(
    0,
    math.min(
      faceBox.landmarkCount ?? (lm.length ~/ 2),
      lm.length ~/ 2,
    ),
  );
  if (nMarks >= 5) {
    for (var i = 0; i < nMarks; i++) {
      final lx = lm[i * 2];
      final ly = lm[i * 2 + 1];
      faceLeft = math.min(faceLeft, lx);
      faceRight = math.max(faceRight, lx);
      faceBottom = math.max(faceBottom, ly);
    }
  } else {
    faceLeft = faceBox.x1;
    faceRight = faceBox.x2;
    faceBottom = faceBox.y2;
  }

  const sizeRate = 0.3;
  const interRate = 0.03;
  final fw = frame.w > 0 ? frame.w : 720.0;
  final fh = frame.h > 0 ? frame.h : 1280.0;
  final roiRect = getRoiRect(FrameSize(fw, fh));
  final centerY = (faceBox.y2 + faceBox.y1) / 2;
  final topY = centerY - ((faceBox.y2 - faceBox.y1) * 2) / 3;
  final interX = math.max(0.0, roiRect.left - faceLeft) +
      math.max(0.0, faceRight - roiRect.right);
  final interY = math.max(0.0, roiRect.top - topY) +
      math.max(0.0, faceBottom - roiRect.bottom);
  if (interX / roiRect.width > interRate ||
      interY / roiRect.height > interRate) {
    return CaptureState.fitInCircle;
  }
  if ((faceBox.y2 - faceBox.y1) * (faceBox.x2 - faceBox.x1) <
      roiRect.width * roiRect.height * sizeRate) {
    return CaptureState.moveCloser;
  }
  if ((faceBox.yaw ?? 0).abs() > settings.yawThreshold ||
      (faceBox.roll ?? 0).abs() > settings.rollThreshold ||
      (faceBox.pitch ?? 0).abs() > settings.pitchThreshold) {
    return CaptureState.noFront;
  }
  final mask = (faceBox.maskLabel ?? '').toLowerCase();
  if (mask.contains('yes')) return CaptureState.faceOccluded;
  final left = (faceBox.eyesLeftLabel ?? '').toLowerCase();
  final right = (faceBox.eyesRightLabel ?? '').toLowerCase();
  if (left.contains('closed') || right.contains('closed')) {
    return CaptureState.eyeClosed;
  }
  if (left.isEmpty &&
      right.isEmpty &&
      ((faceBox.leftEyeClosed ?? 0) > settings.eyecloseThreshold ||
          (faceBox.rightEyeClosed ?? 0) > settings.eyecloseThreshold)) {
    return CaptureState.eyeClosed;
  }
  return CaptureState.captureOk;
}

/// Landmark xy in [cropFace] bitmap pixels (Android `Utils.mapLandmarksToCrop`).
List<({double x, double y})> mapLandmarksToCrop(
  FaceBox faceBox,
  double srcW,
  double srcH,
  double outW,
  double outH,
) {
  final lm = faceBox.landmarks ?? const <double>[];
  final n = math.max(
    0,
    math.min(
      faceBox.landmarkCount ?? (lm.length ~/ 2),
      lm.length ~/ 2,
    ),
  );
  if (n == 0 || srcW <= 0 || srcH <= 0 || outW <= 0 || outH <= 0) {
    return const [];
  }
  final centerX = (faceBox.x1 + faceBox.x2) / 2;
  final centerY = (faceBox.y1 + faceBox.y2) / 2;
  var cropWidth = ((faceBox.x2 - faceBox.x1) * 1.4).round();
  if (cropWidth < 2) {
    cropWidth = math.max(
      2,
      math.max(
        (faceBox.x2 - faceBox.x1).round(),
        (faceBox.y2 - faceBox.y1).round(),
      ),
    );
  }
  final cropX1 = math.max(0.0, centerX - cropWidth / 2);
  final cropY1 = math.max(0.0, centerY - cropWidth / 2);
  final cropX2 = math.min(srcW - 1, centerX + cropWidth / 2);
  final cropY2 = math.min(srcH - 1, centerY + cropWidth / 2);
  final cropSrcW = cropX2 - cropX1 + 1;
  final cropSrcH = cropY2 - cropY1 + 1;
  if (cropSrcW < 1 || cropSrcH < 1) return const [];
  final sx = outW / cropSrcW;
  final sy = outH / cropSrcH;
  final out = <({double x, double y})>[];
  for (var i = 0; i < n; i++) {
    out.add((
      x: ((lm[i * 2]) - cropX1) * sx,
      y: ((lm[i * 2 + 1]) - cropY1) * sy,
    ));
  }
  return out;
}

bool hasLiveness(FaceBox box) {
  final label = box.livenessLabel ?? '';
  if (label.isNotEmpty) return true;
  return (box.liveness ?? 0) > 0.001;
}

FaceBox? _bestMatch(FaceBox dst, List<FaceBox> pb) {
  if (pb.length == 1) return pb.first;
  FaceBox? best;
  var bestIou = 0.1;
  for (final src in pb) {
    final left = dst.x1 > src.x1 ? dst.x1 : src.x1;
    final top = dst.y1 > src.y1 ? dst.y1 : src.y1;
    final right = dst.x2 < src.x2 ? dst.x2 : src.x2;
    final bottom = dst.y2 < src.y2 ? dst.y2 : src.y2;
    final inter = (right - left).clamp(0, double.infinity) *
        (bottom - top).clamp(0, double.infinity);
    final areaA = (dst.x2 - dst.x1).clamp(0, double.infinity) *
        (dst.y2 - dst.y1).clamp(0, double.infinity);
    final areaB = (src.x2 - src.x1).clamp(0, double.infinity) *
        (src.y2 - src.y1).clamp(0, double.infinity);
    final union = areaA + areaB - inter;
    if (union <= 0) continue;
    final v = inter / union;
    if (v > bestIou) {
      bestIou = v;
      best = src;
    }
  }
  return best ?? (pb.isNotEmpty ? pb.first : null);
}

/// Merge liveness scores from side-detect [pb] onto tracked [track] boxes.
List<FaceBox> mergeLiveness(List<FaceBox> track, List<FaceBox> pb) {
  if (pb.isEmpty) return track;
  return track.map((dst) {
    final src = _bestMatch(dst, pb);
    if (src == null) return dst;
    return dst.copyWith(
      liveness: src.liveness,
      livenessLabel: src.livenessLabel,
    );
  }).toList(growable: false);
}
