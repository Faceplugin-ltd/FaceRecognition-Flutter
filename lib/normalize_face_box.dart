/// Canonical FaceBox schema matches iOS bridge output:
/// - `attributes`: PascalCase engine map (`"value"` or `"value · NN%"`)
/// - convenience labels: glassesLabel, sunglassesLabel, occlusionLabel, …
///
/// Android typed FaceBox JSON often omits rich labels; this middleware merges
/// engine `attributes` with typed fields and pretty-prints confidences.
library;

String _trimStr(Object? v) {
  if (v is String) return v.trim();
  if (v != null) return v.toString().trim();
  return '';
}

/// Prefer existing "value · NN%" labels; otherwise append score when 0–1.
String _fmtAttr(String label, double? score) {
  final l = _trimStr(label);
  if (l.isEmpty && (score == null || !score.isFinite)) return '';
  if (l.contains(' · ')) return l;
  // Android FaceBoxParser often emits "Happy (0.95)".
  final paren = RegExp(r'^(.+?)\s*\(([0-9]*\.?[0-9]+)\)\s*$').firstMatch(l);
  if (paren != null) {
    final conf = double.tryParse(paren.group(2)!);
    if (conf != null && conf >= 0 && conf <= 1) {
      return '${paren.group(1)!.trim()} · ${(conf * 100).round()}%';
    }
  }
  if (l.isNotEmpty &&
      score != null &&
      score.isFinite &&
      score >= 0 &&
      score <= 1) {
    return '$l · ${(score * 100).round()}%';
  }
  return l;
}

String _occlusionFromScore(double? score) {
  if (score == null || !score.isFinite || score <= 0.001) return '';
  if (score > 0.5) return 'Occluded · ${(score * 100).round()}%';
  return 'Clear · ${((1 - score) * 100).round()}%';
}

void _putPrefer(Map<String, String> attrs, String key, String value) {
  final v = _trimStr(value);
  if (v.isEmpty) return;
  if (_trimStr(attrs[key]).isEmpty) attrs[key] = v;
}

/// Coerce engine attribute values (string / nested {value,confidence}) to display text.
String _attrDisplay(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    final v = _trimStr(value['value'] ?? value['label'] ?? value['name']);
    final conf = _asDouble(value['confidence'] ?? value['score']);
    return _fmtAttr(v, conf);
  }
  return _fmtAttr(_trimStr(value), null);
}

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

List<double>? _asDoubleList(Object? v) {
  if (v is! List) return null;
  return v
      .map((e) => (e is num) ? e.toDouble() : double.tryParse('$e') ?? 0.0)
      .toList();
}

Map<String, String>? _asStringMap(Object? v) {
  if (v is! Map) return null;
  final out = <String, String>{};
  v.forEach((key, value) {
    final s = _attrDisplay(value);
    if (s.isNotEmpty) out['$key'] = s;
  });
  return out;
}

/// Merge engine `attributes` with typed label fields so Attribute Result UI
/// always has Authenticity / Person / Face / Quality / Geometry coverage.
Map<String, dynamic> normalizeFaceBox(Map<String, dynamic> box) {
  final attributes = <String, String>{};
  final existing = box['attributes'];
  if (existing is Map) {
    existing.forEach((key, value) {
      final v = _attrDisplay(value);
      if (v.isNotEmpty) attributes['$key'] = v;
    });
  }

  final age = _asDouble(box['age']);
  _putPrefer(
    attributes,
    'Age',
    age != null && age > 0 ? '${age.round()}' : '',
  );
  _putPrefer(
    attributes,
    'Gender',
    _fmtAttr('${box['genderLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'Emotion',
    _fmtAttr('${box['emotionLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'MedicalMask',
    _fmtAttr('${box['maskLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'Liveness2D',
    _fmtAttr('${box['livenessLabel'] ?? ''}', _asDouble(box['liveness'])),
  );
  final faceQuality = _asDouble(box['face_quality']);
  final qualityLabel = _fmtAttr(_trimStr(box['qualityLabel']), faceQuality);
  _putPrefer(
    attributes,
    'FaceQuality',
    qualityLabel.isNotEmpty
        ? qualityLabel
        : (faceQuality != null && faceQuality > 0 ? '$faceQuality' : ''),
  );
  _putPrefer(
    attributes,
    'EyesLeft',
    _fmtAttr('${box['eyesLeftLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'EyesRight',
    _fmtAttr('${box['eyesRightLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'Glasses',
    _fmtAttr('${box['glassesLabel'] ?? ''}', null),
  );
  _putPrefer(
    attributes,
    'Sunglasses',
    _fmtAttr('${box['sunglassesLabel'] ?? ''}', null),
  );

  final occlusionLabel = _trimStr(box['occlusionLabel']).isNotEmpty
      ? _fmtAttr(_trimStr(box['occlusionLabel']), null)
      : _occlusionFromScore(_asDouble(box['face_occlusion']));
  _putPrefer(attributes, 'Occlusion', occlusionLabel);

  String pickLabel(String? typed, List<String> keys) {
    final t = _fmtAttr(_trimStr(typed), null);
    if (t.isNotEmpty) return t;
    for (final k in keys) {
      final v = attributes[k];
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  return {
    ...box,
    'glassesLabel': pickLabel(box['glassesLabel']?.toString(), const ['Glasses']),
    'sunglassesLabel':
        pickLabel(box['sunglassesLabel']?.toString(), const ['Sunglasses']),
    'occlusionLabel': occlusionLabel.isNotEmpty
        ? occlusionLabel
        : pickLabel(null, const ['Occlusion', 'FaceOcclusion']),
    'livenessLabel': pickLabel(
      box['livenessLabel']?.toString(),
      const ['Liveness2D', 'Liveness', 'liveness'],
    ),
    'genderLabel': pickLabel(box['genderLabel']?.toString(), const ['Gender']),
    'emotionLabel': pickLabel(
      box['emotionLabel']?.toString(),
      const ['Emotion', 'emotion'],
    ),
    'maskLabel': pickLabel(
      box['maskLabel']?.toString(),
      const ['MedicalMask', 'Mask'],
    ),
    'qualityLabel': qualityLabel.isNotEmpty
        ? qualityLabel
        : pickLabel(null, const ['FaceQuality', 'ExpressionLevel']),
    'eyesLeftLabel':
        pickLabel(box['eyesLeftLabel']?.toString(), const ['EyesLeft']),
    'eyesRightLabel':
        pickLabel(box['eyesRightLabel']?.toString(), const ['EyesRight']),
    'attributes': attributes,
  };
}

List<Map<String, dynamic>> normalizeFaceBoxes(List<dynamic> boxes) {
  return boxes
      .whereType<Map>()
      .map((b) => normalizeFaceBox(Map<String, dynamic>.from(b)))
      .toList();
}

/// Helpers shared with [FaceBox.fromJson].
double? normalizeAsDouble(Object? v) => _asDouble(v);
int? normalizeAsInt(Object? v) => _asInt(v);
List<double>? normalizeAsDoubleList(Object? v) => _asDoubleList(v);
Map<String, String>? normalizeAsStringMap(Object? v) => _asStringMap(v);
