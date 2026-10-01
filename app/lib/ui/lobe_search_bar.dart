import 'package:flutter/material.dart';
import 'package:quinhub/theme/tokens.dart';

/// LobeUI SearchBar（移动端 filled 形态）：高 36、圆角 8、fillTertiary 底、无边框。
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LobeTokens.r),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: t.text),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: t.textQuaternary),
          prefixIcon: Icon(Icons.search, size: 16, color: t.textQuaternary),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          fillColor: t.fillTertiary,
          contentPadding: EdgeInsets.zero,
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
