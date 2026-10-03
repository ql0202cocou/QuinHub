import 'dart:async';
import 'dart:math' as math;

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

  /// 是否还有更早的历史可加载（分页，data-model.md §5）。
  final bool hasMore;

  /// 是否正在加载更早的一页。
  final bool loadingMore;

  const ChatState({
    this.messages = const [],
    this.streamingText = '',
    this.reasoningText = '',
    this.streaming = false,
    this.hasMore = false,
    this.loadingMore = false,
  });
}

/// 单个会话的聊天状态（family 按 conversationId 拆分）。
/// 消息分页加载：初始取最新一页，滚动到顶部时向前翻页；
/// 终态（done/error/cancelled）由 Rust 侧落库，流结束后统一 reload。
class ChatNotifier extends FamilyAsyncNotifier<ChatState, String> {
  static const _pageSize = 50;

  String? _chatId;

  @override
  Future<ChatState> build(String arg) async {
    await ref.watch(coreInitProvider.future); // 等 Rust 核心初始化
    final msgs = await _page(limit: _pageSize);
    return ChatState(messages: msgs, hasMore: msgs.length == _pageSize);
  }

  /// 拉一页消息；before 为 null 取最新一页。limit 超出总数时返回全部。
  Future<List<MessageDto>> _page({
    int? beforeCreatedAt,
    int? beforeRowid,
    required int limit,
  }) {
    return messageListPage(
      conversationId: arg,
      beforeCreatedAt: beforeCreatedAt,
      beforeRowid: beforeRowid,
      limit: limit,
    );
  }

  /// 重新拉取最新消息（保留已加载的更早历史）；流式中保留流式字段。
  Future<void> _reload() async {
    final cur = state.valueOrNull ?? const ChatState();
    final limit = math.max(_pageSize, cur.messages.length);
    final msgs = await _page(limit: limit);
    // msgs.length == limit 时可能恰好看完（假阳性），下次 loadMore 返回空即可纠正
    state = AsyncData(
      ChatState(
        messages: msgs,
        streamingText: cur.streaming ? cur.streamingText : '',
        reasoningText: cur.streaming ? cur.reasoningText : '',
        streaming: cur.streaming,
        hasMore: msgs.length == limit,
      ),
    );
  }

  /// 向前翻一页（更早的历史），拼接到列表头部。流式中不翻页。
  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || !s.hasMore || s.loadingMore || s.streaming) return;
    if (s.messages.isEmpty) return;
    state = AsyncData(
      ChatState(
        messages: s.messages,
        streamingText: s.streamingText,
        reasoningText: s.reasoningText,
        hasMore: s.hasMore,
        loadingMore: true,
      ),
    );
    final first = s.messages.first;
    final older = await _page(
      beforeCreatedAt: first.createdAt.toInt(),
      beforeRowid: first.rowid.toInt(),
      limit: _pageSize,
    );
    final cur = state.valueOrNull;
    if (cur == null) return;
    if (cur.streaming) return; // 翻页期间开始了流式，由 _reload 统一处理
    state = AsyncData(
      ChatState(
        messages: [...older, ...cur.messages],
        hasMore: older.length == _pageSize,
      ),
    );
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
    state = AsyncData(
      ChatState(messages: cur.messages, hasMore: cur.hasMore, streaming: true),
    );
    // 乐观显示刚落库的 user 消息（Rust 侧 insert 先于流式），拉一次保留流式状态
    unawaited(_reload());
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
          final s = state.valueOrNull ?? const ChatState();
          state = AsyncData(
            ChatState(
              messages: s.messages,
              streamingText: text,
              reasoningText: reasoning,
              streaming: true,
              hasMore: s.hasMore,
            ),
          );
        }
      }
    } finally {
      // 流式标记在 reload 前清空，终态从库里读
      final s = state.valueOrNull;
      if (s != null) {
        state = AsyncData(ChatState(messages: s.messages, hasMore: s.hasMore));
      }
      await _reload();
    }
  }
}

final chatProvider =
    AsyncNotifierProvider.family<ChatNotifier, ChatState, String>(
      ChatNotifier.new,
    );
