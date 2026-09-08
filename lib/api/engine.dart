import 'dart:async';
import 'dart:convert';

import '../normalize_face_box.dart';
import '../src/face_recognition_sdk_platform_interface.dart';
import 'types.dart';

FaceRecognitionSdkPlatform get _platform => FaceRecognitionSdkPlatform.instance;

/// FPMC1.… machine code for license requests.
Future<String> getMachineCode() => _platform.getMachineCode();

/// Activate with FP1.… bound to applicationId / bundle id. Returns SDK status code.
Future<int> setActivation(String license) => _platform.setActivation(license);

/// Load engine + models. Returns SDK status code (0 = success).
Future<int> init() => _platform.init();

Future<void> deinit() => _platform.deinit();

Future<String> lastLicenseError() => _platform.lastLicenseError();

Future<String> getLicenseStatus() => _platform.getLicenseStatus();

Future<int> setLandmarkMode(int mode) => _platform.setLandmarkMode(mode);

Future<int> getLandmarkMode() => _platform.getLandmarkMode();

/// Detect faces + attributes. Returns engine JSON string.
Future<String> detect(
  ImageInput image, {
  bool crop = false,
  int flags = DETECT_ALL,
}) {
  return _platform.detect(image, crop: crop, flags: flags);
}

/// Structured face boxes (canonical iOS schema).
/// Android bridge output is normalized so `attributes` + label fields match iOS.
Future<List<FaceBox>> faceDetection(
  ImageInput image, [
  FaceDetectionParam? param,
]) async {
  final json = await _platform.faceDetection(image, param?.toJson());
  try {
    final parsed = jsonDecode(json);
    if (parsed is! List) return <FaceBox>[];
    return normalizeFaceBoxes(parsed)
        .map(FaceBox.fromJson)
        .toList(growable: false);
  } catch (_) {
    return <FaceBox>[];
  }
}

/// Template bytes as base64 (NO_WRAP).
Future<String> templateExtraction(ImageInput image, Object faceBox) {
  final boxJson = faceBox is String ? faceBox : jsonEncode(
    faceBox is FaceBox ? faceBox.toJson() : faceBox,
  );
  return _platform.templateExtraction(image, boxJson);
}

/// Cropped face JPEG as base64 (NO_WRAP).
Future<String> cropFace(ImageInput image, Object faceBox) {
  final boxJson = faceBox is String ? faceBox : jsonEncode(
    faceBox is FaceBox ? faceBox.toJson() : faceBox,
  );
  return _platform.cropFace(image, boxJson);
}

Future<String> extractFeature(ImageInput image) =>
    _platform.extractFeature(image);

Future<double> similarity(String feature1B64, String feature2B64) =>
    _platform.similarity(feature1B64, feature2B64);

Future<String> quality(ImageInput image, {bool crop = false}) =>
    _platform.quality(image, crop: crop);

Future<int> startVideoWorker([Object config = const VideoWorkerConfig(matchThreshold: 0.67)]) {
  final json = config is String
      ? config
      : jsonEncode(
          config is VideoWorkerConfig
              ? config.toJson()
              : (config is Map ? config : <String, dynamic>{}),
        );
  return _platform.startVideoWorker(json);
}

Future<void> stopVideoWorker() => _platform.stopVideoWorker();

Future<int> syncVideoWorkerDatabase(
  List<String> featuresB64, {
  double matchThreshold = 0.67,
}) {
  return _platform.syncVideoWorkerDatabase(
    featuresB64,
    matchThreshold: matchThreshold,
  );
}

Future<Map<Object?, Object?>> probeLiveImage(String imageUri) =>
    _platform.probeLiveImage(imageUri);

Future<LiveFrameResult> applyLiveFrame(
  String imageUri, {
  required int rotateDegrees,
  required int maxEdge,
  required bool feedWorker,
}) async {
  final raw = await _platform.applyLiveFrame(
    imageUri,
    rotateDegrees: rotateDegrees,
    maxEdge: maxEdge,
    feedWorker: feedWorker,
  );
  return LiveFrameResult.fromMap(raw);
}

/// JPEG URI of the last ingested live frame (same bitmap space as VideoWorker).
Future<LiveFrameResult> exportLastLiveFrame() async {
  final raw = await _platform.exportLastLiveFrame();
  return LiveFrameResult.fromMap(raw);
}

Future<void> writeStatus(Map<String, dynamic> payload) {
  return _platform.writeStatus(jsonEncode(payload));
}

/// Subscribe to VideoWorker tracking / match JSON events.
Stream<String> get videoWorkerEvents => _platform.videoWorkerEvents;
