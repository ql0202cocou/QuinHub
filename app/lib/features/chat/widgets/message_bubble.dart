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

/// 消息块（对齐 LobeHub 移动端实测）：
/// - assistant：首行 28px 头像 + 名称（14/500），正文通栏无气泡，
///   底部 12px 元信息（模型 · tokens）+ 右侧小号操作图标；
/// - user：右对齐 fillTertiary 浅灰气泡（圆角 12、内边距 8×12），下方小号操作图标。
/// 长按仍有完整菜单。
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

  /// 助手消息首行：28px 头像 + 名称。流式占位消息也复用。
  static Widget assistantHeader(BuildContext context) {
    final t = context.lobe;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: LobeTokens.s2),
      child: Row(
        children: [
          const LobeAvatar(emoji: '🤖', size: 28),
          const SizedBox(width: LobeTokens.s2),
          Text(
            l10n.assistant,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.text,
            ),
          ),
        ],
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
              borderRadius: BorderRadius.circular(LobeTokens.r),
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
          margin: const EdgeInsets.only(left: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.fillTertiary,
            borderRadius: BorderRadius.circular(LobeTokens.rLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _images(),
              if (content.isNotEmpty)
                Text(
                  content,
                  style: TextStyle(fontSize: 14, height: 1.6, color: t.text),
                ),
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
                    size: LobeActionIconSize.small,
                    onTap: onEditResend!,
                  ),
                if (message.text.isNotEmpty)
                  LobeActionIcon(
                    icon: Icons.copy_outlined,
                    tooltip: l10n.copy,
                    size: LobeActionIconSize.small,
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
    final t = context.lobe;
    final errorText = _errorText(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        assistantHeader(context),
        _images(),
        if (content.isNotEmpty) BlockedMarkdown(text: content),
        if (errorText != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.errorFillTertiary,
              borderRadius: BorderRadius.circular(LobeTokens.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: t.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText,
                    style: TextStyle(color: t.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (message.status == 'cancelled')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.cancelled,
              style: TextStyle(fontSize: 12, color: t.textQuaternary),
            ),
          ),
        const SizedBox(height: 6),
        _metaAndActions(context),
      ],
    );
  }

  /// 元信息（12px textQuaternary：模型 · tokens）+ 右侧小号操作图标。
  Widget _metaAndActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    final done = message.status == 'done';
    final meta = [
      if (message.model != null) message.model!,
      if (message.tokensIn != null && message.tokensOut != null)
        '${message.tokensIn}→${message.tokensOut} tokens',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: t.textQuaternary),
          ),
        ),
        if (done && message.text.isNotEmpty)
          LobeActionIcon(
            icon: Icons.copy_outlined,
            tooltip: l10n.copy,
            size: LobeActionIconSize.small,
            onTap: () => _copy(context),
          ),
        if (done && onRegenerate != null)
          LobeActionIcon(
            icon: Icons.refresh,
            tooltip: l10n.regenerate,
            size: LobeActionIconSize.small,
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
        padding: EdgeInsets.symmetric(vertical: isUser ? 8 : 12),
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
