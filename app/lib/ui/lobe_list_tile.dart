import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI List 风格列表项：图标置于圆角色块 + 标题/副标题/trailing。
class LobeListTile extends StatelessWidget {
  const LobeListTile({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.danger = false,
    this.enabled = true,
  });

  /// 左侧图标（放入圆角色块）；[leading] 非空时优先生效。
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 危险操作（删除等）：图标与文字用 error 色。
  final bool danger;

  /// 禁用时不可点且整体置灰。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final theme = Theme.of(context);
    final accent = !enabled
        ? t.textTertiary
        : danger
        ? theme.colorScheme.error
        : (iconColor ?? t.brand);
    final titleColor = !enabled
        ? t.textTertiary
        : (danger ? theme.colorScheme.error : null);
    final leadingWidget =
        leading ??
        (icon != null
            ? Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              )
            : null);
    return InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LobeTokens.s4,
          vertical: 10,
        ),
        child: Row(
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: LobeTokens.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled ? null : t.textQuaternary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: LobeTokens.s2),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
