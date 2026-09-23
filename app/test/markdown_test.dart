import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
