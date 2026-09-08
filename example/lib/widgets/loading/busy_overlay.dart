import 'package:flutter/material.dart';

import '../../app/theme.dart';

class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: AppColors.accent),
    );
  }
}
