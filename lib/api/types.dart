// Matching native / RN flag names.
// ignore_for_file: constant_identifier_names

import '../normalize_face_box.dart';

/// Image path, file URI, content URI, or base64 / data URI.
typedef ImageInput = String;

const int sdkSuccess = 0;
const int sdkLicenseInvalid = 1;
const int sdkLicenseExpired = 2;
const int sdkNotActivated = 3;
const int sdkInitFailed = 4;

const int DETECT_POSE = 1 << 0;
const int DETECT_LANDMARKS = 1 << 1;
const int DETECT_AGE = 1 << 2;
const int DETECT_GENDER = 1 << 3;
const int DETECT_EMOTION = 1 << 4;
const int DETECT_MASK = 1 << 5;
const int DETECT_QUALITY = 1 << 6;
const int DETECT_FACE_QUALITY = 1 << 7;
const int DETECT_EYES = 1 << 8;
const int DETECT_LIVENESS = 1 << 9;
const int DETECT_GLASSES = 1 << 11;
const int DETECT_LIVENESS_ACCURATE = 1 << 16;
const int DETECT_ALL = 0xffffffff;

const int LANDMARK_MODE_14 = 14;
const int LANDMARK_MODE_68 = 68;
const int LANDMARK_MODE_468 = 468;

/// VisionCamera / camera takePicture-like object, or any `{ path, orientation? }`.
class LiveCameraPhoto {
  const LiveCameraPhoto({
    required this.path,
    this.orientation,
    this.width,
    this.height,
  });

  final String path;
  final String? orientation;
  final double? width;
  final double? height;
}

/// URI string or [LiveCameraPhoto].
typedef LiveFrameInput = Object;

class LiveFrameOptions {
  const LiveFrameOptions({
    this.frontCamera = true,
    this.orientation,
    this.rotateDegrees,
    this.maxEdge,
  });

  /// Front camera → package applies sensor mount correction. Default true.
  final bool frontCamera;

  /// Optional orientation tag (size after probe drives rotation).
  final String? orientation;

  /// Advanced: skip policy and rotate by this many degrees.
  final int? rotateDegrees;

  /// Long-edge cap (default 640).
  final int? maxEdge;
}

class FaceBox {
  const FaceBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.yaw,
    this.roll,
    this.pitch,
    this.liveness,
    this.faceQuality,
    this.faceLuminance,
    this.leftEyeClosed,
    this.rightEyeClosed,
    this.faceOcclusion,
    this.mouthOpened,
    this.age,
    this.gender,
    this.livenessLabel,
    this.genderLabel,
    this.emotionLabel,
    this.maskLabel,
    this.qualityLabel,
    this.eyesLeftLabel,
    this.eyesRightLabel,
    this.glassesLabel,
    this.sunglassesLabel,
    this.occlusionLabel,
    this.attributes,
    this.landmarkCount,
    this.landmarks,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double? yaw;
  final double? roll;
  final double? pitch;
  final double? liveness;
  final double? faceQuality;
  final double? faceLuminance;
  final double? leftEyeClosed;
  final double? rightEyeClosed;
  final double? faceOcclusion;
  final double? mouthOpened;
  final double? age;
  final double? gender;
  final String? livenessLabel;
  final String? genderLabel;
  final String? emotionLabel;
  final String? maskLabel;
  final String? qualityLabel;
  final String? eyesLeftLabel;
  final String? eyesRightLabel;
  final String? glassesLabel;
  final String? sunglassesLabel;
  final String? occlusionLabel;

  /// Full engine attribute map (PascalCase keys) for Attribute Result UI.
  final Map<String, String>? attributes;
  final int? landmarkCount;
  final List<double>? landmarks;

