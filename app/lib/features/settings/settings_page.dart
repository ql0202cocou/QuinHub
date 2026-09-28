import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/state/settings.dart';
import 'package:quinhub/l10n/app_localizations.dart';

/// 设置首页。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final locale = ref.watch(localeProvider).valueOrNull;
    final defaultModel = ref.watch(defaultModelProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.providers),
            subtitle: Text(l10n.providersSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/providers'),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l10n.archivedConversations),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/archived'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.appearance),
            subtitle: Text(switch (themeMode) {
              ThemeMode.light => l10n.light,
              ThemeMode.dark => l10n.dark,
              ThemeMode.system => l10n.followSystem,
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref, themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.language),
            subtitle: Text(switch (locale?.languageCode) {
              'zh' => '中文',
              'en' => 'English',
              _ => l10n.followSystem,
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref, locale),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(l10n.defaultModel),
            subtitle: Text(defaultModel?.modelId ?? l10n.defaultModelUnset),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickDefaultModel(context, ref, defaultModel),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            subtitle: Text('v1.0.0 · M5'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode cur,
  ) async {
    final l10n = AppLocalizations.of(context);
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.appearance),
        children: [
          for (final (m, label) in [
            (ThemeMode.system, l10n.followSystem),
            (ThemeMode.light, l10n.light),
            (ThemeMode.dark, l10n.dark),
          ])
            ListTile(
              title: Text(label),
              trailing: m == cur
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
        ],
      ),
    );
    if (mode != null) {
      await ref.read(themeModeProvider.notifier).setMode(mode);
    }
  }

  Future<void> _pickDefaultModel(
    BuildContext context,
    WidgetRef ref,
    ({String profileId, String modelId})? cur,
  ) async {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.defaultModelUnset),
              trailing: cur == null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(defaultModelProvider.notifier).clear();
              },
            ),
            for (final p in profiles)
              if (p.enabledModels.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final m in p.enabledModels)
                  ListTile(
                    dense: true,
                    title: Text(m),
                    trailing: (cur?.profileId == p.id && cur?.modelId == m)
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(defaultModelProvider.notifier)
                          .set(p.id, m);
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? cur,
  ) async {
    final l10n = AppLocalizations.of(context);
    final lang = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final (v, label) in [
            ('system', l10n.followSystem),
            ('zh', '中文'),
            ('en', 'English'),
          ])
            ListTile(
              title: Text(label),
              trailing: v == (cur?.languageCode ?? 'system')
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (lang != null) {
      await ref
          .read(localeProvider.notifier)
          .setLocale(lang == 'system' ? null : lang);
    }
  }
}
