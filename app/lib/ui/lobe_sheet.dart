import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// 统一底部弹层：drag handle（主题自带）+ 可选标题栏 + 内容区。
Future<T?> showLobeSheet<T>(
  BuildContext context, {
  String? title,
  bool isScrollControlled = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LobeTokens.s5,
                0,
                LobeTokens.s5,
                LobeTokens.s2,
              ),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
          Flexible(child: Builder(builder: builder)),
        ],
      ),
    ),
  );
}
