# QuinHub 移动端 — 第一期方案（对话核心）

日期：2026-09-22
关联文档：
- [decisions.md](./decisions.md) — 技术选型与利弊
- [protocol-mapping.md](./protocol-mapping.md) — OpenAI / Anthropic 协议映射约定
- [engineering.md](./engineering.md) — 工程与协作约定
- [data-model.md](./data-model.md) — SQLite DDL、索引、JSON schema
- [pages-and-routing.md](./pages-and-routing.md) — 页面清单与路由设计
- [release-checklist.md](./release-checklist.md) — 发布与合规 checklist

> **状态：第一期已完成（2026-09-23，commits 至 `5a75787`）。**
> 当前状态盘点与 backlog 见 [2026-09-23-v1-status-and-backlog.md](./2026-09-23-v1-status-and-backlog.md)；
> 各里程碑交接笔记：`2026-09-23-m1-setup-notes.md` ~ `2026-09-23-m5b-polish-notes.md`。

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
│  context  ContextManager：上下文组装（Agent 化，见 decisions 决策四）         │
└───────────────────────────────────────────────────────────────────────────┘
```
- 密钥材料：主密钥由 flutter_secure_storage 存平台 Keystore/Keychain；密文存 SQLite；Rust 侧加解密。
- 统一事件模型 `ChatEvent` 与错误码归一化详见 [protocol-mapping.md](./protocol-mapping.md)。
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
      bridge/                 # frb 生成代码（提交入库，见 engineering.md）
  core/                 # Rust workspace
    crates/api/       # ChatProvider trait + 两家实现 + ChatEvent
    crates/storage/   # sqlx + migrations
    crates/crypto/
    crates/sync/
    crates/context/   # ContextManager（上下文组装/摘要）
    crates/bridge/    # frb 暴露层（api.rs）
  doc/                  # 文档中心（索引 + QuinHub 应用文档）
  doc/agents/           # AGENTS 文档与交接文档（本目录）
```

### 工具链
- Android：Rust NDK 交叉编译（aarch64 / armv7 / x86_64），frb 自动生成 Gradle 集成。
- iOS：xcframework 打包；需要 macOS（本地 Mac 或 CI macOS runner）。
- frb codegen 纳入开发脚本（一条命令重生成桥接代码）。

## 应用标识与 UI 基调
- 名称：**QuinHub**；包名 / bundle id：**com.quinhub.app**（暂无域名，后续可改）。
- UI 基调：**贴近 LobeHub 手机版风格**（布局与交互对标，先建立熟悉感）；Material 3 组件为底，主题 token 按 LobeHub 风格定制，浅/深色双主题。页面与路由详见 [pages-and-routing.md](./pages-and-routing.md)。

## 环境与版本基线
原则：一律取最新 stable，仓库内锁定（fvm / rust-toolchain.toml / lock 文件），CI 与本地一致。

| 项 | 基线 |
|---|---|
| Flutter | 最新 stable，用 fvm 锁定；要求 Impeller 双端默认开启的版本（3.29+） |
| Rust | 最新 stable，rust-toolchain.toml 锁定；targets：aarch64-linux-android、armv7-linux-androideabi、x86_64-linux-android、aarch64-apple-ios、aarch64-apple-ios-sim |
| flutter_rust_bridge | v2 最新，codegen 命令进 justfile/Makefile |
| Android | minSdk 26（Android 8.0）；compileSdk/targetSdk 最新；JDK 17；Gradle/AGP 8.x；NDK r27+（side-by-side） |
| iOS | deployment target 15.0；Xcode 最新 stable（16+） |

## 依赖基线
原则：只加有明确用途的依赖；版本在 lock 文件锁定；新增依赖需说明理由。

**Rust（core/）**
| 用途 | crate | 备注 |
|---|---|---|
| 异步运行时 | tokio (rt-multi-thread) | |
| HTTP | reqwest (rustls-tls, stream) | **用 rustls，避开 OpenSSL 交叉编译** |
| SSE | eventsource-stream | |
| 序列化 | serde / serde_json | |
| 数据库 | sqlx (sqlite, runtime-tokio-rustls) | migrations 随 crate |
| 加密 | aes-gcm | |
| 错误 | thiserror | |
| 日志 | tracing | |
| 其他 | uuid(v4)、async-trait、futures | |

**Flutter（app/）**
| 用途 | 包 |
|---|---|
| 状态管理 | flutter_riverpod + riverpod_annotation；dev：riverpod_generator、riverpod_lint、build_runner |
| 路由 | go_router |
| 密钥存储 | flutter_secure_storage |
| 图片选择/处理 | image_picker、flutter_image_compress |
| 分享 | share_plus |
| Markdown | 首选 flutter_markdown，M4 spike 定稿（见 decisions.md 决策三） |
| 数据类 | freezed + json_serializable（dev：build_runner） |
| 国际化 | flutter_localizations + gen-l10n（arb，中/英） |
| 其他 | url_launcher、flutter_svg |
| 测试 | flutter_test、mocktail |

## 数据模型（同步就绪）
所有实体统一：UUID 主键、`created_at`、`updated_at`、`deleted_at`（软删除墓碑）、`rev`（递增版本号，供同步比对）。DDL、索引与 JSON schema 详见 [data-model.md](./data-model.md)。

