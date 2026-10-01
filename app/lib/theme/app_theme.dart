import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI 风格主题（Material 3 为底，组件主题统一消费 [LobeTokens]）。
/// 字号按 LobeUI（antd 默认 14 基准）对齐，字体用系统默认。
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(LobeTokens.light, Brightness.light);
  static ThemeData dark() => _base(LobeTokens.dark, Brightness.dark);

  static ThemeData _base(LobeTokens t, Brightness brightness) {
    final cs =
        ColorScheme.fromSeed(
          seedColor: t.primary,
          brightness: brightness,
        ).copyWith(
          primary: t.primary,
          onPrimary: t.onPrimary,
          secondary: t.primary,
          onSecondary: t.onPrimary,
          error: t.error,
          errorContainer: t.errorBg,
          onErrorContainer: t.error,
          surface: t.bgContainer,
          onSurface: t.text,
          onSurfaceVariant: t.textSecondary,
          surfaceContainerHighest: t.fillSecondary,
          outline: t.border,
          outlineVariant: t.borderSecondary,
        );
    final text = TextTheme(
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: t.text),
      bodyMedium: TextStyle(fontSize: 14, color: t.text),
      bodySmall: TextStyle(fontSize: 12, color: t.textTertiary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: t.text,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: t.textSecondary,
      ),
      labelSmall: TextStyle(fontSize: 12, color: t.textQuaternary),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LobeTokens.rSm),
    );
    OutlineInputBorder inputBorder(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(LobeTokens.r),
      borderSide: c == Colors.transparent
          ? BorderSide.none
          : BorderSide(color: c),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      textTheme: text,
      scaffoldBackgroundColor: t.bgLayout,
      splashFactory: NoSplash.splashFactory,
      highlightColor: t.fillTertiary,
      hoverColor: t.fillTertiary,
      extensions: [t],
      appBarTheme: AppBarTheme(
        backgroundColor: t.bgLayout,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 44,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.text, size: 22),
      ),
      iconTheme: IconThemeData(color: t.textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: t.bgContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.r),
          side: BorderSide(color: t.borderSecondary),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: LobeTokens.s4),
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: t.textTertiary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fillTertiary,
        isDense: true,
        hintStyle: TextStyle(color: t.textQuaternary),
        labelStyle: TextStyle(color: t.textSecondary),
        floatingLabelStyle: TextStyle(color: t.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(t.border),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.text,
        selectionColor: t.fill,
        selectionHandleColor: t.text,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.bgElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.bgElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.fill,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LobeTokens.rLg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.bgElevated,
        contentTextStyle: TextStyle(color: t.text, fontSize: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.r),
          side: BorderSide(color: t.borderSecondary),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.bgElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.r),
          side: BorderSide(color: t.borderSecondary),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.bgElevated,
          borderRadius: BorderRadius.circular(LobeTokens.rSm),
          boxShadow: t.shadowTertiary,
          border: Border.all(color: t.borderSecondary),
        ),
        textStyle: TextStyle(color: t.textSecondary, fontSize: 12),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: t.borderSecondary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.primary,
        inactiveTrackColor: t.fill,
        thumbColor: t.primary,
        overlayColor: t.fillSecondary,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onPrimary : t.bgContainer,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.fill,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : null,
        ),
        checkColor: WidgetStatePropertyAll(t.onPrimary),
        side: BorderSide(color: t.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LobeTokens.rXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.fillSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          minimumSize: const Size(0, LobeTokens.hMd),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.text,
          minimumSize: const Size(0, LobeTokens.hMd),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        sizeConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
        shape: const CircleBorder(),
      ),
    );
  }
}
