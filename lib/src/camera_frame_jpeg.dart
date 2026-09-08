import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pixel size after EXIF orientation bake (same as native UIImage / Bitmap).
(int width, int height) sizeAfterExifOrientation(
  int width,
  int height,
  int sensorOrientation,
) {
  final sensor = ((sensorOrientation % 360) + 360) % 360;
  if (sensor == 90 || sensor == 270) return (height, width);
  return (width, height);
}

/// Encode a live [CameraImage] to JPEG bytes (no shutter / takePicture).
Uint8List? encodeCameraImageJpeg(
  CameraImage image, {
  int quality = 70,
  int sensorOrientation = 0,
  bool frontCamera = false,
}) {
  try {
    final upright = _uprightFromCameraImage(
      image,
      sensorOrientation,
      frontCamera: frontCamera,
    );
    if (upright == null) return null;
    return Uint8List.fromList(img.encodeJpg(upright, quality: quality));
  } catch (e) {
    debugPrint('[FaceSDK] frame encode=$e');
    return null;
  }
}

/// Rotate sensor-order preview pixels to portrait-upright (matches native CameraFrameUtils).
img.Image? uprightCameraImage(
  CameraImage image,
  int sensorOrientation, {
  bool frontCamera = false,
}) =>
    _uprightFromCameraImage(
      image,
      sensorOrientation,
      frontCamera: frontCamera,
    );

img.Image? _uprightFromCameraImage(
  CameraImage image,
  int sensorOrientation, {
  bool frontCamera = false,
}) {
  final converted = switch (image.format.group) {
    ImageFormatGroup.bgra8888 => _bgra8888(image),
    ImageFormatGroup.yuv420 => _yuv420(image),
    ImageFormatGroup.nv21 => _yuv420(image),
    _ => null,
  };
  if (converted == null) return null;

  if (converted.width <= converted.height) {
    return converted;
  }

  // Landscape sensor buffer → portrait upright (native CameraFrameUtils / yuv2Bitmap).
  // Front −90°, back +90°. Do not mirror.
  final angle = frontCamera ? -90.0 : 90.0;
  return img.copyRotate(converted, angle: angle);
}

img.Image? _bgra8888(CameraImage image) {
  final plane = image.planes.first;
  final bytes = plane.bytes;
  final rowStride = plane.bytesPerRow;
  final out = img.Image(width: image.width, height: image.height);
  for (var y = 0; y < image.height; y++) {
    final row = y * rowStride;
    for (var x = 0; x < image.width; x++) {
      final i = row + x * 4;
      if (i + 2 >= bytes.length) continue;
      out.setPixelRgba(x, y, bytes[i + 2], bytes[i + 1], bytes[i], 255);
    }
  }
  return out;
}

img.Image? _yuv420(CameraImage image) {
  final width = image.width;
  final height = image.height;
  if (image.planes.length < 2) return null;

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes.length > 2 ? image.planes[2] : uPlane;
  final yBytes = yPlane.bytes;
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;
  final yRowStride = yPlane.bytesPerRow;
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  final out = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final yRow = y * yRowStride;
    final uvRow = (y >> 1) * uvRowStride;
    for (var x = 0; x < width; x++) {
      final yp = yBytes[yRow + x] & 0xff;
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final up = uvIndex < uBytes.length ? (uBytes[uvIndex] & 0xff) : 128;
      final vp = uvIndex < vBytes.length ? (vBytes[uvIndex] & 0xff) : 128;
      final r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
      final g =
          (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).round().clamp(0, 255);
      final b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);
      out.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  return out;
}

/// Write a portrait-upright JPEG from a preview frame (no takePicture shutter).
Future<String?> writeCameraFrameJpeg(
  CameraImage image, {
  int quality = 70,
  int sensorOrientation = 0,
  bool frontCamera = false,
}) async {
  final jpeg = encodeCameraImageJpeg(
    image,
    quality: quality,
    sensorOrientation: sensorOrientation,
    frontCamera: frontCamera,
  );
  if (jpeg == null || jpeg.isEmpty) return null;
  final file = File(
    '${Directory.systemTemp.path}/fr_frame_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(jpeg, flush: false);
  return file.path;
}
