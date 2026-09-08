import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-bleed camera preview (FILL_CENTER / `resizeMode="cover"`).
///
/// Bare [CameraPreview] letterboxes; overlays that map with max-scale then look
/// short / misaligned versus FaceRecognitionSDK Apps and RN.
class CoverCameraPreview extends StatelessWidget {
  const CoverCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        if (viewW <= 0 || viewH <= 0) {
          return const ColoredBox(color: Colors.black);
        }
        final viewAr = viewW / viewH;
        final previewAr = controller.value.aspectRatio;
        var scale = viewAr * previewAr;
        if (scale < 1) scale = 1 / scale;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}
