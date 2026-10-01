import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/profile.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_avatar.dart';
import 'package:quinhub/ui/lobe_empty.dart';
import 'package:quinhub/ui/lobe_group.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';

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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProviderTitle(p.name)),
        content: Text(l10n.deleteProviderContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(profilesProvider.notifier).remove(p.id);
    }
  }

  Widget _tile(BuildContext context, WidgetRef ref, ProfileDto p) {
    final l10n = AppLocalizations.of(context);
    return LobeListTile(
      leading: LobeAvatar.seeded(
        seed: p.id,
        text: p.name.characters.first.toUpperCase(),
        size: 34,
      ),
      title: p.name,
      subtitle: '${providerTypeLabel(p.providerType)} · ${p.baseUrl}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.isDefault)
            Icon(Icons.star_rounded, size: 16, color: context.lobe.warning),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                context.push('/settings/providers/${p.id}');
              } else if (v == 'delete') {
                _confirmDelete(context, ref, p);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
        ],
      ),
      onTap: () => context.push('/settings/providers/${p.id}'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providers)),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
        data: (list) => list.isEmpty
            ? LobeEmpty(icon: Icons.key_outlined, message: l10n.noProviders)
            : ListView(
                padding: const EdgeInsets.all(LobeTokens.s3),
                children: [
                  LobeGroup(
                    dividerIndent: 62,
                    children: [for (final p in list) _tile(context, ref, p)],
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/providers/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
