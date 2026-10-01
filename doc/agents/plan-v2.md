# QuinHub 第二期方案（草案）

日期：2026-09-29
状态：**草案，未立项** —— 逐条评审后再拆决策条目进 decisions.md
关联文档：[plan.md](./plan.md)（第一期）、[decisions.md](./decisions.md)、[engineering.md](./engineering.md) §7、[data-model.md](./data-model.md)

> 第一期已完成（M1–M5 + P0 缺口 + LobeHub 风格 UI，至 `ec5cf17`）。本文档只定方向与取舍，不含实现承诺。

## 目标

第二期核心就一件事：**云同步**（服务端自部署 + 客户端落地），让多设备可用。助手体系紧随其后。插件、RAG、语音推到第三期及以后。

原则（继承第一期，不变）：
- BYOK 不变：App 直连模型 API；**API Key 默认不同步**（engineering.md §7），第二台设备重新填 Key，界面上给引导。
- 离线优先：本地 SQLite 永远是真相源，同步是增强；断网可用，恢复后增量合并。
- 服务端单用户自部署：一个 Docker 容器跑全家，不做多租户账号体系。

## 范围取舍（评审重点）

| 候选 | 建议 | 理由 |
|---|---|---|
| **M6 云同步** | 做，本期主线 | 字段（rev/墓碑）与 `SyncBackend` 接口第一期已预留，越晚做回迁成本越高 |
| **M7 助手体系** | 做，M6 之后 | `assistant` 表与 `conversation.assistant_id` 已预留；自定义助手是聊天产品的基本盘 |
| M8 工具调用（function calling） | 仅协议预埋，不做 UI | OpenAI/Anthropic 两家 tools 协议差异不小，先把协议映射写进 protocol-mapping.md，实现等场景明确 |
| 知识库 RAG / 语音 | 推到第三期 | 依赖助手体系成熟；都是大坑，单独立项 |

## M6 云同步设计

### 服务端（新仓库目录 `server/`，Rust + SQLite，Docker 单容器）

- 技术：axum + sqlx（SQLite）。与 core 同语言同栈，schema 思路复用 data-model.md；数据量小，SQLite 文件挂卷即可，备份 = 拷文件。
- API（HTTPS REST，Bearer token；token 用环境变量配置，单用户）：
  - `POST /v1/sync/pull` `{entity, since_rev}` → `{records, server_rev}`
  - `POST /v1/sync/push` `{entity, records[]}` → 每条返回裁决结果
  - `POST /v1/files/{hash}` 附件上传 / `GET /v1/files/{hash}` 下载（图片二进制，内容寻址）
- 实体：provider_profile / conversation / message / assistant / model_info 五张，**独立同步、无跨实体事务**（§7）。
- **rev 权威性**（关键设计点，需评审）：客户端本地 rev 只用于本地变更检测；服务端为每条记录分配全局递增 `server_rev` 作为拉取游标。push 时服务端按 §7 规则裁决（LWW by `updated_at`，相等则墓碑优先），返回最终写入的记录。
- Docker：单 Dockerfile（静态 Rust binary + SQLite 数据卷），`docker run -e SYNC_TOKEN=... -v data:/data` 一条命令起。

### 客户端

- `core/crates/sync`：`HttpSyncBackend` 实现已有 `SyncBackend` trait（push/pull 签名已就位）。
- 本地变更检测：按 rev 扫描各表（索引已有 `idx_*_rev`），维护每实体 `last_pushed_rev` / `last_pulled_rev`（settings 表 KV）。
- 应用远端变更：逐条与本地比 `updated_at` 做 LWW；墓碑写入 `deleted_at`。
- 触发：手动「立即同步」按钮 + 进入前台时自动一次；不做实时推送（WebSocket 推后）。
- UI：设置页加「云同步」分组（服务器地址、token、启用开关、上次同步时间、手动同步）。**新设备引导**：无本地数据时提示「从服务器拉取」。

### 里程碑拆分

- **M6a 服务端**：schema + auth + pull/push + 冲突裁决单测（样本回放，复用 core 测试手法）。
- **M6b 客户端**：HttpSyncBackend + 手动同步 + 双模拟器互测（会话/消息/软删除互相同步）。
- **M6c 收尾**：附件同步 + Dockerfile + 部署文档 + 断网/杀进程恢复回归。

### 验收标准
- 双设备互同步：新建/改名/置顶/归档/删除、消息流，全部一致收敛。
- 断网写 → 恢复后增量同步，无重复无丢失。
- 图片消息附件跨设备可见。
- 服务端 `docker run` 一条命令可用。

## M7 助手体系

- 自定义助手 CRUD：名称/头像/system_prompt/默认模型（`assistant` 表现成）；会话可绑定助手（`assistant_id` 字段已预留，params.system_prompt 与会话级覆盖关系要定优先级）。
- 会话列表/聊天页按助手显示头像（替换现在的通用机器人图标）。
- 助手市场雏形：**内置目录 JSON**（git 仓库维护，App 拉取导入，LobeChat 模式），不做服务端托管。
- 开放问题：是否引入底部 tab（会话 / 助手）？——信息架构变更，届时出交互稿再定。

## M8 工具调用（仅协议预埋）

- 在 protocol-mapping.md 增补 OpenAI `tools` / Anthropic `tool_use` 的映射约定与错误码；`model_info.capabilities` 的 `"tools"` 标记启用。
- 不实现工具执行与 UI，等具体场景（网页搜索等）再立项。

## 明确不做（本期）

语音（ASR/TTS）、知识库 RAG、多用户账号、端到端加密同步（HTTPS + 自部署已够，E2EE 单独立项再议）、桌面端。

## 风险

1. **rev 双轨**（本地 rev vs server_rev）是最容易写错的地方 → M6a 先用单测把裁决矩阵钉死。
2. 附件同步的容量与孤儿文件清理策略（本地删图 → 远端墓碑）需要规则。
3. 助手市场的内容审核不存在（内置目录 = 我们自己维护，可控）。

## 下一步

评审本文档 → 通过的条目转成 decisions.md 决策（新增条目，不改历史）→ M6a 立项开工。
