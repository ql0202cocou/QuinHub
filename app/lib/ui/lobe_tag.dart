import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI Tag（middle）：高 22、左右 8、圆角 3、字号 12。
/// 默认 fillTertiary 底 + textSecondary 字；传 [color] 时字用该色、底为其 6% 透明。
class LobeTag extends StatelessWidget {
  const LobeTag({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: LobeTokens.s2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.06) ?? t.fillTertiary,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: color ?? t.textSecondary,
        ),
      ),
    );
  }
}
