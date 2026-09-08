import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';
import '../../services/person_database.dart';
import '../../services/settings_service.dart';
import '../../widgets/dialogs/app_dialogs.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CaptureResult? _lastResult;
  bool _enrolling = false;

  CaptureSettings _toCaptureSettings(AppSettings s) {
    return CaptureSettings.fromApp(
      cameraLens: s.cameraLens,
      livenessThreshold: s.livenessThreshold,
      livenessLevel: s.livenessLevel,
      yawThreshold: s.yawThreshold,
      rollThreshold: s.rollThreshold,
      pitchThreshold: s.pitchThreshold,
      eyecloseThreshold: s.eyecloseThreshold,
    );
  }

  Future<void> _enroll() async {
    final result = _lastResult;
    if (result == null || result.uri.isEmpty) {
      AppDialogs.toast(context, 'Enrollment failed');
      return;
    }
    setState(() => _enrolling = true);
    try {
      final feature = await templateExtraction(result.uri, result.faceBox);
      var thumb = result.cropB64;
      if (thumb == null || thumb.isEmpty) {
        try {
          thumb = await cropFace(result.uri, result.faceBox);
        } catch (_) {
          thumb = null;
        }
      }
      if (!mounted) return;
      await context.read<PersonDatabase>().add(
            name: autoPersonName(),
            featureBase64: feature,
            thumbnailBase64: thumb,
          );
      if (mounted) {
        AppDialogs.toast(context, 'Person enrolled!');
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) AppDialogs.toast(context, 'Enrollment failed: $e');
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().settings;
    final captureSettings = _toCaptureSettings(settings);

    return FaceCapture(
      settings: captureSettings,
      onCancel: () => Navigator.of(context).maybePop(),
      onCaptured: (result) => setState(() => _lastResult = result),
      renderActions: (_) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Center(
          child: FilledButton(
            onPressed: _enrolling ? null : _enroll,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tile,
              minimumSize: const Size(150, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _enrolling
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Enroll',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color: AppColors.onPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
