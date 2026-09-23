import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/api/chat.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/state/core.dart';
import 'package:uuid/uuid.dart';

class ChatState {
  final List<MessageDto> messages;
  final String streamingText;
  final String reasoningText;
  final bool streaming;

  const ChatState({
    this.messages = const [],
    this.streamingText = '',
    this.reasoningText = '',
    this.streaming = false,
  });
}

/// 单个会话的聊天状态（family 按 conversationId 拆分）。
/// 终态（done/error/cancelled）由 Rust 侧落库，流结束后统一 reload。
class ChatNotifier extends FamilyAsyncNotifier<ChatState, String> {
  String? _chatId;

  @override
  Future<ChatState> build(String arg) async {
    await ref.watch(coreInitProvider.future); // 等 Rust 核心初始化
    final msgs = await messageList(conversationId: arg);
    return ChatState(messages: msgs);
  }

  Future<void> send(String text, {List<ImageInput> images = const []}) =>
      _drive(
        () => chatSend(
          chatId: _newChatId(),
          conversationId: arg,
          userText: text,
          userImages: images,
        ),
      );

  Future<void> regenerate() =>
      _drive(() => chatRegenerate(chatId: _newChatId(), conversationId: arg));

  Future<void> editResend(String messageId, String newText) => _drive(
    () => chatEditResend(
      chatId: _newChatId(),
      conversationId: arg,
      messageId: messageId,
      newText: newText,
    ),
  );

  void cancel() {
    final id = _chatId;
    if (id != null) chatCancel(chatId: id);
  }

  String _newChatId() => _chatId = const Uuid().v4();

  Future<void> _drive(Stream<ChatEventDto> Function() start) async {
    final cur = state.valueOrNull ?? const ChatState();
    var text = '';
    var reasoning = '';
    state = AsyncData(ChatState(messages: cur.messages, streaming: true));
    // 乐观显示刚落库的 user 消息（Rust 侧 insert 先于流式），拉一次保留流式状态
    unawaited(
      messageList(conversationId: arg).then((msgs) {
        final s = state.valueOrNull;
        if (s != null && s.streaming) {
          state = AsyncData(
            ChatState(
              messages: msgs,
              streamingText: s.streamingText,
              reasoningText: s.reasoningText,
              streaming: true,
            ),
          );
        }
      }),
    );
    try {
      await for (final ev in start()) {
        if (ev is ChatEventDto_Delta) {
          text += ev.text;
        } else if (ev is ChatEventDto_ReasoningDelta) {
          reasoning += ev.text;
        } else if (ev is ChatEventDto_Error) {
          // 终态已由 Rust 落库（status=error），finally 里统一 reload
        } else if (ev is ChatEventDto_Usage) {
          // usage 已落库到消息上，流式中不重复展示
        }
        if (ev is ChatEventDto_Delta || ev is ChatEventDto_ReasoningDelta) {
          state = AsyncData(
            ChatState(
              messages: cur.messages,
              streamingText: text,
              reasoningText: reasoning,
              streaming: true,
            ),
          );
        }
      }
    } finally {
      final msgs = await messageList(conversationId: arg);
      state = AsyncData(ChatState(messages: msgs));
    }
  }
}

final chatProvider =
    AsyncNotifierProvider.family<ChatNotifier, ChatState, String>(
      ChatNotifier.new,
    );
