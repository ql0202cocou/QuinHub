# M5b 打磨批次交接（主题 / i18n / 用量 / 图标 / Release）

日期：2026-09-23
状态：完成

## 完成内容
- **主题切换**：settings KV 桥接（`settings_get/set`，Rust 侧 settings 表）；设置页外观三档（浅/深/跟随系统），MaterialApp themeMode 接入
- **i18n**：gen-l10n（非 synthetic package：l10n.yaml + output-dir lib/l10n），zh 模板 + en，约 50 条文案全覆盖主要页面；设置页语言切换（系统/中文/English）持久化
- **用量统计**：聊天页 ⋮ 菜单新增「用量统计」对话框（消息数 + 输入/输出 tokens 合计，纯 Dart 从消息聚合）
- **图标/启动屏**：`tools/gen_icon.py`（纯 stdlib 生成 1024 PNG：深蓝圆角方块 + 白色聊天气泡）→ flutter_launcher_icons（双端全尺寸 + Android 自适应）+ flutter_native_splash（蓝底居中图标）；应用名修正为 QuinHub（AndroidManifest label + iOS Info.plist）
- **Release**：`flutter build apk --release` 跑通（debug 签名占位）；正式签名需用户生成 keystore（release-checklist.md 有指引）
- **CI**：启用 build-android job（cargokit 自动装 NDK；frb 生成物已提交无需 codegen）；build-ios 骨架注释态（待 macOS 条件）

## 踩坑
- **Flutter 3.47 弃用 `RadioListTile` 的 groupValue/onChanged** → 改用 ListTile + 对勾
- **gen-l10n**：`pubspec.yaml` 需 `flutter: generate: true`；ARB 加 key 后要重跑 `flutter gen-l10n`
- **`AppLocalizations.of(context)` 在首帧可能为 null**（delegate 异步加载）：不要在 build 顶层取，事件处理器里取才安全（copy 按钮的教训）
- **l10n 调用不是常量**：含 l10n 的 widget 不能挂 `const`（批量替换时 const 残留是一大半编译错误来源）
- adb 截图抓不到启动屏（时机太早），静态验证 launch_background.xml 即可

## 验证记录
- 模拟器：主题切换即时生效；语言切 English 全界面英文化；图标在应用抽屉正确渲染（自适应裁切）；名称 QuinHub
- 门禁：fmt/clippy/test/analyze 全绿
