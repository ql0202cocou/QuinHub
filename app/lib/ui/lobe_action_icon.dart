import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

enum LobeActionIconSize { small, middle, large }

/// LobeUI ActionIcon：无边框小图标按钮。
/// 尺寸 small 24/14、middle 36/20、large 44/24（容器/图标）；
/// 默认 textTertiary，按下 textSecondary + fillSecondary 底。
class LobeActionIcon extends StatelessWidget {
  const LobeActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = LobeActionIconSize.middle,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final LobeActionIconSize size;

  /// 覆盖图标色（如主色）。
  final Color? color;

  /// filled 变体：fillTertiary 底。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final (box, glyph, radius) = switch (size) {
      LobeActionIconSize.small => (24.0, 14.0, LobeTokens.rXs),
      LobeActionIconSize.middle => (36.0, 20.0, LobeTokens.rSm),
      LobeActionIconSize.large => (44.0, 24.0, LobeTokens.r),
    };
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? t.fillTertiary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: t.fillSecondary,
          child: SizedBox(
            width: box,
            height: box,
            child: Icon(icon, size: glyph, color: color ?? t.textTertiary),
          ),
        ),
      ),
    );
  }
}
