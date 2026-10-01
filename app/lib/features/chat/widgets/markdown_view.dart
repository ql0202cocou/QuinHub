import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';

/// Blocked 增量 Markdown（decisions.md 决策三）：
/// 文本按 block 切分（代码块感知），相同内容的 block 复用同一 widget 实例，
/// 流式到达时只有最后一个未完成 block 重解析，避免整段重渲染闪烁。
///
/// 代码块不走 flutter_markdown 的 pre builder（会触发 _inlines.isEmpty 断言，
/// M4 实测），整块由我们自己渲染（高亮 + 复制）。
class BlockedMarkdown extends StatefulWidget {
  const BlockedMarkdown({super.key, required this.text});

  final String text;

  @override
  State<BlockedMarkdown> createState() => _BlockedMarkdownState();
}

class _BlockedMarkdownState extends State<BlockedMarkdown> {
  final _cache = <String, Widget>{};

  @override
  void didChangeDependencies() {
    // 缓存的 widget 捕获了主题色（代码块/引用/链接），主题切换时清空重建
    _cache.clear();
    super.didChangeDependencies();
  }

  List<String> _split(String text) {
    final blocks = <String>[];
    final buf = StringBuffer();
    var inFence = false;
    for (final line in text.split('\n')) {
      if (line.trimLeft().startsWith('```')) inFence = !inFence;
      buf.write(line);
      buf.write('\n');
      if (!inFence && line.trim().isEmpty) {
        blocks.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) blocks.add(buf.toString());
    return blocks;
  }

  bool _isFenceBlock(String block) => block.trimLeft().startsWith('```');

  Widget _render(String block) {
    return _cache.putIfAbsent(block, () {
      final t = context.lobe;
      if (_isFenceBlock(block)) {
        final lines = block.trimLeft().split('\n');
        final language = lines.first.substring(3).trim();
        final code = lines
            .skip(1)
            .takeWhile((l) => !l.trimRight().startsWith('```'))
            .join('\n');
        return _CodeBlock(code: code, language: language);
      }
      return MarkdownBody(
        data: block,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          a: TextStyle(color: t.brand),
          code: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: t.fill,
            fontSize: 13,
          ),
          blockquotePadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          blockquoteDecoration: BoxDecoration(
            color: t.fillSecondary,
            border: Border(left: BorderSide(color: t.brand, width: 3)),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _split(widget.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final b in blocks) _render(b)],
    );
  }
}

/// 代码块：语法高亮 + 语言标签 + 复制按钮。
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = context.lobe;
    // 测试环境可能无 l10n delegates，tooltip 允许回落；snackbar 文案在回调里再取。
    final copyTip =
        Localizations.of<AppLocalizations>(context, AppLocalizations)?.copy ??
        'Copy';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(LobeTokens.rMd),
        border: Border.all(color: t.fill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  language.isEmpty ? 'text' : language,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const Spacer(),
              LobeActionIcon(
                icon: Icons.copy_outlined,
                tooltip: copyTip,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).copiedCode),
                    ),
                  );
                },
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: HighlightView(
              code.trimRight(),
              language: language.isEmpty ? null : language,
              theme: dark ? atomOneDarkTheme : githubTheme,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
