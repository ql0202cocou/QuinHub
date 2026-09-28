import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/state/conversations.dart';

/// 已归档会话列表（设置 → 已归档会话）。
class ArchivedPage extends ConsumerWidget {
  const ArchivedPage({super.key});

  void _menu(BuildContext context, WidgetRef ref, ConversationDto c) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: Text(l10n.unarchive),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(archivedConversationsProvider.notifier)
                    .unarchive(c.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
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
                  await ref
                      .read(archivedConversationsProvider.notifier)
                      .remove(c.id);
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
    final convs = ref.watch(archivedConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archivedConversations)),
      body: convs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.noArchivedConversations));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: const Icon(Icons.archive_outlined, size: 18),
                title: Text(
                  c.title.isEmpty ? l10n.unnamedConversation : c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(c.modelId ?? ''),
                onTap: () => context.push('/chat/${c.id}'),
                onLongPress: () => _menu(context, ref, c),
              );
            },
          );
        },
      ),
    );
  }
}
