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

待 M1 脚手架完成后补充（Flutter fvm 版本、Rust toolchain、frb codegen、运行命令）。
