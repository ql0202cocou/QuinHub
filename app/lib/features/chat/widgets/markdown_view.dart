import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
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
      // LobeUI Markdown variant="chat"：14px / 行高 1.6，标题倍率 0.25，段距 0.5em
      final base = TextStyle(fontSize: 14, height: 1.6, color: t.text);
      TextStyle h(double scale) => base.copyWith(
        fontSize: 14 * scale,
        height: 1.25,
        fontWeight: FontWeight.w700,
      );
      return MarkdownBody(
        data: block,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: base,
          h1: h(1.375),
          h2: h(1.25),
          h3: h(1.125),
          h4: h(1.0625),
          h5: h(1),
          h6: h(1),
          blockSpacing: 7,
          a: TextStyle(color: t.info),
          listBullet: base.copyWith(color: t.textSecondary),
          listIndent: 20,
          code: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.25,
            color: t.text,
            backgroundColor: t.fillSecondary,
          ),
          blockquote: base.copyWith(color: t.textSecondary),
          blockquotePadding: const EdgeInsets.symmetric(horizontal: 14),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.border, width: 4)),
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.border)),
          ),
          tableBorder: TableBorder.all(color: t.borderSecondary),
          tableHead: base.copyWith(fontWeight: FontWeight.w600),
          tableBody: base,
          tableCellsPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 7,
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

/// 代码块（LobeUI Highlighter 在 Markdown 内的形态）：
/// fillQuaternary 底、圆角 8，头部「语言名 + 复制」，代码 12px、内边距 16。
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  /// LobeUI 高亮配色（lobe-theme）：字符串 success、关键字 info、函数 geekblue、
  /// 存储/布尔 purple、数字 volcano、类型 warning、注释 textQuaternary。
  static Map<String, TextStyle> _theme(LobeTokens t) {
    final keyword = TextStyle(color: t.codeKeyword);
    final string = TextStyle(color: t.success);
    final fn = TextStyle(color: t.codeFunction);
    final storage = TextStyle(color: t.codeStorage);
    final number = TextStyle(color: t.codeNumber);
    final type = TextStyle(color: t.warning);
    return {
      'root': TextStyle(color: t.text, backgroundColor: Colors.transparent),
      'keyword': keyword,
      'selector-tag': keyword,
      'operator': keyword,
      'punctuation': keyword,
      'string': string,
      'regexp': string,
      'addition': string,
      'title': fn,
      'function': fn,
      'section': fn,
      'built_in': storage,
      'literal': storage,
      'meta': storage,
      'number': number,
      'symbol': number,
      'tag': number,
      'deletion': number,
      'type': type,
      'class': type,
      'attr': type,
      'attribute': type,
      'comment': TextStyle(
        color: t.textQuaternary,
        fontStyle: FontStyle.italic,
      ),
      'quote': TextStyle(color: t.textQuaternary, fontStyle: FontStyle.italic),
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'strong': const TextStyle(fontWeight: FontWeight.w700),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    // 测试环境可能无 l10n delegates，tooltip 允许回落；snackbar 文案在回调里再取。
    final copyTip =
        Localizations.of<AppLocalizations>(context, AppLocalizations)?.copy ??
        'Copy';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: t.fillQuaternary,
        borderRadius: BorderRadius.circular(LobeTokens.r),
        border: Border.all(color: t.fillTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.fillTertiary)),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 14, color: t.textTertiary),
                const SizedBox(width: 6),
                Text(
                  language.isEmpty ? 'text' : language,
                  style: TextStyle(fontSize: 13, color: t.textTertiary),
                ),
                const Spacer(),
                LobeActionIcon(
                  icon: Icons.copy_outlined,
                  tooltip: copyTip,
                  size: LobeActionIconSize.small,
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
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: HighlightView(
              code.trimRight(),
              language: language.isEmpty ? null : language,
              theme: _theme(t),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
