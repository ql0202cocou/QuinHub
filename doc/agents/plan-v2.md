# QuinHub 第二期方案（云同步 + 助手体系）

日期：2026-09-29（2026-10-03 评审细化）
状态：**已评审细化，待立项** —— 开工前把通过的条目转成 decisions.md 新决策条目
关联文档：[plan.md](./plan.md)（第一期）、[decisions.md](./decisions.md)、[engineering.md](./engineering.md) §7、[data-model.md](./data-model.md)、[pages-and-routing.md](./pages-and-routing.md)

> 第一期已完成（M1–M5 + P0 缺口 + LobeHub 风格 UI）。本文档在 2026-09-29 草案基础上评审细化，三项关键取舍已确认：
> ① 服务端用**独立 git 仓库**（不放 monorepo）；② 助手市场**本期不做**；③ **保持现有导航**，不引入底部 tab。

## 目标

第二期核心就一件事：**云同步**（服务端自部署 + 客户端落地），让多设备可用。助手体系紧随其后。插件、RAG、语音推到第三期及以后。

原则（继承第一期，不变）：
- BYOK 不变：App 直连模型 API；**API Key 不同步**（engineering.md §7），第二台设备重新填 Key，界面上给引导。
- 离线优先：本地 SQLite 永远是真相源，同步是增强；断网可用，恢复后增量合并。
- 服务端单用户自部署：一个 Docker 容器跑全家，不做多租户账号体系。
- **第二期不新增客户端 schema 迁移**：五个同步实体、墓碑/rev 字段、settings KV 第一期已全部预留，M6/M7 均无需 DDL 变更（同步游标等状态存 settings KV）。

## 范围

| 项 | 结论 | 说明 |
|---|---|---|
| **M6 云同步** | 做，本期主线 | 字段（rev/墓碑）与 `SyncBackend` 接口第一期已预留，越晚做回迁成本越高 |
| **M7 助手体系** | 做，M6 之后 | 自定义助手 CRUD + 会话绑定；**助手市场本期不做**（已确认） |
| M8 工具调用 | 仅协议预埋 | 把 OpenAI/Anthropic tools 映射约定写进 protocol-mapping.md，不做实现与 UI |
| 知识库 RAG / 语音 / 助手市场 | 推到第三期 | 依赖助手体系成熟；均单独立项 |

## M6 云同步

### 总体架构

```
设备 A (Flutter+Rust)                设备 B (Flutter+Rust)
  └ core/crates/sync                  └ core/crates/sync
       │ HttpSyncBackend                    │ HttpSyncBackend
       └──────── HTTPS REST ────────┬───────┘
                                    ▼
                        quinhub-server（独立仓库）
                        axum + sqlx(SQLite) + 文件存储
                        Docker 单容器，单用户 Bearer token
```

- 本地 SQLite 是真相源；服务端只做「权威中继」：分配全局游标、裁决冲突、存附件。
- 实体独立同步、无跨实体事务（engineering.md §7）：provider_profile / model_info / assistant / conversation / message 五张。

### 服务端（独立仓库 `quinhub-server`，Rust + SQLite，Docker 单容器）

- 技术：axum + sqlx（SQLite）+ tracing。与 core 同语言同栈，schema 以 data-model.md 为准（独立实现，不依赖 core crate；每张表加 `server_rev` 列）。
- 仓库与 CI：独立 git 仓库，自带 GitHub Actions（cargo test + docker build）；版本与客户端通过协议版本号对齐，不锁 commit。
- 部署：单 Dockerfile（静态 Rust binary + SQLite 数据卷 + 文件存储卷）。`docker run -e SYNC_TOKEN=... -v data:/data -p 8080:8080` 一条命令起。
- TLS：服务端本身只讲 HTTP；生产部署文档推荐前置 Caddy 反代自动签发证书，或直接跑在 Tailscale 内网。

#### API（REST，Bearer token 认证，token 环境变量配置）

| 端点 | 请求 | 响应 |
|---|---|---|
| `POST /v1/sync/push` | `{entity, records[]}` | `{results: [{id, accepted, record}]}` —— 逐条返回裁决后的最终记录 |
| `POST /v1/sync/pull` | `{entity, since_server_rev, limit}` | `{records[], server_rev, has_more}` —— 按 server_rev 增量拉取 |
| `POST /v1/files/{hash}` | 二进制 body | 幂等上传，内容寻址（sha256） |
| `GET /v1/files/{hash}` | — | 下载附件 |
| `GET /v1/health` | — | 连通性检查（设置页「测试连接」用） |

