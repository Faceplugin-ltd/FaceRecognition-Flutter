import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart' show CameraLens;
import '../../services/settings_service.dart';
import '../../widgets/dialogs/app_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Map<String, TextEditingController> _draft;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _draft = {
      'liveness_threshold': TextEditingController(),
      'identify_threshold': TextEditingController(),
      'yaw_threshold': TextEditingController(),
      'roll_threshold': TextEditingController(),
      'pitch_threshold': TextEditingController(),
      'eyeclose_threshold': TextEditingController(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<SettingsService>().settings;
      _draft['liveness_threshold']!.text = '${s.livenessThreshold}';
      _draft['identify_threshold']!.text = '${s.identifyThreshold}';
      _draft['yaw_threshold']!.text = '${s.yawThreshold}';
      _draft['roll_threshold']!.text = '${s.rollThreshold}';
      _draft['pitch_threshold']!.text = '${s.pitchThreshold}';
      _draft['eyeclose_threshold']!.text = '${s.eyecloseThreshold}';
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    for (final c in _draft.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _inRange(double v, double min, double max) =>
      v.isFinite && v >= min && v <= max;

  Future<void> _commitNum(
    SettingsService svc,
    String key,
    double min,
    double max,
    AppSettings Function(AppSettings, double) apply,
  ) async {
    final v = double.tryParse(_draft[key]!.text.trim());
    if (v == null || !_inRange(v, min, max)) return;
    await svc.save(apply(svc.settings, v));
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SettingsService>();
    final s = svc.settings;

    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Camera'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Camera lens', style: TextStyle(color: AppColors.text)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Radio(
                      label: 'Front',
                      selected: s.cameraLens == CameraLens.front,
                      onTap: () => svc.patch(
                        (cur) => cur.copyWith(cameraLens: CameraLens.front),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _Radio(
                      label: 'Back',
                      selected: s.cameraLens == CameraLens.back,
                      onTap: () => svc.patch(
                        (cur) => cur.copyWith(cameraLens: CameraLens.back),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _SectionTitle('Thresholds'),
          _Card(
            child: Column(
              children: [
                _NumField(
                  label: 'Liveness',
                  controller: _draft['liveness_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'liveness_threshold',
                    0,
                    1,
                    (c, v) => c.copyWith(livenessThreshold: v),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Liveness Level',
                    style: TextStyle(color: AppColors.text, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: _Radio(
                        // FaceRecognitionSDK-Android-App: 0 = High Accuracy
                        label: 'High Accuracy',
                        selected: s.livenessLevel == 0,
                        onTap: () =>
                            svc.patch((cur) => cur.copyWith(livenessLevel: 0)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _Radio(
                        // FaceRecognitionSDK-Android-App: 1 = Light Weight
                        label: 'Light Weight',
                        selected: s.livenessLevel == 1,
                        onTap: () =>
                            svc.patch((cur) => cur.copyWith(livenessLevel: 1)),
                      ),
                    ),
                  ],
                ),
                _NumField(
                  label: 'Identify',
                  controller: _draft['identify_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'identify_threshold',
                    0,
                    1,
                    (c, v) => c.copyWith(identifyThreshold: v),
                  ),
                ),
                _NumField(
                  label: 'Yaw',
                  controller: _draft['yaw_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'yaw_threshold',
                    0,
                    90,
                    (c, v) => c.copyWith(yawThreshold: v),
                  ),
                ),
                _NumField(
                  label: 'Roll',
                  controller: _draft['roll_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'roll_threshold',
                    0,
                    90,
                    (c, v) => c.copyWith(rollThreshold: v),
                  ),
                ),
                _NumField(
                  label: 'Pitch',
                  controller: _draft['pitch_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'pitch_threshold',
                    0,
                    90,
                    (c, v) => c.copyWith(pitchThreshold: v),
                  ),
                ),
                _NumField(
                  label: 'Eye closed',
                  controller: _draft['eyeclose_threshold']!,
                  onChanged: () => _commitNum(
                    svc,
                    'eyeclose_threshold',
                    0,
                    1,
                    (c, v) => c.copyWith(eyecloseThreshold: v),
                  ),
                ),
              ],
            ),
          ),
          const _SectionTitle('Reset'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Restore default settings',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () async {
                    final next = await svc.restoreDefaults();
                    _draft['liveness_threshold']!.text =
                        '${next.livenessThreshold}';
                    _draft['identify_threshold']!.text =
                        '${next.identifyThreshold}';
                    _draft['yaw_threshold']!.text = '${next.yawThreshold}';
                    _draft['roll_threshold']!.text = '${next.rollThreshold}';
                    _draft['pitch_threshold']!.text = '${next.pitchThreshold}';
                    _draft['eyeclose_threshold']!.text =
                        '${next.eyecloseThreshold}';
                    if (mounted) {
                      AppDialogs.toast(context, 'Restored default settings');
                    }
                  },
                ),
                const Divider(color: AppColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Clear all person',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () async {
                    await svc.clearAllPersons();
                    if (mounted) {
                      AppDialogs.toast(context, 'Cleared all person');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
              color: selected ? AppColors.accent : Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.text)),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
          ),
          SizedBox(
            width: 88,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
