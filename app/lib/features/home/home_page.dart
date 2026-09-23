import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/state/core.dart';
import 'package:quinhub/state/profiles.dart';

/// 会话列表首页。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _fmtTime(int millis) {
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Future<void> _newConversation(BuildContext context, WidgetRef ref) async {
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先去设置里添加一个模型提供商')));
      context.push('/settings/providers');
      return;
    }
    final profile =
        profiles.where((p) => p.isDefault).firstOrNull ?? profiles.first;
    if (profile.enabledModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${profile.name}」还没启用模型，点编辑测试并勾选')),
      );
      return;
    }
    final conv = await ref
        .read(conversationsProvider.notifier)
        .createNew(profileId: profile.id, modelId: profile.enabledModels.first);
    if (context.mounted) context.push('/chat/${conv.id}');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ConversationDto c,
  ) async {
    final controller = TextEditingController(text: c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(conversationsProvider.notifier).rename(c.id, title);
    }
  }

  void _menu(BuildContext context, WidgetRef ref, ConversationDto c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(c.pinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(conversationsProvider.notifier)
                    .togglePin(c.id, c.pinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text('删除「${c.title.isEmpty ? '未命名会话' : c.title}」？'),
                    content: const Text('会话内消息将一并删除。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(conversationsProvider.notifier).remove(c.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreInitProvider);
    final convs = ref.watch(conversationsProvider);
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuinHub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: core.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('初始化失败：$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(coreInitProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (_) {
          if (profiles.valueOrNull?.isEmpty ?? true) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.key_outlined, size: 56),
                  const SizedBox(height: 12),
                  const Text('先添加一个模型提供商（API Key）开始对话'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/settings/providers'),
                    icon: const Icon(Icons.add),
                    label: const Text('配置提供商'),
                  ),
                ],
              ),
            );
          }
          final list = convs.valueOrNull ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('还没有会话，点右下角开始'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: c.pinned
                    ? const Icon(Icons.push_pin, size: 18)
                    : const Icon(Icons.chat_bubble_outline, size: 18),
                title: Text(
                  c.title.isEmpty ? '未命名会话' : c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(c.modelId ?? '未选模型'),
                trailing: Text(
                  _fmtTime(c.updatedAt.toInt()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => context.push('/chat/${c.id}'),
                onLongPress: () => _menu(context, ref, c),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newConversation(context, ref),
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