- `ProviderProfile`：id, name, type(openai_compatible | anthropic), base_url, encrypted_key, enabled_models, is_default
- `ModelInfo`：id, profile_id, model_id, display_name, capabilities(vision/tools 标记), context_window
- `Conversation`：id, title, assistant_id(预留), model_id, params(JSON), pinned, archived
- `Message`：id, conversation_id, parent_id(预留分支), role, content(JSON parts: text/image), model, tokens_in, tokens_out, status(streaming/done/error/cancelled), error
- `Assistant`：id, name, avatar, system_prompt, default_model —— 本期仅内置默认助手 + 会话级自定义 system prompt，市场后期接
- `Settings`：主题(浅/深/跟随系统)、语言(中/英)、默认模型

## 第一期功能范围（✅ 已完成 / ⚠️ 缺口见 backlog）
1. **提供商管理**：多个 ProviderProfile 增删改；Key 加密存储；连通性测试（拉取模型列表）。✅
2. **聊天核心**：
   - SSE 流式输出，可取消；失败重试；重新生成；编辑重发。✅
   - 多会话：新建/重命名/置顶/归档/删除，本地持久化，杀进程恢复。✅（归档入口 2026-09-28 补齐：长按菜单归档 + 设置 → 已归档会话页）
   - 会话级模型切换与参数（temperature、top_p、max_tokens、system prompt）。✅（参数弹层 2026-09-28 补齐：聊天页更多菜单 → 会话参数）
   - **图片消息**：拍照/相册选图、压缩、base64 发送（OpenAI `image_url` 与 Anthropic `source` 两种格式适配）；仅对 capabilities 含 vision 的模型开放入口。✅（vision gating 2026-09-28 补齐：Rust 侧 `model_supports_vision` 启发式，非视觉模型禁用图片按钮）
   - Markdown 渲染：代码高亮 + 一键复制、表格、列表；LaTeX 留接口。✅（LaTeX 未做）
   - Token 用量展示（取响应 usage）。✅（消息级 + 会话级统计对话框）
   - **上下文管理（Agent 化）**：历史全量存储不丢弃；ContextManager 负责发送时的上下文组装，默认策略 `auto_summary`（接近模型窗口时自动滚动摘要旧消息）；见 decisions.md 决策四。✅（⚠️ 未用超长真实对话实测触发——backlog 验证项）
3. **导出与分享**：会话导出 Markdown 文件；分享长图（滚动截屏渲染）；均走系统分享面板。✅（长图实为离屏 RepaintBoundary 渲染）
4. **设置**：主题、语言、默认参数。✅（全局默认模型 2026-09-28 补齐：设置页选择器存 settings KV，新建会话优先取用）
5. **同步预留**：`SyncBackend` 接口 + no-op 实现 + 墓碑/版本字段；方向性约定见 [engineering.md](./engineering.md) 同步一节。✅

明确不做（仅留接口/字段）：插件与工具调用、知识库 RAG、语音、绘图、助手市场、账号登录。

## 里程碑
- **M1 脚手架**：Flutter 工程（com.quinhub.app）+ Rust workspace + frb 打通；环境按版本基线锁定；Android（真机/模拟器）跑通一个 echo 流式调用；iOS 构建链路验证（有 Mac 本地验证，否则 CI）。
- **M2 存储与设置**：按 data-model.md 建 schema + 迁移、Key 加密存储链路、Provider 配置页 + 连通性测试。
- **M3 聊天内核**：按 protocol-mapping.md 实现两家 API 流式与错误归一化；ContextManager（auto_summary 策略）；取消/重试；Rust 单测覆盖 SSE 解析、协议映射与上下文组装。
- **M4 聊天 UI**：贴近 LobeHub 风格；消息列表（虚拟滚动 + block 级增量渲染、select 细粒度重建）、Markdown（spike 定稿）、输入栏（含图片消息）、会话管理页。
- **M5 打磨**：导出与分享（Markdown / 长图）、主题/国际化、用量统计、空态错误态、图标启动屏、Release 打包（按 release-checklist.md 逐项落实）。

## 里程碑
- **M1 脚手架** ✅（模拟器 echo 流式实测通过；iOS 链路仅配置就绪，未真机构建）
- **M2 存储与设置** ✅（schema + 迁移、Key 加密、Provider 配置页、杀进程持久化实测）
- **M3 聊天内核** ✅（两家 SSE + 错误归一化 + ContextManager + 取消/重试；25 单测 + 4 mock 集成；真机 401 错误路径实测）
- **M4 聊天 UI** ✅（会话管理、流式渲染、BlockedMarkdown spike 定稿、mock 全链路实测）
- **M5 打磨** ✅（导出分享、主题/i18n、用量、图标启动屏、Release APK 跑通；正式签名待用户 keystore）

## 验收标准（实况）
- ⚠️ 两家 API 各跑通 ≥3 轮流式对话——**mock（OpenAI 协议）全链路 + 真实 OpenAI 401 错误路径已实测；真 Key 成功对话与 Anthropic 真机待用户验收**
- ⚠️ 图片消息在 vision 模型跑通——Android mock 已测格式与链路，真 vision 模型与 iOS 待验
- ⚠️ auto_summary 超长对话触发——单测覆盖组装逻辑，真实长对话未触发过
- ✅ 杀进程重进，会话与消息完整恢复
- ✅ 断网、Key 错误、取消、重试路径均有明确 UI 反馈（取消按钮未真机单测——backlog）
- ⚠️ iOS——未构建（无 macOS），走 CI

## 验证方式
- Rust：SSE 帧解析、Anthropic↔ChatEvent 映射、ContextManager 组装逻辑单元测试（录制样本回放）。
- Flutter：chat 页面 widget test（mock 流式源）。
- 手动验收清单按上方验收标准执行。
