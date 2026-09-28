import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/profile.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/l10n/app_localizations.dart';

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
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: cs.primary.withValues(alpha: 0.10),
        child: Text(
          p.name.characters.first.toUpperCase(),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
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
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
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
            ? Center(child: Text(l10n.noProviders))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 68),
                          _tile(context, ref, list[i]),
                        ],
                      ],
                    ),
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
