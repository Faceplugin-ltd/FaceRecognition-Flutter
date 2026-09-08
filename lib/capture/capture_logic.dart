import 'dart:math' as math;

import '../api/types.dart' show FaceBox;

enum CameraLens { front, back }

/// Thresholds + camera lens for Capture UI.
class CaptureSettings {
  const CaptureSettings({
    this.cameraLens = CameraLens.front,
    this.livenessThreshold = 0.5,
    this.livenessLevel = 0,
    this.yawThreshold = 40,
    this.rollThreshold = 40,
    this.pitchThreshold = 40,
    this.eyecloseThreshold = 0.5,
    this.matchThreshold = 0.8,
  });

  final CameraLens cameraLens;
  final double livenessThreshold;
  final int livenessLevel;
  final double yawThreshold;
  final double rollThreshold;
  final double pitchThreshold;
  final double eyecloseThreshold;

  /// VideoWorker match threshold used by FaceCapture.
  final double matchThreshold;

  static const CaptureSettings defaults = CaptureSettings();

  /// Map demo / app settings onto Capture thresholds (one source of truth).
  factory CaptureSettings.fromApp({
    CameraLens cameraLens = CameraLens.front,
    double livenessThreshold = 0.5,
    int livenessLevel = 0,
    double yawThreshold = 40,
    double rollThreshold = 40,
    double pitchThreshold = 40,
    double eyecloseThreshold = 0.5,
    double matchThreshold = 0.8,
  }) {
    return CaptureSettings(
      cameraLens: cameraLens,
      livenessThreshold: livenessThreshold,
      livenessLevel: livenessLevel,
      yawThreshold: yawThreshold,
      rollThreshold: rollThreshold,
      pitchThreshold: pitchThreshold,
      eyecloseThreshold: eyecloseThreshold,
      matchThreshold: matchThreshold,
    );
  }
}

class CaptureResult {
  const CaptureResult({
    required this.uri,
    required this.faceBox,
    this.cropB64,
  });

  /// Prepared live frame URI (JPEG) used for the successful capture.
  final String uri;
  final FaceBox faceBox;

  /// Optional face crop JPEG as base64 (NO_WRAP).
  final String? cropB64;
}

/// Capture gate states matching FaceRecognitionSDK Apps / RN.
enum FaceCaptureState {
  noFace,
  multipleFaces,
  fitInCircle,
  moveCloser,
  noFront,
  faceOccluded,
  eyeClosed,
  captureOk,
}

class OvalMetrics {
  const OvalMetrics({required this.width, required this.height});

  final double width;
  final double height;
}

