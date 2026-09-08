/// Single live-frame geometry policy for Android + iOS.
///
/// Dart owns all front/back / landscape branching; native only rotates + scales.
///
/// `width` / `height` must be after EXIF / UIImage orientation bake (from probeLiveImage).
/// Camera `orientation` is accepted for API completeness / future use; the
/// post-bake aspect ratio is what drives the rotation today.
library;

// Matching RN export name.
// ignore_for_file: constant_identifier_names

const int liveFrameMaxEdge = 640;

/// Alias matching RN `LIVE_FRAME_MAX_EDGE`.
const int LIVE_FRAME_MAX_EDGE = liveFrameMaxEdge;

class LiveFramePrepInput {
  const LiveFramePrepInput({
    required this.frontCamera,
    this.orientation,
    required this.width,
    required this.height,
    this.maxEdge,
    this.platform,
  });

  final bool frontCamera;

  /// Camera snapshot orientation (e.g. portrait, landscapeLeft).
  final String? orientation;
  final double width;
  final double height;
  final int? maxEdge;

  /// Host OS. Front-portrait +180° is an iOS camera quirk only —
  /// Android EXIF bake is already upright for portrait snapshots.
  final String? platform;
}

class LiveFramePrepPlan {
  const LiveFramePrepPlan({
    required this.rotateDegrees,
    required this.maxEdge,
  });

  final int rotateDegrees;
  final int maxEdge;
}

/// Decide rotateDegrees + maxEdge for VideoWorker / side-detect frames.
///
/// 1. Landscape (w > h): front −90°, back +90°.
/// 2. Else if front on iOS: +180° (front sensor mount vs portrait bake).
/// 3. Else: 0° (Android front portrait stays upright).
LiveFramePrepPlan planLiveFrame(LiveFramePrepInput input) {
  final maxEdge = (input.maxEdge != null && input.maxEdge! > 0)
      ? input.maxEdge!
      : liveFrameMaxEdge;
  final w = input.width.isFinite ? input.width : 0.0;
  final h = input.height.isFinite ? input.height : 0.0;
  final platform = (input.platform ?? '').toLowerCase();

  var rotateDegrees = 0;
  if (w > h) {
    rotateDegrees = input.frontCamera ? -90 : 90;
  } else if (input.frontCamera && platform != 'android') {
    rotateDegrees = 180;
  }

  return LiveFramePrepPlan(rotateDegrees: rotateDegrees, maxEdge: maxEdge);
}
