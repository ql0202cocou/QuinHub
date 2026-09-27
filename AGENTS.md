# AGENTS.md — AI 代理工作指引

本文件是给 AI 编码代理（和新人）的仓库入口。改代码前必读。

## 项目概述

QuinHub：LobeHub 风格移动端 AI 聊天客户端（iOS / Android）。Flutter + Rust（flutter_rust_bridge v2）。BYOK：直连 OpenAI 兼容接口与 Anthropic API。

## 文档

所有文档的索引与阅读指引见 **[doc/README.md](doc/README.md)**。动代码前按索引读对应文档；**凡修改了文档所描述的行为，必须同步更新对应文档。**

存放约定：AGENTS 文档（方案、ADR、协议、工程约定等）与 AGENTS 交接文档（工作日志、进度交接、会话总结、issues、todo-list）放 `doc/agents/`；`doc/` 根目录为文档索引及未来的 QuinHub 应用文档。

## 目录结构

- `app/` — Flutter 工程（包名 com.quinhub.app）；`lib/features/*` 按功能分；`lib/bridge/` 是 frb 生成代码（提交入库，**不要手改**，改 Rust 侧后重跑 codegen）
- `core/` — Rust workspace：`crates/api`（协议）、`crates/storage`（SQLite）、`crates/crypto`、`crates/sync`、`crates/context`（上下文管理）、`crates/bridge`（frb 暴露层）
- `doc/` — 文档中心（索引 + QuinHub 应用文档）
- `doc/agents/` — AGENTS 文档与交接文档

## 常用命令

以下均已在真机/CI 验证（与 Makefile 一致）：

```bash
# Rust
cargo test --workspace          # 单测（含 SSE 样本回放）
cargo fmt --check && cargo clippy --workspace -- -D warnings

# Flutter（先 fvm use；PATH 需含 ~/.local/bin）
fvm flutter analyze && fvm flutter test
fvm flutter gen-l10n            # 改 ARB 后重跑
dart run build_runner build -d  # riverpod/freezed 生成物（不提交）

# 桥接代码（改 Rust bridge 后必须执行并提交生成物）
make frb-codegen

# 环境变量：macOS 已写入 ~/.zshrc（JAVA_HOME / ANDROID_HOME / DEVELOPER_DIR），
# 见 doc/agents/2026-09-27-macos-setup-notes.md
# WSL 旧约定（CARGO_TARGET_DIR / adb 桥接）见 doc/agents/2026-09-23-m1-setup-notes.md
```

## 红线

1. **隐私**：任何日志不得包含 API Key；对话内容默认不入日志。
2. **ADR**：不改 decisions.md 的历史结论；变更新增决策条目并标注替代关系。
3. **提交**：Conventional Commits；提交前过 fmt / clippy / analyze。
4. **生成物**：frb 生成物提交；`*.g.dart` 不提交。
5. **依赖**：新增依赖需在 decisions.md 或 PR 描述里说明理由（见 plan.md 依赖基线）。