- pull 分页：`limit` 默认 500，`has_more` 为 true 时客户端用返回的 `server_rev` 继续拉。
- 协议版本号 `/v1/`：后续破坏性变更升 v2，客户端按版本协商。

### rev 双轨（关键设计点）

- **本地 rev**：各设备自分配、单调递增，只用于本地变更检测（扫描 `rev > last_pushed_rev`，索引第一期已建）。对服务端不可见。
- **server_rev**：服务端为每次写入分配的全局递增序号，作为 pull 游标。客户端按实体在 settings KV 存 `sync.last_pulled_server_rev.<entity>` 与 `sync.last_pushed_rev.<entity>`。
- push 与 pull 的游标互不混用：push 用本地 rev 扫变更，pull 用 server_rev 拉增量。

### 冲突裁决矩阵（M6a 用单测钉死）

**服务端 push 裁决**（对每条 incoming 记录 R，库中已有记录 L）：

| 情形 | 裁决 |
|---|---|
| L 不存在 | 写入 R，分配 server_rev，accepted |
| R.updated_at > L.updated_at | 写入 R（LWW），accepted |
| R.updated_at < L.updated_at | 拒绝，返回 L（客户端需采纳） |
| updated_at 相等 | 墓碑优先：任一方有 deleted_at 则以删除态为准；否则视为相同，accepted（幂等） |

**客户端应用远端记录**（pull 或 push 被拒时，远端记录 R，本地记录 L）：

| 情形 | 处理 |
|---|---|
| L 不存在 | 插入 R，`rev` 置为当前 `last_pushed_rev`（标记为「已同步」，避免回声推送） |
| R.updated_at > L.updated_at | 覆盖 L（含墓碑），`rev` 置为 `last_pushed_rev`（远端赢，本地未推送变更被裁决掉） |
| R.updated_at < L.updated_at | 忽略；本地变更走正常 push 流程 |
| updated_at 相等 | 墓碑优先；否则忽略 |

- 「远端应用不触发再推送」靠 `rev` 置为已推送水位实现，不引入 dirty 标记列（避免 DDL 变更）。
- 首次全量拉取（新设备）按依赖顺序：provider_profile → model_info → assistant → conversation → message，避免 FK 悬挂；中间失败按实体续拉。

### API Key 不同步的落地

- push provider_profile 时客户端**剔除 `encrypted_key` 字段**（序列化置空字符串），服务端不存任何 Key 材料。
- 拉取到新设备后，该 provider 在 UI 显示「待填 API Key」状态（provider 列表黄点提示），点击进入填 Key 引导；连通性测试前禁用会话里该 provider 的模型选择。

### 客户端实现（core/crates/sync + app）

- `HttpSyncBackend`：实现已有 `SyncBackend` trait；push 改为携带 `Vec<record>` 并消费服务端逐条裁决结果（`SyncBackend::push` 签名需从 `Result<()>` 演进为返回裁决结果，属接口内演进，不影响 no-op 之外的调用方）。
- 变更检测：按实体扫 `WHERE rev > last_pushed_rev`，批量 push；成功后推进水位。
- 触发时机：手动「立即同步」按钮 + App 进入前台自动一次（距上次 > 5 分钟才触发）；**不做实时推送**（WebSocket 第三期再议）。聊天流式进行中不打断，等当前流结束再同步。
- 同步过程 UI：设置页显示「上次同步时间 / 同步中 / 上次失败原因」；失败静默记录，不打断使用。
- 设置页「云同步」分组：服务器地址、token（存 flutter_secure_storage，不入 SQLite）、启用开关、测试连接、手动同步、上次同步时间。
- **新设备引导**：无本地数据且配置了服务器时，会话列表空态页提示「从服务器拉取数据」。

### 附件同步与孤儿清理

- 上传：push message 前扫描 content 里的 `files/` 引用，先 `POST /v1/files/{hash}` 补齐服务端缺失文件（客户端 GET 探测，404 才上传）。
- 下载：pull 到含图片的消息后**按需懒下载**——消息渲染时本地无文件则显示占位图并后台下载重试；同步完成后也对本次涉及文件做一次后台批量预取。
- 孤儿清理：本地文件在没有任何未删除消息引用且超过 7 天后由启动时任务清理；**服务端文件本期不自动清理**（容量小，文档注明可手动清），墓碑只作用于消息记录。

### 里程碑与验收

