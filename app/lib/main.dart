import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/frb_generated.dart';
import 'package:quinhub/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const ProviderScope(child: QuinHubApp()));
}

class QuinHubApp extends ConsumerWidget {
  const QuinHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'QuinHub',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
