import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';
import 'package:quinhub/ui/lobe_avatar.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_sheet.dart';
import 'package:quinhub/ui/lobe_tag.dart';

/// 消息气泡（LobeUI 风格）：assistant 左侧头像 + 全宽 Markdown + 底部操作行；
/// user 右侧品牌蓝气泡 + 右对齐操作行。长按仍有完整菜单。
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

  void _copy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.copied)));
  }

  void _menu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showLobeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LobeListTile(
            icon: Icons.copy_outlined,
            title: l10n.copy,
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              Navigator.pop(ctx);
            },
          ),
          if (onRegenerate != null)
            LobeListTile(
              icon: Icons.refresh,
              title: l10n.regenerate,
              onTap: () {
                Navigator.pop(ctx);
                onRegenerate!();
              },
            ),
          if (onEditResend != null)
            LobeListTile(
              icon: Icons.edit_outlined,
              title: l10n.editResend,
              onTap: () {
                Navigator.pop(ctx);
                onEditResend!();
              },
            ),
        ],
      ),
    );
  }

  /// 助手头像：LobeAvatar 品牌色圆角方块。
  static Widget assistantAvatar(BuildContext context, {double size = 28}) {
    return LobeAvatar(
      icon: Icons.smart_toy_outlined,
      color: context.lobe.brand,
      size: size,
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
              borderRadius: BorderRadius.circular(LobeTokens.rMd),
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

  Widget _userBlock(BuildContext context, String content) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.brand,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(LobeTokens.rLg),
              topRight: Radius.circular(LobeTokens.rLg),
              bottomLeft: Radius.circular(LobeTokens.rLg),
              bottomRight: Radius.circular(LobeTokens.rXs),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _images(),
              if (content.isNotEmpty)
                Text(content, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        if (message.text.isNotEmpty || onEditResend != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEditResend != null)
                  LobeActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: l10n.editResend,
                    onTap: onEditResend!,
                  ),
                if (message.text.isNotEmpty)
                  LobeActionIcon(
                    icon: Icons.copy_outlined,
                    tooltip: l10n.copy,
                    onTap: () => _copy(context),
                  ),
              ],
            ),
          ),
      ],
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
                    borderRadius: BorderRadius.circular(LobeTokens.rMd),
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
                Text(l10n.cancelled, style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              _metaAndActions(context),
            ],
          ),
        ),
      ],
    );
  }

  /// 模型/tokens 元信息（LobeTag）+ 操作行（常驻小图标）。
  Widget _metaAndActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final done = message.status == 'done';
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (message.model != null) LobeTag(text: message.model!),
              if (message.tokensIn != null && message.tokensOut != null)
                LobeTag(text: '${message.tokensIn}→${message.tokensOut} tok'),
            ],
          ),
        ),
        if (done && message.text.isNotEmpty)
          LobeActionIcon(
            icon: Icons.copy_outlined,
            tooltip: l10n.copy,
            onTap: () => _copy(context),
          ),
        if (done && onRegenerate != null)
          LobeActionIcon(
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
            ? _userBlock(context, content)
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
