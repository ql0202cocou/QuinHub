import 'package:flutter/material.dart';

/// LobeUI 设计 token（取自 @lobehub/ui 5.51.2 源码 `src/styles/theme`，
/// 并与 LobeHub 手机网页版实测值核对）。默认主色为中性黑白（非 antd 蓝），
/// 中性色为 gray 色阶。经 `context.lobe` 取用。
class LobeTokens extends ThemeExtension<LobeTokens> {
  const LobeTokens({
    required this.primary,
    required this.primaryHover,
    required this.primaryActive,
    required this.primaryBg,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorBg,
    required this.errorFillTertiary,
    required this.info,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.bgLayout,
    required this.bgContainer,
    required this.bgElevated,
    required this.border,
    required this.borderSecondary,
    required this.fill,
    required this.fillSecondary,
    required this.fillTertiary,
    required this.fillQuaternary,
    required this.shadow,
    required this.shadowSecondary,
    required this.shadowTertiary,
    required this.codeKeyword,
    required this.codeFunction,
    required this.codeStorage,
    required this.codeNumber,
  });

  /// 主色（gray 色阶第 9 级）及交互态；[onPrimary] 为主色上的文字色。
  final Color primary;
  final Color primaryHover;
  final Color primaryActive;
  final Color primaryBg;
  final Color onPrimary;

  /// 功能色。
  final Color success;
  final Color warning;
  final Color error;
  final Color errorBg;
  final Color errorFillTertiary;
  final Color info;

  /// 文本色阶（实色灰阶，非透明度）。
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;

  /// 背景：页面底 / 容器 / 浮层（弹层、菜单、对话框）。
  final Color bgLayout;
  final Color bgContainer;
  final Color bgElevated;

  /// 边框。
  final Color border;
  final Color borderSecondary;

  /// 填充色阶（由深到浅）：fill > secondary > tertiary > quaternary。
  final Color fill;
  final Color fillSecondary;
  final Color fillTertiary;
  final Color fillQuaternary;

  /// 阴影：boxShadow（浮层）/ secondary（悬浮按钮）/ tertiary（轻提示）。
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowSecondary;
  final List<BoxShadow> shadowTertiary;

  /// 代码高亮专用色（字符串 = success、类型 = warning、注释 = textQuaternary）。
  final Color codeKeyword;
  final Color codeFunction;
  final Color codeStorage;
  final Color codeNumber;

  /// 圆角阶梯（LobeUI：XS 4 / SM 6 / 默认 8 / LG 12）。
  static const rXs = 4.0;
  static const rSm = 6.0;
  static const r = 8.0;
  static const rLg = 12.0;

  /// 间距阶梯（4 的倍数）。
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;

  /// 控件高度（small / middle / large）。
  static const hSm = 24.0;
  static const hMd = 32.0;
  static const hLg = 40.0;

  static List<BoxShadow> _layered(List<double> alphas, Color base) => [
    for (final (i, geo) in const [
      (40.0, 80.0),
      (20.0, 40.0),
      (10.0, 20.0),
      (5.0, 10.0),
      (2.0, 4.0),
    ].indexed)
      BoxShadow(
        color: base.withValues(alpha: alphas[i]),
        offset: Offset(0, geo.$1),
        blurRadius: geo.$2,
      ),
  ];

  static List<BoxShadow> _secondary(List<double> alphas) => [
    for (final (i, geo) in const [
      (17.5, 23.4, 0.0),
      (9.4, 12.5, 0.0),
      (5.25, 7.0, 0.0),
      (2.8, 3.7, -2.0),
      (1.2, 1.5, 0.0),
    ].indexed)
      BoxShadow(
        color: Colors.black.withValues(alpha: alphas[i]),
        offset: Offset(0, geo.$1),
        blurRadius: geo.$2,
        spreadRadius: geo.$3,
      ),
  ];

