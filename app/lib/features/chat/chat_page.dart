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
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';
import 'package:quinhub/ui/lobe_button.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_sheet.dart';
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

  /// 当前显示操作图标的消息（点按消息切换；同一时间只激活一条）。
  String? _activeMessageId;

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
      if (_scroll.position.pixels <= 48) _loadMore();
    });
  }

  /// 滚动接近顶部时向前翻页；翻页后保持视口停在原消息上（按 extent 增量补偿）。
  Future<void> _loadMore() async {
    final chat = ref.read(chatProvider(_id)).valueOrNull;
    if (chat == null || !chat.hasMore || chat.loadingMore || chat.streaming) {
      return;
    }
    final prevExtent = _scroll.position.maxScrollExtent;
    final prevPixels = _scroll.position.pixels;
    await ref.read(chatProvider(_id).notifier).loadMore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        final delta = _scroll.position.maxScrollExtent - prevExtent;
        if (delta > 0) _scroll.jumpTo(prevPixels + delta);
      }
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
    setState(() {
      _pendingImages.clear();
      _activeMessageId = null;
    });
    await ref.read(chatProvider(_id).notifier).send(text, images: images);
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final source = await showLobeSheet<ImageSource>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LobeListTile(
            icon: Icons.photo_library_outlined,
            title: l10n.gallery,
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          LobeListTile(
            icon: Icons.photo_camera_outlined,
            title: l10n.camera,
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
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

  /// 会话参数弹层：temperature / top_p / max_tokens / system_prompt。
  /// 保存整体写回 conversation.params（'{}' 表示恢复默认），发送链路每次从库里读，无需额外刷新。
  Future<void> _showParams(ConversationDto conv) async {
    final l10n = AppLocalizations.of(context);
    final p = (jsonDecode(conv.params.isEmpty ? '{}' : conv.params) as Map)
        .cast<String, dynamic>();
    var temperature = (p['temperature'] as num?)?.toDouble() ?? 1.0;
    var topP = (p['top_p'] as num?)?.toDouble() ?? 1.0;
    final maxTokens = TextEditingController(
      text: (p['max_tokens'] as num?)?.toString() ?? '',
    );
    final systemPrompt = TextEditingController(
      text: p['system_prompt'] as String? ?? '',
    );
    final action = await showLobeSheet<String>(
      context,
      title: l10n.conversationParams,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Temperature: ${temperature.toStringAsFixed(2)}'),
              Slider(
                value: temperature,
                min: 0,
                max: 2,
                divisions: 40,
                onChanged: (v) => setSheet(() => temperature = v),
              ),
              Text('Top P: ${topP.toStringAsFixed(2)}'),
              Slider(
                value: topP,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (v) => setSheet(() => topP = v),
              ),
              TextField(
                controller: maxTokens,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.maxTokens,
                  hintText: l10n.maxTokensHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: systemPrompt,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.systemPrompt,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  LobeButton(
                    label: l10n.resetToDefault,
                    variant: LobeButtonVariant.text,
                    onPressed: () => Navigator.pop(ctx, 'reset'),
                  ),
                  const Spacer(),
                  LobeButton(
                    label: l10n.cancel,
                    variant: LobeButtonVariant.fill,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 8),
                  LobeButton(
                    label: l10n.save,
                    onPressed: () => Navigator.pop(ctx, 'save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null) return;
    final mt = int.tryParse(maxTokens.text.trim());
    final sp = systemPrompt.text.trim();
    final params = action == 'reset'
        ? '{}'
        : jsonEncode(<String, dynamic>{
            'temperature': temperature,
            'top_p': topP,
            'max_tokens': ?mt,
            if (sp.isNotEmpty) 'system_prompt': sp,
          });
    await conversationUpdateParams(id: conv.id, params: params);
    ref.invalidate(conversationProvider(_id));
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
    final l10n = AppLocalizations.of(context);
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    final t = context.lobe;
    await showLobeSheet<void>(
      context,
      title: l10n.selectModel,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final p in profiles)
            if (p.enabledModels.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              for (final m in p.enabledModels)
                LobeListTile(
                  title: m,
                  trailing: (conv.modelId == m && conv.profileId == p.id)
                      ? Icon(Icons.check, size: 18, color: t.primary)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final convAsync = ref.watch(conversationProvider(_id));
    final chatAsync = ref.watch(chatProvider(_id));
    final chat = chatAsync.valueOrNull;
    final appDir = ref.watch(appDirProvider);
    // vision gating：非视觉模型禁用图片入口（plan.md 第一期范围）
    final vision =
        ref
            .watch(modelVisionProvider(convAsync.valueOrNull?.modelId))
            .valueOrNull ??
        true;

    // 流式时自动跟随底部
    if (chat?.streaming ?? false) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: convAsync.when(
          data: (c) => Text(
            c.title.isEmpty ? l10n.newChat : c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('…'),
          error: (_, _) => Text(l10n.conversation),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.more,
            icon: const Icon(Icons.more_horiz, size: 22),
            onSelected: (v) {
              final msgs = chatAsync.valueOrNull?.messages ?? [];
              final title = convAsync.valueOrNull?.title ?? '';
              if (v == 'md') exportMarkdown(title, msgs, l10n);
              if (v == 'img') shareAsImage(context, title, msgs, l10n);
              if (v == 'usage') _showUsage(l10n);
              if (v == 'params') {
                final c = convAsync.valueOrNull;
                if (c != null) _showParams(c);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'params',
                child: Text(l10n.conversationParams),
              ),
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
                // 点按消息以外的空白处收起操作图标（消息自身的点按优先赢得手势竞争）
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _activeMessageId == null
                      ? null
                      : () => setState(() => _activeMessageId = null),
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      if (chat.loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      for (var i = 0; i < messages.length; i++)
                        _bubbleFor(messages, i, chat, appDir),
                      if (chat.streaming) _streamingBubble(chat),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_pendingImages.isNotEmpty) _imageChips(),
          _inputBar(chat?.streaming ?? false, vision, convAsync.valueOrNull),
        ],
      ),
    );
  }

  /// 输入卡片工具行里的模型选择器（LobeHub：模型名 + 下拉箭头）。
  Widget _modelSelector(ConversationDto? c) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    return InkWell(
      onTap: c == null ? null : () => _pickModel(c),
      borderRadius: BorderRadius.circular(LobeTokens.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                c?.modelId ?? l10n.selectModel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: t.textTertiary),
          ],
        ),
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
      showActions: _activeMessageId == m.id,
      onTap: () => setState(
        () => _activeMessageId = _activeMessageId == m.id ? null : m.id,
      ),
    );
  }

  Widget _streamingBubble(ChatState chat) {
    final t = context.lobe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessageBubble.assistantHeader(context),
          if (chat.reasoningText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.border, width: 2)),
              ),
              child: Text(
                chat.reasoningText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: t.textTertiary,
                ),
              ),
            ),
          if (chat.streamingText.isNotEmpty)
            BlockedMarkdown(text: chat.streamingText),
          const SizedBox(height: 6),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
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
                borderRadius: BorderRadius.circular(LobeTokens.rSm),
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

  /// 输入卡片（对齐 LobeHub 移动端）：圆角 12 卡片，上为输入区（16px），
  /// 下为工具行：图片「+」、模型选择器、发送/停止按钮。
  Widget _inputBar(bool streaming, bool vision, ConversationDto? conv) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        decoration: BoxDecoration(
          color: t.bgElevated,
          borderRadius: BorderRadius.circular(LobeTokens.rLg),
          border: Border.all(color: dark ? t.fillSecondary : t.fill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.4 : 0.04),
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _input,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontSize: 16, height: 1.4, color: t.text),
              decoration: InputDecoration(
                hintText: l10n.inputHint,
                hintStyle: TextStyle(fontSize: 16, color: t.textQuaternary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 8, 8),
              child: Row(
                children: [
                  LobeActionIcon(
                    icon: Icons.add,
                    tooltip: vision ? l10n.gallery : l10n.modelNoVision,
                    size: LobeActionIconSize.small,
                    onTap: (streaming || !vision) ? null : _pickImage,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _modelSelector(conv),
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _input,
                    builder: (_, value, _) => _sendButton(
                      streaming: streaming,
                      canSend:
                          value.text.trim().isNotEmpty ||
                          _pendingImages.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 发送 / 停止按钮：32×32 圆角 8；可发送或流式中为主色实底，否则灰底禁用态。
  Widget _sendButton({required bool streaming, required bool canSend}) {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    final active = streaming || canSend;
    return Semantics(
      button: true,
      label: streaming ? l10n.cancel : l10n.send,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? t.primary : t.fillTertiary,
          borderRadius: BorderRadius.circular(LobeTokens.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: streaming
                ? () => ref.read(chatProvider(_id).notifier).cancel()
                : (canSend ? _send : null),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                streaming ? Icons.stop_rounded : Icons.send_rounded,
                size: 16,
                color: active ? t.onPrimary : t.textQuaternary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
