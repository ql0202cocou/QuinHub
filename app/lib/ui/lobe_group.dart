import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI List 风格分组卡片：圆角容器 + 行间 inset 分隔线。
class LobeGroup extends StatelessWidget {
  const LobeGroup({
    super.key,
    required this.children,
    this.dividerIndent = 60,
    this.margin,
  });

  final List<Widget> children;

  /// 分隔线左缩进（对齐标题文字）。
  final double dividerIndent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(LobeTokens.rLg),
          boxShadow: t.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: dividerIndent, color: t.fill),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
