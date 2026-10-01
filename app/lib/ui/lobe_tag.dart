import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI 风格小号标签（模型名、tokens 元信息等）。
class LobeTag extends StatelessWidget {
  const LobeTag({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final fg = color ?? t.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? t.textQuaternary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: fg),
      ),
    );
  }
}
