# QuinHub 移动端 — 技术决策记录（ADR）

日期：2026-09-22
状态：已确认

## 决策汇总

| 项 | 决策 |
|---|---|
| 技术路线 | Flutter + Rust（Rust 全包核心），flutter_rust_bridge v2 桥接 |
| 平台 | iOS + Android 双端，本期即配置双端工具链 |
| 状态管理 | Riverpod（riverpod_annotation + riverpod_generator） |
| API 接入 | BYOK：用户填自己的 Key，App 直连官方 API，不经中转 |
| 协议 | OpenAI 兼容接口（可自定义 base_url）+ Anthropic API，两套协议解析 |
| 存储 | 本地 SQLite 为主，数据模型预留云同步字段（墓碑 + 版本号）；服务端后期单独立项、Docker 部署 |
| 功能范围 | 第一期只做对话核心（含图片消息、导出分享）；插件/知识库/语音/助手市场只留架构接口 |
| 应用标识 | 名称 QuinHub；包名 / bundle id：com.quinhub.app |
| UI 基调 | 贴近 LobeHub 手机版风格（Material 3 为底，主题 token 定制） |
| 图片消息 | 第一期纳入（M4 后半）；仅 vision 模型开放入口 |
| 导出/分享 | 导出 Markdown 文件 + 分享长图（M5） |
| 上下文管理 | 历史全量存储；Agent 化 ContextManager（默认 auto_summary，见决策四） |
| LaTeX / 文本选择 | flutter_math_fork（$$ 块 + 行内 $）；渲染态不可选，长按菜单进选择文本页（见决策五） |

## 决策一：Rust / Dart 分工边界

结论：**Rust 全包核心**（网络 + SSE 解析 + 存储 + 加密在 Rust，Dart 纯 UI/状态）。

候选方案利弊：

### 选项 1：Rust 全包核心（采纳）
- 利：两家 API 的协议解析、重试、错误处理只写一遍，Rust 强类型 + 编译期检查，协议边界难写错；长流式解析、大 JSON 处理不占 Dart UI 线程；Rust 单测不依赖 Flutter 环境，可录制样本回放。
- 弊：双语言工具链（Android NDK 多 ABI 交叉编译、iOS xcframework、frb 代码生成），CI 复杂度上升；调试链路跨 Dart→Rust 两层，Rust 改动无热重载；涉及 API 行为的改动都要动 Rust 层并重新生成桥接代码；团队需维护两种语言。
- 备注：AI 判断只做移动端时 Rust 的「跨桌面复用」溢价拿不到，曾推荐纯 Dart；团队基于 Rust 能力与偏好仍选本项。

### 选项 2：Dart 管网络，Rust 只做解析/存储/加密（否决）
- 边界别扭：Dart 发请求、Rust 解析 SSE，则每条流式 delta 要 Dart→Rust→Dart 过桥两次；而 SSE 解析只是按行切分文本，不值得为此架桥。利不抵弊。

### 选项 3：纯 Dart 起步，分层预留（未采纳，保留为降级路线）
- 利：工具链最简单、迭代最快（全量热重载）、Dart 生态够用（dio 流式、drift、flutter_secure_storage）；后期可逐模块下沉 Rust，不是单行道。
- 弊：极端长回复下 Dart isolate 解析有掉帧风险（可缓解）；密钥明文过 Dart 内存；未来桌面端需重写核心。
- 若 Flutter + Rust 工具链在实践中成本过高，可退回本方案：架构分层（api/storage/sync 抽象）保持一致，迁移成本低。

## 决策二：状态管理

结论：**Riverpod**。

### Riverpod（采纳）
- 利：编译期安全，不依赖 BuildContext；StreamProvider/AsyncNotifier 与 SSE 流天然契合；family 按会话 ID 拆状态自然；`select` 细粒度重建，流式 delta 到达时只重建对应消息气泡，对长列表性能友好；模板代码少。
- 弊：自由度大需定规范；依赖 build_runner 代码生成；多形态 Provider 有学习成本。

### Bloc（否决）
- 利：Event→Bloc→State 单向数据流结构严谨，协作风格统一；状态机表达清晰；可测性好。
- 弊：Event/State/Bloc 三件套模板代码重，琐碎状态也躲不开；依赖 widget 树注入；按需监听流要包一层，不如 StreamProvider 直接。

### 实现备注（M2）
先用无代码生成的写法（手写 `AsyncNotifier` / `NotifierProvider`），`riverpod_annotation + riverpod_generator` 待状态复杂度上来后再引入，避免 M2 就背上 build_runner。

## 决策三：Markdown 渲染（Flutter 侧最大风险点）

结论：**先做「block 级增量渲染层」（与具体库解耦），库首选 flutter_markdown，M4 用 spike 定稿**。

背景：LobeHub 式流式 Markdown（代码高亮、增量渲染不闪烁）在 Flutter 没有现成完美方案。

### 关键设计：block 级增量渲染层（确定要做）
无论选哪个库，消息内容先解析为 block 列表（段落/代码块/表格/列表），已完成的 block 缓存为 widget，流式到达时**只重渲染最后一个未完成 block**。这是性能与不闪烁的关键，业界通用做法。

