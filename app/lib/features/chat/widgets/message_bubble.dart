import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';
import 'package:quinhub/l10n/app_localizations.dart';

/// 消息气泡（LobeHub 风格）：assistant 左侧头像 + 全宽 Markdown + 底部操作行；
/// user 右侧圆角气泡。长按仍有完整菜单。
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

  /// 助手头像：圆角方块 + 品牌色 robot。
  static Widget assistantAvatar(BuildContext context, {double size = 28}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.smart_toy_outlined,
        size: size * 0.62,
        color: cs.primary,
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
              borderRadius: BorderRadius.circular(12),
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

  Widget _userBubble(BuildContext context, String content) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _images(),
            if (content.isNotEmpty)
              Text(content, style: TextStyle(color: cs.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }

  Widget _assistantBlock(BuildContext context, String content) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final errorText = _errorText(l10n);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        assistantAvatar(context),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
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
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 2),
              _metaAndActions(context),
            ],
          ),
        ),
      ],
    );
  }

  /// 模型/tokens 元信息 + 操作行（LobeHub 风格：常驻小图标）。
  Widget _metaAndActions(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final meta = [
      if (message.model != null) message.model!,
      if (message.tokensIn != null && message.tokensOut != null)
        'tokens ${message.tokensIn}→${message.tokensOut}',
    ].join(' · ');
    final done = message.status == 'done';
    return Row(
      children: [
        if (meta.isNotEmpty)
          Expanded(
            child: Text(
              meta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          )
        else
          const Spacer(),
        if (done && message.text.isNotEmpty)
          _ActionIcon(
            icon: Icons.copy_outlined,
            tooltip: l10n.copy,
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.copied)));
            },
          ),
        if (done && onRegenerate != null)
          _ActionIcon(
            icon: Icons.refresh,
            tooltip: l10n.regenerate,
            onTap: onRegenerate!,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final content = message.text;
    return GestureDetector(
      onLongPress: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: isUser
            ? _userBubble(context, content)
            : _assistantBlock(context, content),
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
