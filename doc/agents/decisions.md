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
| 功能范围 | 第一期只做对话核心；插件/知识库/语音/助手市场只留架构接口 |

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

## 其他已确认
- 只做 iOS + Android 客户端，不考虑桌面端。
- 云同步服务端后期单独立项（Docker 部署）；本期客户端仅定义 `SyncBackend` 接口 + no-op 实现 + 同步就绪的数据模型字段。
- iOS 构建需要 macOS：本地 Mac 或 CI macOS runner（GitHub Actions / Codemagic）；无本地 Mac 时开发期先在 Android/模拟器迭代，IPA 打包走 CI。
