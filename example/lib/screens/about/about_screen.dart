import 'package:flutter/material.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

import '../../app/theme.dart';
import '../../widgets/face_plugin_logo.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _licenseText = 'License: …';

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    try {
      final status = LicenseStatus.fromJson(await getLicenseStatus());
      if (!mounted) return;
      setState(() => _licenseText = 'License: ${status.label}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _licenseText = 'License: Not licensed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          FacePluginLogo(
            onPressed: FacePluginLogo.openWebsite,
          ),
          const SizedBox(height: 16),
          const Text(
            'FacePlugin',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Face Recognition SDK',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.accent, fontSize: 15),
          ),
          const SizedBox(height: 16),
          _AboutCard(text: _licenseText, compact: true, centered: true),
          const SizedBox(height: 16),
          const _AboutCard(
            text:
                'FacePlugin builds on-device identity technology — face recognition, '
                'liveness, and document reading — so biometric data never has to leave '
                'the phone.',
          ),
          const SizedBox(height: 16),
          const _AboutCard(
            text:
                'This app demos the Face Recognition SDK for Flutter: enroll, '
                'identify, capture, and attribute analysis. Everything runs fully '
                'on-premise.',
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: FacePluginLogo.openWebsite,
            child: const Text(
              'faceplugin.com',
              style: TextStyle(color: AppColors.accent, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '© 2026 FacePlugin. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.text,
    this.compact = false,
    this.centered = false,
  });
  final String text;
  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: AppColors.text,
          fontSize: compact ? 13 : 14,
          height: 1.55,
        ),
      ),
    );
  }
}