  factory FaceBox.fromJson(Map<String, dynamic> json) {
    final normalized = normalizeFaceBox(json);
    return FaceBox(
      x1: normalizeAsDouble(normalized['x1']) ?? 0,
      y1: normalizeAsDouble(normalized['y1']) ?? 0,
      x2: normalizeAsDouble(normalized['x2']) ?? 0,
      y2: normalizeAsDouble(normalized['y2']) ?? 0,
      yaw: normalizeAsDouble(normalized['yaw']),
      roll: normalizeAsDouble(normalized['roll']),
      pitch: normalizeAsDouble(normalized['pitch']),
      liveness: normalizeAsDouble(normalized['liveness']),
      faceQuality: normalizeAsDouble(normalized['face_quality']),
      faceLuminance: normalizeAsDouble(normalized['face_luminance']),
      leftEyeClosed: normalizeAsDouble(normalized['left_eye_closed']),
      rightEyeClosed: normalizeAsDouble(normalized['right_eye_closed']),
      faceOcclusion: normalizeAsDouble(normalized['face_occlusion']),
      mouthOpened: normalizeAsDouble(normalized['mouth_opened']),
      age: normalizeAsDouble(normalized['age']),
      gender: normalizeAsDouble(normalized['gender']),
      livenessLabel: normalized['livenessLabel']?.toString(),
      genderLabel: normalized['genderLabel']?.toString(),
      emotionLabel: normalized['emotionLabel']?.toString(),
      maskLabel: normalized['maskLabel']?.toString(),
      qualityLabel: normalized['qualityLabel']?.toString(),
      eyesLeftLabel: normalized['eyesLeftLabel']?.toString(),
      eyesRightLabel: normalized['eyesRightLabel']?.toString(),
      glassesLabel: normalized['glassesLabel']?.toString(),
      sunglassesLabel: normalized['sunglassesLabel']?.toString(),
      occlusionLabel: normalized['occlusionLabel']?.toString(),
      attributes: normalizeAsStringMap(normalized['attributes']),
      landmarkCount: normalizeAsInt(normalized['landmarkCount']),
      landmarks: normalizeAsDoubleList(normalized['landmarks']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      if (yaw != null) 'yaw': yaw,
      if (roll != null) 'roll': roll,
      if (pitch != null) 'pitch': pitch,
      if (liveness != null) 'liveness': liveness,
      if (faceQuality != null) 'face_quality': faceQuality,
      if (faceLuminance != null) 'face_luminance': faceLuminance,
      if (leftEyeClosed != null) 'left_eye_closed': leftEyeClosed,
      if (rightEyeClosed != null) 'right_eye_closed': rightEyeClosed,
      if (faceOcclusion != null) 'face_occlusion': faceOcclusion,
      if (mouthOpened != null) 'mouth_opened': mouthOpened,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (livenessLabel != null) 'livenessLabel': livenessLabel,
      if (genderLabel != null) 'genderLabel': genderLabel,
      if (emotionLabel != null) 'emotionLabel': emotionLabel,
      if (maskLabel != null) 'maskLabel': maskLabel,
      if (qualityLabel != null) 'qualityLabel': qualityLabel,
      if (eyesLeftLabel != null) 'eyesLeftLabel': eyesLeftLabel,
      if (eyesRightLabel != null) 'eyesRightLabel': eyesRightLabel,
      if (glassesLabel != null) 'glassesLabel': glassesLabel,
      if (sunglassesLabel != null) 'sunglassesLabel': sunglassesLabel,
      if (occlusionLabel != null) 'occlusionLabel': occlusionLabel,
      if (attributes != null) 'attributes': attributes,
      if (landmarkCount != null) 'landmarkCount': landmarkCount,
      if (landmarks != null) 'landmarks': landmarks,
    };
  }

  FaceBox copyWith({
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    double? yaw,
    double? roll,
    double? pitch,
    double? liveness,
    double? faceQuality,
    double? faceLuminance,
    double? leftEyeClosed,
    double? rightEyeClosed,
    double? faceOcclusion,
    double? mouthOpened,
    double? age,
    double? gender,
    String? livenessLabel,
    String? genderLabel,
    String? emotionLabel,
    String? maskLabel,
    String? qualityLabel,
    String? eyesLeftLabel,
    String? eyesRightLabel,
    String? glassesLabel,
    String? sunglassesLabel,
    String? occlusionLabel,
    Map<String, String>? attributes,
    int? landmarkCount,
    List<double>? landmarks,
  }) {
    return FaceBox(
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      liveness: liveness ?? this.liveness,
      faceQuality: faceQuality ?? this.faceQuality,
      faceLuminance: faceLuminance ?? this.faceLuminance,
      leftEyeClosed: leftEyeClosed ?? this.leftEyeClosed,
      rightEyeClosed: rightEyeClosed ?? this.rightEyeClosed,
      faceOcclusion: faceOcclusion ?? this.faceOcclusion,
      mouthOpened: mouthOpened ?? this.mouthOpened,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      livenessLabel: livenessLabel ?? this.livenessLabel,
      genderLabel: genderLabel ?? this.genderLabel,
      emotionLabel: emotionLabel ?? this.emotionLabel,
      maskLabel: maskLabel ?? this.maskLabel,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      eyesLeftLabel: eyesLeftLabel ?? this.eyesLeftLabel,
      eyesRightLabel: eyesRightLabel ?? this.eyesRightLabel,
      glassesLabel: glassesLabel ?? this.glassesLabel,
      sunglassesLabel: sunglassesLabel ?? this.sunglassesLabel,
      occlusionLabel: occlusionLabel ?? this.occlusionLabel,
      attributes: attributes ?? this.attributes,
      landmarkCount: landmarkCount ?? this.landmarkCount,
      landmarks: landmarks ?? this.landmarks,
    );
  }
}

class FaceDetectionParam {
  const FaceDetectionParam({
    this.allAttributes,
    this.checkLiveness,
    this.checkLivenessLevel,
    this.checkEyeCloseness,
    this.checkFaceOcclusion,
    this.estimateAgeGender,
    this.checkPose,
    this.checkLandmarks,
    this.checkQuality,
    this.checkEmotion,
    this.checkMask,
    this.checkGlasses,
  });

