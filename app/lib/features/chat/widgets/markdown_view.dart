import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';

/// Blocked 增量 Markdown（decisions.md 决策三）：
/// 文本按 block 切分（代码块 / $$ 数学块感知），相同内容的 block 复用同一 widget 实例，
/// 流式到达时只有最后一个未完成 block 重解析，避免整段重渲染闪烁。
///
/// 代码块不走 flutter_markdown 的 pre builder（会触发 _inlines.isEmpty 断言，
/// M4 实测），整块由我们自己渲染（高亮 + 复制）。
/// LaTeX：$$ 块级公式整块用 flutter_math_fork 渲染；$ 行内公式走自定义
/// inlineSyntax + builder（decisions.md 决策五）。
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
    var inMath = false;
    for (final line in text.split('\n')) {
      final t = line.trimLeft();
      if (t.startsWith('```')) {
        inFence = !inFence;
      } else if (!inFence && t.startsWith(r'$$')) {
        inMath = !inMath;
      }
      buf.write(line);
      buf.write('\n');
      if (!inFence && !inMath && line.trim().isEmpty) {
        blocks.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) blocks.add(buf.toString());
    return blocks;
  }

  bool _isFenceBlock(String block) => block.trimLeft().startsWith('```');

  bool _isMathBlock(String block) =>
      !_isFenceBlock(block) && block.trimLeft().startsWith(r'$$');

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
      if (_isMathBlock(block)) {
        final expr = block
            .trimLeft()
            .split('\n')
            .skip(1)
            .takeWhile((l) => !l.trimLeft().startsWith(r'$$'))
            .join('\n')
            .trim();
        return _MathBlock(expr: expr);
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
        inlineSyntaxes: [_InlineLatexSyntax()],
        builders: {'math': _InlineLatexBuilder()},
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
/// fillQuaternary 底、圆角 8，头部「折叠箭头 + 语言名 + 复制」，代码 12px、内边距 16。
/// 点头部折叠 / 展开代码区（默认展开）。折叠状态存在 State 里：BlockedMarkdown
/// 复用缓存的 widget 实例，流式追加时 block 位置不变，Element 与 State 得以保留。
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _collapsed = false;

  String get code => widget.code;
  String get language => widget.language;

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
          InkWell(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _collapsed ? Colors.transparent : t.fillTertiary,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: t.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
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
                          content: Text(
                            AppLocalizations.of(context).copiedCode,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _collapsed
                ? const SizedBox(width: double.infinity)
                : SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }
}

/// $$ 块级公式：整行横向可滚动，解析失败回落为原文文本。
class _MathBlock extends StatelessWidget {
  const _MathBlock({required this.expr});

  final String expr;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final style = TextStyle(fontSize: 14, color: t.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            expr,
            mathStyle: MathStyle.display,
            textStyle: style,
            onErrorFallback: (_) => Text(expr, style: style),
          ),
        ),
      ),
    );
  }
}

/// $ 行内公式语法。要求首尾非空白，避免把 "$5 和 $6" 这类货币写法误判为公式。
class _InlineLatexSyntax extends md.InlineSyntax {
  _InlineLatexSyntax()
    : super(
        r'\$([^\s$][^$\n]*?[^\s$]|[^\s$])\$',
        startCharacter: r'$'.codeUnitAt(0),
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

/// 行内公式 builder：以 WidgetSpan 嵌入段落，解析失败回落为原文。
class _InlineLatexBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = (parentStyle ?? const TextStyle()).copyWith(fontSize: 13);
    final expr = element.textContent;
    return Math.tex(
      expr,
      mathStyle: MathStyle.text,
      textStyle: style,
      onErrorFallback: (_) => Text('\$$expr\$', style: style),
    );
  }
}
