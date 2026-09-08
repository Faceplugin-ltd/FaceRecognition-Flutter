import 'face_box.dart';

/// SDK status codes returned by [setActivation] / [init].
/// Values match the native `FaceRecognitionSDK` constants.
const int sdkSuccess = 0;
const int sdkLicenseInvalid = 1;
const int sdkLicenseExpired = 2;
const int sdkNotActivated = 3;
const int sdkInitFailed = 4;

/// Which physical camera the Capture / Identify UI should use.
enum CameraLens { front, back }

/// Thresholds + camera lens for the [FaceCapture] UI.
///
/// Camel-cased; internally mapped to the engine's snake_case thresholds
/// (`yaw_threshold`, …) when running the capture face gate.
class CaptureSettings {
  const CaptureSettings({
    required this.cameraLens,
    required this.livenessThreshold,
    required this.livenessLevel,
    required this.yawThreshold,
    required this.rollThreshold,
    required this.pitchThreshold,
    required this.eyecloseThreshold,
    this.matchThreshold = 0.8,
  });

  final CameraLens cameraLens;
  final double livenessThreshold;
  final int livenessLevel;
  final double yawThreshold;
  final double rollThreshold;
  final double pitchThreshold;
  final double eyecloseThreshold;
  final double matchThreshold;

  /// Build from demo [AppSettings]-shaped values (example app helper).
  factory CaptureSettings.fromApp({
    required CameraLens cameraLens,
    required double livenessThreshold,
    required int livenessLevel,
    required double yawThreshold,
    required double rollThreshold,
    required double pitchThreshold,
    required double eyecloseThreshold,
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

/// Result of a successful capture: the prepared frame + detected face.
class CaptureResult {
  const CaptureResult({
    required this.uri,
    required this.faceBox,
    this.cropB64,
  });

  /// Prepared live-frame URI (JPEG) used for the successful capture.
  final String uri;
  final FaceBox faceBox;

  /// Optional face-crop JPEG as base64 (NO_WRAP), when available.
  final String? cropB64;
}

/// Which detectors / attribute estimators to run in [faceDetection].
///
/// [toJson] emits the snake_case keys the native bridge parses
/// (`check_liveness`, `check_liveness_level`, …).
class FaceDetectionParam {
  const FaceDetectionParam({
    this.allAttributes = false,
    this.checkLiveness = false,
    this.checkLivenessLevel = 0,
    this.checkPose = false,
    this.checkLandmarks = false,
    this.checkEyeCloseness = false,
    this.checkFaceOcclusion = false,
    this.estimateAgeGender = false,
    this.checkQuality = false,
    this.checkEmotion = false,
    this.checkMask = false,
    this.checkGlasses = false,
  });

  final bool allAttributes;
  final bool checkLiveness;
  final int checkLivenessLevel;
  final bool checkPose;
  final bool checkLandmarks;
  final bool checkEyeCloseness;
  final bool checkFaceOcclusion;
  final bool estimateAgeGender;
  final bool checkQuality;
  final bool checkEmotion;
  final bool checkMask;
  final bool checkGlasses;

  Map<String, dynamic> toJson() {
    return {
      'allAttributes': allAttributes,
      'check_liveness': checkLiveness,
      'check_liveness_level': checkLivenessLevel,
      'check_pose': checkPose,
      'check_landmarks': checkLandmarks,
      'check_eye_closeness': checkEyeCloseness,
      'check_face_occlusion': checkFaceOcclusion,
      'estimate_age_gender': estimateAgeGender,
      'check_quality': checkQuality,
      'check_emotion': checkEmotion,
      'check_mask': checkMask,
      'check_glasses': checkGlasses,
    };
  }
}

/// VideoWorker start configuration.
class VideoWorkerConfig {
  const VideoWorkerConfig({this.matchThreshold = 0.67});

  final double matchThreshold;

  Map<String, dynamic> toJson() => {'matchThreshold': matchThreshold};
}

/// A camera snapshot to feed into VideoWorker via [ingestLiveCameraFrame].
class LiveCameraPhoto {
  const LiveCameraPhoto({
    required this.path,
    this.orientation,
    this.width,
    this.height,
  });

  final String path;
  final String? orientation;
  final int? width;
  final int? height;
}

/// Options controlling how a live frame is rotated / scaled before ingest.
class LiveFrameOptions {
  const LiveFrameOptions({
    required this.frontCamera,
    this.orientation,
    this.rotateDegrees,
    this.maxEdge,
  });

  final bool frontCamera;
  final String? orientation;

  /// Advanced: skip the geometry policy and rotate by this many degrees.
  final double? rotateDegrees;

  /// Long-edge cap (default [liveFrameMaxEdge]).
  final int? maxEdge;
}

/// Result of ingesting a live frame into VideoWorker.
class LiveFrameResult {
  const LiveFrameResult({
    required this.ingested,
    required this.width,
    required this.height,
    this.uri,
  });

  final bool ingested;
  final double width;
  final double height;
  final String? uri;

  factory LiveFrameResult.fromMap(Map<Object?, Object?>? raw) {
    return LiveFrameResult(
      ingested: raw?['ingested'] == true,
      width: _num(raw?['width']),
      height: _num(raw?['height']),
      uri: raw?['uri'] is String ? raw!['uri'] as String : null,
    );
  }
}

/// A prepared JPEG of the last ingested live frame.
class ExportedFrame {
  const ExportedFrame({
    required this.ingested,
    required this.width,
    required this.height,
    this.uri,
  });

  final bool ingested;
  final double width;
  final double height;
  final String? uri;

  factory ExportedFrame.fromMap(Map<Object?, Object?>? raw) {
    return ExportedFrame(
      ingested: raw?['ingested'] == true,
      width: _num(raw?['width']),
      height: _num(raw?['height']),
      uri: raw?['uri'] is String ? raw!['uri'] as String : null,
    );
  }
}

double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
