import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:face_recognition_sdk/face_recognition_sdk.dart' show CameraLens;

/// FaceRecognitionSDK Apps defaults.
class AppSettings {
  const AppSettings({
    this.cameraLens = CameraLens.front,
    this.livenessThreshold = 0.5,
    this.livenessLevel = 0,
    this.identifyThreshold = 0.67,
    this.yawThreshold = 40,
    this.rollThreshold = 40,
    this.pitchThreshold = 40,
    this.eyecloseThreshold = 0.5,
  });

  final CameraLens cameraLens;
  final double livenessThreshold;
  final int livenessLevel;
  final double identifyThreshold;
  final double yawThreshold;
  final double rollThreshold;
  final double pitchThreshold;
  final double eyecloseThreshold;

  static const defaults = AppSettings();

  AppSettings copyWith({
    CameraLens? cameraLens,
    double? livenessThreshold,
    int? livenessLevel,
    double? identifyThreshold,
    double? yawThreshold,
    double? rollThreshold,
    double? pitchThreshold,
    double? eyecloseThreshold,
  }) {
    return AppSettings(
      cameraLens: cameraLens ?? this.cameraLens,
      livenessThreshold: livenessThreshold ?? this.livenessThreshold,
      livenessLevel: livenessLevel ?? this.livenessLevel,
      identifyThreshold: identifyThreshold ?? this.identifyThreshold,
      yawThreshold: yawThreshold ?? this.yawThreshold,
      rollThreshold: rollThreshold ?? this.rollThreshold,
      pitchThreshold: pitchThreshold ?? this.pitchThreshold,
      eyecloseThreshold: eyecloseThreshold ?? this.eyecloseThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'camera_lens': cameraLens == CameraLens.back ? 'back' : 'front',
        'liveness_threshold': livenessThreshold,
        'liveness_level': livenessLevel,
        'identify_threshold': identifyThreshold,
        'yaw_threshold': yawThreshold,
        'roll_threshold': rollThreshold,
        'pitch_threshold': pitchThreshold,
        'eyeclose_threshold': eyecloseThreshold,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      cameraLens:
          json['camera_lens'] == 'back' ? CameraLens.back : CameraLens.front,
      livenessThreshold:
          _num(json['liveness_threshold'], defaults.livenessThreshold),
      livenessLevel: json['liveness_level'] == 1 ? 1 : 0,
      identifyThreshold:
          _num(json['identify_threshold'], defaults.identifyThreshold),
      yawThreshold: _num(json['yaw_threshold'], defaults.yawThreshold),
      rollThreshold: _num(json['roll_threshold'], defaults.rollThreshold),
      pitchThreshold: _num(json['pitch_threshold'], defaults.pitchThreshold),
      eyecloseThreshold:
          _num(json['eyeclose_threshold'], defaults.eyecloseThreshold),
    );
  }
}

double _num(Object? v, double fallback) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool livenessPassed(AppSettings settings, double score, [String? label]) {
  final lower = (label ?? '').toLowerCase();
  if (lower.contains('spoof') || lower.contains('fake')) return false;
  if (lower.contains('real') ||
      lower.contains('genuine') ||
      (lower.contains('live') && !lower.contains('liveness'))) {
    // Explicit real/live label from engine — accept even if score omitted.
    if (score <= 0.001) return true;
  }
  return score >= settings.livenessThreshold;
}

String qualityText(double score) {
  if (score < 0.5) return 'Low · ${(score * 100).round()}%';
  if (score < 0.75) return 'Medium · ${(score * 100).round()}%';
  return 'High · ${(score * 100).round()}%';
}

class SettingsService extends ChangeNotifier {
  static const _prefsKey = 'face_settings_sdk_v1';

  AppSettings _settings = AppSettings.defaults;
  Future<void> Function()? _clearPersons;

  AppSettings get settings => _settings;

  void setClearPersonsCallback(Future<void> Function() clear) {
    _clearPersons = clear;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _settings = AppSettings.defaults;
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _settings = AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        _settings = AppSettings.defaults;
      }
    } catch (e) {
      debugPrint('[SettingsService] load failed: $e');
      _settings = AppSettings.defaults;
    }
    notifyListeners();
  }

  Future<void> save(AppSettings next) async {
    _settings = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    notifyListeners();
  }

  Future<void> patch(AppSettings Function(AppSettings) update) {
    return save(update(_settings));
  }

  Future<AppSettings> restoreDefaults() async {
    await save(AppSettings.defaults);
    return _settings;
  }

  Future<void> clearAllPersons() async {
    final cb = _clearPersons;
    if (cb != null) await cb();
  }
}
