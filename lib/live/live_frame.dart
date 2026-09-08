import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:image/image.dart' as img;

import '../api/engine.dart';
import '../api/types.dart';
import '../live_frame_prep.dart';

String _hostPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return defaultTargetPlatform.name.toLowerCase();
  }
}

String _resolveLiveUri(LiveFrameInput input) {
  if (input is String) {
    if (input.startsWith('file://') ||
        input.startsWith('content:') ||
        input.startsWith('data:')) {
      return input;
    }
    if (input.startsWith('/')) return 'file://$input';
    return input;
  }
  if (input is LiveCameraPhoto) {
    final path = input.path;
    if (path.startsWith('file://') || path.startsWith('content:')) return path;
    return path.startsWith('/') ? 'file://$path' : path;
  }
  throw ArgumentError(
    'ingestLiveCameraFrame: expected a URI string or LiveCameraPhoto',
  );
}

({String uri, LiveFrameOptions options}) _resolveLiveArgs(
  LiveFrameInput input, [
  Object? frontOrOptions,
  String? orientationArg,
]) {
  if (input is! String && input is! LiveCameraPhoto) {
    throw ArgumentError('ingestLiveCameraFrame: invalid arguments');
  }

  if (frontOrOptions is bool) {
    final photoOrient = input is LiveCameraPhoto ? input.orientation : null;
    return (
      uri: _resolveLiveUri(input),
      options: LiveFrameOptions(
        frontCamera: frontOrOptions,
        orientation: orientationArg ?? photoOrient,
      ),
    );
  }

  final opts = frontOrOptions is LiveFrameOptions
      ? frontOrOptions
      : const LiveFrameOptions();
  final photoOrient = input is LiveCameraPhoto ? input.orientation : null;
  return (
    uri: _resolveLiveUri(input),
    options: LiveFrameOptions(
      frontCamera: opts.frontCamera,
      orientation: opts.orientation ?? photoOrient,
      rotateDegrees: opts.rotateDegrees,
      maxEdge: opts.maxEdge,
    ),
  );
}

Future<LiveFrameResult> _prepareAndMaybeFeed(
  LiveFrameInput input, [
  Object? frontOrOptions,
  String? orientationArg,
  bool feedWorker = true,
]) async {
  final resolved = _resolveLiveArgs(input, frontOrOptions, orientationArg);
  final options = resolved.options;
  final maxEdge = (options.maxEdge != null && options.maxEdge! > 0)
      ? options.maxEdge!
      : LIVE_FRAME_MAX_EDGE;

  late final int rotateDegrees;
  if (options.rotateDegrees != null) {
    rotateDegrees = options.rotateDegrees!;
  } else {
    final probed = await probeLiveImage(resolved.uri);
    final plan = planLiveFrame(
      LiveFramePrepInput(
        frontCamera: options.frontCamera,
        orientation: options.orientation,
        width: (probed['width'] is num) ? (probed['width'] as num).toDouble() : 0,
        height:
            (probed['height'] is num) ? (probed['height'] as num).toDouble() : 0,
        maxEdge: maxEdge,
        platform: _hostPlatform(),
      ),
    );
    rotateDegrees = plan.rotateDegrees;
  }

  return applyLiveFrame(
    resolved.uri,
    rotateDegrees: rotateDegrees,
    maxEdge: maxEdge,
    feedWorker: feedWorker,
  );
}

/// Feed one camera snapshot (or URI) into VideoWorker.
///
/// Beginner:
///   await ingestLiveCameraFrame(photo, LiveFrameOptions(frontCamera: true));
///
/// Legacy:
///   await ingestLiveCameraFrame(uri, true, 'portrait');
Future<LiveFrameResult> ingestLiveCameraFrame(
  LiveFrameInput input, [
  Object? frontOrOptions,
  String? orientation,
]) {
  return _prepareAndMaybeFeed(input, frontOrOptions, orientation, true);
}

/// Same prep as ingest, but only writes a JPEG (does not feed VideoWorker).
Future<String> prepareLiveCameraFrame(
  LiveFrameInput input, [
  Object? frontOrOptions,
  String? orientation,
]) async {
  final result =
      await _prepareAndMaybeFeed(input, frontOrOptions, orientation, false);
  final uri = result.uri;
  if (uri == null || uri.isEmpty) {
    throw StateError('prepareLiveCameraFrame: no output URI');
  }
  return uri;
}

/// Feed a [CameraImage] preview frame into VideoWorker.
///
/// **iOS:** use with `startImageStream` and `ImageFormatGroup.bgra8888`.
/// **Android:** prefer [ingestLiveCameraFrame] with `takePicture` (JPEG path).
Future<LiveFrameResult> feedCameraFrame(
  CameraImage image, {
  required int sensorOrientation,
  required bool frontCamera,
  int? maxEdge,
}) async {
  assert(sensorOrientation >= 0); // Camera metadata; stream bake uses buffer w/h + planLiveFrame.
  final jpegPath = _cameraImageToTempJpeg(image);
  if (jpegPath == null) {
    return const LiveFrameResult(ingested: false, width: 0, height: 0);
  }

  final edge = (maxEdge != null && maxEdge > 0)
      ? maxEdge
      : LIVE_FRAME_MAX_EDGE;
  final plan = planLiveFrame(
    LiveFramePrepInput(
      frontCamera: frontCamera,
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      maxEdge: edge,
      platform: _hostPlatform(),
    ),
  );

  try {
    return await applyLiveFrame(
      'file://$jpegPath',
      rotateDegrees: plan.rotateDegrees,
      maxEdge: plan.maxEdge,
      feedWorker: true,
    );
  } finally {
    // Best-effort cleanup; ignore if the file is still in use.
    try {
      File(jpegPath).deleteSync();
    } catch (_) {}
  }
}

String? _cameraImageToTempJpeg(CameraImage image) {
  final converted = _cameraImageToImage(image);
  if (converted == null) return null;
  final jpg = img.encodeJpg(converted, quality: 85);
  final path =
      '${Directory.systemTemp.path}/fr_live_${DateTime.now().microsecondsSinceEpoch}.jpg';
  File(path).writeAsBytesSync(jpg, flush: true);
  return path;
}

img.Image? _cameraImageToImage(CameraImage image) {
  if (image.format.group == ImageFormatGroup.bgra8888) {
    final plane = image.planes[0];
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      bytesOffset: plane.bytes.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
      rowStride: plane.bytesPerRow,
    );
  }
  return null;
}

