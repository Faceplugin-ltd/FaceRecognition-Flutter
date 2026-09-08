import 'dart:convert';

/// Parsed FaceRecognitionSDK.getLicenseStatus JSON.
class LicenseStatus {
  const LicenseStatus({
    required this.licensed,
    required this.level,
    required this.levelName,
    required this.recognition,
    required this.liveness,
    required this.label,
  });

  final bool licensed;
  final int level;
  final String levelName;
  final bool recognition;
  final bool liveness;
  final String label;

  static const notLicensed = LicenseStatus(
    licensed: false,
    level: -1,
    levelName: 'None',
    recognition: false,
    liveness: false,
    label: 'Not licensed',
  );

  factory LicenseStatus.fromJson(String? json) {
    try {
      final decoded = jsonDecode(json ?? '{}');
      if (decoded is! Map) return notLicensed;
      final o = Map<String, dynamic>.from(decoded);
      final rawLabel = o['label'];
      final label = rawLabel is String && rawLabel.trim().isNotEmpty
          ? rawLabel
          : 'Not licensed';
      return LicenseStatus(
        licensed: o['licensed'] == true,
        level: o['level'] is int ? o['level'] as int : -1,
        levelName: o['levelName'] is String ? o['levelName'] as String : 'None',
        recognition: o['recognition'] == true,
        liveness: o['liveness'] == true,
        label: label,
      );
    } catch (_) {
      return notLicensed;
    }
  }

  String? denyMessage({required bool wantRecognition, required bool wantLiveness}) {
    final parts = <String>[];
    if (wantLiveness && !liveness) {
      parts.add('Liveness is not available on this license ($label).');
    }
    if (wantRecognition && !recognition) {
      parts.add('Recognition is not available on this license ($label).');
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }
}

/// Home status bar after a successful init — Android `Ready · %s`.
String readyStatusMessage(String label) {
  final t = label.trim();
  return t.isEmpty ? 'Ready' : 'Ready · $t';
}
