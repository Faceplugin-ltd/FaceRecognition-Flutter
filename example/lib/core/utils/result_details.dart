import 'package:face_recognition_sdk/face_recognition_sdk.dart' as sdk;

import '../../services/settings_service.dart';

export 'package:face_recognition_sdk/face_recognition_sdk.dart'
    show DetailKind, DetailRow;

/// Demo wrapper — Settings stay in the app; rows come from the package.
List<sdk.DetailRow> resultDetailRows(
  sdk.FaceBox box,
  AppSettings settings, {
  String? personName,
  double? similarity,
  bool includeMatch = false,
}) {
  return sdk.resultDetailRows(
    box,
    sdk.ResultDisplaySettings(livenessThreshold: settings.livenessThreshold),
    personName: personName,
    similarity: similarity,
    includeMatch: includeMatch,
  );
}
