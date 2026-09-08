import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/types.dart';
import '../capture/cover_camera_preview.dart';
import '../live/identify_session.dart';

/// Drop-in live 1:N identify. App supplies templates and handles the match.
class FaceIdentify extends StatefulWidget {
  const FaceIdentify({
    super.key,
    required this.settings,
    required this.featureTemplates,
    required this.onMatch,
    this.onCancel,
    this.title = 'Identify',
  });

  final IdentifySettings settings;
  final List<String> featureTemplates;
  final void Function(int personIndex, double score) onMatch;
  final VoidCallback? onCancel;
  final String title;

  @override
  State<FaceIdentify> createState() => _FaceIdentifyState();
}

class _FaceIdentifyState extends State<FaceIdentify> {
  CameraController? _controller;
  IdentifySession? _session;
  bool _ready = false;
  List<FaceBox> _boxes = [];
  Size _frame = const Size(480, 640);

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  @override
  void dispose() {
    unawaited(_session?.dispose());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      final preferFront = widget.settings.frontCamera;
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
      _session = IdentifySession(
        settings: widget.settings,
        featureTemplates: widget.featureTemplates,
        onTracking: (boxes, frame) {
          if (!mounted) return;
          setState(() {
            _boxes = boxes;
            _frame = frame;
          });
        },
        onMatch: (personIndex, score) {
          _session?.leave();
          widget.onMatch(personIndex, score);
        },
      );
      await _session!.attach(controller);
      await _session!.start();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _controller;
    if (!_ready || cam == null || !cam.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverCameraPreview(controller: cam),
        CustomPaint(
          painter: _BoxPainter(
            boxes: _boxes,
            frame: _frame,
            mirror: _session?.overlayMirror ?? false,
          ),
        ),
        if (widget.onCancel != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 0,
          right: 0,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ],
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({
    required this.boxes,
    required this.frame,
    required this.mirror,
  });

  final List<FaceBox> boxes;
  final Size frame;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.width <= 0 || frame.height <= 0) return;
    final scale = (size.width / frame.width) > (size.height / frame.height)
        ? size.width / frame.width
        : size.height / frame.height;
    final dx = (size.width - frame.width * scale) / 2;
    final dy = (size.height - frame.height * scale) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF00E5FF);
    for (final b in boxes) {
      var x1 = b.x1 * scale + dx;
      var x2 = b.x2 * scale + dx;
      final y1 = b.y1 * scale + dy;
      final y2 = b.y2 * scale + dy;
      if (mirror) {
        x1 = size.width - x1;
        x2 = size.width - x2;
      }
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) =>
      old.boxes != boxes || old.frame != frame || old.mirror != mirror;
}
