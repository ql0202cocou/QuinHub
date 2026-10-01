import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinhub/theme/app_theme.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_action_icon.dart';
import 'package:quinhub/ui/lobe_avatar.dart';
import 'package:quinhub/ui/lobe_button.dart';
import 'package:quinhub/ui/lobe_group.dart';
import 'package:quinhub/ui/lobe_list_tile.dart';

/// 用 App 浅色主题包一层，组件里的 `context.lobe` 取到 [LobeTokens.light]。
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

final _t = LobeTokens.light;

void main() {
  group('LobeButton', () {
    Finder inButton(Type type) => find.descendant(
      of: find.byType(LobeButton),
      matching: find.byType(type),
    );

    testWidgets('点击触发 onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(LobeButton(label: 'Save', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('onPressed 为空时半透明且不可点', (tester) async {
      await tester.pumpWidget(_wrap(const LobeButton(label: 'Save')));
      expect(tester.widget<Opacity>(inButton(Opacity)).opacity, 0.5);
      expect(tester.widget<InkWell>(inButton(InkWell)).onTap, isNull);
    });

    testWidgets('loading 时显示转圈、不触发回调、保持不透明', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          LobeButton(label: 'Save', loading: true, onPressed: () => taps++),
        ),
      );
      expect(inButton(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(taps, 0);
      expect(tester.widget<Opacity>(inButton(Opacity)).opacity, 1);
    });

    testWidgets('尺寸对应高度 24 / 32 / 40', (tester) async {
      for (final (size, height) in [
        (LobeButtonSize.small, 24.0),
        (LobeButtonSize.middle, 32.0),
        (LobeButtonSize.large, 40.0),
      ]) {
        await tester.pumpWidget(
          _wrap(LobeButton(label: 'Go', size: size, onPressed: () {})),
        );
        expect(tester.getSize(find.byType(LobeButton)).height, height);
      }
    });

    testWidgets('变体底色取对应 token', (tester) async {
      for (final (variant, color) in [
        (LobeButtonVariant.primary, _t.primary),
        (LobeButtonVariant.fill, _t.fillTertiary),
        (LobeButtonVariant.text, Colors.transparent),
        (LobeButtonVariant.danger, _t.error),
      ]) {
        await tester.pumpWidget(
          _wrap(LobeButton(label: 'Go', variant: variant, onPressed: () {})),
        );
        expect(
          tester.widget<Material>(inButton(Material).first).color,
          color,
          reason: '$variant',
        );
      }
    });
  });

  group('LobeActionIcon', () {
    testWidgets('三档尺寸对应容器 / 图标大小', (tester) async {
      for (final (size, box, glyph) in [
        (LobeActionIconSize.small, 24.0, 14.0),
        (LobeActionIconSize.middle, 36.0, 20.0),
        (LobeActionIconSize.large, 44.0, 24.0),
      ]) {
        await tester.pumpWidget(
          _wrap(
            LobeActionIcon(
              icon: Icons.copy,
              tooltip: 'Copy',
              size: size,
              onTap: () {},
            ),
          ),
        );
        expect(tester.getSize(find.byType(LobeActionIcon)), Size(box, box));
        expect(tester.widget<Icon>(find.byIcon(Icons.copy)).size, glyph);
      }
    });

    testWidgets('默认图标色为 textTertiary，点击触发回调', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          LobeActionIcon(
            icon: Icons.copy,
            tooltip: 'Copy',
            onTap: () => taps++,
          ),
        ),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.copy)).color,
        _t.textTertiary,
      );
      await tester.tap(find.byIcon(Icons.copy));
      expect(taps, 1);
    });
  });

  group('LobeListTile', () {
    Color? titleColor(WidgetTester tester, String title) =>
        tester.widget<Text>(find.text(title)).style?.color;

    testWidgets('默认：标题 text 色、图标 textTertiary', (tester) async {
      await tester.pumpWidget(
        _wrap(const LobeListTile(icon: Icons.key, title: 'Providers')),
      );
      expect(titleColor(tester, 'Providers'), _t.text);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.key)).color,
        _t.textTertiary,
      );
    });

    testWidgets('danger：标题与图标用 error 色', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LobeListTile(icon: Icons.delete, title: 'Delete', danger: true),
        ),
      );
      expect(titleColor(tester, 'Delete'), _t.error);
      expect(tester.widget<Icon>(find.byIcon(Icons.delete)).color, _t.error);
    });

    testWidgets('禁用：置灰且点击不触发', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          LobeListTile(title: 'About', enabled: false, onTap: () => taps++),
        ),
      );
      expect(titleColor(tester, 'About'), _t.textQuaternary);
      await tester.tap(find.text('About'));
      expect(taps, 0);
    });

    testWidgets('arrow 为 true 时显示右箭头', (tester) async {
      await tester.pumpWidget(_wrap(const LobeListTile(title: 'A')));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.pumpWidget(
        _wrap(const LobeListTile(title: 'A', arrow: true)),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('LobeAvatar', () {
    test('seeded：同一 seed 稳定取到同一 emoji 与底色', () {
      final a = LobeAvatar.seeded(seed: 'conv-123');
      final b = LobeAvatar.seeded(seed: 'conv-123');
      expect(a.emoji, isNotNull);
      expect(a.emoji, b.emoji);
      expect(a.background, b.background);
    });

    testWidgets('text：取前 2 个字符并大写', (tester) async {
      await tester.pumpWidget(_wrap(const LobeAvatar(text: 'mock')));
      expect(find.text('MO'), findsOneWidget);
    });
  });

  group('LobeGroup', () {
    Finder band() => find.byWidgetPredicate(
      (w) => w is Container && w.color == _t.fillTertiary,
    );

    testWidgets('band 默认显示 6px 分隔横条，传 false 时不显示', (tester) async {
      await tester.pumpWidget(_wrap(const LobeGroup(children: [Text('x')])));
      expect(band(), findsOneWidget);
      expect(tester.getSize(band()).height, 6);

      await tester.pumpWidget(
        _wrap(const LobeGroup(band: false, children: [Text('x')])),
      );
      expect(band(), findsNothing);
    });

    testWidgets('有 title 时显示小标题', (tester) async {
      await tester.pumpWidget(
        _wrap(const LobeGroup(title: '通用', children: [Text('x')])),
      );
      expect(find.text('通用'), findsOneWidget);
    });
  });

  group('LobeTokens', () {
    testWidgets('未注册 extension 时按亮度回落', (tester) async {
      late LobeTokens got;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              got = context.lobe;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(got.primary, LobeTokens.dark.primary);
    });

    test('lerp 两端分别等于 light / dark', () {
      final light = LobeTokens.light;
      final dark = LobeTokens.dark;
      expect(light.lerp(dark, 0).bgLayout, light.bgLayout);
      expect(light.lerp(dark, 1).bgLayout, dark.bgLayout);
      expect(light.lerp(null, 0.5), same(light));
    });
  });
}
