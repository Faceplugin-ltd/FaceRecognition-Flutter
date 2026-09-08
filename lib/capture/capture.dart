import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/engine.dart'
    show
        cropFace,
        exportLastLiveFrame,
        faceDetection,
        startVideoWorker,
        stopVideoWorker,
        videoWorkerEvents;
import '../api/types.dart'
    show
        FaceBox,
        FaceDetectionParam,
        LiveCameraPhoto,
        LiveFrameOptions,
        VideoWorkerConfig;
import '../live/live_frame.dart' show ingestLiveCameraFrame;
import 'capture_logic.dart';
import 'capture_overlay.dart';
import 'cover_camera_preview.dart';
import 'video_worker.dart';

export 'capture_logic.dart';
export 'capture_overlay.dart';
export 'cover_camera_preview.dart';
export 'video_worker.dart';

String _qualityText(double score) {
  if (score < 0.5) return 'Low · ${(score * 100).round()}%';
  if (score < 0.75) return 'Medium · ${(score * 100).round()}%';
  return 'High · ${(score * 100).round()}%';
}

/// Ready-made Capture mode UI (oval guide + VideoWorker + eye/pose gates).
///
/// Matches FaceRecognitionSDK Apps / FaceRecognition-ReactNative-App Capture.
class FaceCapture extends StatefulWidget {
  const FaceCapture({
    super.key,
    required this.settings,
    required this.onCaptured,
    this.onCancel,
    this.renderActions,
    this.title = 'Face Capture',
  });

  final CaptureSettings settings;
  final ValueChanged<CaptureResult> onCaptured;
  final VoidCallback? onCancel;

  /// Optional actions under the result metrics (e.g. Enroll).
  final Widget Function(CaptureResult result)? renderActions;
  final String title;

  @override
  State<FaceCapture> createState() => _FaceCaptureState();
}

class _FaceCaptureState extends State<FaceCapture> {
  CameraController? _controller;
  StreamSubscription<String>? _eventsSub;
  Timer? _poll;

  bool _initializing = true;
  bool _workerReady = false;
  bool _snapBusy = false;
  bool _eyesBusy = false;
  bool _showResult = false;

  CaptureViewMode _viewMode = CaptureViewMode.noFacePrepare;
  String _warning = '';
  FaceBox? _faceBox;
  FaceBox? _capturedFace;
  FaceBox? _resultBox;
  OvalMetrics _frame = const OvalMetrics(width: 720, height: 1280);
  String? _captureUri;
  String? _lastUri;
  List<FaceBox> _lastEyes = const [];
  CaptureResult? _captureResult;

