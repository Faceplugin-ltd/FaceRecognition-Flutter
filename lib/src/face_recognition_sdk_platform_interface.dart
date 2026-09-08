import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'face_recognition_sdk_method_channel.dart';

/// Platform interface for FaceRecognition SDK native bridges.
abstract class FaceRecognitionSdkPlatform extends PlatformInterface {
  FaceRecognitionSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FaceRecognitionSdkPlatform _instance = MethodChannelFaceRecognitionSdk();

  static FaceRecognitionSdkPlatform get instance => _instance;

  static set instance(FaceRecognitionSdkPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  Stream<String> get videoWorkerEvents {
    throw UnimplementedError('videoWorkerEvents has not been implemented.');
  }

  Future<String> getMachineCode() {
    throw UnimplementedError('getMachineCode() has not been implemented.');
  }

  Future<int> setActivation(String license) {
    throw UnimplementedError('setActivation() has not been implemented.');
  }

  Future<int> init() {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<void> deinit() {
    throw UnimplementedError('deinit() has not been implemented.');
  }

  Future<String> lastLicenseError() {
    throw UnimplementedError('lastLicenseError() has not been implemented.');
  }

  Future<String> getLicenseStatus() {
    throw UnimplementedError('getLicenseStatus() has not been implemented.');
  }

  Future<int> setLandmarkMode(int mode) {
    throw UnimplementedError('setLandmarkMode() has not been implemented.');
  }

  Future<int> getLandmarkMode() {
    throw UnimplementedError('getLandmarkMode() has not been implemented.');
  }

  Future<String> detect(String image, {bool crop = false, int flags = 0xffffffff}) {
    throw UnimplementedError('detect() has not been implemented.');
  }

  Future<String> faceDetection(String image, Map<String, dynamic>? param) {
    throw UnimplementedError('faceDetection() has not been implemented.');
  }

  Future<String> templateExtraction(String image, String faceBoxJson) {
    throw UnimplementedError('templateExtraction() has not been implemented.');
  }

  Future<String> cropFace(String image, String faceBoxJson) {
    throw UnimplementedError('cropFace() has not been implemented.');
  }

  Future<String> extractFeature(String image) {
    throw UnimplementedError('extractFeature() has not been implemented.');
  }

  Future<double> similarity(String feature1B64, String feature2B64) {
    throw UnimplementedError('similarity() has not been implemented.');
  }

  Future<String> quality(String image, {bool crop = false}) {
    throw UnimplementedError('quality() has not been implemented.');
  }

  Future<int> startVideoWorker(String configJson) {
    throw UnimplementedError('startVideoWorker() has not been implemented.');
  }

  Future<void> stopVideoWorker() {
    throw UnimplementedError('stopVideoWorker() has not been implemented.');
  }

  Future<int> syncVideoWorkerDatabase(
    List<String> featuresB64, {
    double matchThreshold = 0.67,
  }) {
    throw UnimplementedError('syncVideoWorkerDatabase() has not been implemented.');
  }

  Future<Map<Object?, Object?>> probeLiveImage(String imageUri) {
    throw UnimplementedError('probeLiveImage() has not been implemented.');
  }

  Future<Map<Object?, Object?>> applyLiveFrame(
    String imageUri, {
    required int rotateDegrees,
    required int maxEdge,
    required bool feedWorker,
  }) {
    throw UnimplementedError('applyLiveFrame() has not been implemented.');
  }

  Future<Map<Object?, Object?>> exportLastLiveFrame() {
    throw UnimplementedError('exportLastLiveFrame() has not been implemented.');
  }

  Future<void> writeStatus(String json) {
    throw UnimplementedError('writeStatus() has not been implemented.');
  }
}
