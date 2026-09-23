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
