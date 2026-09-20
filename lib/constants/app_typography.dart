import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String sansFont = 'Roboto';
  static const String monoFont = 'monospace';

  static const TextStyle displayLg = TextStyle(
    fontFamily: sansFont,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 64 / 57,
    letterSpacing: -0.25,
    color: AppColors.onSurface,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: sansFont,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 40 / 32,
    color: AppColors.onSurface,
  );

  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: sansFont,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 34 / 26,
    color: AppColors.primary,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: sansFont,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 36 / 28,
    letterSpacing: -0.5,
    color: AppColors.onSurface,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: sansFont,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 32 / 24,
    color: AppColors.onSurface,
  );

  static const TextStyle titleLg = TextStyle(
    fontFamily: sansFont,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 28 / 22,
    color: AppColors.onSurface,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: sansFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: 0.15,
    color: AppColors.onSurface,
  );

  static const TextStyle titleSm = TextStyle(
    fontFamily: sansFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.1,
    color: AppColors.onSurface,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sansFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    letterSpacing: 0.5,
    color: AppColors.onSurface,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: sansFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.25,
    color: AppColors.onSurface,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: sansFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0.4,
    color: AppColors.onSurfaceVariant,
  );

  // Monospace Labels
  static const TextStyle labelLg = TextStyle(
    fontFamily: monoFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.1,
    color: AppColors.onSurface,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: monoFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.5,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: monoFont,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 14 / 10,
    letterSpacing: 0.5,
    color: AppColors.onSurfaceVariant,
  );
}
