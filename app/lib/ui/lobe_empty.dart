import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_button.dart';

/// LobeUI 风格空状态：大圆角图标块 + 文案 + 可选按钮。
class LobeEmpty extends StatelessWidget {
  const LobeEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(LobeTokens.rXl),
              ),
              child: Icon(icon, size: 32, color: t.textTertiary),
            ),
            const SizedBox(height: LobeTokens.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: t.textSecondary),
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
