import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';

/// 统一底部弹层（仿 LobeUI Drawer placement=bottom）：bgElevated 底、顶部圆角 12；
/// 有 [title] 时显示「标题 + 关闭」头部，否则仅留顶部间距。
Future<T?> showLobeSheet<T>(
  BuildContext context, {
  String? title,
  bool isScrollControlled = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: false,
    builder: (ctx) {
      final t = ctx.lobe;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LobeTokens.s4,
                  LobeTokens.s2,
                  LobeTokens.s2,
                  LobeTokens.s1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                    LobeActionIcon(
                      icon: Icons.close,
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: LobeTokens.s2),
            Flexible(child: Builder(builder: builder)),
            const SizedBox(height: LobeTokens.s2),
          ],
        ),
      );
    },
  );
}
