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
import 'package:share_plus/share_plus.dart';

/// 消息块（对齐 LobeHub 移动端实测）：
/// - assistant：首行 28px 头像 + 名称（14/500），正文通栏无气泡，
///   底部 12px 元信息（模型 · tokens）+ 右侧小号操作图标；
/// - user：右对齐 fillTertiary 浅灰气泡（圆角 12、内边距 8×12），下方小号操作图标。
/// 操作图标默认隐藏，点按消息后显示（[showActions]，由聊天页统一管理当前激活的消息）；
/// 元信息常驻。长按仍有完整菜单。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.appDir,
    this.onRegenerate,
    this.onEditResend,
    this.onDelete,
    this.showActions = false,
    this.onTap,
  });

  final MessageDto message;
  final String appDir;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEditResend;
  final VoidCallback? onDelete;

  /// 是否显示操作图标（复制 / 重新生成 / 编辑重发）。
  final bool showActions;

  /// 点按消息（聊天页用来切换 [showActions]）。
  final VoidCallback? onTap;

  static const _revealDuration = Duration(milliseconds: 160);

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
          if (message.text.isNotEmpty)
            LobeListTile(
              icon: Icons.text_fields,
              title: l10n.selectText,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SelectTextPage(text: message.text),
                  ),
                );
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

  Widget _images(BuildContext context) {
    if (message.images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final img in message.images)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) =>
                      _ImageViewerPage(path: '$appDir/$img'),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              ),
              child: Hero(
                tag: '$appDir/$img',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LobeTokens.r),
                  child: Image.file(
                    File('$appDir/$img'),
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  ),
                ),
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
              _images(context),
              if (content.isNotEmpty)
                Text(
                  content,
                  style: TextStyle(fontSize: 14, height: 1.6, color: t.text),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: _revealDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topRight,
          child: !showActions || (message.text.isEmpty && onEditResend == null)
              ? const SizedBox(width: double.infinity)
              : Padding(
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
        _images(context),
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

  /// 元信息（12px textQuaternary：模型 · tokens，常驻）+ 右侧小号操作图标（点按后淡入）。
  /// 行高固定 24，图标显隐不引起布局跳动。
  Widget _metaAndActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    final done = message.status == 'done';
    final meta = [
      if (message.model != null) message.model!,
      if (message.tokensIn != null && message.tokensOut != null)
        '${message.tokensIn}→${message.tokensOut} tokens',
    ].join(' · ');
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.textQuaternary),
            ),
          ),
          AnimatedOpacity(
            opacity: showActions ? 1 : 0,
            duration: _revealDuration,
            child: IgnorePointer(
              ignoring: !showActions,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final content = message.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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

/// 选择文本页：全屏展示消息原文（Markdown 源码），可拖选复制。
/// 渲染态 selectable 见 decisions.md 决策三备注（flutter_markdown selectable 断言 bug），
/// 故用独立页面 + SelectableText 替代。
class _SelectTextPage extends StatelessWidget {
  const _SelectTextPage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).selectText)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(
            text,
            style: TextStyle(fontSize: 14, height: 1.6, color: t.text),
          ),
        ),
      ),
    );
  }
}

/// 图片大图预览：黑底全屏，双指缩放（InteractiveViewer），可分享原图。
class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.path});

  /// 图片绝对路径。
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                SharePlus.instance.share(ShareParams(files: [XFile(path)])),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Hero(
            tag: path,
            child: Image.file(
              File(path),
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
