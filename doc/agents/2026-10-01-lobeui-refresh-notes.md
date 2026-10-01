# 2026-10-01 LobeUI 风格 UI 翻新笔记

## 背景

用户反馈整体 UI「过于简洁」，要求按 LobeUI（@lobehub/ui）的设计语言翻新全部页面。LobeUI 是 React 组件库无法直接用于 Flutter，经确认采用 **Flutter 复刻**：自建 token 体系 + 轻量组件库，零新增三方依赖，以换皮为主，唯一新增交互是 user 气泡下的常驻操作行（编辑重发/复制，原先只能长按菜单触发）。明暗双主题。

## 落地内容

### Token 体系

- `app/lib/theme/tokens.dart`：`LobeTokens extends ThemeExtension`，含品牌蓝梯度（light `#1677FF` / dark `#1668DC`）、功能色、antd 透明度文本色阶、容器色（fill/fillSecondary/cardBg/layoutBg）、圆角（4/8/12/16/20）与间距（4 倍数）静态常量、柔和卡片阴影；明暗双套静态实例。
- `context.lobe` 快捷取用；主题未注册 extension 时按亮度回落（裸 MaterialApp 的 widget 测试依赖此行为）。
- `app/lib/theme/app_theme.dart` 重写：补齐完整 textTheme，全部组件主题（AppBar/Card/Input/Dialog/Sheet/Slider/FAB 等）消费 tokens。

### 组件库 `app/lib/ui/`

LobeGroup、LobeListTile（图标可空、支持 enabled 禁用置灰）、LobeButton（4 变体 + loading，无图标时走普通构造避免间距偏移）、LobeAvatar（默认构造定色 / `.seeded` 按字符串稳定取色，6 色柔和调色板）、LobeTag、LobeSearchBar、showLobeSheet（统一底部弹层骨架）、LobeEmpty、LobeActionIcon。

### 页面换皮（state / 路由 / bridge 调用未改）

- home：pill 搜索栏、LobeAvatar+Tag 会话项、LobeGroup 分区、LobeEmpty 空态、菜单走 showLobeSheet。
- chat：模型选择改品牌色 chip、输入栏品牌蓝圆形发送/停止钮（arrow_upward/stop）、参数/模型/图片来源弹层统一 showLobeSheet。
- message_bubble：user 品牌蓝实底白字气泡 + 右对齐操作行（编辑重发/复制）；assistant 元信息改 LobeTag；长按菜单统一组件。
- markdown_view：代码块圆角 12 + LobeActionIcon 复制；引用块品牌色竖条；链接 brand 色。tooltip 用 `Localizations.of` 可空取值兼容无 l10n 的测试环境。
- settings/archived/providers/provider_edit：全部分组与列表项组件化，设置项图标按语义配彩色色块；编辑页按钮换 LobeButton、模型勾选列表入 LobeGroup。
- share.dart 分享长图：固定白底导出图改用 `LobeTokens.light` 显式色值（不跟随 App 主题），角色标签换 LobeTag。

## 验证

- `fvm flutter analyze` 无问题；`fvm flutter test` 全部通过（修复了两处测试环境兼容：token 回落、l10n 可空取值）。未改 l10n key、路由、state、bridge 与 Rust 侧。
- 真机观感（2026-10-01，Android 模拟器 quinmo-api36 + mock_sse.py）：明暗双主题截图已验证，见 `assets/2026-10-01-lobeui/`（首页/聊天页/设置页/长按弹层/提供商页）。流式发送、停止钮切换、Markdown 主题切换缓存重建均正常。

## 后续可补

- LobeAvatar 调色板如需更贴 LobeUI 可再调（当前为 6 色柔和调色板，真机观感已可接受）。
