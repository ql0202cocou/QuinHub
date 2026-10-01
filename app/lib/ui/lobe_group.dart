import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeHub 移动端列表分组：平铺无卡片。
/// 组与组之间用 6px fillTertiary 横条分隔（[band]），可选 12/500 次级色小标题。
class LobeGroup extends StatelessWidget {
  const LobeGroup({
    super.key,
    required this.children,
    this.title,
    this.band = true,
  });

  final List<Widget> children;
  final String? title;

  /// 顶部是否画分隔横条（页面第一组通常传 false）。
  final bool band;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (band) Container(height: 6, color: t.fillTertiary),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LobeTokens.s4,
              LobeTokens.s4,
              LobeTokens.s4,
              LobeTokens.s1,
            ),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: t.textSecondary,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}
