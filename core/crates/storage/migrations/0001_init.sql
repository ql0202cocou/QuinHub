-- 0001_init.sql — 基线 schema，对应 doc/agents/data-model.md
-- 通用约定：TEXT UUID 主键；时间 INTEGER epoch 毫秒；deleted_at 软删除墓碑；rev 递增。

CREATE TABLE provider_profile (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('openai_compatible','anthropic')),
  base_url        TEXT NOT NULL,
  encrypted_key   TEXT NOT NULL,
  enabled_models  TEXT NOT NULL DEFAULT '[]',
  is_default      INTEGER NOT NULL DEFAULT 0,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  rev             INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE model_info (
  id             TEXT PRIMARY KEY,
  profile_id     TEXT NOT NULL REFERENCES provider_profile(id),
  model_id       TEXT NOT NULL,
  display_name   TEXT NOT NULL,
  capabilities   TEXT NOT NULL DEFAULT '[]',
  context_window INTEGER,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER,
  rev            INTEGER NOT NULL DEFAULT 1,
  UNIQUE (profile_id, model_id)
);

CREATE TABLE assistant (
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

CREATE TABLE conversation (
  id           TEXT PRIMARY KEY,
  title        TEXT NOT NULL DEFAULT '',
  assistant_id TEXT REFERENCES assistant(id),
  model_id     TEXT,
  params       TEXT NOT NULL DEFAULT '{}',
  pinned       INTEGER NOT NULL DEFAULT 0,
  archived     INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER,
  rev          INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE message (
  id              TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversation(id),
  parent_id       TEXT,
  role            TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
  content         TEXT NOT NULL,
  model           TEXT,
  tokens_in       INTEGER,
  tokens_out      INTEGER,
  status          TEXT NOT NULL DEFAULT 'done'
                  CHECK (status IN ('streaming','done','error','cancelled')),
  error           TEXT,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  rev             INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX idx_message_conv_created ON message(conversation_id, created_at);
CREATE INDEX idx_conversation_list    ON conversation(archived, pinned, updated_at DESC);
CREATE INDEX idx_model_profile        ON model_info(profile_id);
CREATE INDEX idx_message_rev          ON message(rev);
CREATE INDEX idx_conversation_rev     ON conversation(rev);
CREATE INDEX idx_provider_rev         ON provider_profile(rev);
CREATE INDEX idx_model_rev            ON model_info(rev);
CREATE INDEX idx_assistant_rev        ON assistant(rev);
