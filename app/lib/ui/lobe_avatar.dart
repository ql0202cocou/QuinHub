import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI Avatar：方形，圆角 max(size/6, 2)。
/// - emoji：无 [background] 时透明底、emoji 视觉占满，有底色时缩到约 85%
///   （emoji 字形比字号大约 1.25 倍，故字号取 size×0.8 / ×0.62）；
/// - text：colorBorder 底、粗体、字号 size×0.5、取前 2 个字符；
/// - icon：fillTertiary 底 + textSecondary 图标。
class LobeAvatar extends StatelessWidget {
  const LobeAvatar({
    super.key,
    this.emoji,
    this.text,
    this.icon,
    this.background,
    this.size = 40,
  });

  /// 按 [seed]（如会话 id）从 emoji 池与底色池中稳定取值，
  /// 对应 LobeHub 助手的「emoji + 柔和底色」头像。
  factory LobeAvatar.seeded({
    Key? key,
    required String seed,
    double size = 40,
  }) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return LobeAvatar(
      key: key,
      emoji: _emojis[h % _emojis.length],
      background: _backgrounds[(h ~/ _emojis.length) % _backgrounds.length],
      size: size,
    );
  }

  final String? emoji;
  final String? text;
  final IconData? icon;
  final Color? background;
  final double size;

  static const _emojis = [
    '🤖', '🦄', '🐳', '🦊', '🐼', '🐙', '🦉', '🐧', '🌵', '🍀', //
    '🔮', '🚀', '🎨', '📚', '💡', '🧩', '🪐', '🌈', '🍊', '🫧',
  ];

  /// LobeUI 助手头像常用的柔和底色（低饱和）。
  static const _backgrounds = [
    Color(0x1F1677FF),
    Color(0x1F722ED1),
    Color(0x1F13C2C2),
    Color(0x1FEB2F96),
    Color(0x1FFA8C16),
    Color(0x1F52C41A),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    final radius = size < 24 ? size * 0.33 : (size / 6).clamp(2.0, 999.0);
    final Widget child;
    Color? bg = background;
    if (emoji != null) {
      child = Text(
        emoji!,
        style: TextStyle(
          fontSize: size * (background == null ? 0.8 : 0.62),
          height: 1,
        ),
      );
    } else if (text != null) {
      bg ??= t.border;
      final s = text!.trim();
      child = Text(
        (s.length > 2 ? s.substring(0, 2) : s).toUpperCase(),
        style: TextStyle(
          color: t.text,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
          height: 1,
        ),
      );
    } else {
      bg ??= t.fillTertiary;
      child = Icon(
        icon ?? Icons.smart_toy_outlined,
        size: size * 0.55,
        color: t.textSecondary,
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
