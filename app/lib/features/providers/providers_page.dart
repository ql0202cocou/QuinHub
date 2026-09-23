import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/profile.dart';
import 'package:quinhub/state/profiles.dart';

String providerTypeLabel(String type) => switch (type) {
  'openai_compatible' => 'OpenAI 兼容',
  'anthropic' => 'Anthropic',
  _ => type,
};

/// 提供商列表页。
class ProvidersPage extends ConsumerWidget {
  const ProvidersPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProfileDto p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${p.name}」？'),
        content: const Text('关联会话将保留，但无法继续对话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(profilesProvider.notifier).remove(p.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('模型提供商')),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('还没有提供商，点右下角添加'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(p.name.characters.first.toUpperCase()),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(p.name)),
                        if (p.isDefault) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${providerTypeLabel(p.providerType)} · ${p.baseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.push('/settings/providers/${p.id}');
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, p);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                    onTap: () => context.push('/settings/providers/${p.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/providers/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
