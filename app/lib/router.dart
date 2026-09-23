import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/features/home/home_page.dart';
import 'package:quinhub/features/providers/provider_edit_page.dart';
import 'package:quinhub/features/providers/providers_page.dart';
import 'package:quinhub/features/settings/settings_page.dart';

/// 路由表与 doc/agents/pages-and-routing.md 一致。
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/settings/providers',
        builder: (_, _) => const ProvidersPage(),
      ),
      GoRoute(
        path: '/settings/providers/:id',
        builder: (_, state) =>
            ProviderEditPage(profileId: state.pathParameters['id']!),
      ),
    ],
  ),
);
