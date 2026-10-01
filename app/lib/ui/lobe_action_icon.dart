import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// 消息操作行小图标（复制/重生成/编辑），LobeUI ActionIcon 风格。
class LobeActionIcon extends StatelessWidget {
  const LobeActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(LobeTokens.rSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: context.lobe.textTertiary),
        ),
      ),
    );
  }
}
