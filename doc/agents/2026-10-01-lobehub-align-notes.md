# 2026-10-01 UI 对齐 LobeHub 笔记

## 背景

上一轮翻新（[2026-10-01-lobeui-refresh-notes.md](2026-10-01-lobeui-refresh-notes.md)）的 token 多为凭印象填的 antd 默认值，观感与 LobeHub 差距明显。用户要求向 LobeHub 对齐并「使用 LobeUI 组件库」。LobeUI 是 React 库无法直接用于 Flutter，经确认走 **深度复刻**：以 @lobehub/ui 源码为规格、LobeHub 手机网页版实测为参照，逐项翻译成 Flutter。

用户已确认的取舍：

- 主色：**中性黑白**（LobeHub 默认），不保留蓝色。
- 模型选择器：从顶栏移入输入卡片工具行。
- 底部 TabBar：不加（无「社区」功能），设置入口仍在首页右上角。
- 字体：系统默认，不打包 Geist。

## 参照来源

- 源码：@lobehub/ui **5.51.2**（main `e7fa3d9`，2026-09-28）。主题在 `src/styles/theme/`（13 级色阶 + light/dark algorithm），组件规格以 `src/base-ui/*` 为准（`src/*` 下的 antd 版本已标 deprecated）。
- 实测：LobeHub 手机网页版（375×812 视口），明暗双主题截图在 `assets/2026-10-01-lobehub-ref/`；计算样式数值（底色 #F8F8F8、正文 #080808、主色 #222、搜索框 36/8、设置行 56、消息气泡 8×12/12 等）与源码一致。

## 落地内容

- `theme/tokens.dart`：按 LobeUI 命名重写（primary / text 色阶 / bgLayout·Container·Elevated / border / fill 四级 / 功能色 / 分层阴影 / 代码高亮色 / 圆角 4·6·8·12 / 控件高 24·32·40）。`light` / `dark` 由 `const` 改为 `static final`（阴影列表由函数生成）。
- `theme/app_theme.dart`：全部组件主题改为消费新 token；AppBar 高 44 居中标题；去掉 Material 水波纹（`NoSplash`），按压反馈用 fillTertiary；FAB 48px 主色。
- `app/lib/ui/`：
  - LobeButton：variant 改为 primary / fill / text / danger（`tonal` 移除），新增 size 与 `block`；禁用为 50% 透明。
  - LobeActionIcon：新增 small / middle / large 三档；消息与代码块用 small。
  - LobeAvatar：改为 emoji / 文字 / 图标三种形态；`.seeded` 从 20 个 emoji × 6 种柔和底色中稳定取值。
  - LobeGroup：由「白卡片」改为「6px 横条 + 可选小标题」的平铺分组。
  - LobeListTile 改为设置类菜单行（单色图标 + 箭头）；新增 LobeListItem（会话/归档/提供商列表）。
  - LobeTag、LobeSearchBar、LobeEmpty（改为 emoji）、showLobeSheet（标题 + 关闭按钮，无拖拽条）按规格调整。
- 页面：
  - 首页：分区头可折叠。
  - 聊天页：输入卡片 + 工具行；assistant 正文通栏；user 浅灰气泡。
  - Markdown：chat 变体字号；代码块 fillQuaternary + 头部；高亮配色改为 lobe-theme。
  - 设置 / 归档 / 提供商 / 编辑页：平铺列表。
  - 分享长图：色值跟随新 token。

交互逻辑（state / 路由 / bridge）未改。新增的交互只有以下几处：

- 首页分区可以折叠；
- 输入为空时发送按钮显示为禁用态；
- 提供商行的更多按钮换成了 ActionIcon。

## 验证

- `fvm flutter analyze` 无问题，`fvm flutter test` 4/4 通过。
- Android 模拟器 quinmo-api36 + mock_sse.py：首页、聊天页、设置页、外观弹层、模型选择弹层、提供商页明暗截图见 `assets/2026-10-01-lobehub-align/`。流式发送、停止按钮、发送按钮禁用/启用切换均正常。

## 后续可补

- 代码块折叠、消息操作改为「点按显示」（LobeHub 移动端默认隐藏操作行），需要时再做。
- LobeHub 助手头像为 Fluent 3D emoji 图片，当前用系统 emoji 字体代替。
