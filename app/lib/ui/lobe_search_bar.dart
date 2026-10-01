import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI 风格 pill 搜索框。
class LobeSearchBar extends StatelessWidget {
  const LobeSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lobe;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, size: 20, color: t.textTertiary),
        fillColor: t.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: t.brand, width: 1.2),
        ),
      ),
    );
  }
}
