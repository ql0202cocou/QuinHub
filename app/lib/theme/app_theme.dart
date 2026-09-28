import 'package:flutter/material.dart';

/// LobeHub 风格主题 token（plan.md：Material 3 为底，token 按 LobeHub 定制）。
/// 设计语言：品牌蓝 + 大圆角 + 零阴影卡片 + 浅灰底衬白卡 + 克制留白。
class AppTheme {
  AppTheme._();

  /// 品牌色（LobeChat 标志性的 Ant 蓝）。
  static const seed = Color(0xFF1677FF);

  static const _lightBg = Color(0xFFF4F5F7);
  static const _lightCard = Colors.white;
  static const _darkBg = Color(0xFF101014);
  static const _darkCard = Color(0xFF1C1C21);

  /// 大圆角 token：卡片 16 / 气泡 16（小角 4）/ 输入框 12 / 弹层 20。
  static const radiusCard = 16.0;
  static const radiusBubble = 16.0;
  static const radiusInput = 12.0;
  static const radiusSheet = 20.0;

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(seedColor: seed)
        .copyWith(surface: _lightCard);
    return _base(cs, _lightBg, _lightCard);
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(surface: _darkCard);
    return _base(cs, _darkBg, _darkCard);
  }

  static ThemeData _base(ColorScheme cs, Color bg, Color card) {
    final rounded = BorderRadius.circular(radiusCard);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: rounded),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12.5,
          color: cs.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.primary, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: rounded),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 0.6,
        color: cs.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