### 候选库
- **flutter_markdown**（首选）：flutter.dev 官方生态，成熟稳定，自定义 builder 可扩展；代码高亮需自接（flutter_highlight 或自绘）；样式定制成本中等。
- **markdown_widget**：内置目录与代码高亮，定制性不错；社区体量小，长期维护风险。
- **gpt_markdown**：面向 AI 聊天场景（流式、LaTeX、代码块开箱即用）；库较新，API 变动风险。
- **自研渲染**：完全可控、性能上限最高；成本也最高，仅在前三者不满足时考虑。

执行方式：M4 安排半天 spike，用真实流式样本在真机上对比 flutter_markdown 与 gpt_markdown（流畅度、定制成本），届时定稿并更新本条目。

### Spike 结果（M4 实测，2026-09-23，定稿）
落地 **flutter_markdown + 自研 block 层**，但有重要修正：
- **flutter_markdown 的 `pre` 自定义 builder 会触发 `_inlines.isEmpty` 断言崩溃**（widget 测试 A/B/C 隔离证实）；`selectable: true` 模式同样有此问题。
- **对策**：代码块不走 pre builder——block 切分天然把 fence 块独立出来，整块由我们自渲染（flutter_highlight 高亮 + 复制按钮），flutter_markdown 只渲染普通 Markdown block。选择复制用长按消息菜单替代。
- gpt_markdown 未实测（flutter_markdown 经此修正后够用）；若后续要 LaTeX 再评估。
- 相关 widget 测试：app/test/markdown_test.dart。

## 决策四：上下文管理（Agent 化）

结论：**历史全量存储不丢弃；发送时的上下文组装抽象为 ContextManager 模块（Agent 化），默认策略 `auto_summary`**。

来源：用户明确要求「整个上下文全部存储，整个上下文的管理做成 Agent 的模式」。

### 设计
- **存储层**：消息永久全量落库，不做任何截断/丢弃（与数据模型一致）。
- **发送层**：`ContextManager`（`core/crates/context`）负责把会话历史组装为本次请求的 messages，策略可插拔：
  - `auto_summary`（默认）：估算 token，接近模型 context_window 时，用 LLM 对旧消息做滚动摘要（摘要消息 + 最近原样消息一起发送）；
  - `full`：全量发送，超限报错（调试用）；
  - 后续可扩展检索召回、长期记忆（mem0 类）等更完整的 Agent 记忆形态。
- 摘要本身作为 system 角色的内部消息持久化（对用户可见但可折叠展示），保证可审计、可回滚。
- 摘要调用复用当前会话的 Provider 与模型（费用用户自担，BYOK 模式下自然成立）。

### 待细化（M3 设计时定稿）
- 「Agent 模式」的更复杂形态（自动话题切分、按需召回旧消息、跨会话记忆）本期不实现，接口预留。
- token 估算方案：第一期用字符近似（≈4 字符/token）或 tiktoken 离线词表，M3 定。

## 决策五：LaTeX 渲染与消息文本选择（2026-10-03，P3 收敛）

结论：**LaTeX 用 flutter_math_fork；消息「可选中复制」走长按菜单 → 全屏选择文本页，不在渲染态启用 selectable。**

### LaTeX（backlog #11）
- 选型：flutter_math_fork（KaTeX 移植，纯 Dart 渲染、无需 webview）。**新增依赖理由**：gpt_markdown 虽自带 LaTeX，但决策三已定稿 flutter_markdown + 自研 block 层，换库要重写流式渲染与样式体系，代价远大于加一个渲染库。
- 实现：`$$` 块级公式在 block 切分层整体拦截（与代码块同机制），整块 `Math.tex` 渲染，横向可滚动；行内 `$...$` 走 markdown 包自定义 `InlineSyntax` + flutter_markdown `builders` 的 `visitElementAfterWithContext`，以 WidgetSpan 嵌入段落。
- 防误判：行内语法要求公式首尾非空白，`$5 和 $6` 这类货币写法不触发；解析失败一律回落为原文文本。
- 行内 builder 的注意点（实测）：flutter_markdown 0.7.7 的 `visitText` 按**外层 block tag** 派发，行内自定义 tag 只有 `visitElementAfterWithContext` 会命中。

### 可选中复制（backlog #13）
- 背景：决策三备注的 flutter_markdown `selectable: true` 断言 bug 在 0.7.7 仍存在风险；且 SelectionArea 的长按拖选会与消息气泡的点按/长按手势冲突（点文本无法唤起操作图标）。
- 方案：长按菜单加「选择文本」→ 全屏页 `SelectableText` 展示消息原文（Markdown 源码），系统级拖选复制。渲染态保持不可选，交互零冲突。
- 若未来要在渲染态直接拖选，需先解决手势冲突再重试 SelectionArea（届时更新本条目）。

## 其他已确认
- 只做 iOS + Android 客户端，不考虑桌面端。
- 云同步服务端后期单独立项（Docker 部署）；本期客户端仅定义 `SyncBackend` 接口 + no-op 实现 + 同步就绪的数据模型字段；方向性约定见 [engineering.md](./engineering.md)。
- iOS 构建需要 macOS：本地 Mac 或 CI macOS runner（GitHub Actions / Codemagic）；无本地 Mac 时开发期先在 Android/模拟器迭代，IPA 打包走 CI。
- reqwest 固定使用 rustls（而非 OpenSSL），避免 Android/iOS 交叉编译 OpenSSL 的工具链问题。
- 日志隐私红线：任何日志不得包含 API Key；对话内容默认不入日志。