- **M6a 服务端**：schema + Bearer auth + push/pull + 裁决矩阵单测（样本回放，复用 core 测试手法）+ health 端点。
- **M6b 客户端同步内核**：HttpSyncBackend + 变更检测 + 远端应用矩阵单测 + 双模拟器互测（会话/消息/软删除互相同步、断网写恢复增量同步）。
- **M6c 收尾**：附件同步 + 设置页 UI + 新设备引导 + Key 待填引导 + Dockerfile + 部署文档 + 断网/杀进程恢复回归。

验收标准：
- 双设备互同步：会话新建/改名/置顶/归档/删除、消息流、助手、provider 配置（除 Key）全部一致收敛。
- 断网写 → 恢复后增量同步，无重复无丢失；双设备并发改同一会话按 LWW 收敛且结果可解释。
- 图片消息附件跨设备可见（懒下载占位 → 出图）。
- 新设备从空库一键拉全量；provider 显示「待填 Key」引导。
- 服务端 `docker run` 一条命令可用，部署文档可照做。

## M7 助手体系

范围：自定义助手 CRUD + 会话绑定 + 头像展示。**助手市场本期不做**（已确认，第三期立项）；**不引入底部 tab**，入口沿用现有导航（已确认）。

- **助手管理**：设置页新增「助手」分组 → 助手列表 / 编辑页（名称、头像、system_prompt、默认模型）。内置默认助手不可删除，可改名/改 prompt。
- **头像**：emoji 或内置图标集二选一；本期不做自定义图片上传。
- **会话绑定**：聊天页更多菜单加「绑定助手」；新建会话时可选助手（默认不绑定）。会话列表与聊天页顶栏显示助手头像（替换通用机器人图标）。
- **system prompt 优先级**（定稿）：`conversation.params.system_prompt`（会话级显式设置）> 绑定助手的 `system_prompt` > 空。发送时由 ContextManager 组装；会话只存 `assistant_id`，助手改 prompt 后已绑定会话自然跟随。
- **默认模型**：新建绑定助手的会话时，优先取 `assistant.default_model`，其次全局默认模型。
- **同步**：assistant 表参与 M6 同步（五实体之一），无需额外工作。

### 里程碑与验收

- **M7a 数据与逻辑**：assistant CRUD 存储层 + bridge API + prompt 优先级接入 ContextManager（单测覆盖优先级矩阵）。
- **M7b UI**：助手管理页 + 绑定入口 + 头像展示 + 新建会话选助手。

验收标准：
- 助手增删改查、绑定/解绑会话全流程可用，杀进程恢复。
- prompt 优先级：会话级覆盖助手级，助手修改后已绑定会话生效（未设会话级时）。
- 助手随 M6 同步跨设备一致。

## M8 工具调用（仅协议预埋）

- 在 protocol-mapping.md 增补：OpenAI `tools` / `tool_calls` 与 Anthropic `tool_use` / `tool_result` 的字段映射约定、流式帧差异、错误码归类。
- `model_info.capabilities` 的 `"tools"` 标记语义写进 data-model.md（仅标记能力，本期不消费）。
- 不实现工具执行循环与 UI；等具体场景（网页搜索等）单独立项。

## 明确不做（本期）

助手市场、语音（ASR/TTS）、知识库 RAG、多用户账号、端到端加密同步（HTTPS + 自部署已够，E2EE 单独立项再议）、实时推送（WebSocket）、桌面端、底部 tab 信息架构改版。

## 风险与对策

1. **rev 双轨与回声推送**是最容易写错的地方 → M6a/M6b 先用单测把裁决矩阵与应用矩阵钉死，双模拟器互测覆盖并发写。
2. **附件孤儿文件**累积 → 本地 7 天宽限清理；服务端本期手动清，文档写明。
3. **独立仓库版本漂移** → 协议带 `/v1/` 版本号；客户端设置页「测试连接」校验协议兼容性。
4. **单用户 token 认证较弱** → 定位自部署内网/反代 TLS 场景，文档强调不要把裸 HTTP 端口暴露公网。
5. **助手 prompt 优先级误用**（用户以为改了助手但会话没生效）→ 会话级设置 UI 上标注「覆盖助手默认」。

## 文档回写清单（随实现执行）

- decisions.md：新增决策条目（服务端独立仓库、rev 双轨与裁决规则、附件内容寻址、助手市场本期不做、保持现有导航），不改历史。
- protocol-mapping.md：M8 tools 映射约定。
- data-model.md：settings KV 同步游标键、capabilities `"tools"` 语义。
- pages-and-routing.md：设置页云同步分组、助手管理页、绑定助手入口。
- doc/README.md：状态行与交接文档索引。

## 下一步

本文档立项确认 → 条目转 decisions.md 新决策 → M6a（服务端仓库初始化 + 裁决矩阵单测）开工。
