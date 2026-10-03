import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Tema Material 3 de la app (claro y oscuro) construido a mano para
/// mantener la identidad de marca en todos los componentes.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.primaryLight : AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.primaryDark : const Color(0xFFE4EDFD),
      onPrimaryContainer: isDark ? Colors.white : AppColors.primaryDark,
      secondary: AppColors.sky,
      onSecondary: Colors.white,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      onSurface: isDark ? Colors.white : AppColors.ink,
      surfaceContainerLowest: isDark ? AppColors.darkCanvas : Colors.white,
      surfaceContainerLow: isDark ? AppColors.darkSurface : AppColors.canvas,
      surfaceContainer: isDark ? AppColors.darkSurface : AppColors.canvas,
      surfaceContainerHigh: isDark ? const Color(0xFF162541) : Colors.white,
      onSurfaceVariant: isDark ? AppColors.inkFaint : AppColors.inkMuted,
      outline: isDark ? AppColors.darkLine : AppColors.line,
      outlineVariant: isDark ? AppColors.darkLine : AppColors.line,
      shadow: Colors.black.withValues(alpha: 0.08),
      scrim: Colors.black54,
      inverseSurface: isDark ? Colors.white : AppColors.navy,
      onInverseSurface: isDark ? AppColors.navy : Colors.white,
      inversePrimary: AppColors.primaryLight,
    );

    final TextTheme text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brLg,
          side: BorderSide(color: scheme.outline),
        ),
      ),

      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
        insetPadding: const EdgeInsets.all(Gap.lg),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outline,
        linearMinHeight: 6,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.6),
      ),

      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final Color ink = scheme.onSurface;
    final Color muted = scheme.onSurfaceVariant;
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700, color: ink, height: 1.2, letterSpacing: -0.6),
      headlineMedium: TextStyle(
          fontSize: 27, fontWeight: FontWeight.w700, color: ink, height: 1.22, letterSpacing: -0.5),
      headlineSmall: TextStyle(
          fontSize: 23, fontWeight: FontWeight.w700, color: ink, height: 1.25, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink, height: 1.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink, height: 1.35),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: muted, height: 1.5),
      bodySmall: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w400, color: muted, height: 1.45),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
      labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.4),
    );
  }
}
