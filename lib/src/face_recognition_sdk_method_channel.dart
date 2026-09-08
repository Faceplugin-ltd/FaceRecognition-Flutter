import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'face_recognition_sdk_platform_interface.dart';

/// Method/event channel implementation for FaceRecognition SDK.
class MethodChannelFaceRecognitionSdk extends FaceRecognitionSdkPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('FaceRecognitionSdk');

  @visibleForTesting
  final EventChannel eventChannel =
      const EventChannel('FaceRecognitionSdk/videoWorker');

  StreamSubscription<dynamic>? _eventSub;
  StreamController<String>? _controller;

  @override
  Stream<String> get videoWorkerEvents {
    _controller ??= StreamController<String>.broadcast(
      onListen: _ensureEventSubscription,
      onCancel: () {
        if (_controller?.hasListener == false) {
          _eventSub?.cancel();
          _eventSub = null;
        }
      },
    );
    return _controller!.stream;
  }

  void _ensureEventSubscription() {
    if (_eventSub != null) return;
    _eventSub = eventChannel.receiveBroadcastStream().listen(
      (event) {
        final json = _extractEventJson(event);
        _controller?.add(json);
      },
      onError: (Object error, StackTrace stack) {
        _controller?.addError(error, stack);
      },
    );
  }

  String _extractEventJson(dynamic event) {
    if (event is String) return event;
    if (event is Map) {
      final json = event['json'];
      if (json is String) return json;
      return '{}';
    }
    return '{}';
  }

  @override
  Future<String> getMachineCode() async {
    final result = await methodChannel.invokeMethod<String>('getMachineCode');
    return result ?? '';
  }

  @override
  Future<int> setActivation(String license) async {
    // Pass a bare String — native plugins expect call.arguments as String
    // (Map {'license': …} was cast to null → "" → "empty license").
    final result =
        await methodChannel.invokeMethod<int>('setActivation', license);
    return result ?? 4;
  }

  @override
  Future<int> init() async {
    final result = await methodChannel.invokeMethod<int>('init');
    return result ?? 4;
  }

  @override
  Future<void> deinit() async {
    await methodChannel.invokeMethod<void>('deinit');
  }

  @override
  Future<String> lastLicenseError() async {
    final result = await methodChannel.invokeMethod<String>('lastLicenseError');
    return result ?? '';
  }

  @override
  Future<String> getLicenseStatus() async {
    final result = await methodChannel.invokeMethod<String>('getLicenseStatus');
    return result ??
        '{"licensed":false,"level":-1,"levelName":"None","recognition":false,"liveness":false,"label":"Not licensed"}';
  }

  @override
  Future<int> setLandmarkMode(int mode) async {
    final result =
        await methodChannel.invokeMethod<int>('setLandmarkMode', mode);
    return result ?? mode;
  }

  @override
  Future<int> getLandmarkMode() async {
    final result = await methodChannel.invokeMethod<int>('getLandmarkMode');
    return result ?? 68;
  }

  @override
  Future<String> detect(
    String image, {
    bool crop = false,
    int flags = 0xffffffff,
  }) async {
    final result = await methodChannel.invokeMethod<String>(
      'detect',
      <String, dynamic>{
        'image': image,
        'crop': crop,
        'flags': flags,
      },
    );
    return result ?? '[]';
  }

  @override
  Future<String> faceDetection(String image, Map<String, dynamic>? param) async {
    // Native Android stringArg only accepts JSON strings (RN does JSON.stringify).
    // Sending a Map silently dropped allAttributes → empty emotion / broken liveness.
    final result = await methodChannel.invokeMethod<String>(
      'faceDetection',
      <String, dynamic>{
        'image': image,
        'param': param == null ? null : jsonEncode(param),
      },
    );
    return result ?? '[]';
  }

  @override
  Future<String> templateExtraction(String image, String faceBoxJson) async {
    final result = await methodChannel.invokeMethod<String>(
      'templateExtraction',
      <String, dynamic>{
        'image': image,
        'faceBox': faceBoxJson,
      },
    );
    return result ?? '';
  }

  @override
  Future<String> cropFace(String image, String faceBoxJson) async {
    final result = await methodChannel.invokeMethod<String>(
      'cropFace',
      <String, dynamic>{
        'image': image,
        'faceBox': faceBoxJson,
      },
    );
    return result ?? '';
  }

  @override
  Future<String> extractFeature(String image) async {
    final result = await methodChannel.invokeMethod<String>(
      'extractFeature',
      <String, dynamic>{'image': image},
    );
    return result ?? '';
  }

  @override
  Future<double> similarity(String feature1B64, String feature2B64) async {
    final result = await methodChannel.invokeMethod<num>(
      'similarity',
      <String, dynamic>{
        'feature1': feature1B64,
        'feature2': feature2B64,
      },
    );
    return result?.toDouble() ?? 0.0;
  }

  @override
  Future<String> quality(String image, {bool crop = false}) async {
    final result = await methodChannel.invokeMethod<String>(
      'quality',
      <String, dynamic>{
        'image': image,
        'crop': crop,
      },
    );
    return result ?? '';
  }

  @override
  Future<int> startVideoWorker(String configJson) async {
    final result = await methodChannel.invokeMethod<int>(
      'startVideoWorker',
      <String, dynamic>{'config': configJson},
    );
    return result ?? 4;
  }

  @override
  Future<void> stopVideoWorker() async {
    await methodChannel.invokeMethod<void>('stopVideoWorker');
  }

  @override
  Future<int> syncVideoWorkerDatabase(
    List<String> featuresB64, {
    double matchThreshold = 0.67,
  }) async {
    final result = await methodChannel.invokeMethod<int>(
      'syncVideoWorkerDatabase',
      <String, dynamic>{
        'features': featuresB64,
        'matchThreshold': matchThreshold,
      },
    );
    return result ?? 4;
  }

  @override
  Future<Map<Object?, Object?>> probeLiveImage(String imageUri) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'probeLiveImage',
      <String, dynamic>{'image': imageUri},
    );
    return result ?? <Object?, Object?>{'width': 0, 'height': 0};
  }

  @override
  Future<Map<Object?, Object?>> applyLiveFrame(
    String imageUri, {
    required int rotateDegrees,
    required int maxEdge,
    required bool feedWorker,
  }) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'applyLiveFrame',
      <String, dynamic>{
        'image': imageUri,
        'rotateDegrees': rotateDegrees,
        'maxEdge': maxEdge,
        'feedWorker': feedWorker,
      },
    );
    return result ??
        <Object?, Object?>{
          'ingested': false,
          'width': 0,
          'height': 0,
          'uri': null,
        };
  }

  @override
  Future<Map<Object?, Object?>> exportLastLiveFrame() async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'exportLastLiveFrame',
    );
    return result ??
        <Object?, Object?>{
          'ingested': false,
          'width': 0,
          'height': 0,
          'uri': null,
        };
  }

  @override
  Future<void> writeStatus(String json) async {
    await methodChannel.invokeMethod<void>('writeStatus', json);
  }
}
