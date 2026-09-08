import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';
import '../../services/person_database.dart';
import '../../services/sdk_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/buttons/tile_button.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/enrolled_thumbnail.dart';
import '../../widgets/loading/busy_overlay.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  final _picker = ImagePicker();

  void _guard(VoidCallback go) {
    final sdk = context.read<SdkService>();
    if (!sdk.ready) {
      AppDialogs.toast(
        context,
        sdk.loading ? 'Loading native SDK…' : 'SDK not ready',
      );
      return;
    }
    go();
  }

  Future<void> _enrollFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final boxes = await faceDetection(
        picked.path,
        const FaceDetectionParam(allAttributes: false),
      );
      if (boxes.length != 1) {
        if (mounted) {
          AppDialogs.toast(
            context,
            boxes.isEmpty ? 'No face detected!' : 'Multiple face detected!',
          );
        }
        return;
      }
      final feature = await templateExtraction(picked.path, boxes.first);
      String? thumb;
      try {
        thumb = await cropFace(picked.path, boxes.first);
      } catch (_) {
        thumb = null;
      }
      if (!mounted) return;
      await context.read<PersonDatabase>().add(
            name: autoPersonName(),
            featureBase64: feature,
            thumbnailBase64: thumb,
          );
      if (mounted) AppDialogs.toast(context, 'Person enrolled!');
    } catch (e) {
      if (mounted) AppDialogs.toast(context, 'Enrollment failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attributeFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final settings = context.read<SettingsService>().settings;
      final boxes = await faceDetection(
        picked.path,
        FaceDetectionParam(
          allAttributes: true,
          checkLivenessLevel: settings.livenessLevel,
        ),
      );
      if (boxes.length != 1) {
        if (mounted) {
          AppDialogs.toast(
            context,
            boxes.isEmpty ? 'No face detected!' : 'Multiple face detected!',
          );
        }
        return;
      }
      final box = boxes.first;
      final decoded = await decodeImageFromList(
        await File(picked.path).readAsBytes(),
      );
      final marks = mapLandmarksToCrop(
        box,
        decoded.width.toDouble(),
        decoded.height.toDouble(),
        200,
        200,
      );
      if (!mounted) return;
      goAttributeResult(
        context,
        AttributeResultArgs(
          faceUri: picked.path,
          box: box,
          cropLandmarks: marks,
        ),
      );
    } catch (e) {
      if (mounted) AppDialogs.toast(context, 'Could not load image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sdk = context.watch<SdkService>();
    final people = context.watch<PersonDatabase>().persons;
    final showWarning = !sdk.ready && sdk.status.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Face Recognition',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 2,
                  ),
                ),
                if (sdk.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      sdk.status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sdk.ready
                            ? AppColors.livenessReal
                            : AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TileButton(
                          title: 'ENROLL',
                          icon: Icons.person_add_alt_1,
                          disabled: !sdk.ready,
                          onPressed: () => _guard(_enrollFromGallery),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TileButton(
                          title: 'IDENTIFY',
                          icon: Icons.face_retouching_natural,
                          disabled: !sdk.ready,
                          onPressed: () =>
                              _guard(() => context.push('/identify')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TileButton(
                          title: 'CAPTURE',
                          icon: Icons.camera_alt,
                          disabled: !sdk.ready,
                          onPressed: () =>
                              _guard(() => context.push('/capture')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TileButton(
                          title: 'ATTRIBUTE',
                          icon: Icons.analytics_outlined,
                          disabled: !sdk.ready,
                          onPressed: () => _guard(_attributeFromGallery),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TileButton(
                          title: 'SETTINGS',
                          icon: Icons.settings,
                          onPressed: () => context.push('/settings'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TileButton(
                          title: 'ABOUT',
                          icon: Icons.info_outline,
                          onPressed: () => context.push('/about'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (people.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 30, 16, 0),
                    child: Text(
                      'Enrolled Face',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        padding: EdgeInsets.only(
                          top: showWarning ? 56 : 10,
                          bottom: 24,
                        ),
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people[index];
                          return Container(
                            height: 72,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                EnrolledThumbnail(person: person),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    person.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => context
                                      .read<PersonDatabase>()
                                      .remove(person.id),
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (people.isEmpty && !showWarning)
                        Center(
                          child: Text(
                            sdk.ready ? 'No enrolled faces yet.' : '',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      if (showWarning)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Material(
                            elevation: 4,
                            color: Colors.transparent,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusError,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sdk.status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.onPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const BusyOverlay(),
        ],
      ),
    );
  }
}
