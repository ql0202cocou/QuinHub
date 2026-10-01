import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/conversation.dart';
import 'package:quinhub/state/conversations.dart';
import 'package:quinhub/state/core.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/state/settings.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_avatar.dart';
import 'package:quinhub/ui/lobe_empty.dart';
import 'package:quinhub/ui/lobe_group.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_search_bar.dart';
import 'package:quinhub/ui/lobe_sheet.dart';
import 'package:quinhub/ui/lobe_tag.dart';

/// 会话列表首页：搜索 + 置顶/最近分区（LobeUI 风格）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    showLobeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LobeListTile(
            icon: c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            title: c.pinned ? l10n.unpin : l10n.pin,
            onTap: () {
              Navigator.pop(ctx);
              ref
                  .read(conversationsProvider.notifier)
                  .togglePin(c.id, c.pinned);
            },
          ),
          LobeListTile(
            icon: Icons.drive_file_rename_outline,
            title: l10n.rename,
            onTap: () {
              Navigator.pop(ctx);
              _rename(context, ref, c);
            },
          ),
          LobeListTile(
            icon: Icons.archive_outlined,
            title: l10n.archive,
            onTap: () {
              Navigator.pop(ctx);
              ref
                  .read(conversationsProvider.notifier)
                  .toggleArchive(c.id, c.archived);
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
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LobeTokens.s5,
        LobeTokens.s3,
        LobeTokens.s5,
        LobeTokens.s1,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ConversationDto c) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = context.lobe;
    return InkWell(
      onTap: () => context.push('/chat/${c.id}'),
      onLongPress: () => _menu(context, ref, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LobeTokens.s4,
          vertical: 10,
        ),
        child: Row(
          children: [
            LobeAvatar.seeded(
              seed: c.id,
              icon: Icons.chat_bubble_outline_rounded,
              size: 40,
            ),
            const SizedBox(width: LobeTokens.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title.isEmpty ? l10n.unnamedConversation : c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (c.modelId != null) ...[
                    const SizedBox(height: 4),
                    LobeTag(text: c.modelId!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LobeTokens.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtTime(c.updatedAt.toInt()),
                  style: theme.textTheme.labelSmall,
                ),
                if (c.pinned)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.push_pin,
                      size: 14,
                      color: t.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        error: (e, _) => LobeEmpty(
          icon: Icons.error_outline,
          message: l10n.initFailed('$e'),
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(coreInitProvider),
        ),
        data: (_) {
          if (profiles.valueOrNull?.isEmpty ?? true) {
            return LobeEmpty(
              icon: Icons.key_outlined,
              message: l10n.noProvidersGuide,
              actionLabel: l10n.configureProviders,
              onAction: () => context.push('/settings/providers'),
            );
          }
          final all = convs.valueOrNull ?? [];
          final q = _query.trim().toLowerCase();
          final list = q.isEmpty
              ? all
              : all.where((c) => c.title.toLowerCase().contains(q)).toList();
          final pinned = list.where((c) => c.pinned).toList();
          final recent = list.where((c) => !c.pinned).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LobeTokens.s4,
                  LobeTokens.s1,
                  LobeTokens.s4,
                  LobeTokens.s2,
                ),
                child: LobeSearchBar(
                  controller: _search,
                  hint: l10n.searchChats,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? LobeEmpty(
                        icon: Icons.chat_bubble_outline_rounded,
                        message: q.isEmpty
                            ? l10n.noConversations
                            : l10n.noSearchResult,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          if (pinned.isNotEmpty) ...[
                            _sectionLabel(l10n.pinnedSection),
                            LobeGroup(
                              margin: const EdgeInsets.symmetric(
                                horizontal: LobeTokens.s3,
                              ),
                              dividerIndent: 62,
                              children: [
                                for (final c in pinned) _tile(context, ref, c),
                              ],
                            ),
                          ],
                          if (recent.isNotEmpty) ...[
                            _sectionLabel(l10n.recentSection),
                            LobeGroup(
                              margin: const EdgeInsets.symmetric(
                                horizontal: LobeTokens.s3,
                              ),
                              dividerIndent: 62,
                              children: [
                                for (final c in recent) _tile(context, ref, c),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newConversation(context, ref),
        child: const Icon(Icons.edit_note_rounded),
      ),
    );
  }
}
