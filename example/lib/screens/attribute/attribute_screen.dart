import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/utils/result_details.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart'
    hide resultDetailRows, DetailRow, DetailKind;
import '../../services/settings_service.dart';
import '../../widgets/overlay/landmark_image.dart';

class AttributeScreen extends StatefulWidget {
  const AttributeScreen({super.key, required this.args});

  final AttributeResultArgs args;

  @override
  State<AttributeScreen> createState() => _AttributeScreenState();
}

class _AttributeScreenState extends State<AttributeScreen> {
  String? _cropUri;
  List<({double x, double y})> _marks = [];
  List<DetailRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _marks = widget.args.cropLandmarks;
    _load();
  }

  Future<void> _load() async {
    final faceUri = widget.args.faceUri;
    final box = widget.args.box;
    try {
      final b64 = await cropFace(faceUri, box);
      final uri = 'data:image/jpeg;base64,$b64';
      if (_marks.isEmpty) {
        var srcW = (box.x2 + 1).clamp(1, double.infinity);
        var srcH = (box.y2 + 1).clamp(1, double.infinity);
        try {
          final bytes = await File(faceUri).readAsBytes();
          final decoded = await decodeImageFromList(bytes);
          srcW = decoded.width.toDouble();
          srcH = decoded.height.toDouble();
        } catch (_) {
          // Keep box-based fallback when URI is not a local file.
        }
        _marks = mapLandmarksToCrop(
          box,
          srcW.toDouble(),
          srcH.toDouble(),
          200,
          200,
        );
      }
      if (mounted) setState(() => _cropUri = uri);
    } catch (_) {
      if (mounted) setState(() => _cropUri = faceUri);
    }
    if (!mounted) return;
    final settings = context.read<SettingsService>().settings;
    final rows = resultDetailRows(box, settings, includeMatch: false);
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      appBar: AppBar(
        backgroundColor: AppColors.blackBg,
        title: const Text('Attribute Result'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LandmarkImage(
              uri: _cropUri,
              landmarks: _marks,
              width: 240,
              height: 240,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                if (row.kind == DetailKind.section) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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
