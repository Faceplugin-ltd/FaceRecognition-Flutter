import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_frame_jpeg.dart' show uprightCameraImage;
import 'package:image/image.dart' as img;
import 'face_box.dart';
import 'live_frame.dart';
import 'models.dart';

const MethodChannel _channel = MethodChannel('FaceRecognitionSdk');
const EventChannel _eventChannel = EventChannel('FaceRecognitionSdk/videoWorker');

Stream<String>? _videoWorkerEvents;

/// Broadcast stream of VideoWorker tracking / match JSON events.
///
/// Native sends `{ "json": "<string>" }` maps; this exposes the raw JSON
/// strings for [parseVideoWorkerEvent].
Stream<String> get videoWorkerEvents {
  return _videoWorkerEvents ??= _eventChannel
      .receiveBroadcastStream()
      .map<String>((event) {
    if (event is Map) {
      final json = event['json'];
      if (json is String) return json;
    }
    return '{}';
  });
}

/// `FPMC1.…` machine code for license requests.
Future<String> getMachineCode() async {
  final res = await _channel.invokeMethod<Object?>('getMachineCode');
  return res is String ? res : '';
}

/// Activate with an `FP1.…` license. Returns an SDK status code.
Future<int> setActivation(String license) async {
  final res = await _channel.invokeMethod<Object?>(
    'setActivation',
    {'license': license},
  );
  return _toInt(res, sdkNotActivated);
}

/// Load engine + models. Returns an SDK status code (0 = success).
Future<int> init() async {
  final res = await _channel.invokeMethod<Object?>('init');
  return _toInt(res, sdkInitFailed);
}

/// Release engine + models.
Future<void> deinit() async {
  await _channel.invokeMethod<Object?>('deinit');
}

/// Human-readable detail for the last license failure.
Future<String> lastLicenseError() async {
  final res = await _channel.invokeMethod<Object?>('lastLicenseError');
  return res is String ? res : '';
}

/// License tier JSON: licensed, level, recognition, liveness, label.
Future<String> getLicenseStatus() async {
  final res = await _channel.invokeMethod<Object?>('getLicenseStatus');
  return res is String ? res : '';
}

/// Persist an arbitrary status payload (written to app storage by native).
Future<void> writeStatus(Map<String, dynamic> payload) async {
  await _channel.invokeMethod<Object?>(
    'writeStatus',
    {'payload': jsonEncode(payload)},
  );
}

