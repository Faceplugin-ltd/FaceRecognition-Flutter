import '../api/types.dart';

class DetailRow {
  const DetailRow.section(this.title)
      : kind = DetailKind.section,
        value = title;

  const DetailRow.field(this.title, this.value) : kind = DetailKind.field;

  final DetailKind kind;
  final String title;
  final String value;
}

enum DetailKind { section, field }

/// Thresholds needed to format result rows (demo Settings stay in the app).
class ResultDisplaySettings {
  const ResultDisplaySettings({this.livenessThreshold = 0.5});

  final double livenessThreshold;
}

bool livenessPassed(
  ResultDisplaySettings settings,
  double score, [
  String? label,
]) {
  final lower = (label ?? '').toLowerCase();
  if (lower.contains('spoof') || lower.contains('fake')) return false;
  if (lower.contains('real') ||
      lower.contains('genuine') ||
      (lower.contains('live') && !lower.contains('liveness'))) {
    if (score <= 0.001) return true;
  }
  return score >= settings.livenessThreshold;
}

String qualityText(double score) {
  if (score < 0.5) return 'Low · ${(score * 100).round()}%';
  if (score < 0.75) return 'Medium · ${(score * 100).round()}%';
  return 'High · ${(score * 100).round()}%';
}

String _genderText(double? gender, String? label) {
  if (label != null && label.isNotEmpty) return label;
  return '';
}

String _livenessText(
  ResultDisplaySettings settings,
  double score,
  String? label,
) {
  final lower = (label ?? '').toLowerCase();
  final live = lower.contains('spoof') || lower.contains('fake')
      ? 'Spoof'
      : lower.contains('real') ||
              lower.contains('genuine') ||
              lower.contains('live')
          ? 'Real'
          : livenessPassed(settings, score, label)
              ? 'Real'
              : 'Spoof';
  if (label != null && label.contains(' · ')) return label;
  if (score > 0.001) return '$live · ${(score * 100).round()}%';
  return live;
}

Map<String, String> _attrMap(FaceBox box) {
  final out = <String, String>{};
  final raw = box.attributes;
  if (raw == null) return out;
  raw.forEach((k, v) {
    if (v.trim().isNotEmpty) out[k] = v;
  });
  return out;
}

String _engineAttr(Map<String, String> extra, List<String> keys) {
  for (final key in keys) {
    final v = extra[key];
    if (v != null && v.trim().isNotEmpty) return v;
  }
  return '';
}

