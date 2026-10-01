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
import 'package:quinhub/ui/lobe_button.dart';
import 'package:quinhub/ui/lobe_empty.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_search_bar.dart';
import 'package:quinhub/ui/lobe_sheet.dart';

/// 会话列表首页：搜索 + 置顶/最近分区（LobeUI 风格）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _search = TextEditingController();
  String _query = '';

  /// 折叠的分区（LobeHub 首页分组可点击标题收起）。
  final _collapsed = <String>{};

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
        content: TextField(controller: controller, autofocus: true),
        actions: [
          LobeButton(
            label: l10n.cancel,
            variant: LobeButtonVariant.text,
            onPressed: () => Navigator.pop(ctx),
          ),
          LobeButton(
            label: l10n.save,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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
                await ref.read(conversationsProvider.notifier).remove(c.id);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 分区标题（LobeHub 首页分组头）：高 38、14px、右侧折叠箭头。
  Widget _sectionHeader(String key, String text, int count) {
    final t = context.lobe;
    final collapsed = _collapsed.contains(key);
    return InkWell(
      onTap: () => setState(
        () => collapsed ? _collapsed.remove(key) : _collapsed.add(key),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(LobeTokens.s4, 8, 10, 8),
        child: Row(
          children: [
            Text(text, style: TextStyle(fontSize: 14, color: t.text)),
            const SizedBox(width: LobeTokens.s1),
            Text(
              '$count',
              style: TextStyle(fontSize: 12, color: t.textQuaternary),
            ),
            const Spacer(),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(String key, String title, List<ConversationDto> items) {
    if (items.isEmpty) return const [];
    return [
      _sectionHeader(key, title, items.length),
      if (!_collapsed.contains(key))
        for (final c in items) _tile(context, ref, c),
    ];
  }

  Widget _tile(BuildContext context, WidgetRef ref, ConversationDto c) {
    final l10n = AppLocalizations.of(context);
    return LobeListItem(
      avatar: LobeAvatar.seeded(seed: c.id),
      title: c.title.isEmpty ? l10n.unnamedConversation : c.title,
      description: c.modelId,
      date: _fmtTime(c.updatedAt.toInt()),
      onTap: () => context.push('/chat/${c.id}'),
      onLongPress: () => _menu(context, ref, c),
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
        centerTitle: false,
        titleSpacing: LobeTokens.s4,
        title: const Text(
          'QuinHub',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: context.lobe.textSecondary,
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: LobeTokens.s1),
        ],
      ),
      body: core.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LobeEmpty(
          emoji: '⚠️',
          message: l10n.initFailed('$e'),
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(coreInitProvider),
        ),
        data: (_) {
          if (profiles.valueOrNull?.isEmpty ?? true) {
            return LobeEmpty(
              emoji: '🔑',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: LobeTokens.s4,
                  vertical: LobeTokens.s2,
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
                        emoji: q.isEmpty ? '💬' : '🔍',
                        message: q.isEmpty
                            ? l10n.noConversations
                            : l10n.noSearchResult,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          ..._section('pinned', l10n.pinnedSection, pinned),
                          ..._section('recent', l10n.recentSection, recent),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: context.lobe.shadowSecondary,
        ),
        child: FloatingActionButton(
          onPressed: () => _newConversation(context, ref),
          child: const Icon(Icons.add_comment_outlined, size: 22),
        ),
      ),
    );
  }
}