  static final light = LobeTokens(
    primary: const Color(0xFF222222),
    primaryHover: const Color(0xFF333333),
    primaryActive: const Color(0xFF111111),
    primaryBg: const Color(0xFFF5F5F5),
    onPrimary: const Color(0xFFF8F8F8),
    success: const Color(0xFF379D4A),
    warning: const Color(0xFFEE9E0B),
    error: const Color(0xFFEC5E41),
    errorBg: const Color(0xFFFFF7F6),
    errorFillTertiary: const Color(0x0FFF2C0B),
    info: const Color(0xFF0072F5),
    text: const Color(0xFF080808),
    textSecondary: const Color(0xFF666666),
    textTertiary: const Color(0xFF999999),
    textQuaternary: const Color(0xFFBBBBBB),
    bgLayout: const Color(0xFFF8F8F8),
    bgContainer: const Color(0xFFFFFFFF),
    bgElevated: const Color(0xFFFFFFFF),
    border: const Color(0xFFE3E3E3),
    borderSecondary: const Color(0xFFEEEEEE),
    fill: const Color(0x1F000000),
    fillSecondary: const Color(0x0F000000),
    fillTertiary: const Color(0x08000000),
    fillQuaternary: const Color(0x04000000),
    shadow: _layered(const [.06, .05, .04, .03, .02], Colors.black),
    shadowSecondary: _secondary(const [.04, .03, .02, .01, .01]),
    shadowTertiary: const [
      BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 4),
    ],
    codeKeyword: const Color(0xFF0072F5),
    codeFunction: const Color(0xFF005AE0),
    codeStorage: const Color(0xFF892B8A),
    codeNumber: const Color(0xFFA53716),
  );

  static final dark = LobeTokens(
    primary: const Color(0xFFEEEEEE),
    primaryHover: const Color(0xFFFFFFFF),
    primaryActive: const Color(0xFFCCCCCC),
    primaryBg: const Color(0xFF111111),
    onPrimary: const Color(0xFF000000),
    success: const Color(0xFFC4F042),
    warning: const Color(0xFFFFB224),
    error: const Color(0xFFF4416C),
    errorBg: const Color(0xFF380015),
    errorFillTertiary: const Color(0x38FF005F),
    info: const Color(0xFF60B1FF),
    text: const Color(0xFFFFFFFF),
    textSecondary: const Color(0xFFAAAAAA),
    textTertiary: const Color(0xFF6F6F6F),
    textQuaternary: const Color(0xFF555555),
    bgLayout: const Color(0xFF000000),
    bgContainer: const Color(0xFF0D0D0D),
    bgElevated: const Color(0xFF1A1A1A),
    border: const Color(0xFF202020),
    borderSecondary: const Color(0xFF1A1A1A),
    fill: const Color(0x29FFFFFF),
    fillSecondary: const Color(0x1AFFFFFF),
    fillTertiary: const Color(0x0FFFFFFF),
    fillQuaternary: const Color(0x05FFFFFF),
    shadow: _layered(const [.09, .08, .06, .05, .03], Colors.black),
    shadowSecondary: _secondary(const [.06, .05, .03, .02, .02]),
    shadowTertiary: const [
      BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x08000000), offset: Offset(0, 2), blurRadius: 4),
    ],
    codeKeyword: const Color(0xFF60B1FF),
    codeFunction: const Color(0xFF9ABEFF),
    codeStorage: const Color(0xFFD590DA),
    codeNumber: const Color(0xFFFF9480),
  );

  @override
  LobeTokens copyWith() => this;

  @override
  LobeTokens lerp(LobeTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return LobeTokens(
      primary: c(primary, other.primary),
      primaryHover: c(primaryHover, other.primaryHover),
      primaryActive: c(primaryActive, other.primaryActive),
      primaryBg: c(primaryBg, other.primaryBg),
      onPrimary: c(onPrimary, other.onPrimary),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      errorBg: c(errorBg, other.errorBg),
      errorFillTertiary: c(errorFillTertiary, other.errorFillTertiary),
      info: c(info, other.info),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textQuaternary: c(textQuaternary, other.textQuaternary),
      bgLayout: c(bgLayout, other.bgLayout),
      bgContainer: c(bgContainer, other.bgContainer),
      bgElevated: c(bgElevated, other.bgElevated),
      border: c(border, other.border),
      borderSecondary: c(borderSecondary, other.borderSecondary),
      fill: c(fill, other.fill),
      fillSecondary: c(fillSecondary, other.fillSecondary),
      fillTertiary: c(fillTertiary, other.fillTertiary),
      fillQuaternary: c(fillQuaternary, other.fillQuaternary),
      shadow: s(shadow, other.shadow),
      shadowSecondary: s(shadowSecondary, other.shadowSecondary),
      shadowTertiary: s(shadowTertiary, other.shadowTertiary),
      codeKeyword: c(codeKeyword, other.codeKeyword),
      codeFunction: c(codeFunction, other.codeFunction),
      codeStorage: c(codeStorage, other.codeStorage),
      codeNumber: c(codeNumber, other.codeNumber),
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
