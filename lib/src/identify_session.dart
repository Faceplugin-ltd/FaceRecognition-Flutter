import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'capture_logic.dart';
import 'channel.dart';
import 'face_box.dart';
import 'models.dart';
import 'video_worker.dart';

class IdentifySettings {
  const IdentifySettings({
    required this.frontCamera,
    required this.matchThreshold,
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

/// Live 1:N identify — VideoWorker + silent frame ingest (RN `IdentifySession`).
class IdentifySession {
  IdentifySession({
    required this.settings,
    required this.featureTemplates,
    required this.onTracking,
    required this.onMatch,
  });

  final IdentifySettings settings;
  final List<String> featureTemplates;
  final void Function(List<FaceBox> boxes, Size frame) onTracking;
  final void Function(int personIndex, double score) onMatch;

  Size frameSize = const Size(480, 640);
  String? lastUri;
  List<FaceBox> lastLiveness = const [];

  /// Flutter front preview is mirrored on both platforms; Android JPEG is not.
  bool get overlayMirror => settings.frontCamera && Platform.isAndroid;

  CameraController? _controller;
  StreamSubscription<String>? _eventsSub;
  Timer? _poll;
  bool _streaming = false;
  bool _cancelled = false;
  bool _workerReady = false;
  bool _snapBusy = false;
  bool _livBusy = false;
  int _lastFrameMs = 0;
  int _lastLivenessMs = 0;

  Future<void> attach(CameraController controller) async {
    _controller = controller;
  }

  Future<void> start() async {
    _cancelled = false;
    _eventsSub = videoWorkerEvents.listen(_onWorkerEvent);

    final started = await startVideoWorker(
      VideoWorkerConfig(matchThreshold: settings.matchThreshold),
    );
    final synced = await syncVideoWorkerDatabase(
      featureTemplates,
      matchThreshold: settings.matchThreshold,
    );
    if (!_cancelled) {
      _workerReady = started == 0 && synced == 0;
    }

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
    _cancelled = true;
    _workerReady = false;
  }

  Future<void> stop() async {
    leave();
    _poll?.cancel();
    _poll = null;
    await _stopStream();
    await _eventsSub?.cancel();
    _eventsSub = null;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while ((_livBusy || _snapBusy) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await stopVideoWorker();
  }

  Future<void> dispose() => stop();

  void _onWorkerEvent(String json) {
    if (_cancelled) return;
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
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized || _streaming) return;
    await cam.startImageStream(_onCameraImage);
    _streaming = true;
  }

  Future<void> _stopStream() async {
    final cam = _controller;
    if (cam == null || !_streaming) return;
    try {
      if (cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}
    _streaming = false;
  }

  void _onCameraImage(CameraImage image) {
    if (_cancelled || !_workerReady || _snapBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < settings.frameIntervalMs) return;
    _lastFrameMs = now;
    _snapBusy = true;
    unawaited(_processStreamFrame(image));
  }

  Future<void> _tickAndroid() async {
    if (_cancelled ||
        !_workerReady ||
        _snapBusy ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _snapBusy = true;
    try {
      final cam = _controller!;
      final photo = await cam.takePicture();
      final live = await ingestLiveCameraFrame(
        LiveCameraPhoto(path: photo.path),
        LiveFrameOptions(frontCamera: settings.frontCamera),
      );
      await _afterLiveFrame(live);
    } catch (_) {
      // Camera warming up.
    } finally {
      _snapBusy = false;
    }
  }

  Future<void> _processStreamFrame(CameraImage image) async {
    try {
      final cam = _controller!;
      final live = await feedCameraFrame(
        image,
        sensorOrientation: cam.description.sensorOrientation,
        frontCamera: settings.frontCamera,
      );
      await _afterLiveFrame(live);
    } catch (_) {
      // Preview frame can fail while camera warms up.
    } finally {
      _snapBusy = false;
    }
  }

  Future<void> _afterLiveFrame(LiveFrameResult live) async {
    if (!live.ingested || _cancelled) return;
    if (live.width > 0 && live.height > 0) {
      frameSize = Size(live.width, live.height);
    }
    try {
      final exported = await exportLastLiveFrame();
      final uri = exported.uri;
      if (uri == null || uri.isEmpty) return;
      lastUri = uri;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_livBusy || now - _lastLivenessMs < settings.livenessIntervalMs) {
        return;
      }
      if (_cancelled || !_workerReady) return;
      _lastLivenessMs = now;
      _livBusy = true;
      try {
        if (_cancelled) return;
        final liv = await faceDetection(
          uri,
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
