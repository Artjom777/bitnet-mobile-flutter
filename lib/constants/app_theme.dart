import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.appleBackground,
      primaryColor: AppColors.appleBlue,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.appleBackground,
        onSurface: AppColors.appleLabel,
        onSurfaceVariant: AppColors.appleSecondaryLabel,
        primary: AppColors.appleBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.appleTeal,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.appleGreen,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.appleRed,
        onError: Colors.white,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        outline: AppColors.appleGlassBorder,
        outlineVariant: AppColors.outlineVariant,
      ),
      fontFamily: AppTypography.sansFont,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLg,
        headlineLarge: AppTypography.headlineLg,
        headlineMedium: AppTypography.headlineMd,
        headlineSmall: AppTypography.headlineSm,
        titleLarge: AppTypography.titleLg,
        titleMedium: AppTypography.titleMd,
        titleSmall: AppTypography.titleSm,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelLarge: AppTypography.labelLg,
        labelMedium: AppTypography.labelMd,
        labelSmall: AppTypography.labelSm,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.appleBlue,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
        thumbColor: Colors.white,
        overlayColor: AppColors.appleBlue.withOpacity(0.15),
        trackHeight: 4.0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.appleGreen;
          }
          return Colors.white.withOpacity(0.15);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
