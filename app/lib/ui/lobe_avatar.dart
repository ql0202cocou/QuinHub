import 'package:flutter/material.dart';

/// LobeUI 风格圆角方块头像：柔和渐变底 + 图标/文字。
class LobeAvatar extends StatelessWidget {
  const LobeAvatar({
    super.key,
    this.icon,
    this.text,
    this.color,
    this.size = 40,
  }) : seed = null;

  /// 按 [seed]（如会话 id）从调色板稳定取色。
  const LobeAvatar.seeded({
    super.key,
    required String this.seed,
    this.icon,
    this.text,
    this.size = 40,
  }) : color = null;

  final IconData? icon;
  final String? text;
  final Color? color;
  final String? seed;
  final double size;

  /// 柔和调色板（LobeUI 常用的低饱和彩色）。
  static const _palette = [
    Color(0xFF1677FF),
    Color(0xFF722ED1),
    Color(0xFF13C2C2),
    Color(0xFFEB2F96),
    Color(0xFFFA8C16),
    Color(0xFF52C41A),
  ];

  Color _base() {
    if (color != null) return color!;
    final s = seed ?? '';
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final base = _base();
    final brightness = Theme.of(context).brightness;
    final bgFrom = base.withValues(
      alpha: brightness == Brightness.dark ? 0.28 : 0.16,
    );
    final bgTo = base.withValues(
      alpha: brightness == Brightness.dark ? 0.16 : 0.08,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgFrom, bgTo],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: text != null
          ? Text(
              text!,
              style: TextStyle(
                color: base,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.38,
              ),
            )
          : Icon(
              icon ?? Icons.smart_toy_outlined,
              size: size * 0.52,
              color: base,
            ),
    );
  }
}