/// Detect faces + requested attributes in [imageUri].
Future<List<FaceBox>> faceDetection(
  String imageUri, [
  FaceDetectionParam param = const FaceDetectionParam(),
]) async {
  final res = await _channel.invokeMethod<Object?>('faceDetection', {
    'image': imageUri,
    'imageUri': imageUri,
    'param': jsonEncode(param.toJson()),
  });
  if (res is! String || res.isEmpty) return const [];
  try {
    final decoded = jsonDecode(res);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => _normalizeFaceBox(FaceBox.fromJson(
              Map<Object?, Object?>.from(e),
            )))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// Extract a recognition template for [faceBox]; returns base64 (NO_WRAP).
Future<String> templateExtraction(String imageUri, FaceBox faceBox) async {
  final boxJson = faceBox.toJsonString();
  final res = await _channel.invokeMethod<Object?>('templateExtraction', {
    'image': imageUri,
    'imageUri': imageUri,
    'faceBox': boxJson,
    'faceBoxJson': boxJson,
  });
  return res is String ? res : '';
}

/// Crop [faceBox] from [imageUri]; returns a base64 JPEG (NO_WRAP).
Future<String> cropFace(String imageUri, FaceBox faceBox) async {
  final boxJson = faceBox.toJsonString();
  final res = await _channel.invokeMethod<Object?>('cropFace', {
    'image': imageUri,
    'imageUri': imageUri,
    'faceBox': boxJson,
    'faceBoxJson': boxJson,
  });
  return res is String ? res : '';
}

/// Start VideoWorker tracking. Returns 0 on success.
Future<int> startVideoWorker(VideoWorkerConfig config) async {
  final configJson = jsonEncode(config.toJson());
  final res = await _channel.invokeMethod<Object?>('startVideoWorker', {
    'config': configJson,
    'configJson': configJson,
  });
  return _toInt(res, -1);
}

/// Stop VideoWorker tracking.
Future<void> stopVideoWorker() async {
  await _channel.invokeMethod<Object?>('stopVideoWorker');
}

/// Load enrolled feature templates into VideoWorker. Returns 0 on success.
Future<int> syncVideoWorkerDatabase(
  List<String> features, {
  double matchThreshold = 0.67,
}) async {
  final res = await _channel.invokeMethod<Object?>('syncVideoWorkerDatabase', {
    'features': features,
    'matchThreshold': matchThreshold,
  });
  return _toInt(res, -1);
}

/// Prepare a camera snapshot and feed it into VideoWorker.
Future<LiveFrameResult> ingestLiveCameraFrame(
  LiveCameraPhoto photo,
  LiveFrameOptions options,
) async {
  final uri = _resolveLiveUri(photo.path);
  final maxEdge = (options.maxEdge != null && options.maxEdge! > 0)
      ? options.maxEdge!
      : liveFrameMaxEdge;

  double rotateDegrees;
  if (options.rotateDegrees != null && options.rotateDegrees!.isFinite) {
    rotateDegrees = options.rotateDegrees!;
  } else {
    final probed = await _channel.invokeMethod<Object?>('probeLiveImage', {
      'image': uri,
      'imageUri': uri,
    });
    final pm = probed is Map ? probed : const <Object?, Object?>{};
    final plan = planLiveFrame(
      frontCamera: options.frontCamera,
      orientation: options.orientation ?? photo.orientation,
      width: _toDouble(pm['width']),
      height: _toDouble(pm['height']),
      maxEdge: maxEdge,
      platform: _platformName(),
    );
    rotateDegrees = plan.rotateDegrees;
  }

  final raw = await _channel.invokeMethod<Object?>('applyLiveFrame', {
    'image': uri,
    'imageUri': uri,
    'rotateDegrees': rotateDegrees,
    'maxEdge': maxEdge,
    'feedWorker': true,
  });
  return LiveFrameResult.fromMap(
    raw is Map ? Map<Object?, Object?>.from(raw) : null,
  );
}

/// Export the last ingested live frame as a JPEG file URI.
Future<ExportedFrame> exportLastLiveFrame() async {
  final raw = await _channel.invokeMethod<Object?>('exportLastLiveFrame');
  return ExportedFrame.fromMap(
    raw is Map ? Map<Object?, Object?>.from(raw) : null,
  );
}

/// Feed a silent preview [CameraImage] into VideoWorker (no takePicture shutter).
///
/// Rotates preview pixels using [sensorOrientation] (same upright result as
/// takePicture + EXIF bake), then applies [planLiveFrame] with explicit
/// rotateDegrees — no extra mirror/flip in the processing path.
Future<LiveFrameResult> ingestCameraPreviewFrame(
  CameraImage image, {
  required int sensorOrientation,
  required bool frontCamera,
  String? orientation,
  int quality = 70,
  int maxEdge = liveFrameMaxEdge,
}) async {
  final upright = uprightCameraImage(
    image,
    sensorOrientation,
    frontCamera: frontCamera,
  );
  if (upright == null) {
    return const LiveFrameResult(ingested: false, width: 0, height: 0);
  }
  final jpeg = img.encodeJpg(upright, quality: quality);
  if (jpeg.isEmpty) {
    return const LiveFrameResult(ingested: false, width: 0, height: 0);
  }
  final path =
      '${Directory.systemTemp.path}/fr_frame_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(path).writeAsBytes(jpeg, flush: false);
  try {
    final plan = planLiveFrame(
      frontCamera: frontCamera,
      orientation: orientation,
      width: upright.width.toDouble(),
      height: upright.height.toDouble(),
      maxEdge: maxEdge,
      platform: _platformName(),
      uprightBaked: true,
    );
    return await ingestLiveCameraFrame(
      LiveCameraPhoto(path: path, orientation: orientation),
      LiveFrameOptions(
        frontCamera: frontCamera,
        orientation: orientation,
        rotateDegrees: plan.rotateDegrees,
        maxEdge: plan.maxEdge,
      ),
    );
  } finally {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

/// Alias kept for callers that used the earlier preview-stream API name.
Future<LiveFrameResult> feedCameraFrame(
  CameraImage image, {
  required int sensorOrientation,
  required bool frontCamera,
  int quality = 70,
  int maxEncodeEdge = liveFrameMaxEdge,
}) {
  return ingestCameraPreviewFrame(
    image,
    sensorOrientation: sensorOrientation,
    frontCamera: frontCamera,
    quality: quality,
    maxEdge: maxEncodeEdge,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _toInt(Object? v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _platformName() {
  return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

String _resolveLiveUri(String path) {
  if (path.startsWith('file://') ||
      path.startsWith('content:') ||
      path.startsWith('data:')) {
    return path;
  }
  if (path.startsWith('/')) return 'file://$path';
  return path;
}

String _fmtAttr(String? label, double? score) {
  final l = (label ?? '').trim();
  if (l.isEmpty && (score == null || !score.isFinite)) return '';
  if (l.contains(' · ')) return l;
  if (l.isNotEmpty &&
      score != null &&
      score.isFinite &&
      score >= 0 &&
      score <= 1) {
    return '$l · ${(score * 100).round()}%';
  }
  return l;
}

String _occlusionFromScore(double? score) {
  if (score == null || !score.isFinite || score <= 0.001) return '';
  if (score > 0.5) return 'Occluded · ${(score * 100).round()}%';
  return 'Clear · ${((1 - score) * 100).round()}%';
}

/// Fill an iOS-shaped `attributes` map when the engine omitted one
/// (Android typed FaceBox), mirroring RN `normalizeFaceBox`.
FaceBox _normalizeFaceBox(FaceBox box) {
  if (box.attributes != null && box.attributes!.isNotEmpty) return box;

  final attrs = <String, String>{};
  void put(String key, String? value) {
    final v = (value ?? '').trim();
    if (v.isNotEmpty) attrs[key] = v;
  }

  put('Age', (box.age != null && box.age! > 0) ? box.age!.round().toString() : '');
  put('Gender', box.genderLabel);
  put('Emotion', box.emotionLabel);
  put('MedicalMask', box.maskLabel);
  put('Liveness2D', _fmtAttr(box.livenessLabel, box.liveness));
  put(
    'FaceQuality',
    (box.qualityLabel != null && box.qualityLabel!.trim().isNotEmpty)
        ? box.qualityLabel!.trim()
        : ((box.faceQuality != null && box.faceQuality! > 0)
            ? box.faceQuality!.toString()
            : ''),
  );
  put('EyesLeft', box.eyesLeftLabel);
  put('EyesRight', box.eyesRightLabel);
  put('Glasses', box.glassesLabel);
  put('Sunglasses', box.sunglassesLabel);

  final occlusion =
      (box.occlusionLabel != null && box.occlusionLabel!.trim().isNotEmpty)
          ? box.occlusionLabel!.trim()
          : _occlusionFromScore(box.faceOcclusion);
  put('Occlusion', occlusion);

  return box.copyWith(
    glassesLabel: box.glassesLabel ?? '',
    sunglassesLabel: box.sunglassesLabel ?? '',
    occlusionLabel: occlusion.isNotEmpty ? occlusion : (box.occlusionLabel ?? ''),
    attributes: attrs.isEmpty ? null : attrs,
  );
}
