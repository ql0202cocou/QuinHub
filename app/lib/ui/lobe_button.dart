import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

enum LobeButtonVariant { primary, tonal, text, danger }

/// LobeUI 风格按钮：圆角 12，四种变体。
class LobeButton extends StatelessWidget {
  const LobeButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = LobeButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LobeButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LobeTokens.rMd),
    );
    final effectiveOnPressed = loading ? null : onPressed;
    final labelWidget = Text(label);
    final iconWidget = loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon != null ? Icon(icon, size: 18) : null);

    final style = switch (variant) {
      LobeButtonVariant.primary => FilledButton.styleFrom(
        backgroundColor: t.brand,
        disabledBackgroundColor: t.fill,
        shape: shape,
      ),
      LobeButtonVariant.tonal => TextButton.styleFrom(
        foregroundColor: t.brand,
        backgroundColor: t.brand.withValues(alpha: 0.10),
        disabledBackgroundColor: t.fill,
        shape: shape,
      ),
      LobeButtonVariant.text => TextButton.styleFrom(
        foregroundColor: t.textSecondary,
        shape: shape,
      ),
      LobeButtonVariant.danger => FilledButton.styleFrom(
        backgroundColor: cs.error,
        disabledBackgroundColor: t.fill,
        shape: shape,
      ),
    };

    final filled =
        variant == LobeButtonVariant.primary ||
        variant == LobeButtonVariant.danger;
    // 无图标时走普通构造，避免 .icon 构造的固定 icon-label 间距导致文字偏移
    if (iconWidget == null) {
      return filled
          ? FilledButton(
              onPressed: effectiveOnPressed,
              style: style,
              child: labelWidget,
            )
          : TextButton(
              onPressed: effectiveOnPressed,
              style: style,
              child: labelWidget,
            );
    }
    return filled
        ? FilledButton.icon(
            onPressed: effectiveOnPressed,
            icon: iconWidget,
            label: labelWidget,
            style: style,
          )
        : TextButton.icon(
            onPressed: effectiveOnPressed,
            icon: iconWidget,
            label: labelWidget,
            style: style,
          );
  }
}
