import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI base-ui Button 的 type：主色实底 / 灰填充 / 透明 / 危险。
enum LobeButtonVariant { primary, fill, text, danger }

enum LobeButtonSize { small, middle, large }

/// LobeUI 风格按钮（base-ui Button）：高度 24/32/40，圆角 6/6/8，
/// 字重 500，禁用为半透明。
class LobeButton extends StatelessWidget {
  const LobeButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = LobeButtonVariant.primary,
    this.size = LobeButtonSize.middle,
    this.loading = false,
    this.block = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LobeButtonVariant variant;
  final LobeButtonSize size;
  final bool loading;

  /// 撑满父级宽度。
  final bool block;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final (height, padX, radius, fontSize) = switch (size) {
      LobeButtonSize.small => (LobeTokens.hSm, 8.0, LobeTokens.rSm, 12.0),
      LobeButtonSize.middle => (LobeTokens.hMd, 14.0, LobeTokens.rSm, 13.0),
      LobeButtonSize.large => (LobeTokens.hLg, 16.0, LobeTokens.r, 14.0),
    };
    final (bg, pressedBg, fg) = switch (variant) {
      LobeButtonVariant.primary => (t.primary, t.primaryActive, t.onPrimary),
      LobeButtonVariant.fill => (t.fillTertiary, t.fill, t.text),
      LobeButtonVariant.text => (Colors.transparent, t.fillSecondary, t.text),
      LobeButtonVariant.danger => (t.error, t.error, Colors.white),
    };
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: fontSize,
            height: fontSize,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: fontSize + 3, color: fg),
        if (loading || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          highlightColor: pressedBg == bg
              ? Colors.black.withValues(alpha: 0.08)
              : pressedBg,
          child: Semantics(
            button: true,
            enabled: enabled,
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: padX),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
