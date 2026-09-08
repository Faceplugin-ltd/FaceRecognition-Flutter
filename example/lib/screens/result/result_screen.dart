import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/utils/result_details.dart';
import '../../services/settings_service.dart';
import '../../widgets/overlay/landmark_image.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.args});

  final IdentifyResultArgs args;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<DetailRow> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsService>().settings;
      setState(() {
        _rows = resultDetailRows(
          widget.args.box,
          settings,
          includeMatch: false,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      appBar: AppBar(
        backgroundColor: AppColors.blackBg,
        title: const Text('Identify Result'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _PhotoCol(
                    caption: 'Identified',
                    child: LandmarkImage(
                      uri: args.identifiedUri,
                      landmarks: args.cropLandmarks,
                      width: 140,
                      height: 140,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PhotoCol(
                    caption: 'Enrolled',
                    subtitle: 'ID: ${args.personName}',
                    child: LandmarkImage(
                      filePath: args.enrolledThumbPath,
                      width: 140,
                      height: 140,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Similarity: ${args.similarity}',
            style: const TextStyle(color: AppColors.text, fontSize: 18),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                if (row.kind == DetailKind.section) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      row.title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.value,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCol extends StatelessWidget {
  const _PhotoCol({
    required this.child,
    required this.caption,
    this.subtitle,
  });

  final Widget child;
  final String caption;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          child,
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(caption, style: const TextStyle(color: AppColors.text)),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                subtitle!,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
