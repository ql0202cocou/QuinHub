import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/state/core.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/state/settings.dart';
import 'package:quinhub/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addProviderFirst)));
      context.push('/settings/providers');
      return;
    }
    // 优先用全局默认模型（设置页可配），失效时回落到默认提供商的首个启用模型
    final dm = ref.read(defaultModelProvider).valueOrNull;
    final dmProfile = dm == null
        ? null
        : profiles.where((p) => p.id == dm.profileId).firstOrNull;
    final String profileId;
    final String modelId;
    if (dmProfile != null && dmProfile.enabledModels.contains(dm!.modelId)) {
      profileId = dmProfile.id;
      modelId = dm.modelId;
    } else {
      final profile =
          profiles.where((p) => p.isDefault).firstOrNull ?? profiles.first;
      if (profile.enabledModels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noEnabledModels(profile.name))),
        );
        return;
      }
      profileId = profile.id;
      modelId = profile.enabledModels.first;
    }
    final conv = await ref
        .read(conversationsProvider.notifier)
        .createNew(profileId: profileId, modelId: modelId);
    if (context.mounted) context.push('/chat/${conv.id}');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ConversationDto c,
  ) async {
    final controller = TextEditingController(text: c.title);
    final l10n = AppLocalizations.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameConversation),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(conversationsProvider.notifier).rename(c.id, title);
    }
  }

  void _menu(BuildContext context, WidgetRef ref, ConversationDto c) {
    final l10n = AppLocalizations.of(context);
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
              title: Text(c.pinned ? l10n.unpin : l10n.pin),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(conversationsProvider.notifier)
                    .togglePin(c.id, c.pinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.rename),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.archive),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(conversationsProvider.notifier)
                    .toggleArchive(c.id, c.archived);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.delete, style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(
                      l10n.deleteConversationTitle(
                        c.title.isEmpty ? l10n.unnamedConversation : c.title,
                      ),
                    ),
                    content: Text(l10n.deleteConversationContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
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
              Text(l10n.initFailed('$e'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(coreInitProvider),
                child: Text(l10n.retry),
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
                  Text(l10n.noProvidersGuide),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/settings/providers'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.configureProviders),
                  ),
                ],
              ),
            );
          }
          final list = convs.valueOrNull ?? [];
          if (list.isEmpty) {
            return Center(child: Text(l10n.noConversations));
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
                  c.title.isEmpty ? l10n.unnamedConversation : c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(c.modelId ?? l10n.unnamedConversation),
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
