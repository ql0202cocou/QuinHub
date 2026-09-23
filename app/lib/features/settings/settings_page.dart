import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
