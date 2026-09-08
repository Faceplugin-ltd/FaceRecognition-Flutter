import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'capture_logic.dart';
import 'capture_overlay.dart';
import 'channel.dart';
import 'cover_camera_preview.dart';
import 'face_box.dart';
import 'models.dart';
import 'video_worker.dart';

/// Internal capture animation / guide states — see [CaptureViewMode].
typedef _CaptureViewMode = CaptureViewMode;

/// Ready-made Capture UI: oval guide + VideoWorker tracking + eye/pose gates.
///
/// Port of the React Native `FaceCapture` component. Requires camera
/// permission (requested automatically) and `package:camera`.
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
  final void Function(CaptureResult) onCaptured;
  final VoidCallback? onCancel;

  /// Optional actions rendered under the result metrics (e.g. an Enroll button).
  final Widget Function(CaptureResult)? renderActions;
  final String title;

  @override
  State<FaceCapture> createState() => _FaceCaptureState();
}

class _FaceCaptureState extends State<FaceCapture>
    with SingleTickerProviderStateMixin {
  static const _uiText = Color(0xFFE6E1E5);
  static const _uiAccent = Color(0xFFD0BCFF);
  static const _uiAccentDim = Color(0xFF4F378B);
  static const _uiBlackBg = Color(0xFF303033);
  static const _uiDanger = Color(0xFFFF6B6B);
  static const _plainText = TextStyle(decoration: TextDecoration.none);

  CameraController? _controller;
  StreamSubscription<String>? _eventsSub;
  late final AnimationController _anim;
  Animatable<double>? _scaleAnim;

  bool _initializing = true;
  bool _permissionDenied = false;
  bool _workerReady = false;
  bool _busy = false;
  bool _eyesBusy = false;
  bool _cancelled = false;
  bool _streaming = false;
  Timer? _poll;
  int _lastFrameMs = 0;

  _CaptureViewMode _viewMode = _CaptureViewMode.noFacePrepare;
  double _scale = 1.4;
  FrameSize _frame = const FrameSize(720, 1280);
  String? _lastUri;
  List<FaceBox> _lastEyes = const [];
  int _okStreak = 0;

  FaceBox? _faceBox;
  FaceBox? _capturedFace;
  FaceBox? _resultBox;
  String? _captureUri;
  bool _showResult = false;
  CaptureResult? _captureResult;
  String _warning = '';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(() {
        if (_scaleAnim != null && mounted) {
          setState(() => _scale = _scaleAnim!.transform(_anim.value));
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _eventsSub?.cancel();
    _poll?.cancel();
    unawaited(_stopStream());
    unawaited(stopVideoWorker());
    _anim.dispose();
    _controller?.dispose();
    super.dispose();
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

  Future<void> _bootstrap() async {
    final granted = await Permission.camera.request();
    if (!granted.isGranted) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _permissionDenied = true;
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final preferFront = widget.settings.cameraLens == CameraLens.front;
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
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;

      _eventsSub = videoWorkerEvents.listen(_onWorkerEvent);
      try {
        final code = await startVideoWorker(
          VideoWorkerConfig(matchThreshold: widget.settings.matchThreshold),
        );
        _workerReady = code == 0;
      } catch (_) {
        _workerReady = false;
      }

      if (Platform.isAndroid) {
        _poll = Timer.periodic(
          const Duration(milliseconds: 120),
          (_) => unawaited(_tickAndroid()),
        );
      } else {
        await _startStream();
      }

      setState(() => _initializing = false);
      _setMode(_CaptureViewMode.noFacePrepare, force: true);
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // --- Mode animation state machine -----------------------------------------

  void _setMode(_CaptureViewMode mode, {bool force = false}) {
    if (!force && _viewMode == mode) return;
    _viewMode = mode;
    if (mounted) setState(() {});

    _anim.stop();
    switch (mode) {
      case _CaptureViewMode.noFacePrepare:
        _runScaleAnim(
          from: 1.4,
          to: 0.88,
          durationMs: 800,
          curve: Curves.easeOutQuad,
          onDone: () => _setMode(_CaptureViewMode.repeatNoFacePrepare),
        );
        break;
      case _CaptureViewMode.repeatNoFacePrepare:
        _scale = 0.88;
        _scaleAnim = Tween<double>(begin: 0.88, end: 0.92);
        _anim
          ..duration = const Duration(milliseconds: 1300)
          ..repeat(reverse: true)
          ..reset()
          ..forward();
        break;
      case _CaptureViewMode.toFaceCircle:
        _runScaleAnim(
          from: 1.4,
          to: 0,
          durationMs: 800,
          onDone: () => _setMode(_CaptureViewMode.faceCircle),
        );
        break;
      case _CaptureViewMode.faceCircleToNoFace:
        _runScaleAnim(
          from: 0,
          to: 1,
          durationMs: 600,
          onDone: () => _setMode(_CaptureViewMode.noFacePrepare),
        );
        break;
      case _CaptureViewMode.faceCircle:
        _anim.stop();
        _scale = 0;
        break;
      case _CaptureViewMode.faceCapturePrepare:
        _runScaleAnim(
          from: 0,
          to: 1,
          durationMs: 500,
          onDone: () => _setMode(_CaptureViewMode.faceCaptureDone),
        );
        break;
      case _CaptureViewMode.faceCaptureDone:
        _runScaleAnim(
          from: 0,
          to: 1,
          durationMs: 500,
          onDone: _finalizeCapture,
        );
        break;
    }
  }

  void _runScaleAnim({
    required double from,
    required double to,
    required int durationMs,
    VoidCallback? onDone,
    Curve curve = Curves.linear,
  }) {
    _anim.stop();
    _scale = from;
    _scaleAnim = Tween<double>(begin: from, end: to)
        .chain(CurveTween(curve: curve));
    _anim.duration = Duration(milliseconds: durationMs);
    late final void Function(AnimationStatus) listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        _anim.removeStatusListener(listener);
        if (!_cancelled && mounted) onDone?.call();
      }
    };
    _anim.addStatusListener(listener);
    _anim
      ..reset()
      ..forward();
  }

  Future<void> _finalizeCapture() async {
    final uri = _lastUri;
    final fallback = _capturedFace;
    if (uri == null) {
      if (mounted) setState(() => _showResult = true);
      return;
    }
    try {
      final boxes = await faceDetection(
        uri,
        FaceDetectionParam(
          allAttributes: true,
          checkLivenessLevel: widget.settings.livenessLevel,
        ),
      );
      await _finishWithResult(boxes.isNotEmpty ? boxes.first : fallback, uri);
    } catch (_) {
      await _finishWithResult(fallback, uri);
    }
  }

  Future<void> _finishWithResult(FaceBox? shown, String? bitmapUri) async {
    if (shown == null || bitmapUri == null) {
      if (mounted) setState(() => _showResult = true);
      return;
    }
    _resultBox = shown;
    _capturedFace = shown;
    final still = checkFace([shown], widget.settings, _frame);
    if (still == CaptureState.faceOccluded) {
      _warning = 'Face occluded!';
    } else if (still == CaptureState.eyeClosed) {
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
    _captureResult = result;
    if (mounted) setState(() => _showResult = true);
    widget.onCaptured(result);
  }

  // --- VideoWorker events ---------------------------------------------------

  void _onWorkerEvent(String json) {
    if (_cancelled || !mounted) return;
    final mode = _viewMode;
    if (mode == _CaptureViewMode.faceCaptureDone ||
        mode == _CaptureViewMode.noFacePrepare) {
      return;
    }
    final ev = parseVideoWorkerEvent(json);
    if (ev is! VideoWorkerTracking) return;

    final s = widget.settings;
    var boxes =
        ev.faces.where((f) => !f.weak).map(workerFaceToBox).toList();
    boxes = mergeEyes(
      boxes,
      _lastEyes,
      swapLeftRight: s.cameraLens == CameraLens.front,
    );
    final state = checkFace(boxes, s, _frame);
    setState(() => _faceBox = boxes.isNotEmpty ? boxes.first : null);

    if (mode == _CaptureViewMode.repeatNoFacePrepare) {
      if (state != CaptureState.noFace) {
        _setMode(_CaptureViewMode.toFaceCircle);
      }
      return;
    }

    if (mode == _CaptureViewMode.faceCircle) {
      if (state == CaptureState.noFace) {
        _warning = '';
        _okStreak = 0;
        _setMode(_CaptureViewMode.faceCircleToNoFace);
        return;
      }
      if (state == CaptureState.captureOk) {
        if (_lastEyes.isEmpty) {
          setState(() => _warning = '');
          return;
        }
        unawaited(_beginCapture(boxes));
        return;
      }
      _okStreak = 0;
      setState(() => _warning = warningFor(state));
      return;
    }

    if (mode == _CaptureViewMode.faceCapturePrepare) {
      if (state == CaptureState.captureOk && boxes.isNotEmpty) {
        unawaited(exportLastLiveFrame().then((exported) {
          final uri = exported.uri;
          if (uri == null || uri.isEmpty) return;
          _lastUri = uri;
          _captureUri = uri;
          _capturedFace = boxes.first;
        }).catchError((_) {}));
      }
    }
  }

  Future<void> _beginCapture(List<FaceBox> boxes) async {
    try {
      final exported = await exportLastLiveFrame();
      final uri = exported.uri;
      if (uri != null && uri.isNotEmpty && boxes.isNotEmpty) {
        _lastUri = uri;
        _captureUri = uri;
        _capturedFace = boxes.first;
        if (exported.width > 0 && exported.height > 0) {
          _frame = FrameSize(exported.width, exported.height);
        }
      }
    } catch (_) {
      // keep prior uri if export fails
    }
    _warning = '';
    _okStreak = 0;
    _setMode(_CaptureViewMode.faceCapturePrepare);
  }

  // --- Live preview stream (no takePicture shutter) -------------------------

  Future<void> _startStream() async {
    if (!Platform.isIOS) return;
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized || _streaming) return;
    await cam.startImageStream(_onCameraImage);
    _streaming = true;
  }

  void _onCameraImage(CameraImage image) {
    final mode = _viewMode;
    if (_cancelled ||
        !_workerReady ||
        mode == _CaptureViewMode.noFacePrepare ||
        mode == _CaptureViewMode.faceCaptureDone ||
        _busy) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < 120) return;
    _lastFrameMs = now;
    _busy = true;
    unawaited(_processStreamFrame(image));
  }

  Future<void> _tickAndroid() async {
    final mode = _viewMode;
    if (_cancelled ||
        !_workerReady ||
        mode == _CaptureViewMode.noFacePrepare ||
        mode == _CaptureViewMode.faceCaptureDone ||
        _busy ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _busy = true;
    try {
      final cam = _controller!;
      final front = widget.settings.cameraLens == CameraLens.front;
      final photo = await cam.takePicture();
      final live = await ingestLiveCameraFrame(
        LiveCameraPhoto(path: photo.path),
        LiveFrameOptions(frontCamera: front),
      );
      await _afterLiveFrame(live);
    } catch (_) {
      // Camera warming up.
    } finally {
      _busy = false;
    }
  }

  Future<void> _processStreamFrame(CameraImage image) async {
    try {
      final cam = _controller!;
      final front = widget.settings.cameraLens == CameraLens.front;
      final live = await feedCameraFrame(
        image,
        sensorOrientation: cam.description.sensorOrientation,
        frontCamera: front,
      );
      await _afterLiveFrame(live);
    } catch (_) {
      // Preview frame can fail while camera warms up.
    } finally {
      _busy = false;
    }
  }

  Future<void> _afterLiveFrame(LiveFrameResult live) async {
    if (!live.ingested) return;
    if (live.width > 0 && live.height > 0) {
      _frame = FrameSize(live.width, live.height);
      if (mounted) setState(() {});
    }
    if (!_eyesBusy) {
      _eyesBusy = true;
      try {
        final exported = await exportLastLiveFrame();
        final uri = exported.uri;
        if (uri != null && uri.isNotEmpty) {
          _lastUri = uri;
          final eyes = await faceDetection(
            uri,
            const FaceDetectionParam(
              checkEyeCloseness: true,
              checkPose: false,
              checkLandmarks: false,
              checkLiveness: false,
            ),
          );
          if (eyes.isNotEmpty) _lastEyes = eyes;
        }
      } catch (_) {
        // eyes optional until ready
      } finally {
        _eyesBusy = false;
      }
    }
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return DefaultTextStyle(
        style: _plainText.copyWith(color: _uiText),
        child: const ColoredBox(
          color: _uiBlackBg,
          child: Center(
            child: Text('Camera permission denied'),
          ),
        ),
      );
    }

    final controller = _controller;
    if (_initializing || controller == null) {
      return const ColoredBox(
        color: _uiBlackBg,
        child: Center(child: CircularProgressIndicator(color: _uiAccent)),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final front = widget.settings.cameraLens == CameraLens.front;
    // Android: mirrored preview + unmirrored JPEG → flip overlay. iOS stream is already mirrored.
    final mirrorOverlay = front && Platform.isAndroid;
    final mirrorCapturedPreview = front && Platform.isAndroid;
    final done = _viewMode == _CaptureViewMode.faceCaptureDone;
    final shown = _resultBox;

    return DefaultTextStyle(
      style: _plainText,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!done)
              CoverCameraPreview(controller: controller)
            else
              const ColoredBox(color: _uiBlackBg),
            CaptureOverlay(
              width: size.width,
              height: size.height,
              frame: _frame,
              mirror: mirrorOverlay,
              mirrorCapturedPreview: mirrorCapturedPreview,
              viewMode: _viewMode,
              scale: _scale,
              faceBox: _faceBox,
              capturedUri: done ? _captureUri : null,
            ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              height: 48,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _uiText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 48 / 22,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (_warning.isNotEmpty)
              Positioned(
                top: 64,
                right: 20,
                child: Text(
                  _warning,
                  style: const TextStyle(
                    color: _uiDanger,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            if (_showResult) _buildResultPane(size, shown),
            if (widget.onCancel != null)
              Positioned(
                top: 52,
                left: 16,
                child: Material(
                  color: _uiAccentDim,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onCancel,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back, color: _uiText),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPane(Size size, FaceBox? shown) {
    final s = widget.settings;
    final liveness = shown?.liveness ?? 0;
    final label = (shown?.livenessLabel ?? '').toLowerCase();
    final livenessLine = shown == null
        ? ''
        : (label.contains('spoof') || label.contains('fake'))
            ? 'Liveness: Spoof, score = $liveness'
            : (liveness >= s.livenessThreshold)
                ? 'Liveness: Real, score = $liveness'
                : 'Liveness: Spoof, score = $liveness';

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: size.width, height: size.width),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 16),
              child: Text(
                livenessLine,
                style: const TextStyle(
                  color: _uiText,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 16),
              child: Text(
                _qualityText(shown?.faceQuality ?? 0) +
                    ((shown?.qualityLabel != null &&
                            shown!.qualityLabel!.isNotEmpty)
                        ? '\n${shown.qualityLabel}'
                        : ''),
                style: const TextStyle(
                  color: _uiText,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 16),
              child: Text(
                'Luminance: ${shown?.faceLuminance ?? 0}',
                style: const TextStyle(
                  color: _uiText,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (_captureResult != null && widget.renderActions != null)
              widget.renderActions!(_captureResult!),
          ],
        ),
      ),
    );
  }

  static String _qualityText(double score) {
    if (score < 0.5) return 'Low · ${(score * 100).round()}%';
    if (score < 0.75) return 'Medium · ${(score * 100).round()}%';
    return 'High · ${(score * 100).round()}%';
  }
}
