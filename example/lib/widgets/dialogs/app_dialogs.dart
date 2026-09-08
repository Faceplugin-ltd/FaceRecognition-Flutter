import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

class AppDialogs {
  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(message, style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void toast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final media = MediaQuery.of(context);
    // Keep toasts pinned near the top while visible (not the default bottom).
    final bottomInset =
        (media.size.height - media.padding.top - 72).clamp(80.0, double.infinity);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomInset,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    HapticFeedback.selectionClick();
  }
}
