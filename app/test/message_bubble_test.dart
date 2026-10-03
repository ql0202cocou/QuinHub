import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:quinhub/features/chat/widgets/message_bubble.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/app_theme.dart';

MessageDto _msg(String role) => MessageDto(
  id: 'm1',
  role: role,
  text: 'hello',
  images: const [],
  model: 'mock-1',
  status: 'done',
  createdAt: 0,
  rowid: 1,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  group('MessageBubble 点按显示操作图标', () {
    double actionsOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byIcon(Icons.refresh),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('assistant：默认隐藏且不可点，元信息常驻', (tester) async {
      var regen = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _msg('assistant'),
            appDir: '',
            onRegenerate: () => regen++,
          ),
        ),
      );
      expect(find.text('mock-1'), findsOneWidget);
      expect(actionsOpacity(tester), 0);
      await tester.tap(find.byIcon(Icons.refresh), warnIfMissed: false);
      expect(regen, 0);
    });

    testWidgets('assistant：showActions 为 true 时可见可点', (tester) async {
      var regen = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _msg('assistant'),
            appDir: '',
            showActions: true,
            onRegenerate: () => regen++,
          ),
        ),
      );
      expect(actionsOpacity(tester), 1);
      await tester.tap(find.byIcon(Icons.refresh));
      expect(regen, 1);
    });

    testWidgets('user：操作行随 showActions 出现 / 收起', (tester) async {
      Widget bubble(bool show) => _wrap(
        MessageBubble(
          message: _msg('user'),
          appDir: '',
          showActions: show,
          onEditResend: () {},
        ),
      );
      await tester.pumpWidget(bubble(false));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.pumpWidget(bubble(true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('点按消息触发 onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _msg('assistant'),
            appDir: '',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('hello'));
      expect(taps, 1);
    });

    testWidgets('长按菜单进选择文本页', (tester) async {
      await tester.pumpWidget(
        _wrap(MessageBubble(message: _msg('assistant'), appDir: '')),
      );
      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select text'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('点图片缩略图进大图预览', (tester) async {
      final m = MessageDto(
        id: 'm1',
        role: 'user',
        text: '',
        images: const ['files/x.jpg'],
        model: null,
        status: 'done',
        createdAt: 0,
        rowid: 1,
      );
      await tester.pumpWidget(_wrap(MessageBubble(message: m, appDir: '')));
      await tester.tap(find.byType(Image).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  });
}
