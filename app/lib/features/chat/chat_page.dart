import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';
import 'package:quinhub/features/chat/widgets/message_bubble.dart';
import 'package:quinhub/state/chat.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/state/profiles.dart';

/// 聊天页：消息列表 + 流式渲染 + 输入栏 + 模型切换 + 长按消息菜单。
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
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(chatProvider(_id).notifier).send(text);
  }

  Future<void> _editResend(MessageDto m) async {
    final controller = TextEditingController(text: m.content);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑并重发'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await ref.read(chatProvider(_id).notifier).editResend(m.id, text);
    }
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
    final convAsync = ref.watch(conversationProvider(_id));
    final chatAsync = ref.watch(chatProvider(_id));
    final chat = chatAsync.valueOrNull;

    // 流式时自动跟随底部
    if (chat?.streaming ?? false) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: convAsync.when(
          data: (c) => Text(c.title.isEmpty ? '新会话' : c.title),
          loading: () => const Text('…'),
          error: (_, _) => const Text('会话'),
        ),
        actions: [
          convAsync.maybeWhen(
            data: (c) => TextButton(
              onPressed: () => _pickModel(c),
              child: Text(
                c.modelId ?? '选模型',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
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
                      _bubbleFor(messages, i, chat),
                    if (chat.streaming) _streamingBubble(chat),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          _inputBar(chat?.streaming ?? false),
        ],
      ),
    );
  }

  Widget _bubbleFor(List<MessageDto> messages, int i, ChatState chat) {
    final m = messages[i];
    final isLastAssistant =
        m.role == 'assistant' && i == messages.length - 1 && !chat.streaming;
    return MessageBubble(
      key: ValueKey(m.id),
      message: m,
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
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(bool streaming) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '输入消息…',
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
