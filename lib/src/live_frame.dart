/// Single live-frame geometry policy shared by Android + iOS.
///
/// Dart owns all front/back / landscape branching; native only rotates + scales.
/// Ported from the React Native `liveFramePrep.ts`.
library;

/// Default long-edge cap for VideoWorker / side-detect frames.
const int liveFrameMaxEdge = 640;

class LiveFramePrepPlan {
  const LiveFramePrepPlan({required this.rotateDegrees, required this.maxEdge});

  final double rotateDegrees;
  final int maxEdge;
}

/// Decide rotateDegrees + maxEdge for a live frame.
///
/// 1. Landscape (w > h): front -90 deg, back +90 deg.
/// 2. Else front on iOS: +180 deg (VisionCamera takeSnapshot portrait bake only).
/// 3. Else: 0 deg (Android front portrait stays upright).
///
/// [width] / [height] must be the post-EXIF-bake pixel size (from
/// `probeLiveImage`), or the upright pixel size when [uprightBaked] is true
/// (preview stream — matches native CameraFrameUtils, no extra +180).
LiveFramePrepPlan planLiveFrame({
  required bool frontCamera,
  required double width,
  required double height,
  String? orientation,
  int? maxEdge,
  String? platform,
  bool uprightBaked = false,
}) {
  final edge = (maxEdge != null && maxEdge > 0) ? maxEdge : liveFrameMaxEdge;
  final w = width.isFinite ? width : 0;
  final h = height.isFinite ? height : 0;
  final os = (platform ?? '').toLowerCase();

  double rotateDegrees = 0;
  if (w > h) {
    rotateDegrees = frontCamera ? -90 : 90;
  } else if (frontCamera && os != 'android' && !uprightBaked) {
    rotateDegrees = 180;
  }

  return LiveFramePrepPlan(rotateDegrees: rotateDegrees, maxEdge: edge);
}
