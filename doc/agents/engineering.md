# QuinHub 移动端 — 工程与协作约定

版本：v0.1
关联文档：[plan.md](./plan.md)、[decisions.md](./decisions.md)、[protocol-mapping.md](./protocol-mapping.md)

## 1. 仓库
- monorepo：`app/`（Flutter）+ `core/`（Rust workspace）+ `doc/`（文档中心）+ `doc/agents/`（AGENTS 文档与交接文档）。
- 分支：`main` 保持稳定；功能分支 `feature/*`；PR 合并。
- Commit message：Conventional Commits（`feat:` / `fix:` / `chore:` / `docs:` / `refactor:` / `test:`）。

## 2. 版本锁定（本地与 CI 一致）
- Flutter：fvm 锁定（提交 `.fvmrc`）。
- Rust：提交 `rust-toolchain.toml`。
- 依赖：`pubspec.lock`、`Cargo.lock` 均提交入库。

## 3. 代码生成物
- frb 桥接代码（`app/lib/bridge/`）：**提交入库**；CI 重新执行 codegen 并 diff 校验，保证与 Rust 源码一致。
- Riverpod / freezed 生成物（`*.g.dart`）：gitignore，本地 `build_runner` 生成。

## 4. 格式化与静态检查（pre-commit + CI 双门禁）
- Rust：`cargo fmt --check`、`cargo clippy --workspace -- -D warnings`。
- Dart：`dart format --set-exit-if-changed`、`flutter analyze`（启用 riverpod_lint）。

## 5. CI 骨架（GitHub Actions）
| Job | 内容 |
|---|---|
| `rust-test` | `cargo test --workspace`（协议样本回放单测在此跑） |
| `rust-lint` | fmt + clippy |
| `flutter-test` | `flutter analyze` + `flutter test` |
| `build-android` | debug APK（验证 Rust NDK 交叉编译链路） |
| `build-ios` | macOS runner 构建（M5 前打通即可；无本地 Mac 时的 IPA 通道） |

## 6. 日志与错误
- Rust 侧统一 `tracing`；bridge 层把 warn/error 级日志透传到 Dart 侧（后续做调试面板）。
- **隐私红线**：任何日志不得包含 API Key；对话内容默认不入日志（debug 构建可用环境变量开启）。
- Rust 错误用 thiserror 定义（`ApiError` / `StorageError` / `CryptoError`），bridge 层映射为 Dart 异常（`code` + `message`）；`code` 取值见 protocol-mapping.md 第 4 节。

## 7. 同步方向约定（服务端实现前的护栏）
服务端后做，但客户端按以下方向设计，避免返工：
- 实体独立同步，无跨实体事务；`rev` 单调递增（客户端本地分配，服务端裁决冲突）。
- 拉取：增量（`since_rev`）；推送：本地变更队列批量提交。
- 冲突策略：last-write-wins（按 `updated_at`）；`updated_at` 相同则删除（墓碑）优先。
- 认证预留：Bearer token。
- **API Key 默认不同步**，仅存本地设备；如未来需要多设备共享 Key，单独立项决策（涉及端到端加密）。
- 传输：HTTPS REST 起步；WebSocket 实时推送后续可选。

## 8. 文档维护
- `doc/agents/` 下的 AGENTS 文档随实现演进回写：决策变更改 decisions.md（追加新决策，不改历史结论，标注替代关系）；协议实现差异回写 protocol-mapping.md。
- 存放约定见 [../README.md](../README.md)：AGENTS 文档与交接文档放 `doc/agents/`，QuinHub 应用文档放 `doc/`。
