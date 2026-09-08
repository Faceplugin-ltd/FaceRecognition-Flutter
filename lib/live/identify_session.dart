import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';

import '../api/engine.dart';
import '../api/types.dart';
import '../capture/capture_logic.dart';
import '../capture/video_worker.dart';
import 'live_frame.dart';

class IdentifySettings {
  const IdentifySettings({
    required this.frontCamera,
    this.matchThreshold = 0.67,
    this.livenessLevel = 0,
    this.frameIntervalMs = 120,
    this.livenessIntervalMs = 450,
  });

  final bool frontCamera;
  final double matchThreshold;
  final int livenessLevel;
  final int frameIntervalMs;
  final int livenessIntervalMs;
}

class IdentifySession {
  IdentifySession({
    required this.settings,
    required this.featureTemplates,
    required this.onTracking,
    required this.onMatch,
  });

  final IdentifySettings settings;
  final List<String> featureTemplates;
  final void Function(List<FaceBox> boxes, Size frameSize) onTracking;
  final void Function(int personIndex, double score) onMatch;

  CameraController? _camera;
  StreamSubscription<String>? _eventsSub;
  Timer? _poll;
  bool _workerReady = false;
  bool _streaming = false;
  bool _snapBusy = false;
  bool _livBusy = false;
  bool _stopped = false;
  int _lastFrameMs = 0;
  int _lastLivenessMs = 0;

  List<FaceBox> lastLiveness = const [];
  Size frameSize = const Size(480, 640);
  String? lastUri;

  /// Flutter front preview is mirrored. Android JPEG frames are not → flip overlay X.
  /// iOS stream pixels are already mirrored (AVFoundation).
  bool get overlayMirror => settings.frontCamera && Platform.isAndroid;

  Future<void> attach(CameraController camera) async {
    _camera = camera;
  }

  Future<void> start() async {
    _stopped = false;
    _eventsSub = videoWorkerEvents.listen(_onWorkerEvent);
    final started = await startVideoWorker(
      VideoWorkerConfig(matchThreshold: settings.matchThreshold),
    );
    final synced = await syncVideoWorkerDatabase(
      featureTemplates,
      matchThreshold: settings.matchThreshold,
    );
    _workerReady = started == 0 && synced == 0;
    if (Platform.isAndroid) {
      _poll = Timer.periodic(
        Duration(milliseconds: settings.frameIntervalMs),
        (_) => unawaited(_tickAndroid()),
      );
    } else {
      await _startStream();
    }
  }

  void leave() {
    _stopped = true;
    _workerReady = false;
  }

  Future<void> stop() async {
    leave();
    _poll?.cancel();
    _poll = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _stopStream();
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while ((_livBusy || _snapBusy) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await stopVideoWorker();
  }

  Future<void> dispose() => stop();

  Future<void> _stopStream() async {
    final cam = _camera;
    if (cam == null || !_streaming) return;
    try {
      if (cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}
    _streaming = false;
  }

  void _onWorkerEvent(String json) {
    if (_stopped) return;
    final ev = parseVideoWorkerEvent(json);
    if (ev == null) return;

    if (ev is VideoWorkerTracking) {
      if (frameSize.width <= 0 && ev.frameWidth > 0 && ev.frameHeight > 0) {
        frameSize = Size(ev.frameWidth, ev.frameHeight);
      }
      var next = ev.faces.map(workerFaceToBox).toList();
      next = mergeLiveness(next, lastLiveness);
      onTracking(next, frameSize);
      for (final f in ev.faces) {
        final m = f.match;
        if (m != null && m.matched && m.personIndex != null) {
          onMatch(m.personIndex!, m.score ?? 0);
          break;
        }
      }
    } else if (ev is VideoWorkerMatchEvent) {
      if (ev.matched && ev.personIndex != null) {
        onMatch(ev.personIndex!, ev.score ?? 0);
      }
    }
  }

  Future<void> _startStream() async {
    if (!Platform.isIOS) return;
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _streaming) return;
    await cam.startImageStream(_onCameraImage);
    _streaming = true;
  }

  void _onCameraImage(CameraImage image) {
    if (_stopped || !_workerReady || _snapBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < settings.frameIntervalMs) return;
    _lastFrameMs = now;
    _snapBusy = true;
    unawaited(_processStreamFrame(image));
  }

  Future<void> _tickAndroid() async {
    if (_stopped ||
        !_workerReady ||
        _snapBusy ||
        _camera == null ||
        !_camera!.value.isInitialized) {
      return;
    }
    _snapBusy = true;
    try {
      final photo = await _camera!.takePicture();
      final live = await ingestLiveCameraFrame(
        LiveCameraPhoto(path: photo.path),
        LiveFrameOptions(frontCamera: settings.frontCamera),
      );
      await _afterLiveFrame(live);
    } catch (_) {
    } finally {
      _snapBusy = false;
    }
  }

  Future<void> _processStreamFrame(CameraImage image) async {
    try {
      final cam = _camera!;
      final live = await feedCameraFrame(
        image,
        sensorOrientation: cam.description.sensorOrientation,
        frontCamera: settings.frontCamera,
      );
      await _afterLiveFrame(live);
    } catch (_) {
    } finally {
      _snapBusy = false;
    }
  }

  Future<void> _afterLiveFrame(LiveFrameResult live) async {
    if (!live.ingested || _stopped) return;
    if (live.width > 0 && live.height > 0) {
      frameSize = Size(live.width.toDouble(), live.height.toDouble());
    }
    try {
      final exported = await exportLastLiveFrame();
      if (exported.uri == null || exported.uri!.isEmpty) return;
      lastUri = exported.uri;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_livBusy || now - _lastLivenessMs < settings.livenessIntervalMs) {
        return;
      }
      if (_stopped || !_workerReady) return;
      _lastLivenessMs = now;
      _livBusy = true;
      try {
        if (_stopped) return;
        final liv = await faceDetection(
          lastUri!,
          FaceDetectionParam(
            checkLiveness: true,
            checkLivenessLevel: settings.livenessLevel,
          ),
        );
        if (liv.isNotEmpty) lastLiveness = liv;
      } finally {
        _livBusy = false;
      }
    } catch (_) {
      _livBusy = false;
    }
  }
}
