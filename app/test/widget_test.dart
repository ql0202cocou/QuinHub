import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1：真实 UI 测试在 M4 补齐（需要 mock 流式源）。
  test('smoke', () {
    expect(1 + 1, 2);
  });
}
