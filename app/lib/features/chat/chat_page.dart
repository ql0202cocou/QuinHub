import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quinhub/bridge/api/chat.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';
import 'package:quinhub/features/chat/widgets/message_bubble.dart';
import 'package:quinhub/features/chat/share.dart';
import 'package:quinhub/state/chat.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/state/core.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:uuid/uuid.dart';
import 'package:quinhub/l10n/app_localizations.dart';

/// 聊天页：消息列表 + 流式渲染 + 输入栏（含图片）+ 模型切换 + 长按消息菜单。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _atBottom = true;

  /// 待发送图片（已压缩落盘 files/）。
  final List<({String filePath, Uint8List bytes})> _pendingImages = [];

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      _atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 48;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _atBottom) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;
    final images = [
      for (final img in _pendingImages)
        ImageInput(
          mime: 'image/jpeg',
          data: base64Encode(img.bytes),
          filePath: img.filePath,
        ),
    ];
    _input.clear();
    setState(() => _pendingImages.clear());
    await ref.read(chatProvider(_id).notifier).send(text, images: images);
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.gallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.camera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2048);
    if (x == null) return;
    final bytes =
        await FlutterImageCompress.compressWithFile(x.path, quality: 85) ??
        await x.readAsBytes();
    final appDir = ref.read(appDirProvider);
    final rel = 'files/${const Uuid().v4()}.jpg';
    final f = File('$appDir/$rel');
    await f.create(recursive: true);
    await f.writeAsBytes(bytes);
    setState(() => _pendingImages.add((filePath: rel, bytes: bytes)));
  }

  Future<void> _editResend(MessageDto m) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: m.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editResend),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.send),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await ref.read(chatProvider(_id).notifier).editResend(m.id, text);
    }
  }

  void _showUsage(AppLocalizations l10n) {
    final msgs = ref.read(chatProvider(_id)).valueOrNull?.messages ?? [];
    final done = msgs.where((m) => m.role == 'assistant' && m.status == 'done');
    final inSum = done.fold<int>(0, (a, m) => a + (m.tokensIn?.toInt() ?? 0));
    final outSum = done.fold<int>(0, (a, m) => a + (m.tokensOut?.toInt() ?? 0));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.usageStats),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.usageMessages(msgs.length)),
            Text(l10n.usageTokensIn(inSum)),
            Text(l10n.usageTokensOut(outSum)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.acknowledge),
          ),
        ],
      ),
    );
  }

  Future<void> _pickModel(ConversationDto conv) async {
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in profiles)
              if (p.enabledModels.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final m in p.enabledModels)
                  ListTile(
                    dense: true,
                    title: Text(m),
                    trailing: (conv.modelId == m && conv.profileId == p.id)
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await conversationSetModel(
                        id: conv.id,
                        profileId: p.id,
                        modelId: m,
                      );
                      ref.invalidate(conversationProvider(_id));
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final convAsync = ref.watch(conversationProvider(_id));
    final chatAsync = ref.watch(chatProvider(_id));
    final chat = chatAsync.valueOrNull;
    final appDir = ref.watch(appDirProvider);

    // 流式时自动跟随底部
    if (chat?.streaming ?? false) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: convAsync.when(
          data: (c) => Text(c.title.isEmpty ? l10n.newChat : c.title),
          loading: () => const Text('…'),
          error: (_, _) => Text(l10n.conversation),
        ),
        actions: [
          convAsync.maybeWhen(
            data: (c) => TextButton(
              onPressed: () => _pickModel(c),
              child: Text(
                c.modelId ?? l10n.selectModel,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (v) {
              final msgs = chatAsync.valueOrNull?.messages ?? [];
              final title = convAsync.valueOrNull?.title ?? '';
              if (v == 'md') exportMarkdown(title, msgs, l10n);
              if (v == 'img') shareAsImage(context, title, msgs, l10n);
              if (v == 'usage') _showUsage(l10n);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'md', child: Text(l10n.exportMarkdown)),
              PopupMenuItem(value: 'img', child: Text(l10n.shareImage)),
              PopupMenuItem(value: 'usage', child: Text(l10n.usageStats)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
              data: (_) {
                final messages = chat!.messages;
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    for (var i = 0; i < messages.length; i++)
                      _bubbleFor(messages, i, chat, appDir),
                    if (chat.streaming) _streamingBubble(chat),
                  ],
                );
              },
            ),
          ),
          if (_pendingImages.isNotEmpty) _imageChips(),
          const Divider(height: 1),
          _inputBar(chat?.streaming ?? false),
        ],
      ),
    );
  }

  Widget _bubbleFor(
    List<MessageDto> messages,
    int i,
    ChatState chat,
    String appDir,
  ) {
    final m = messages[i];
    final isLastAssistant =
        m.role == 'assistant' && i == messages.length - 1 && !chat.streaming;
    return MessageBubble(
      key: ValueKey(m.id),
      message: m,
      appDir: appDir,
      onRegenerate: isLastAssistant
          ? () => ref.read(chatProvider(_id).notifier).regenerate()
          : null,
      onEditResend: m.role == 'user' ? () => _editResend(m) : null,
    );
  }

  Widget _streamingBubble(ChatState chat) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chat.reasoningText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                chat.reasoningText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (chat.streamingText.isNotEmpty)
            BlockedMarkdown(text: chat.streamingText),
          const SizedBox(height: 4),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _imageChips() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _pendingImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final img = _pendingImages[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  img.bytes,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: IconButton(
                  icon: const Icon(Icons.cancel, size: 18),
                  onPressed: () => setState(() => _pendingImages.removeAt(i)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _inputBar(bool streaming) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: streaming ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.inputHint,
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: streaming
                  ? () => ref.read(chatProvider(_id).notifier).cancel()
                  : _send,
              icon: Icon(streaming ? Icons.stop : Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
