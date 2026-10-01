import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeHub 移动端菜单行（设置页等）：平铺无底色，内边距 16、间距 12，
/// 20px 单色线框图标（textTertiary）+ 15px 标题 + 可选副标题 + trailing。
/// [arrow] 为 true 时 trailing 后追加 16px 浅色右箭头。
class LobeListTile extends StatelessWidget {
  const LobeListTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.arrow = false,
    this.danger = false,
    this.enabled = true,
  });

  /// 左侧图标；[leading] 非空时优先生效。
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool arrow;

  /// 危险操作（删除等）：图标与文字用 error 色。
  final bool danger;

  /// 禁用时不可点且整体置灰。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final iconColor = !enabled
        ? t.textQuaternary
        : danger
        ? t.error
        : t.textTertiary;
    final titleColor = !enabled
        ? t.textQuaternary
        : danger
        ? t.error
        : t.text;
    final leadingWidget =
        leading ??
        (icon != null ? Icon(icon, size: 20, color: iconColor) : null);
    return InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: enabled ? t.textTertiary : t.textQuaternary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: LobeTokens.s2),
                trailing!,
              ],
              if (arrow) ...[
                const SizedBox(width: LobeTokens.s1),
                Icon(Icons.chevron_right, size: 18, color: t.border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// LobeUI ListItem（会话列表等）：高 64、内边距 12/16/12/12、
/// 40px 头像 + 14/500 标题 + 12px 描述 + 右侧 12px 日期。
class LobeListItem extends StatelessWidget {
  const LobeListItem({
    super.key,
    required this.avatar,
    required this.title,
    this.description,
    this.date,
    this.addon,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.active = false,
  });

  final Widget avatar;
  final String title;
  final String? description;
  final String? date;

  /// 标题行右侧的附加标记（如置顶图标）。
  final Widget? addon;

  /// 行尾控件（如更多菜单），位于日期之后。
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 选中态：fillSecondary 底。
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Material(
      color: active ? t.fillSecondary : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: LobeTokens.s3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: t.text,
                            ),
                          ),
                        ),
                        if (addon != null) ...[
                          const SizedBox(width: LobeTokens.s1),
                          addon!,
                        ],
                      ],
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: t.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (date != null) ...[
                const SizedBox(width: LobeTokens.s2),
                Text(
                  date!,
                  style: TextStyle(fontSize: 12, color: t.textQuaternary),
                ),
              ],
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
