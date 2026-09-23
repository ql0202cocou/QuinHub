import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 设置首页（M2：提供商入口 + 占位项）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('模型提供商'),
            subtitle: const Text('OpenAI 兼容 / Anthropic 的 Key 与模型'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/providers'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('外观'),
            subtitle: Text('跟随系统'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.language_outlined),
            title: Text('语言'),
            subtitle: Text('中文'),
            enabled: false,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于 QuinHub'),
            subtitle: Text('v1.0.0 · M2'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
