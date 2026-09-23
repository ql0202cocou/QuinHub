import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/api/settings.dart';
import 'package:quinhub/state/core.dart';

/// 主题模式（浅/深/跟随系统），持久化在 settings 表。
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    await ref.watch(coreInitProvider.future);
    final v = await settingsGet(key: _key);
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await settingsSet(key: _key, value: mode.name);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// 语言（system / zh / en），持久化在 settings 表。
class LocaleNotifier extends AsyncNotifier<Locale?> {
  static const _key = 'language';

  @override
  Future<Locale?> build() async {
    await ref.watch(coreInitProvider.future);
    final v = await settingsGet(key: _key);
    return switch (v) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null, // null = 跟随系统
    };
  }

  Future<void> setLocale(String? language) async {
    final locale = switch (language) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
    state = AsyncData(locale);
    await settingsSet(key: _key, value: language ?? 'system');
  }
}

final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
