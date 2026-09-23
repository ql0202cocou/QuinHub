import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/state/core.dart';

/// 会话列表（M2 占位页：核心初始化状态 + 引导配置 Provider）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreInitProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuinHub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: core.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('初始化失败：$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(coreInitProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (_) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 56),
              const SizedBox(height: 12),
              const Text('还没有会话', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              const Text('先添加一个模型提供商（API Key）开始对话'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/settings/providers'),
                icon: const Icon(Icons.key_outlined),
                label: const Text('配置提供商'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