/// Mirrors Android ResultDetails.rows / RN resultDetails.ts.
List<DetailRow> resultDetailRows(
  FaceBox box,
  ResultDisplaySettings settings, {
  String? personName,
  double? similarity,
  bool includeMatch = false,
}) {
  final rows = <DetailRow>[];
  final extra = _attrMap(box);
  final used = <String>{};

  void push(String title, String value) {
    if (value.trim().isNotEmpty) {
      rows.add(DetailRow.field(title, value));
    }
  }

  void section(String title) => rows.add(DetailRow.section(title));

  void take(String title, List<String> keys, [String? fallback]) {
    final engine = _engineAttr(extra, keys);
    final resolved = engine.isNotEmpty ? engine : (fallback ?? '');
    if (resolved.trim().isNotEmpty) {
      push(title, resolved);
      used.addAll(keys);
    }
  }

  if (includeMatch && personName != null) {
    section('Match');
    push('Person', personName);
    if (similarity != null) {
      push('Similarity', '${(similarity * 100).round()}%');
    }
  }

  section('Authenticity');
  take(
    'Liveness',
    const ['Liveness2D', 'liveness', 'Liveness'],
    _livenessText(settings, box.liveness ?? 0, box.livenessLabel),
  );

  section('Person');
  take(
    'Age',
    const ['Age', 'age'],
    (box.age != null && box.age! > 0) ? '${box.age!.round()}' : null,
  );
  take(
    'Gender',
    const ['Gender', 'gender'],
    _genderText(box.gender, box.genderLabel),
  );
  take(
    'Emotion',
    const ['Emotion', 'emotion'],
    box.emotionLabel,
  );
  take('All emotions', const ['Emotions', 'emotions']);

  section('Face');
  take('Mask', const ['MedicalMask', 'Mask', 'mask'], box.maskLabel);
  take('Glasses', const ['Glasses', 'glasses'], box.glassesLabel);
  take('Sunglasses', const ['Sunglasses', 'sunglasses'], box.sunglassesLabel);
  take(
    'Occlusion',
    const ['Occlusion', 'FaceOcclusion', 'occlusion'],
    box.occlusionLabel,
  );

  final leftEngine = _engineAttr(extra, const ['EyesLeft', 'eyesLeft']);
  final rightEngine = _engineAttr(extra, const ['EyesRight', 'eyesRight']);
  final leftEye =
      leftEngine.isNotEmpty ? leftEngine : (box.eyesLeftLabel ?? '');
  final rightEye =
      rightEngine.isNotEmpty ? rightEngine : (box.eyesRightLabel ?? '');
  if (leftEye.isNotEmpty || rightEye.isNotEmpty) {
    push(
      'Eyes',
      'Left  ${leftEye.isEmpty ? '—' : leftEye}\n'
      'Right  ${rightEye.isEmpty ? '—' : rightEye}',
    );
    used.addAll(const ['EyesLeft', 'EyesRight', 'eyesLeft', 'eyesRight']);
  }

  section('Quality');
  final overallFallback = box.qualityLabel ??
      ((box.faceQuality != null && (box.faceQuality ?? 0) > 0)
          ? qualityText(box.faceQuality!)
          : null);
  take(
    'Overall',
    const ['FaceQuality', 'ExpressionLevel', 'face_quality'],
    overallFallback,
  );
  if (!rows.any((r) => r.kind == DetailKind.field && r.title == 'Overall') &&
      box.faceQuality != null) {
    push('Overall', qualityText(box.faceQuality!));
  }
  for (final key in const [
    'Lighting',
    'Sharpness',
    'Noise',
    'Flare',
    'BlurLevel',
    'NoiseLevel',
  ]) {
    take(key, [key]);
  }

  section('Geometry');
  push(
    'Pose',
    'yaw ${box.yaw ?? 0}°   roll ${box.roll ?? 0}°   pitch ${box.pitch ?? 0}°',
  );
  push('Box', '${box.x1}, ${box.y1} → ${box.x2}, ${box.y2}');
  if (box.faceLuminance != null && box.faceLuminance! > 0) {
    push('Luminance', '${((box.faceLuminance ?? 0) * 100).round()}%');
  }

  final skipLeftover = {
    ...used,
    'MouthOpened',
    'Deepfake',
    'Template',
    'mouth_opened',
  };
  final leftovers = extra.entries.where((e) {
    if (e.value.trim().isEmpty) return false;
    if (skipLeftover.contains(e.key)) return false;
    return !rows.any(
      (r) =>
          r.kind == DetailKind.field &&
          r.title.toLowerCase() == e.key.toLowerCase(),
    );
  }).toList();
  if (leftovers.isNotEmpty) {
    section('More from engine');
    for (final e in leftovers) {
      push(e.key, e.value);
    }
  }

  if (box.landmarkCount != null &&
      box.landmarkCount! > 0 &&
      box.landmarks != null &&
      box.landmarks!.isNotEmpty) {
    section('Landmarks');
    push('Count', '${box.landmarkCount} points');
    final n = box.landmarkCount! < (box.landmarks!.length ~/ 2)
        ? box.landmarkCount!
        : box.landmarks!.length ~/ 2;
    if (n > 0) {
      final lines = <String>[];
      for (var i = 0; i < n; i++) {
        lines.add(
          '${i + 1}: ${box.landmarks![i * 2]}, ${box.landmarks![i * 2 + 1]}',
        );
      }
      push('Positions', lines.join('\n'));
    }
  }

  final filtered = <DetailRow>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.kind == DetailKind.section) {
      final next = i + 1 < rows.length ? rows[i + 1] : null;
      if (next != null &&
          next.kind == DetailKind.field &&
          next.value.trim().isNotEmpty) {
        filtered.add(row);
      }
    } else if (row.value.trim().isNotEmpty) {
      filtered.add(row);
    }
  }
  return filtered;
}
