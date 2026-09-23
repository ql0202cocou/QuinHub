import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';

/// 消息气泡（LobeHub 风格接近全宽）：user 浅色块靠右，assistant 全宽 Markdown。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onEditResend,
    this.onDelete,
  });

  final MessageDto message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEditResend;
  final VoidCallback? onDelete;

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(ctx);
              },
            ),
            if (onRegenerate != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate!();
                },
              ),
            if (onEditResend != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑并重发'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEditResend!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final errorText = _errorText();

    final content = message.content;
    final bubble = isUser
        ? Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(left: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                content,
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty) BlockedMarkdown(text: content),
              if (errorText != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.status == 'cancelled')
                Text(
                  '已取消',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
            ],
          );

    return GestureDetector(
      onLongPress: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bubble,
            if (!isUser && (message.model != null || message.tokensOut != null))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (message.model != null) message.model!,
                    if (message.tokensIn != null && message.tokensOut != null)
                      'tokens ${message.tokensIn}→${message.tokensOut}',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _errorText() {
    if (message.status != 'error') return null;
    final raw = message.error;
    if (raw == null) return '未知错误';
    // error 为 JSON {"code","message"}（bridge 落库格式）
    try {
      final m = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(raw);
      if (m != null) return m.group(1)!.replaceAll(r'\"', '"');
    } catch (_) {}
    return raw;
  }
}
