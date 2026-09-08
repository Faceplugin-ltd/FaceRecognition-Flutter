import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart'
    hide livenessPassed, qualityText;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../services/person_database.dart';
import '../../services/settings_service.dart';
import '../../widgets/overlay/face_overlay.dart';

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  CameraController? _controller;
  IdentifySession? _session;

  bool _initializing = true;
  bool _recognized = false;
  bool _confirming = false;
  List<FaceBox> _boxes = [];
  Size _frameSize = const Size(480, 640);
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    unawaited(_session?.dispose());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final settings = context.read<SettingsService>().settings;
    _settings = settings;

    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    try {
      final cameras = await availableCameras();
      final preferFront = settings.cameraLens == CameraLens.front;
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

      final session = IdentifySession(
        settings: IdentifySettings(
          frontCamera: preferFront,
          matchThreshold: settings.identifyThreshold,
          livenessLevel: settings.livenessLevel,
        ),
        featureTemplates: context.read<PersonDatabase>().featureTemplates,
        onTracking: (boxes, frame) {
          if (_recognized || !mounted) return;
          setState(() {
            _boxes = boxes;
            _frameSize = frame;
          });
        },
        onMatch: (personIndex, score) {
          unawaited(_tryConfirm(personIndex, score));
        },
      );
      _session = session;
      await session.attach(controller);
      await session.start();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      debugPrint('[Identify] camera/worker failed: $e');
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _tryConfirm(int personIndex, double score) async {
    final s = _settings;
    final session = _session;
    if (s == null || session == null || _recognized) return;
    if (_confirming) return;
    _confirming = true;
    session.leave();
    final uri = session.lastUri;
    if (uri == null) {
      _confirming = false;
      return;
    }
    try {
      if (!mounted) {
        _confirming = false;
        return;
      }
      final list = context.read<PersonDatabase>().persons;
      final person = personIndex >= 0 && personIndex < list.length
          ? list[personIndex]
          : (personIndex > 0 && personIndex - 1 < list.length
              ? list[personIndex - 1]
              : null);
      if (person == null) {
        _confirming = false;
        return;
      }

      final faceBox = _boxes.isNotEmpty ? _boxes.first : null;
      if (faceBox == null) {
        _confirming = false;
        return;
      }

      _recognized = true;
      var identifiedUri = uri;
      var cropLandmarks = <({double x, double y})>[];
      try {
        final cropB64 = await cropFace(uri, faceBox);
        identifiedUri = 'data:image/jpeg;base64,$cropB64';
        cropLandmarks = mapLandmarksToCrop(
          faceBox,
          session.frameSize.width,
          session.frameSize.height,
          200,
          200,
        );
      } catch (_) {}

      if (!mounted) return;
      final enrolledThumb =
          await context.read<PersonDatabase>().resolveThumbnail(person);
      if (!mounted) return;
      goIdentifyResult(
        context,
        IdentifyResultArgs(
          identifiedUri: identifiedUri,
          enrolledThumbPath: enrolledThumb,
          personName: person.name,
          similarity: score,
          box: faceBox,
          cropLandmarks: cropLandmarks,
        ),
      );
    } catch (_) {
      _confirming = false;
      _recognized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final controller = _controller;
    final session = _session;
    if (_initializing || settings == null || controller == null) {
      return const Scaffold(
        backgroundColor: AppColors.blackBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CoverCameraPreview(controller: controller),
          FaceOverlay(
            width: size.width,
            height: size.height,
            frameW: _frameSize.width,
            frameH: _frameSize.height,
            mirror: session?.overlayMirror ?? false,
            boxes: _boxes,
            settings: settings,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: Material(
              color: AppColors.accentDim,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back, color: AppColors.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