  final bool? allAttributes;
  final bool? checkLiveness;
  final int? checkLivenessLevel;
  final bool? checkEyeCloseness;
  final bool? checkFaceOcclusion;
  final bool? estimateAgeGender;
  final bool? checkPose;
  final bool? checkLandmarks;
  final bool? checkQuality;
  final bool? checkEmotion;
  final bool? checkMask;
  final bool? checkGlasses;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (allAttributes != null) 'allAttributes': allAttributes,
      if (checkLiveness != null) 'check_liveness': checkLiveness,
      if (checkLivenessLevel != null) 'check_liveness_level': checkLivenessLevel,
      if (checkEyeCloseness != null) 'check_eye_closeness': checkEyeCloseness,
      if (checkFaceOcclusion != null) 'check_face_occlusion': checkFaceOcclusion,
      if (estimateAgeGender != null) 'estimate_age_gender': estimateAgeGender,
      if (checkPose != null) 'check_pose': checkPose,
      if (checkLandmarks != null) 'check_landmarks': checkLandmarks,
      if (checkQuality != null) 'check_quality': checkQuality,
      if (checkEmotion != null) 'check_emotion': checkEmotion,
      if (checkMask != null) 'check_mask': checkMask,
      if (checkGlasses != null) 'check_glasses': checkGlasses,
    };
  }
}

class VideoWorkerConfig {
  const VideoWorkerConfig({this.matchThreshold});

  final double? matchThreshold;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (matchThreshold != null) 'matchThreshold': matchThreshold,
    };
  }
}

class LiveFrameResult {
  const LiveFrameResult({
    required this.ingested,
    required this.width,
    required this.height,
    this.uri,
  });

  final bool ingested;
  final int width;
  final int height;
  final String? uri;

  factory LiveFrameResult.fromMap(Map<Object?, Object?> raw) {
    final uriVal = raw['uri'];
    return LiveFrameResult(
      ingested: raw['ingested'] == true,
      width: (raw['width'] is num) ? (raw['width'] as num).toInt() : 0,
      height: (raw['height'] is num) ? (raw['height'] as num).toInt() : 0,
      uri: uriVal is String ? uriVal : null,
    );
  }
}
