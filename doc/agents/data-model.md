# QuinHub 移动端 — 数据模型 DDL 与索引

版本：v0.1（M2 依据，实现中回写差异）
关联文档：[plan.md](./plan.md)

## 1. 通用约定

- 主键：TEXT，UUID v4。
- 时间：INTEGER，Unix epoch 毫秒。
- 同步字段（每张业务表必备）：`updated_at`、`deleted_at`（NULL = 未删除，软删除墓碑）、`rev`（INTEGER，每次变更 +1）。
- 枚举：TEXT + CHECK 约束。
- JSON 字段：TEXT 存 JSON 字符串，结构见第 3 节。
- 迁移：sqlx migrate，`core/crates/storage/migrations/`，版本号前缀文件名（`0001_init.sql` 起）。
- **图片二进制不进 SQLite**：存 app 文档目录 `files/`，消息 content 里存相对路径引用。

## 2. 建表语句（0001_init.sql 基线）

```sql
CREATE TABLE provider_profile (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('openai_compatible','anthropic')),
  base_url        TEXT NOT NULL,
  encrypted_key   TEXT NOT NULL,              -- AES-GCM 密文，base64
  enabled_models  TEXT NOT NULL DEFAULT '[]', -- JSON: ["model_id", ...]
  is_default      INTEGER NOT NULL DEFAULT 0, -- 布尔 0/1
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  rev             INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE model_info (
  id             TEXT PRIMARY KEY,
  profile_id     TEXT NOT NULL REFERENCES provider_profile(id),
  model_id       TEXT NOT NULL,               -- 服务商侧模型名，如 gpt-4o / claude-sonnet-4-5
  display_name   TEXT NOT NULL,
  capabilities   TEXT NOT NULL DEFAULT '[]',  -- JSON: ["vision","tools"]
  context_window INTEGER,                     -- tokens，未知为 NULL
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER,
  rev            INTEGER NOT NULL DEFAULT 1,
  UNIQUE (profile_id, model_id)
);

CREATE TABLE conversation (
  id           TEXT PRIMARY KEY,
  title        TEXT NOT NULL DEFAULT '',
  assistant_id TEXT REFERENCES assistant(id),  -- 预留
  model_id     TEXT,                           -- NULL = 用默认模型
  params       TEXT NOT NULL DEFAULT '{}',     -- JSON，见第 3 节
  pinned       INTEGER NOT NULL DEFAULT 0,
  archived     INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER,
  rev          INTEGER NOT NULL DEFAULT 1
);

-- 0002_conversation_profile.sql（M4 追加）：
-- ALTER TABLE conversation ADD COLUMN profile_id TEXT REFERENCES provider_profile(id);
-- 会话关联提供商（模型属于哪个 profile 的 Key）；旧行为 NULL。

CREATE TABLE message (
  id              TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversation(id),
  parent_id       TEXT,                        -- 预留：消息分支
  role            TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
  content         TEXT NOT NULL,               -- JSON parts，见第 3 节
  model           TEXT,
  tokens_in       INTEGER,
  tokens_out      INTEGER,
  status          TEXT NOT NULL DEFAULT 'done'
                  CHECK (status IN ('streaming','done','error','cancelled')),
  error           TEXT,                        -- JSON: {"code":"...","message":"..."}
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  rev             INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE assistant (                       -- 本期仅内置默认助手
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  avatar        TEXT,
  system_prompt TEXT NOT NULL DEFAULT '',
  default_model TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  deleted_at    INTEGER,
  rev           INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE settings (                        -- 键值对
  key   TEXT PRIMARY KEY,                      -- theme / language / default_model / ...
  value TEXT NOT NULL                          -- JSON
);
```

## 3. JSON 字段结构

**conversation.params**
```json
{
  "temperature": 0.7,
  "top_p": 1.0,
  "max_tokens": 4096,
  "system_prompt": "...",
  "context_strategy": "auto_summary"
}
```
- `context_strategy`：上下文管理策略（决策四，Agent 化 ContextManager）。`auto_summary` = 接近窗口时滚动摘要；`full` = 全量（超限报错）；后续扩展 `rag` 等。默认 `auto_summary`。

**message.content**（parts 数组）
```json
[
  { "type": "text", "text": "..." },
  { "type": "image", "mime": "image/jpeg", "file": "files/abc123.jpg" }
]
```

**model_info.capabilities**：`["vision", "tools"]`（tools 为预留标记）。

## 4. 索引

```sql
CREATE INDEX idx_message_conv_created ON message(conversation_id, created_at);
CREATE INDEX idx_conversation_list    ON conversation(archived, pinned, updated_at DESC);
CREATE INDEX idx_model_profile        ON model_info(profile_id);
-- 同步拉取（since_rev）用，每张业务表：
CREATE INDEX idx_message_rev       ON message(rev);
CREATE INDEX idx_conversation_rev  ON conversation(rev);
CREATE INDEX idx_provider_rev      ON provider_profile(rev);
CREATE INDEX idx_model_rev         ON model_info(rev);
CREATE INDEX idx_assistant_rev     ON assistant(rev);
```

## 5. 常用查询约定
- 会话列表：`WHERE archived = 0 AND deleted_at IS NULL ORDER BY pinned DESC, updated_at DESC`。
- 消息分页：`WHERE conversation_id = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ? OFFSET ?`（倒序取页，UI 翻转）。
- 软删除一律走 `UPDATE ... SET deleted_at = ?, rev = rev + 1`，不做物理删除（同步需要墓碑）。
