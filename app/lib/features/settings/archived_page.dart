import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/ui/lobe_avatar.dart';
import 'package:quinhub/ui/lobe_button.dart';
import 'package:quinhub/ui/lobe_empty.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_sheet.dart';

/// 已归档会话列表（设置 → 已归档会话）。
class ArchivedPage extends ConsumerWidget {
  const ArchivedPage({super.key});

  void _menu(BuildContext context, WidgetRef ref, ConversationDto c) {
    final l10n = AppLocalizations.of(context);
    showLobeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LobeListTile(
            icon: Icons.unarchive_outlined,
            title: l10n.unarchive,
            onTap: () {
              Navigator.pop(ctx);
              ref.read(archivedConversationsProvider.notifier).unarchive(c.id);
            },
          ),
          LobeListTile(
            icon: Icons.delete_outline,
            title: l10n.delete,
            danger: true,
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
                    LobeButton(
                      label: l10n.cancel,
                      variant: LobeButtonVariant.text,
                      onPressed: () => Navigator.pop(dctx, false),
                    ),
                    LobeButton(
                      label: l10n.delete,
                      variant: LobeButtonVariant.danger,
                      onPressed: () => Navigator.pop(dctx, true),
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
            return LobeEmpty(
              emoji: '🗃️',
              message: l10n.noArchivedConversations,
            );
          }
          return ListView(
            children: [
              for (final c in list)
                LobeListItem(
                  avatar: LobeAvatar.seeded(seed: c.id),
                  title: c.title.isEmpty ? l10n.unnamedConversation : c.title,
                  description: c.modelId,
                  onTap: () => context.push('/chat/${c.id}'),
                  onLongPress: () => _menu(context, ref, c),
                ),
            ],
          );
        },
      ),
    );
  }
}
