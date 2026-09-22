# QuinHub 移动端 — 第一期方案（对话核心）

日期：2026-09-22
关联文档：[decisions.md](./decisions.md)（技术选型与利弊）

## 目标
做类似 LobeHub 手机版的 AI 聊天应用，iOS + Android 双端。第一期只做「对话」核心；插件、知识库、语音、助手市场等只留架构接口，不开发。本期只做客户端，服务端（账号、云同步）后期单独立项、Docker 部署。

## 架构

### 分层
```
┌───────────────────────────── Dart (Flutter) ─────────────────────────────┐
│  UI 层：页面 / 组件（chat、providers、settings）                            │
│  状态层：Riverpod（按会话 family 拆分，select 细粒度重建）                   │
├────────────────────── flutter_rust_bridge v2 ────────────────────────────┤
│  Stream<ChatEvent> 回推流式 delta；一次性调用走 async Future                 │
├───────────────────────────── Rust core ──────────────────────────────────┤
│  api      ChatProvider trait + openai_compatible / anthropic 实现          │
│           SSE 流式（reqwest + eventsource-stream），统一 ChatEvent 事件模型   │
│  storage  SQLite（sqlx + migrations），全部实体落库                          │
│  crypto   API Key AES-GCM 加解密                                            │
│  sync     SyncBackend trait + no-op 占位实现（后期换 HTTP 实现）              │
└───────────────────────────────────────────────────────────────────────────┘
```
- 密钥材料：主密钥由 flutter_secure_storage 存平台 Keystore/Keychain；密文存 SQLite；Rust 侧加解密。
- 统一事件模型 `ChatEvent`：`Delta(text)` / `Usage(in,out)` / `Done` / `Error(code,msg)`，两家协议都映射到它，UI 只认这一套。
- 取消机制：Dart 侧调 `cancel(chat_id)` → Rust 侧 abort 对应请求任务。

### 目录结构
```
QuinHub/
  app/                  # Flutter 工程
    lib/
      main.dart, router.dart, theme/
      features/chat/          # chat_page, message_list, markdown_view, input_bar
      features/providers/     # provider 配置页
      features/settings/
      state/                  # Riverpod providers / notifiers
      bridge/                 # frb 生成代码
  core/                 # Rust workspace
    crates/api/       # ChatProvider trait + 两家实现 + ChatEvent
    crates/storage/   # sqlx + migrations
    crates/crypto/
    crates/sync/
    crates/bridge/    # frb 暴露层（api.rs）
  doc/agents/           # 决策记录、方案文档（本目录）
```

### 工具链
- Android：Rust NDK 交叉编译（aarch64 / armv7 / x86_64），frb 自动生成 Gradle 集成。
- iOS：xcframework 打包；需要 macOS（本地 Mac 或 CI macOS runner）。
- frb codegen 纳入开发脚本（一条命令重生成桥接代码）。

## 数据模型（同步就绪）
所有实体统一：UUID 主键、`created_at`、`updated_at`、`deleted_at`（软删除墓碑）、`rev`（递增版本号，供同步比对）。

- `ProviderProfile`：id, name, type(openai_compatible | anthropic), base_url, encrypted_key, enabled_models, is_default
- `ModelInfo`：id, profile_id, model_id, display_name, capabilities(vision/tools 标记), context_window
- `Conversation`：id, title, assistant_id(预留), model_id, params(JSON: temperature/top_p/max_tokens/system_prompt), pinned, archived
- `Message`：id, conversation_id, parent_id(预留分支), role, content(JSON parts: text/image), model, tokens_in, tokens_out, status(streaming/done/error/cancelled), error
- `Assistant`：id, name, avatar, system_prompt, default_model —— 本期仅内置默认助手 + 会话级自定义 system prompt，市场后期接
- `Settings`：主题(浅/深/跟随系统)、语言(中/英)、默认模型

## 第一期功能范围
1. **提供商管理**：多个 ProviderProfile 增删改；Key 加密存储；连通性测试（拉取模型列表）。
2. **聊天核心**：
   - SSE 流式输出，可取消；失败重试；重新生成；编辑重发。
   - 多会话：新建/重命名/置顶/归档/删除，本地持久化，杀进程恢复。
   - 会话级模型切换与参数（temperature、top_p、max_tokens、system prompt）。
   - Markdown 渲染：代码高亮 + 一键复制、表格、列表；LaTeX 留接口。
   - Token 用量展示（取响应 usage）。
3. **设置**：主题、语言、默认参数。
4. **同步预留**：`SyncBackend` 接口 + no-op 实现 + 墓碑/版本字段；服务端 API 契约待服务端立项后定。

明确不做（仅留接口/字段）：插件与工具调用、知识库 RAG、语音、绘图、助手市场、账号登录。

## 里程碑
- **M1 脚手架**：Flutter 工程 + Rust workspace + frb 打通；Android（真机/模拟器）跑通一个 echo 流式调用；iOS 构建链路验证（有 Mac 本地验证，否则 CI）。
- **M2 存储与设置**：SQLite schema + 迁移、Key 加密存储链路、Provider 配置页 + 连通性测试。
- **M3 聊天内核**：两家 API 流式打通，统一 ChatEvent，取消/重试/错误处理；Rust 单测覆盖 SSE 解析与协议映射。
- **M4 聊天 UI**：消息列表（虚拟滚动 + 流式增量渲染、select 细粒度重建）、Markdown、输入栏、会话管理页。
- **M5 打磨**：主题/国际化、用量统计、空态错误态、图标启动屏、Release 打包（APK；IPA 视 macOS 条件）。

## 验收标准
- 真机（Android + iOS 至少各一，iOS 可用模拟器兜底）上两家 API 各跑通 ≥3 轮流式对话，滚动流畅。
- 杀进程重进，会话与消息完整恢复。
- 断网、Key 错误、取消、重试路径均有明确 UI 反馈。

## 验证方式
- Rust：SSE 帧解析、Anthropic↔ChatEvent 映射单元测试（录制样本回放）。
- Flutter：chat 页面 widget test（mock 流式源）。
- 手动验收清单按上方验收标准执行。
