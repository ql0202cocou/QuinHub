import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:quinhub/features/chat/widgets/markdown_view.dart';

const reply = '''好的，这是来自 mock 的流式回复。

**加粗** 与 `inline code`，然后是一个代码块：

```python
def hello(name):
    return f"hello {name}"
```

列表：
- 第一项
- 第二项

完毕 ✅
''';

void main() {
  testWidgets('A: 裸 MarkdownBody 无 builders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownBody(data: reply)),
      ),
    );
    expect(find.textContaining('加粗'), findsWidgets);
  });

  testWidgets('B: BlockedMarkdown 无自定义 builders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: _BlockedNoBuilder(text: reply)),
      ),
    );
    expect(find.textContaining('加粗'), findsWidgets);
  });

  testWidgets('C: BlockedMarkdown 完整（含代码块 builder）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BlockedMarkdown(text: reply)),
      ),
    );
    expect(find.textContaining('加粗'), findsWidgets);
  });

  testWidgets('D: 代码块点头部折叠 / 展开', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BlockedMarkdown(text: reply)),
      ),
    );
    final code = find.textContaining('def hello', findRichText: true);
    expect(code, findsOneWidget);

    await tester.tap(find.text('python'));
    await tester.pumpAndSettle();
    expect(code, findsNothing);

    await tester.tap(find.text('python'));
    await tester.pumpAndSettle();
    expect(code, findsOneWidget);
  });

  testWidgets('E: 流式追加内容后折叠状态保留', (tester) async {
    const head = '前言\n\n```python\nprint(1)\n```\n\n';
    Widget md(String text) => MaterialApp(
      home: Scaffold(body: BlockedMarkdown(text: text)),
    );
    final code = find.textContaining('print(1)', findRichText: true);

    await tester.pumpWidget(md(head));
    await tester.tap(find.text('python'));
    await tester.pumpAndSettle();
    expect(code, findsNothing);

    // 模拟流式：代码块之后继续到达新段落
    await tester.pumpWidget(md('$head后续内容'));
    await tester.pumpAndSettle();
    expect(find.textContaining('后续内容'), findsOneWidget);
    expect(code, findsNothing);
  });

  testWidgets(r'F: $$ 块级公式渲染为 Math', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BlockedMarkdown(text: '前言\n\n\$\$\nE=mc^2\n\$\$\n\n后续'),
        ),
      ),
    );
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('后续'), findsOneWidget);
  });

  testWidgets(r'G: $ 行内公式渲染；货币写法不误判', (tester) async {
    Widget md(String text) => MaterialApp(
      home: Scaffold(body: BlockedMarkdown(text: text)),
    );
    await tester.pumpWidget(md(r'质能方程 $E=mc^2$ 很有名'));
    expect(find.byType(Math), findsOneWidget);

    // "$5 和 $6" 首尾有空白/是货币，不应渲染为公式
    await tester.pumpWidget(md(r'价格 $5 和 $6 元'));
    expect(find.byType(Math), findsNothing);
    expect(find.textContaining('价格'), findsWidgets);
  });

  testWidgets(r'H: 流式中未闭合 $$ 不崩溃', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BlockedMarkdown(text: '前言\n\n\$\$\nE=mc')),
      ),
    );
    expect(find.byType(Math), findsOneWidget);
  });
}

/// 复用 BlockedMarkdown 的切分但不带 pre builder
class _BlockedNoBuilder extends StatelessWidget {
  const _BlockedNoBuilder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = <String>[];
    final buf = StringBuffer();
    var inFence = false;
    for (final line in text.split('\n')) {
      if (line.trimLeft().startsWith('```')) inFence = !inFence;
      buf.writeln(line);
      if (!inFence && line.trim().isEmpty) {
        blocks.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) blocks.add(buf.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final b in blocks) MarkdownBody(data: b)],
    );
  }
}
