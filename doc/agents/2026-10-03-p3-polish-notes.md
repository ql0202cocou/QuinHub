# 2026-10-03 P3 收敛交接：LaTeX / 选择文本 / 大图预览 / 消息分页

日期：2026-10-03
范围：第一期 backlog P3 四项（#11–#14）收敛；第二期 plan-v2 同日评审细化（见 plan-v2.md 头部）。

## 改动概览

| 项 | 内容 | 关键文件 |
|---|---|---|
| #11 LaTeX | flutter_math_fork（新依赖，理由见 decisions 决策五）；`$$` 块在 block 切分层拦截整渲，行内 `$...$` 走 md.InlineSyntax + builders | `app/lib/features/chat/widgets/markdown_view.dart` |
| #13 可选中复制 | 长按菜单「选择文本」→ 全屏 SelectableText 原文页；不做渲染态 selectable（手势冲突 + 历史断言 bug） | `app/lib/features/chat/widgets/message_bubble.dart` |
| #14 大图预览 | 缩略图点按 → 黑底全屏 InteractiveViewer 缩放 + 分享原图（share_plus） | 同上 |
| #12 消息分页 | storage `list_messages_page`（(created_at, rowid) 游标）→ bridge `message_list_page` → ChatNotifier 分页状态 → 聊天页滚顶自动翻页 + 视口补偿 | `core/crates/storage`、`core/crates/bridge/src/api/message.rs`、`app/lib/state/chat.dart`、`chat_page.dart` |

## 实现要点（坑）

1. **flutter_markdown 0.7.7 行内自定义 tag**：`visitText` 按外层 block tag（如 `p`）派发，行内 tag 只有 `visitElementAfterWithContext` 会命中；块级 tag 才走 `visitElementAfter`（决策五已记）。
2. **行内 $ 防误判**：语法要求公式首尾非空白（`$5 和 $6` 不触发）；解析失败一律回落原文。
3. **分页游标**：`Message` 加了 `#[sqlx(default)] rowid` 字段（仅分页查询 SELECT rowid 时有值，其余为 0）；游标 (created_at, rowid) 解决同毫秒消息漏/重。DTO 新增必填 `rowid`，构造 MessageDto 的测试都要补。
4. **翻页视口补偿**：记录翻页前 maxScrollExtent，翻页后按增量 jumpTo；流式中禁止翻页（loadMore 与 _drive 的 reload 有竞态守卫）。
5. `_reload` limit = max(50, 已加载数)，保留已翻出的历史；hasMore 在「恰好拉完」时有假阳性，下次 loadMore 返回空即纠正。

## 验证

- Rust：fmt + clippy 干净；workspace 44 测试全过（storage 新增 `message_pagination`，覆盖同毫秒连插翻页）。
- Flutter：analyze 干净；32 测试全过（markdown 新增 F/G/H 公式用例，bubble 新增选择文本/大图预览用例）。
- 未做真机验证：分页翻页手感、LaTeX 实际渲染效果、大图缩放手势，待用户真机过一遍。

## 动画细节（同日补充）

- 代码块折叠箭头 `AnimatedRotation` 补 `curve: easeOut`（原默认线性，与 AnimatedSize 节奏不一致）。
- 图片大图预览：缩略图 ↔ 全屏 Hero 共享元素 + 淡入路由（`PageRouteBuilder` + `FadeTransition`）。
- 发送/停止按钮：`AnimatedContainer` 160ms 色彩过渡（可发送/流式/禁用三态切换不再瞬时变色）。
- 有意不动的：翻页视口补偿与流式跟随用 `jumpTo`（动画跟不上 delta）；user 操作行 AnimatedSize、assistant 操作行 AnimatedOpacity 两种机制（定高防跳动 vs 收起不占位）均保留。

## 遗留

- backlog 仅剩：P1 真机验收四项（用户资产）、P2 keystore/崩溃收集决策、P3 的消息分支 UI 与流式逐消息 tokens。
- 生成物：`make frb-codegen` 已重跑，frb 生成物需随本次改动一并提交。
