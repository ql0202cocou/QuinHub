import 'package:flutter/material.dart';

/// LobeUI 风格设计 token（仿 @lobehub/ui / antd token 体系）。
/// 经 `Theme.of(context).extension<LobeTokens>()` 或 `context.lobe` 取用。
class LobeTokens extends ThemeExtension<LobeTokens> {
  const LobeTokens({
    required this.brand,
    required this.brandHover,
    required this.brandActive,
    required this.success,
    required this.warning,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.layoutBg,
    required this.cardBg,
    required this.fill,
    required this.fillSecondary,
    required this.cardShadow,
  });

  /// 品牌蓝（LobeChat 标志性的 Ant 蓝）及交互梯度。
  final Color brand;
  final Color brandHover;
  final Color brandActive;

  /// 功能色（error 直接用 ColorScheme.error）。
  final Color success;
  final Color warning;
  final Color info;

  /// 文本色阶（antd 透明度规范）。
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;

  /// 容器色：页面底衬 / 卡片 / 填充 / 弱填充。
  final Color layoutBg;
  final Color cardBg;
  final Color fill;
  final Color fillSecondary;

  /// 柔和卡片阴影（dark 下近无）。
  final List<BoxShadow> cardShadow;

  /// 圆角阶梯。
  static const rXs = 4.0;
  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 20.0;

  /// 间距阶梯（4 的倍数）。
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;

  static const light = LobeTokens(
    brand: Color(0xFF1677FF),
    brandHover: Color(0xFF4096FF),
    brandActive: Color(0xFF0958D9),
    success: Color(0xFF52C41A),
    warning: Color(0xFFFAAD14),
    info: Color(0xFF1677FF),
    textPrimary: Color(0xE0000000),
    textSecondary: Color(0xA6000000),
    textTertiary: Color(0x73000000),
    textQuaternary: Color(0x40000000),
    layoutBg: Color(0xFFF4F5F7),
    cardBg: Colors.white,
    fill: Color(0x0F000000),
    fillSecondary: Color(0x08000000),
    cardShadow: [
      BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
    ],
  );

  static const dark = LobeTokens(
    brand: Color(0xFF1668DC),
    brandHover: Color(0xFF3C89E8),
    brandActive: Color(0xFF1554AD),
    success: Color(0xFF49AA19),
    warning: Color(0xFFD89614),
    info: Color(0xFF1668DC),
    textPrimary: Color(0xE0FFFFFF),
    textSecondary: Color(0xA6FFFFFF),
    textTertiary: Color(0x73FFFFFF),
    textQuaternary: Color(0x40FFFFFF),
    layoutBg: Color(0xFF101014),
    cardBg: Color(0xFF1C1C21),
    fill: Color(0x14FFFFFF),
    fillSecondary: Color(0x0AFFFFFF),
    cardShadow: [],
  );

  @override
  LobeTokens copyWith({
    Color? brand,
    Color? brandHover,
    Color? brandActive,
    Color? success,
    Color? warning,
    Color? info,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textQuaternary,
    Color? layoutBg,
    Color? cardBg,
    Color? fill,
    Color? fillSecondary,
    List<BoxShadow>? cardShadow,
  }) {
    return LobeTokens(
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      brandActive: brandActive ?? this.brandActive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textQuaternary: textQuaternary ?? this.textQuaternary,
      layoutBg: layoutBg ?? this.layoutBg,
      cardBg: cardBg ?? this.cardBg,
      fill: fill ?? this.fill,
      fillSecondary: fillSecondary ?? this.fillSecondary,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  LobeTokens lerp(LobeTokens? other, double t) {
    if (other == null) return this;
    return LobeTokens(
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      brandActive: Color.lerp(brandActive, other.brandActive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textQuaternary: Color.lerp(textQuaternary, other.textQuaternary, t)!,
      layoutBg: Color.lerp(layoutBg, other.layoutBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fillSecondary: Color.lerp(fillSecondary, other.fillSecondary, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension LobeTokensX on BuildContext {
  /// 主题未注册 [LobeTokens]（如裸 MaterialApp 的测试环境）时按亮度回落。
  LobeTokens get lobe =>
      Theme.of(this).extension<LobeTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? LobeTokens.dark
          : LobeTokens.light);
}
