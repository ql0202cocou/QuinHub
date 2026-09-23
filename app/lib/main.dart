import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quinhub/bridge/frb_generated.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/router.dart';
import 'package:quinhub/state/core.dart';
import 'package:quinhub/state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final dir = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [appDirProvider.overrideWithValue(dir.path)],
      child: const QuinHubApp(),
    ),
  );
}

class QuinHubApp extends ConsumerWidget {
  const QuinHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final locale = ref.watch(localeProvider).valueOrNull;
    return MaterialApp.router(
      title: 'QuinHub',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
