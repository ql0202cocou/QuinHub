import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI 风格主题（Material 3 为底，组件主题统一消费 [LobeTokens]）。
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(LobeTokens.light, Brightness.light);
  static ThemeData dark() => _base(LobeTokens.dark, Brightness.dark);

  static ThemeData _base(LobeTokens t, Brightness brightness) {
    final cs =
        ColorScheme.fromSeed(
          seedColor: LobeTokens.light.brand,
          brightness: brightness,
        ).copyWith(
          primary: t.brand,
          surface: t.cardBg,
          onSurface: t.textPrimary,
          onSurfaceVariant: t.textSecondary,
          outlineVariant: t.fill,
        );
    final text = TextTheme(
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: t.textPrimary),
      bodyMedium: TextStyle(fontSize: 15, color: t.textPrimary),
      bodySmall: TextStyle(fontSize: 13, color: t.textSecondary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: t.textPrimary,
      ),
      labelMedium: TextStyle(fontSize: 12.5, color: t.textSecondary),
      labelSmall: TextStyle(fontSize: 12, color: t.textTertiary),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: text,
      scaffoldBackgroundColor: t.layoutBg,
      extensions: [t],
      appBarTheme: AppBarTheme(
        backgroundColor: t.layoutBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: t.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rLg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LobeTokens.s4,
          vertical: 2,
        ),
        titleTextStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fill,
        isDense: true,
        hintStyle: TextStyle(color: t.textQuaternary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rMd),
          borderSide: BorderSide(color: t.brand, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.cardBg,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LobeTokens.rXl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rMd),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rMd),
        ),
      ),
      dividerTheme: DividerThemeData(space: 1, thickness: 0.6, color: t.fill),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.brand,
        thumbColor: t.brand,
        overlayColor: t.brand.withValues(alpha: 0.12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LobeTokens.rMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.brand,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
    );
  }
}
