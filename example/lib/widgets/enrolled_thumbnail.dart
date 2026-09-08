import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/person_database.dart';

/// Resolves relative/legacy thumbnail paths under documents/thumbnails.
class EnrolledThumbnail extends StatelessWidget {
  const EnrolledThumbnail({
    super.key,
    required this.person,
    this.size = 60,
  });

  final EnrolledPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final db = context.read<PersonDatabase>();
    return FutureBuilder<String?>(
      future: db.resolveThumbnail(person),
      builder: (context, snap) {
        final path = snap.data;
        if (path == null || path.isEmpty) {
          return _placeholder();
        }
        return ClipOval(
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: AppColors.muted, size: size * 0.45),
    );
  }
}
