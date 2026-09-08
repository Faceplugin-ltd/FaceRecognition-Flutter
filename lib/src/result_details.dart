import 'face_box.dart';

enum DetailKind { section, field }

class DetailRow {
  const DetailRow({
    required this.kind,
    required this.title,
    required this.value,
  });

  final DetailKind kind;
  final String title;
  final String value;
}

class ResultDisplaySettings {
  const ResultDisplaySettings({required this.livenessThreshold});

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
  if (gender == 0) return 'Male';
  if (gender == 1) return 'Female';
  return 'Unknown';
}

String _livenessText(
  ResultDisplaySettings settings,
  double score,
  String? label,
) {
  final lower = (label ?? '').toLowerCase();
  final live = lower.contains('spoof') || lower.contains('fake')
      ? 'Spoof'
      : lower.contains('real')
          ? 'Real'
          : livenessPassed(settings, score, label)
              ? 'Real'
              : 'Spoof';
  if (label != null && label.contains(' · ')) return label;
  return '$live · ${(score * 100).round()}%';
}

Map<String, String> _attrMap(FaceBox box) {
  final out = <String, String>{};
  final raw = box.attributes;
  if (raw != null) {
    for (final e in raw.entries) {
      if (e.value.trim().isNotEmpty) out[e.key] = e.value;
    }
  }
  return out;
}

String _engineAttr(Map<String, String> extra, List<String> keys) {
  for (final key in keys) {
    final v = extra[key];
    if (v != null && v.trim().isNotEmpty) return v;
  }
  return '';
}

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
      rows.add(DetailRow(kind: DetailKind.field, title: title, value: value));
    }
  }

  void section(String title) {
    rows.add(DetailRow(kind: DetailKind.section, title: title, value: title));
  }

  void take(String title, List<String> keys, [String? fallback]) {
    final value = _engineAttr(extra, keys).trim().isNotEmpty
        ? _engineAttr(extra, keys)
        : (fallback ?? '');
    if (value.trim().isNotEmpty) {
      push(title, value);
      used.addAll(keys);
    }
  }

  if (includeMatch && personName != null && personName.isNotEmpty) {
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
  take('Age', const ['Age', 'age'],
      box.age != null && box.age! > 0 ? box.age!.round().toString() : null);
  take('Gender', const ['Gender', 'gender'],
      _genderText(box.gender, box.genderLabel));
  take('Emotion', const ['Emotion', 'emotion'], box.emotionLabel);
  take('All emotions', const ['Emotions']);

  section('Face');
  take('Mask', const ['MedicalMask', 'Mask', 'mask'], box.maskLabel);
  take('Glasses', const ['Glasses', 'glasses'], box.glassesLabel);
  take('Sunglasses', const ['Sunglasses', 'sunglasses'], box.sunglassesLabel);
  take('Occlusion', const ['Occlusion', 'FaceOcclusion', 'occlusion'],
      box.occlusionLabel);
  final left =
      _engineAttr(extra, const ['EyesLeft', 'eyesLeft']).trim().isNotEmpty
          ? _engineAttr(extra, const ['EyesLeft', 'eyesLeft'])
          : (box.eyesLeftLabel ?? '');
  final right =
      _engineAttr(extra, const ['EyesRight', 'eyesRight']).trim().isNotEmpty
          ? _engineAttr(extra, const ['EyesRight', 'eyesRight'])
          : (box.eyesRightLabel ?? '');
  if (left.isNotEmpty || right.isNotEmpty) {
    push('Eyes', 'Left  ${left.isEmpty ? '—' : left}\nRight  ${right.isEmpty ? '—' : right}');
    used.addAll(const ['EyesLeft', 'EyesRight', 'eyesLeft', 'eyesRight']);
  }

  section('Quality');
  take(
    'Overall',
    const ['FaceQuality', 'ExpressionLevel', 'face_quality'],
    box.qualityLabel ??
        ((box.faceQuality ?? 0) > 0
            ? qualityText(box.faceQuality!)
            : null),
  );
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
  if ((box.faceLuminance ?? 0) > 0) {
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
    if (e.value.trim().isEmpty || skipLeftover.contains(e.key)) return false;
    return !rows.any(
      (r) =>
          r.kind == DetailKind.field &&
          r.title.toLowerCase() == e.key.toLowerCase(),
    );
  });
  if (leftovers.isNotEmpty) {
    section('More from engine');
    for (final e in leftovers) {
      push(e.key, e.value);
    }
  }

  final lm = box.landmarks ?? const <double>[];
  final n = box.landmarkCount ?? (lm.length ~/ 2);
  if (n > 0 && lm.isNotEmpty) {
    section('Landmarks');
    push('Count', '$n points');
    final count = n.clamp(0, lm.length ~/ 2);
    if (count > 0) {
      final lines = <String>[];
      for (var i = 0; i < count; i++) {
        lines.add('${i + 1}: ${lm[i * 2]}, ${lm[i * 2 + 1]}');
      }
      push('Positions', lines.join('\n'));
    }
  }

  return [
    for (var i = 0; i < rows.length; i++)
      if (rows[i].kind != DetailKind.section ||
          (i + 1 < rows.length &&
              rows[i + 1].kind == DetailKind.field &&
              rows[i + 1].value.trim().isNotEmpty))
        rows[i],
  ];
}