  CaptureSettings get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _eventsSub?.cancel();
    unawaited(stopVideoWorker());
    _controller?.dispose();
    super.dispose();
  }

  void _setMode(CaptureViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
  }

  Future<void> _bootstrap() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _warning = 'Camera permission required';
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final preferFront = _s.cameraLens == CameraLens.front;
      final selected = cameras.firstWhere(
        (c) => preferFront
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;

      _eventsSub = videoWorkerEvents.listen(_onWorkerEvent);
      final code = await startVideoWorker(
        VideoWorkerConfig(matchThreshold: _s.matchThreshold),
      );
      _workerReady = code == 0;

      _poll = Timer.periodic(const Duration(milliseconds: 120), (_) {
        unawaited(_tick());
      });

      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _warning = 'Camera failed: $e';
        });
      }
    }
  }

  Future<void> _beginCapture(List<FaceBox> boxes) async {
    try {
      final exported = await exportLastLiveFrame();
      if (exported.uri != null && exported.uri!.isNotEmpty && boxes.isNotEmpty) {
        _lastUri = exported.uri;
        _captureUri = exported.uri;
        _capturedFace = boxes.first;
        if (exported.width > 0 && exported.height > 0) {
          _frame = OvalMetrics(
            width: exported.width.toDouble(),
            height: exported.height.toDouble(),
          );
        }
      }
    } catch (_) {}
    _warning = '';
    _setMode(CaptureViewMode.faceCapturePrepare);
  }

  void _onWorkerEvent(String json) {
    if (!mounted) return;
    final mode = _viewMode;
    if (mode == CaptureViewMode.faceCaptureDone ||
        mode == CaptureViewMode.noFacePrepare) {
      return;
    }
    final ev = parseVideoWorkerEvent(json);
    if (ev is! VideoWorkerTracking) return;

    var boxes = ev.faces
        .where((f) => !f.weak)
        .map(workerFaceToBox)
        .toList(growable: false);
    boxes = mergeEyes(
      boxes,
      _lastEyes,
      swapLeftRight: _s.cameraLens == CameraLens.front,
    );
    final state = checkFace(boxes, _s, _frame);
    setState(() => _faceBox = boxes.isNotEmpty ? boxes.first : null);

    if (mode == CaptureViewMode.repeatNoFacePrepare) {
      if (state != FaceCaptureState.noFace) {
        _setMode(CaptureViewMode.toFaceCircle);
      }
      return;
    }

    if (mode == CaptureViewMode.faceCircle) {
      if (state == FaceCaptureState.noFace) {
        setState(() {
          _warning = '';
        });
        _setMode(CaptureViewMode.faceCircleToNoFace);
        return;
      }
      if (state == FaceCaptureState.captureOk) {
        unawaited(_beginCapture(boxes));
        return;
      }
      setState(() {
        _warning = warningFor(state);
      });
      return;
    }

    if (mode == CaptureViewMode.faceCapturePrepare) {
      if (state == FaceCaptureState.captureOk && boxes.isNotEmpty) {
        unawaited(() async {
          try {
            final exported = await exportLastLiveFrame();
            if (exported.uri == null || exported.uri!.isEmpty) return;
            if (!mounted) return;
            setState(() {
              _lastUri = exported.uri;
              _captureUri = exported.uri;
              _capturedFace = boxes.first;
            });
          } catch (_) {}
        }());
      }
    }
  }

  Future<void> _tick() async {
    final mode = _viewMode;
    if (!_workerReady ||
        _snapBusy ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        mode == CaptureViewMode.noFacePrepare ||
        mode == CaptureViewMode.faceCaptureDone) {
      return;
    }
    _snapBusy = true;
    try {
      final photo = await _controller!.takePicture();
      final front = _s.cameraLens == CameraLens.front;
      final live = await ingestLiveCameraFrame(
        LiveCameraPhoto(path: photo.path),
        LiveFrameOptions(frontCamera: front),
      );
      if (!live.ingested) return;
      if (live.width > 0 && live.height > 0 && mounted) {
        setState(() {
          _frame = OvalMetrics(
            width: live.width.toDouble(),
            height: live.height.toDouble(),
          );
        });
      }
      try {
        final exported = await exportLastLiveFrame();
        if (exported.uri != null && exported.uri!.isNotEmpty) {
          _lastUri = exported.uri;
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      _snapBusy = false;
    }
  }

  Future<void> _finishWithResult(FaceBox? shown, String? bitmapUri) async {
    if (shown == null || bitmapUri == null || bitmapUri.isEmpty) {
      if (mounted) setState(() => _showResult = true);
      return;
    }
    final still = checkFace([shown], _s, _frame);
    if (still == FaceCaptureState.faceOccluded) {
      _warning = 'Face occluded!';
    } else if (still == FaceCaptureState.eyeClosed) {
      _warning = 'Eye closed!';
    }

    String? cropB64;
    try {
      cropB64 = await cropFace(bitmapUri, shown);
    } catch (_) {
      cropB64 = null;
    }
    final result = CaptureResult(
      uri: bitmapUri,
      faceBox: shown,
      cropB64: cropB64,
    );
    if (!mounted) return;
    setState(() {
      _resultBox = shown;
      _capturedFace = shown;
      _captureResult = result;
      _showResult = true;
    });
    widget.onCaptured(result);
  }

  Future<void> _onModeFinished(CaptureViewMode mode) async {
    switch (mode) {
      case CaptureViewMode.noFacePrepare:
        _setMode(CaptureViewMode.repeatNoFacePrepare);
      case CaptureViewMode.toFaceCircle:
        _setMode(CaptureViewMode.faceCircle);
      case CaptureViewMode.faceCircleToNoFace:
        _setMode(CaptureViewMode.noFacePrepare);
      case CaptureViewMode.faceCapturePrepare:
        _setMode(CaptureViewMode.faceCaptureDone);
      case CaptureViewMode.faceCaptureDone:
        final uri = _lastUri;
        final fallback = _capturedFace;
        if (uri == null || uri.isEmpty) {
          if (mounted) setState(() => _showResult = true);
          return;
        }
        try {
          await stopVideoWorker();
          final boxes = await faceDetection(
            uri,
            FaceDetectionParam(
              allAttributes: true,
              checkLivenessLevel: _s.livenessLevel,
            ),
          );
          await _finishWithResult(boxes.isNotEmpty ? boxes.first : fallback, uri);
        } catch (_) {
          await _finishWithResult(fallback, uri);
        }
      case CaptureViewMode.repeatNoFacePrepare:
      case CaptureViewMode.faceCircle:
        break;
    }
  }

  String _livenessLine(FaceBox? shown) {
    if (shown == null) return '';
    final label = (shown.livenessLabel ?? '').toLowerCase();
    if (label.contains('spoof') || label.contains('fake')) {
      return 'Liveness: Spoof, score = ${shown.liveness ?? 0}';
    }
    if ((shown.liveness ?? 0) >= _s.livenessThreshold) {
      return 'Liveness: Real, score = ${shown.liveness ?? 0}';
    }
    return 'Liveness: Spoof, score = ${shown.liveness ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final size = MediaQuery.sizeOf(context);
    final front = _s.cameraLens == CameraLens.front;
    // Flutter camera front preview is mirrored (like CameraX / SDK Apps).
    final mirrorOverlay = front;
    final shown = _resultBox;

    if (_initializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF303033),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD0BCFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_viewMode != CaptureViewMode.faceCaptureDone &&
              controller != null &&
              controller.value.isInitialized)
            CoverCameraPreview(controller: controller)
          else
            const ColoredBox(color: Color(0xFF303033)),
          CaptureOverlay(
            width: size.width,
            height: size.height,
            frame: _frame,
            mirror: mirrorOverlay,
            viewMode: _viewMode,
            faceBox: _faceBox,
            capturedUri: _captureUri,
            onModeFinished: (m) => unawaited(_onModeFinished(m)),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 0,
            right: 0,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE6E1E5),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 48 / 22,
              ),
            ),
          ),
          if (_showResult)
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AspectRatio(aspectRatio: 1, child: SizedBox.expand()),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 16),
                    child: Text(
                      _livenessLine(shown),
                      style: const TextStyle(
                        color: Color(0xFFE6E1E5),
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 16),
                    child: Text(
                      '${_qualityText(shown?.faceQuality ?? 0)}'
                      '${(shown?.qualityLabel ?? '').isNotEmpty ? '\n${shown!.qualityLabel}' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFE6E1E5),
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 16),
                    child: Text(
                      'Luminance: ${shown?.faceLuminance ?? 0}',
                      style: const TextStyle(
                        color: Color(0xFFE6E1E5),
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (_captureResult != null && widget.renderActions != null)
                    widget.renderActions!(_captureResult!),
                ],
              ),
            ),
          if (widget.onCancel != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 40,
              left: 16,
              child: Material(
                color: const Color(0xFF4F378B),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onCancel,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back, color: Color(0xFFE6E1E5)),
                  ),
                ),
              ),
            ),
          // Always paint coaching / post-capture warnings above camera, oval, and result.
          if (_warning.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Text(
                  _warning,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Color(0xCC000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
