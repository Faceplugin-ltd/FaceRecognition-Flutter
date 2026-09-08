import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera preview that fills its parent using `BoxFit.cover` (no letterboxing),
/// matching the CameraX / VisionCamera `resizeMode: cover` behaviour.
class CoverCameraPreview extends StatelessWidget {
  const CoverCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    // previewSize is reported in sensor (landscape) orientation; swap to
    // portrait so the aspect ratio matches the on-screen preview.
    final preview = controller.value.previewSize;
    final previewW = preview?.height ?? 9;
    final previewH = preview?.width ?? 16;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewW,
          height: previewH,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
