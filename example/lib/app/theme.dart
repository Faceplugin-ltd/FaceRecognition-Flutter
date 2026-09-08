import 'package:flutter/material.dart';

/// FaceRecognition Flutter demo palette — aligned with FaceRecognition-React-Native
/// example theme and FaceRecognitionSDK-Android-App Material3 capture chrome.
class AppColors {
  static const bg = Color(0xFF1C1B1F);
  static const card = Color(0xFF5B2D8E);
  static const tile = Color(0xFF63317B);
  static const tileTouch = Color(0xFFBF41E3);
  static const accent = Color(0xFFD0BCFF);
  static const accentDim = Color(0xFF4F378B);
  static const text = Color(0xFFE6E1E5);
  static const muted = Color(0xFF938F99);
  static const statusInfo = Color(0xFF1976D2);
  static const statusOk = Color(0xFF388E3C);
  static const statusWarn = Color(0xFF78350F);
  static const statusError = Color(0xFFB3261E);
  static const surface = Color(0xFF252525);
  static const surfaceAlt = Color(0xFF1C2B42);
  static const border = Color(0xFF49454F);
  static const blackBg = Color(0xFF303033);
  static const livenessReal = Color(0xFF2EE6A6);
  static const livenessSpoof = Color(0xFFFF6B6B);
  static const danger = Color(0xFFFF6B6B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const overlayScrim = Color(0xD91C1B1F);
  static const ovalStroke = Color(0xFFEADDFF);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    // Force plain text — no inherited underlines on body / labels / buttons.
    final plain = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      decoration: TextDecoration.none,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accentDim,
        surface: AppColors.surface,
        error: AppColors.statusError,
      ),
      textTheme: plain,
      primaryTextTheme: plain,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      // Avoid ListTile.tileColor without a Material ancestor (Flutter assert).
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.text,
        iconColor: AppColors.muted,
      ),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
    );
  }
}