class RoiRect {
  const RoiRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

/// Android CaptureView.getROIRect — used by checkFace fit/size tests.
RoiRect getRoiRect(OvalMetrics frame) {
  final margin = frame.width / 6;
  final rectHeight = ((frame.width - 2 * margin) * 6) / 5;
  final top = (frame.height - rectHeight) / 2;
  return RoiRect(
    left: margin,
    top: top,
    right: frame.width - margin,
    bottom: top + rectHeight,
  );
}

/// Android CaptureView.getROIRect1 — circular guide in the overlay.
RoiRect getRoiRect1(OvalMetrics frame) {
  final margin = frame.width / 6;
  final rectHeight = frame.width - 2 * margin;
  final top = (frame.height - rectHeight) / 2;
  return RoiRect(
    left: margin,
    top: top,
    right: frame.width - margin,
    bottom: top + rectHeight,
  );
}

/// Map frame ROI into view coords (Android CaptureView.mapRoiToView).
RoiRect mapRoiToView(OvalMetrics frame, double viewW, double viewH) {
  final roi = getRoiRect1(frame);
  final ratioView = viewW / viewH;
  final ratioFrame = frame.width / frame.height;
  final ratio = viewH / frame.height;
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
  return RoiRect(left: left, top: top, right: right, bottom: bottom);
}

/// Preview FILL_CENTER mapping (Android FaceView).
({double x, double y}) mapFramePoint(
  double x,
  double y,
  double fw,
  double fh,
  double vw,
  double vh,
  bool mirror,
) {
  final scale = (vw / fw) > (vh / fh) ? (vw / fw) : (vh / fh);
  final dx = (vw - fw * scale) / 2;
  final dy = (vh - fh * scale) / 2;
  var vx = x * scale + dx;
  final vy = y * scale + dy;
  if (mirror) vx = vw - vx;
  return (x: vx, y: vy);
}

String warningFor(FaceCaptureState state) {
  switch (state) {
    case FaceCaptureState.multipleFaces:
      return 'Multiple face detected!';
    case FaceCaptureState.fitInCircle:
      return 'Fit in circle!';
    case FaceCaptureState.moveCloser:
      return 'Move closer!';
    case FaceCaptureState.noFront:
      return 'Not fronted face!';
    case FaceCaptureState.faceOccluded:
      return 'Face occluded!';
    case FaceCaptureState.eyeClosed:
      return 'Eye closed!';
    case FaceCaptureState.noFace:
    case FaceCaptureState.captureOk:
      return '';
  }
}

/// Android CaptureActivity.checkFace — pose / fit / eyes (no mouth/spoof gates).
FaceCaptureState checkFace(
  Object boxesOrFace,
  CaptureSettings settings,
  OvalMetrics oval,
) {
  final List<FaceBox> boxes;
  if (boxesOrFace is FaceBox) {
    boxes = <FaceBox>[boxesOrFace];
  } else if (boxesOrFace is List<FaceBox>) {
    boxes = boxesOrFace;
  } else if (boxesOrFace is List) {
    boxes = boxesOrFace.whereType<FaceBox>().toList();
  } else {
    return FaceCaptureState.noFace;
  }

  if (boxes.isEmpty) return FaceCaptureState.noFace;
  if (boxes.length > 1) return FaceCaptureState.multipleFaces;

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
  final fw = oval.width > 0 ? oval.width : 720.0;
  final fh = oval.height > 0 ? oval.height : 1280.0;
  final roiRect = getRoiRect(OvalMetrics(width: fw, height: fh));
  final centerY = (faceBox.y2 + faceBox.y1) / 2;
  final topY = centerY - ((faceBox.y2 - faceBox.y1) * 2) / 3;
  final interX =
      math.max(0.0, roiRect.left - faceLeft) + math.max(0.0, faceRight - roiRect.right);
  final interY =
      math.max(0.0, roiRect.top - topY) + math.max(0.0, faceBottom - roiRect.bottom);
  if (interX / roiRect.width > interRate || interY / roiRect.height > interRate) {
    return FaceCaptureState.fitInCircle;
  }
  if ((faceBox.y2 - faceBox.y1) * (faceBox.x2 - faceBox.x1) <
      roiRect.width * roiRect.height * sizeRate) {
    return FaceCaptureState.moveCloser;
  }
  if ((faceBox.yaw?.abs() ?? 0) > settings.yawThreshold ||
      (faceBox.roll?.abs() ?? 0) > settings.rollThreshold ||
      (faceBox.pitch?.abs() ?? 0) > settings.pitchThreshold) {
    return FaceCaptureState.noFront;
  }
  final mask = (faceBox.maskLabel ?? '').toLowerCase();
  if (mask.contains('yes')) return FaceCaptureState.faceOccluded;

  final left = (faceBox.eyesLeftLabel ?? '').toLowerCase();
  final right = (faceBox.eyesRightLabel ?? '').toLowerCase();
  if (left.contains('closed') || right.contains('closed')) {
    return FaceCaptureState.eyeClosed;
  }
  if (left.isEmpty &&
      right.isEmpty &&
      ((faceBox.leftEyeClosed ?? 0) > settings.eyecloseThreshold ||
          (faceBox.rightEyeClosed ?? 0) > settings.eyecloseThreshold)) {
    return FaceCaptureState.eyeClosed;
  }

  return FaceCaptureState.captureOk;
}

FaceBox? _bestMatch(FaceBox dst, List<FaceBox> pb) {
  if (pb.length == 1) return pb.first;
  FaceBox? best;
  var bestIou = 0.1;
  for (final src in pb) {
    final v = _iou(dst, src);
    if (v > bestIou) {
      bestIou = v;
      best = src;
    }
  }
  return best ?? (pb.isNotEmpty ? pb.first : null);
}

double _iou(FaceBox a, FaceBox b) {
  final left = a.x1 > b.x1 ? a.x1 : b.x1;
  final top = a.y1 > b.y1 ? a.y1 : b.y1;
  final right = a.x2 < b.x2 ? a.x2 : b.x2;
  final bottom = a.y2 < b.y2 ? a.y2 : b.y2;
  final inter = (right - left).clamp(0, double.infinity) *
      (bottom - top).clamp(0, double.infinity);
  final areaA = (a.x2 - a.x1).clamp(0, double.infinity) *
      (a.y2 - a.y1).clamp(0, double.infinity);
  final areaB = (b.x2 - b.x1).clamp(0, double.infinity) *
      (b.y2 - b.y1).clamp(0, double.infinity);
  final union = areaA + areaB - inter;
  if (union <= 0) return 0;
  return inter / union;
}

/// Merge eye labels from a side detect pass (swap L/R when front preview).
List<FaceBox> mergeEyes(
  List<FaceBox> track,
  List<FaceBox> pb, {
  required bool swapLeftRight,
}) {
  if (pb.isEmpty) return track;
  return track.map((dst) {
    final src = _bestMatch(dst, pb);
    if (src == null) return dst;
    if (swapLeftRight) {
      return dst.copyWith(
        eyesLeftLabel: src.eyesRightLabel,
        eyesRightLabel: src.eyesLeftLabel,
        leftEyeClosed: src.rightEyeClosed,
        rightEyeClosed: src.leftEyeClosed,
      );
    }
    return dst.copyWith(
      eyesLeftLabel: src.eyesLeftLabel,
      eyesRightLabel: src.eyesRightLabel,
      leftEyeClosed: src.leftEyeClosed,
      rightEyeClosed: src.rightEyeClosed,
    );
  }).toList(growable: false);
}

/// Landmark xy in cropFace bitmap pixels — matches Android Utils.mapLandmarksToCrop.
List<({double x, double y})> mapLandmarksToCrop(
  FaceBox faceBox,
  double srcW,
  double srcH,
  double outW,
  double outH,
) {
  final lm = faceBox.landmarks ?? const <double>[];
  final n = (faceBox.landmarkCount ?? (lm.length ~/ 2))
      .clamp(0, lm.length ~/ 2);
  if (n == 0 || srcW <= 0 || srcH <= 0 || outW <= 0 || outH <= 0) {
    return const [];
  }
  final centerX = (faceBox.x1 + faceBox.x2) / 2;
  final centerY = (faceBox.y1 + faceBox.y2) / 2;
  var cropWidth = ((faceBox.x2 - faceBox.x1) * 1.4).roundToDouble();
  if (cropWidth < 2) {
    cropWidth = [
      2.0,
      faceBox.x2 - faceBox.x1,
      faceBox.y2 - faceBox.y1,
    ].reduce((a, b) => a > b ? a : b);
  }
  final cropX1 = (centerX - cropWidth / 2).clamp(0, double.infinity);
  final cropY1 = (centerY - cropWidth / 2).clamp(0, double.infinity);
  final cropX2 = (centerX + cropWidth / 2).clamp(0, srcW - 1);
  final cropY2 = (centerY + cropWidth / 2).clamp(0, srcH - 1);
  final cropSrcW = cropX2 - cropX1 + 1;
  final cropSrcH = cropY2 - cropY1 + 1;
  if (cropSrcW < 1 || cropSrcH < 1) return const [];
  final sx = outW / cropSrcW;
  final sy = outH / cropSrcH;
  final out = <({double x, double y})>[];
  for (var i = 0; i < n; i++) {
    out.add((
      x: (lm[i * 2] - cropX1) * sx,
      y: (lm[i * 2 + 1] - cropY1) * sy,
    ));
  }
  return out;
}

bool hasLiveness(FaceBox box) {
  if ((box.livenessLabel ?? '').isNotEmpty) return true;
  return (box.liveness ?? 0) > 0.001;
}

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
