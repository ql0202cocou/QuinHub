import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_button.dart';

/// LobeUI 风格空状态：大号 emoji + 次级色文案 + 可选主按钮。
class LobeEmpty extends StatelessWidget {
  const LobeEmpty({
    super.key,
    required this.emoji,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LobeTokens.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48, height: 1)),
            const SizedBox(height: LobeTokens.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: t.textTertiary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: LobeTokens.s5),
              LobeButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
