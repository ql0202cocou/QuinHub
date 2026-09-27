# QuinHub v1 现状盘点与 Backlog（交接总览）

日期：2026-09-23
状态：第一期完成（M1–M5，commits `fc41a6a`..`5a75787`）
阅读对象：接手开发的同事 / AI 代理 / 未来的自己

## 一句话现状

QuinHub 第一期「对话核心」已完成并真机（Android 模拟器）实测通过：多会话双协议流式对话、图片消息、Markdown 高亮、导出分享、主题、中英双语、加密存 Key。Release APK 可构建（debug 签名占位）。

## 仓库地图

- `app/` — Flutter（Riverpod 无 codegen 写法 + go_router + gen-l10n）
- `core/` — Rust workspace（api / storage / crypto / sync / context / bridge 六 crate）
- `doc/` — 文档中心（索引见 [../README.md](../README.md)）
- `mock_sse.py` — 联调用 mock SSE 服务器（用法见 M4 交接笔记）
- `tools/gen_icon.py` — 图标生成器（换设计稿后重跑 + flutter_launcher_icons）

## 未 push

本地 main 领先 origin/main 7 个 commit（`3398f1f` 之后全部）。交接前记得 `git push`。

## Backlog（第一期缺口，按优先级）

### P0 — 功能缺口（方案承诺过）
1. **会话参数编辑 UI**：聊天页加参数入口（temperature / top_p / max_tokens / system_prompt）。
   现状：`conversation.params` JSON 存取、Rust 读取、ContextManager 预算全就绪，只差编辑界面与 `conversation_update_params` 桥接（storage 需加 update params 方法 + UI 弹层）。
2. **会话归档入口**：会话菜单加「归档/取消归档」+ 归档列表查看处。
   现状：`update_conversation_meta(archived)` 桥接已就绪，只缺 UI。
3. **全局默认模型**：设置页加「默认模型」项（settings 表 KV 已就绪），新建会话时优先用它。

### P1 — 真实验收（需要用户资产）
4. 真 Key 各跑 ≥3 轮：OpenAI 兼容 + Anthropic（错误路径已实测，成功路径只过过 mock）。
5. vision 模型图片对话真机验证（mock 已验格式/链路，真模型语义回答未验）。
6. auto_summary 超长对话实测（组装逻辑有单测，真实触发未验）。
7. 流式「停止」按钮真机点测（watch 信号取消，代码审过未点过）。

### P2 — 平台与发布
8. ~~**iOS 构建**~~ ✅ 模拟器链路已打通（2026-09-27，macOS）：`flutter build ios --simulator` 构建 + iPhone 17 模拟器运行通过；Podfile/pod 集成产物与 Info.plist 照片/相机权限描述已补齐，详见 [2026-09-27-macos-setup-notes.md](2026-09-27-macos-setup-notes.md)。剩余：真机签名 / IPA（需开发者账号）、CI build-ios 骨架启用。
9. 正式签名 keystore（用户本人，指引在 release-checklist.md）。
10. 崩溃收集决策（默认不接；接则在隐私政策声明）。

### P3 — 体验提升（非承诺项）
11. LaTeX 渲染（接口已留；gpt_markdown 自带或加 flutter_math_fork）。
12. 消息分页加载（目前全量；千条以上再议）。
13. 消息可选中复制（flutter_markdown selectable 有断言 bug，长按复制整段替代；治本要换库或升级后重试）。
14. 消息分支 UI（parent_id 已留）、图片大图预览、流式时逐消息 tokens 实时显示。

## 新接手者 30 分钟上手路径

1. 读 `doc/README.md` → `plan.md` → `decisions.md`
2. 环境：`doc/agents/2026-09-23-m1-setup-notes.md`（WSL 全组件位置与环境变量）
3. 跑通：`make rust-test && make flutter-test`，模拟器联调看 M4 笔记的 mock 链路
4. 改代码前看 `engineering.md` 红线；历史坑各里程碑笔记里都记着

## 第二期方向（未立项）
云同步服务端（Docker，方向约定在 engineering.md 第 7 节）、助手市场、插件/工具调用、知识库 RAG、语音。接口与字段均已预留。
