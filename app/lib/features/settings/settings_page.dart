import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/state/profiles.dart';
import 'package:quinhub/state/settings.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_group.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';
import 'package:quinhub/ui/lobe_sheet.dart';

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
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          LobeGroup(
            band: false,
            children: [
              LobeListTile(
                icon: Icons.key_outlined,
                title: l10n.providers,
                subtitle: l10n.providersSubtitle,
                arrow: true,
                onTap: () => context.push('/settings/providers'),
              ),
              LobeListTile(
                icon: Icons.archive_outlined,
                title: l10n.archivedConversations,
                arrow: true,
                onTap: () => context.push('/settings/archived'),
              ),
            ],
          ),
          LobeGroup(
            children: [
              LobeListTile(
                icon: Icons.palette_outlined,
                title: l10n.appearance,
                subtitle: switch (themeMode) {
                  ThemeMode.light => l10n.light,
                  ThemeMode.dark => l10n.dark,
                  ThemeMode.system => l10n.followSystem,
                },
                arrow: true,
                onTap: () => _pickTheme(context, ref, themeMode),
              ),
              LobeListTile(
                icon: Icons.language_outlined,
                title: l10n.language,
                subtitle: switch (locale?.languageCode) {
                  'zh' => '中文',
                  'en' => 'English',
                  _ => l10n.followSystem,
                },
                arrow: true,
                onTap: () => _pickLanguage(context, ref, locale),
              ),
              LobeListTile(
                icon: Icons.smart_toy_outlined,
                title: l10n.defaultModel,
                subtitle: defaultModel?.modelId ?? l10n.defaultModelUnset,
                arrow: true,
                onTap: () => _pickDefaultModel(context, ref, defaultModel),
              ),
            ],
          ),
          LobeGroup(
            children: [
              LobeListTile(
                icon: Icons.info_outline,
                title: l10n.about,
                subtitle: 'v1.0.0 · M5',
                enabled: false,
              ),
            ],
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
    final t = context.lobe;
    final mode = await showLobeSheet<ThemeMode>(
      context,
      title: l10n.appearance,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (m, label) in [
            (ThemeMode.system, l10n.followSystem),
            (ThemeMode.light, l10n.light),
            (ThemeMode.dark, l10n.dark),
          ])
            LobeListTile(
              title: label,
              trailing: m == cur
                  ? Icon(Icons.check, size: 18, color: t.primary)
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
    final t = context.lobe;
    final profiles = ref.read(profilesProvider).valueOrNull ?? [];
    await showLobeSheet<void>(
      context,
      title: l10n.defaultModel,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          LobeListTile(
            title: l10n.defaultModelUnset,
            trailing: cur == null
                ? Icon(Icons.check, size: 18, color: t.primary)
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
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              for (final m in p.enabledModels)
                LobeListTile(
                  title: m,
                  trailing: (cur?.profileId == p.id && cur?.modelId == m)
                      ? Icon(Icons.check, size: 18, color: t.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(defaultModelProvider.notifier).set(p.id, m);
                  },
                ),
            ],
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? cur,
  ) async {
    final l10n = AppLocalizations.of(context);
    final t = context.lobe;
    final lang = await showLobeSheet<String>(
      context,
      title: l10n.language,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in [
            ('system', l10n.followSystem),
            ('zh', '中文'),
            ('en', 'English'),
          ])
            LobeListTile(
              title: label,
              trailing: v == (cur?.languageCode ?? 'system')
                  ? Icon(Icons.check, size: 18, color: t.primary)
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
