import 'dart:convert';

import '../api/types.dart' show FaceBox;

class VideoWorkerMatch {
  const VideoWorkerMatch({
    required this.matched,
    this.personIndex,
    this.score,
  });

  final bool matched;
  final int? personIndex;
  final double? score;
}

class VideoWorkerFace {
  const VideoWorkerFace({
    required this.trackId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.landmarks,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.weak,
    this.match,
    this.liveness,
    this.livenessLabel,
  });

  final int trackId;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<({double x, double y})> landmarks;
  final double yaw;
  final double pitch;
  final double roll;
  final bool weak;
  final VideoWorkerMatch? match;
  final double? liveness;
  final String? livenessLabel;
}

sealed class VideoWorkerEvent {
  const VideoWorkerEvent();
}

class VideoWorkerTracking extends VideoWorkerEvent {
  const VideoWorkerTracking({
    required this.frameWidth,
    required this.frameHeight,
    required this.faces,
  });

  final double frameWidth;
  final double frameHeight;
  final List<VideoWorkerFace> faces;
}

class VideoWorkerMatchEvent extends VideoWorkerEvent {
  const VideoWorkerMatchEvent({
    required this.trackId,
    required this.matched,
    this.personIndex,
    this.score,
  });

  final int trackId;
  final bool matched;
  final int? personIndex;
  final double? score;
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String && v.trim().isNotEmpty) return double.tryParse(v);
  return null;
}

List<({double x, double y})> _parseLandmarks(Object? raw) {
  if (raw is! List) return const [];
  final out = <({double x, double y})>[];
  for (final p in raw) {
    if (p is! Map) continue;
    final x = _num(p['x']) ?? 0;
    final y = _num(p['y']) ?? 0;
    if (x == 0 && y == 0) continue;
    out.add((x: x, y: y));
  }
  return out;
}

VideoWorkerFace? _parseWorkerFace(Map<Object?, Object?> raw) {
  final region = raw['faceRegion'];
  if (region is! Map) return null;
  final x = _num(region['x']) ?? 0;
  final y = _num(region['y']) ?? 0;
  final w = _num(region['width']) ?? 0;
  final h = _num(region['height']) ?? 0;
  VideoWorkerMatch? match;
  final matchRaw = raw['match'];
  if (matchRaw is Map) {
    match = VideoWorkerMatch(
      matched: matchRaw['matched'] == true,
      personIndex: _num(matchRaw['person_index'])?.toInt(),
      score: _num(matchRaw['score']),
    );
  }
  final pose = raw['facePose'];
  final poseMap = pose is Map ? pose : const <Object?, Object?>{};
  final live = _parseWorkerLiveness(raw);
  return VideoWorkerFace(
    trackId: _num(raw['track_id'])?.toInt() ?? 0,
    x: x,
    y: y,
    width: w,
    height: h,
    landmarks: _parseLandmarks(raw['facePoints']),
    yaw: _num(poseMap['yaw']) ?? 0,
    pitch: _num(poseMap['pitch']) ?? 0,
    roll: _num(poseMap['roll']) ?? 0,
    weak: raw['weak'] == true,
    match: match,
    liveness: live.liveness,
    livenessLabel: live.label,
  );
}

({double? liveness, String? label}) _parseWorkerLiveness(Map<Object?, Object?> raw) {
  double? score = _num(raw['liveness']);
  String? label = raw['livenessLabel'] is String
      ? raw['livenessLabel'] as String
      : raw['liveness_label'] is String
          ? raw['liveness_label'] as String
          : null;
  if (label != null && label.isEmpty) label = null;
  final attrs = raw['attributes'];
  if (attrs is Map) {
    final live = attrs['Liveness2D'] ?? attrs['liveness'];
    if (live is Map) {
      label ??= live['value'] is String && (live['value'] as String).isNotEmpty
          ? live['value'] as String
          : null;
      score ??= _num(live['confidence']) ?? _num(live['value']);
    }
  }
  return (liveness: score, label: label);
}

VideoWorkerEvent? parseVideoWorkerEvent(String json) {
  try {
    final root = jsonDecode(json);
    if (root is! Map) return null;
    final event = root['event'];
    if (event == 'tracking') {
      final facesRaw = root['faces'];
      final faces = <VideoWorkerFace>[];
      if (facesRaw is List) {
        for (final f in facesRaw) {
          if (f is Map) {
            final parsed = _parseWorkerFace(Map<Object?, Object?>.from(f));
            if (parsed != null) faces.add(parsed);
          }
        }
      }
      return VideoWorkerTracking(
        frameWidth: _num(root['frame_width']) ?? 0,
        frameHeight: _num(root['frame_height']) ?? 0,
        faces: faces,
      );
    }
    if (event == 'match') {
      return VideoWorkerMatchEvent(
        trackId: _num(root['track_id'])?.toInt() ?? 0,
        matched: root['matched'] == true,
        personIndex: _num(root['person_index'])?.toInt(),
        score: _num(root['score']),
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

FaceBox workerFaceToBox(VideoWorkerFace face) {
  return FaceBox(
    x1: face.x.roundToDouble(),
    y1: face.y.roundToDouble(),
    x2: (face.x + face.width).roundToDouble(),
    y2: (face.y + face.height).roundToDouble(),
    yaw: face.yaw,
    pitch: face.pitch,
    roll: face.roll,
    liveness: face.liveness,
    livenessLabel: face.livenessLabel,
    landmarkCount: face.landmarks.length,
    landmarks: [
      for (final p in face.landmarks) ...[p.x, p.y],
    ],
  );
}
