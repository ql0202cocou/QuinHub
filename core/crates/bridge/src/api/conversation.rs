//! 会话桥接：CRUD + 模型切换。

use super::lifecycle::storage;
use super::BridgeError;
use anyhow::Context;

fn clean(e: anyhow::Error) -> BridgeError {
    BridgeError(format!("{e:#}"))
}
use quinhub_storage::Conversation;

pub struct ConversationDto {
    pub id: String,
    pub title: String,
    pub profile_id: Option<String>,
    pub model_id: Option<String>,
    pub params: String,
    pub pinned: bool,
    pub archived: bool,
    pub updated_at: i64,
}

fn to_dto(c: Conversation) -> ConversationDto {
    ConversationDto {
        id: c.id,
        title: c.title,
        profile_id: c.profile_id,
        model_id: c.model_id,
        params: c.params,
        pinned: c.pinned,
        archived: c.archived,
        updated_at: c.updated_at,
    }
}

pub async fn conversation_create(
    profile_id: Option<String>,
    model_id: Option<String>,
) -> Result<ConversationDto, BridgeError> {
    let c = storage()
        .map_err(clean)?
        .create_conversation(profile_id.as_deref(), model_id.as_deref())
        .await
        .context("create conversation")
        .map_err(clean)?;
    Ok(to_dto(c))
}

pub async fn conversation_list() -> Result<Vec<ConversationDto>, BridgeError> {
    let rows = storage()
        .map_err(clean)?
        .list_conversations()
        .await
        .context("list conversations")
        .map_err(clean)?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn conversation_archived_list() -> Result<Vec<ConversationDto>, BridgeError> {
    let rows = storage()
        .map_err(clean)?
        .list_archived_conversations()
        .await
        .context("list archived conversations")
        .map_err(clean)?;
    Ok(rows.into_iter().map(to_dto).collect())
}

/// params 必须是 JSON 对象字符串（如 {"temperature":0.7}）；"{}" 表示恢复默认。
pub async fn conversation_update_params(
    id: String,
    params: String,
) -> Result<ConversationDto, BridgeError> {
    let v: serde_json::Value = serde_json::from_str(&params)
        .context("params must be JSON")
        .map_err(clean)?;
    if !v.is_object() {
        return Err(BridgeError("params must be a JSON object".into()));
    }
    let c = storage()
        .map_err(clean)?
        .update_conversation_params(&id, &params)
        .await
        .context("update conversation params")
        .map_err(clean)?;
    Ok(to_dto(c))
}

pub async fn conversation_get(id: String) -> Result<ConversationDto, BridgeError> {
    let c = storage()
        .map_err(clean)?
        .get_conversation(&id)
        .await
        .context("get conversation")
        .map_err(clean)?;
    Ok(to_dto(c))
}

/// title/pinned/archived 传 None 表示不动。
pub async fn conversation_update_meta(
    id: String,
    title: Option<String>,
    pinned: Option<bool>,
    archived: Option<bool>,
) -> Result<ConversationDto, BridgeError> {
    let c = storage()
        .map_err(clean)?
        .update_conversation_meta(&id, title.as_deref(), pinned, archived)
        .await
        .context("update conversation")
        .map_err(clean)?;
    Ok(to_dto(c))
}

pub async fn conversation_set_model(
    id: String,
    profile_id: String,
    model_id: String,
) -> Result<ConversationDto, BridgeError> {
    let c = storage()
        .map_err(clean)?
        .set_conversation_model(&id, &profile_id, &model_id)
        .await
        .context("set model")
        .map_err(clean)?;
    Ok(to_dto(c))
}

pub async fn conversation_delete(id: String) -> Result<(), BridgeError> {
    storage()
        .map_err(clean)?
        .delete_conversation(&id)
        .await
        .context("delete conversation")
        .map_err(clean)
}
