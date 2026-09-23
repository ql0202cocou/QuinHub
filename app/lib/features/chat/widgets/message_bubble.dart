import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';
import 'package:quinhub/l10n/app_localizations.dart';

/// 消息气泡（LobeHub 风格接近全宽）：user 浅色块靠右，assistant 全宽 Markdown。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.appDir,
    this.onRegenerate,
    this.onEditResend,
    this.onDelete,
  });

  final MessageDto message;
  final String appDir;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEditResend;
  final VoidCallback? onDelete;

  void _menu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n.copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(ctx);
              },
            ),
            if (onRegenerate != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.regenerate),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate!();
                },
              ),
            if (onEditResend != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editResend),
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

  Widget _images() {
    if (message.images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final img in message.images)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File('$appDir/$img'),
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final errorText = _errorText(l10n);

    final content = message.text;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _images(),
                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _images(),
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
                  l10n.cancelled,
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

  String? _errorText(AppLocalizations l10n) {
    if (message.status != 'error') return null;
    final raw = message.error;
    if (raw == null) return l10n.unknownError;
    // error 为 JSON {"code","message"}（bridge 落库格式）
    try {
      final m = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(raw);
      if (m != null) return m.group(1)!.replaceAll(r'\"', '"');
    } catch (_) {}
    return raw;
  }
}
