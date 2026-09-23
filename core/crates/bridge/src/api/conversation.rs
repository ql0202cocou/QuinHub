//! 会话桥接：CRUD + 模型切换。

use super::lifecycle::storage;
use anyhow::Context;
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
) -> anyhow::Result<ConversationDto> {
    let c = storage()?
        .create_conversation(profile_id.as_deref(), model_id.as_deref())
        .await
        .context("create conversation")?;
    Ok(to_dto(c))
}

pub async fn conversation_list() -> anyhow::Result<Vec<ConversationDto>> {
    let rows = storage()?
        .list_conversations()
        .await
        .context("list conversations")?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn conversation_get(id: String) -> anyhow::Result<ConversationDto> {
    let c = storage()?
        .get_conversation(&id)
        .await
        .context("get conversation")?;
    Ok(to_dto(c))
}

/// title/pinned/archived 传 None 表示不动。
pub async fn conversation_update_meta(
    id: String,
    title: Option<String>,
    pinned: Option<bool>,
    archived: Option<bool>,
) -> anyhow::Result<ConversationDto> {
    let c = storage()?
        .update_conversation_meta(&id, title.as_deref(), pinned, archived)
        .await
        .context("update conversation")?;
    Ok(to_dto(c))
}

pub async fn conversation_set_model(
    id: String,
    profile_id: String,
    model_id: String,
) -> anyhow::Result<ConversationDto> {
    let c = storage()?
        .set_conversation_model(&id, &profile_id, &model_id)
        .await
        .context("set model")?;
    Ok(to_dto(c))
}

pub async fn conversation_delete(id: String) -> anyhow::Result<()> {
    storage()?
        .delete_conversation(&id)
        .await
        .context("delete conversation")
}
