import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Face crop with numbered landmark dots (Android LandmarkImageView).
class LandmarkImage extends StatelessWidget {
  const LandmarkImage({
    super.key,
    required this.width,
    required this.height,
    this.uri,
    this.filePath,
    this.landmarks = const [],
    this.imageSize = const Size(200, 200),
  });

  final double width;
  final double height;
  final String? uri;
  final String? filePath;
  final List<({double x, double y})> landmarks;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    final mapped = <Offset>[];
    if (landmarks.isNotEmpty && imageSize.width > 0 && imageSize.height > 0) {
      final scale = (width / imageSize.width) < (height / imageSize.height)
          ? width / imageSize.width
          : height / imageSize.height;
      final dx = (width - imageSize.width * scale) / 2;
      final dy = (height - imageSize.height * scale) / 2;
      for (final p in landmarks) {
        mapped.add(Offset(p.x * scale + dx, p.y * scale + dy));
      }
    }

    ImageProvider? provider;
    if (filePath != null && filePath!.isNotEmpty) {
      provider = FileImage(File(filePath!));
    } else if (uri != null && uri!.isNotEmpty) {
      if (uri!.startsWith('data:')) {
        // data URI — decode via MemoryImage not needed if we pass file; skip
        provider = null;
      } else if (uri!.startsWith('file://')) {
        provider = FileImage(File(Uri.parse(uri!).toFilePath()));
      } else if (uri!.startsWith('/')) {
        provider = FileImage(File(uri!));
      } else {
        provider = NetworkImage(uri!);
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppColors.blackBg),
          if (provider != null)
            Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.blackBg),
            )
          else if (uri != null && uri!.startsWith('data:image'))
            Image.memory(
              Uri.parse(uri!).data!.contentAsBytes(),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.blackBg),
            ),
          for (var i = 0; i < mapped.length; i++)
            Positioned(
              left: mapped[i].dx - 4,
              top: mapped[i].dy - 4,
              child: IgnorePointer(
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Positioned(
                        top: -12,
                        left: -6,
                        width: 20,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
