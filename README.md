# QuinHub

LobeHub 风格的移动端 AI 聊天客户端（iOS / Android）。BYOK 模式：用户填自己的 API Key，直连 OpenAI 兼容接口与 Anthropic API。

> 当前状态：**设计阶段**（M1 未开工）。所有方案与约定见 `doc/`。

## 文档

所有项目文档的索引见 **[doc/README.md](doc/README.md)**。

## 技术栈

Flutter（UI，Riverpod）+ Rust（核心：网络 / SSE / SQLite / 加密），flutter_rust_bridge v2 桥接。

## 目录结构

```
QuinHub/
  app/          # Flutter 工程（M1 创建）
  core/         # Rust workspace（M1 创建）
  doc/          # 文档中心（索引 + QuinHub 应用文档）
  doc/agents/   # AGENTS 文档与交接文档
```

## 快速开始

环境组件与安装细节（WSL 全量记录，含踩坑）见 `doc/agents/2026-09-23-m1-setup-notes.md`。

```bash
# 环境变量（每个新 shell；Makefile 已内置 JAVA_HOME / CARGO_TARGET_DIR）
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# 测试与静态检查
make rust-test          # cargo test --workspace（13 个套件）
make flutter-test       # flutter analyze + test
make fmt                # cargo fmt + dart format

# 改了 core/crates/bridge/src/api/ 后必须重新生成桥接代码并提交生成物
make frb-codegen

# 构建 / 运行（Android 模拟器 adb 桥接配置见 M1 交接笔记）
make build-android      # debug APK
# 真 Key 联调：App 内 设置 → 模型提供商 → 添加；或 mock 链路见 M4 交接笔记
```

**改代码前必读**：`AGENTS.md`（红线）→ `doc/README.md`（文档索引）。
