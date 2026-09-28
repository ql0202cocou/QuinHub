import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/state/core.dart';

/// 会话列表（pinned 在前、按 updated_at 倒序，由 Rust 侧排序）。
class ConversationsNotifier extends AsyncNotifier<List<ConversationDto>> {
  @override
  Future<List<ConversationDto>> build() async {
    await ref.watch(coreInitProvider.future); // 等 Rust 核心初始化
    return conversationList();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(conversationList);
  }

  Future<ConversationDto> createNew({
    String? profileId,
    String? modelId,
  }) async {
    final c = await conversationCreate(profileId: profileId, modelId: modelId);
    await reload();
    return c;
  }

  Future<void> rename(String id, String title) async {
    await conversationUpdateMeta(id: id, title: title);
    await reload();
  }

  Future<void> togglePin(String id, bool pinned) async {
    await conversationUpdateMeta(id: id, pinned: !pinned);
    await reload();
  }

  Future<void> toggleArchive(String id, bool archived) async {
    await conversationUpdateMeta(id: id, archived: !archived);
    await reload();
    ref.invalidate(archivedConversationsProvider);
  }

  Future<void> remove(String id) async {
    await conversationDelete(id: id);
    await reload();
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ConversationDto>>(
      ConversationsNotifier.new,
    );

/// 单个会话详情（标题/模型，聊天页顶栏用）。
final conversationProvider = FutureProvider.family<ConversationDto, String>((
  ref,
  id,
) async {
  await ref.watch(coreInitProvider.future); // 等 Rust 核心初始化
  return conversationGet(id: id);
});

/// 已归档会话列表（设置 → 已归档会话页用）。
class ArchivedConversationsNotifier
    extends AsyncNotifier<List<ConversationDto>> {
  @override
  Future<List<ConversationDto>> build() async {
    await ref.watch(coreInitProvider.future);
    return conversationArchivedList();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(conversationArchivedList);
  }

  Future<void> unarchive(String id) async {
    await conversationUpdateMeta(id: id, archived: false);
    await reload();
    ref.invalidate(conversationsProvider);
  }

  Future<void> remove(String id) async {
    await conversationDelete(id: id);
    await reload();
  }
}

final archivedConversationsProvider =
    AsyncNotifierProvider<ArchivedConversationsNotifier, List<ConversationDto>>(
      ArchivedConversationsNotifier.new,
    );
