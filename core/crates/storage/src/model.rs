use sqlx::FromRow;

/// ProviderProfile 记录。字段与 provider_profile 表一一对应（data-model.md）。
#[derive(Debug, Clone, FromRow)]
pub struct ProviderProfile {
    pub id: String,
    pub name: String,
    #[sqlx(rename = "type")]
    pub provider_type: String,
    pub base_url: String,
    pub encrypted_key: String,
    /// JSON array: ["model_id", ...]
    pub enabled_models: String,
    pub is_default: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted_at: Option<i64>,
    pub rev: i64,
}

/// 新建/更新入参（bridge 层传入，key 已是密文）。
#[derive(Debug, Clone)]
pub struct NewProfile {
    pub name: String,
    pub provider_type: String,
    pub base_url: String,
    pub encrypted_key: String,
    pub is_default: bool,
}

#[derive(Debug, Clone, FromRow)]
pub struct Conversation {
    pub id: String,
    pub title: String,
    pub assistant_id: Option<String>,
    /// 关联的提供商（0002 迁移加入，旧行为 NULL）。
    pub profile_id: Option<String>,
    /// 模型名（如 gpt-4o / claude-sonnet-4-5）。
    pub model_id: Option<String>,
    /// JSON：temperature/top_p/max_tokens/system_prompt/context_strategy。
    pub params: String,
    pub pinned: bool,
    pub archived: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted_at: Option<i64>,
    pub rev: i64,
}

#[derive(Debug, Clone, FromRow)]
pub struct Message {
    pub id: String,
    pub conversation_id: String,
    pub parent_id: Option<String>,
    pub role: String,
    /// JSON parts（本期纯文本：[{"type":"text","text":...}]）。
    pub content: String,
    pub model: Option<String>,
    pub tokens_in: Option<i64>,
    pub tokens_out: Option<i64>,
    pub status: String,
    pub error: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted_at: Option<i64>,
    pub rev: i64,
}
