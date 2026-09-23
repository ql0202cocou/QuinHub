//! 消息桥接：列表查询。

use super::lifecycle::storage;
use anyhow::Context;
use quinhub_storage::Message;

pub struct MessageDto {
    pub id: String,
    pub role: String,
    /// 本期为纯文本（content parts 中的 text）。
    pub content: String,
    pub model: Option<String>,
    pub status: String,
    pub error: Option<String>,
    pub tokens_in: Option<i64>,
    pub tokens_out: Option<i64>,
    pub created_at: i64,
}

fn to_dto(m: Message) -> MessageDto {
    MessageDto {
        id: m.id,
        role: m.role,
        content: m.content,
        model: m.model,
        status: m.status,
        error: m.error,
        tokens_in: m.tokens_in,
        tokens_out: m.tokens_out,
        created_at: m.created_at,
    }
}

pub async fn message_list(conversation_id: String) -> anyhow::Result<Vec<MessageDto>> {
    let rows = storage()?
        .list_messages(&conversation_id)
        .await
        .context("list messages")?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn message_delete(id: String) -> anyhow::Result<()> {
    storage()?
        .delete_message(&id)
        .await
        .context("delete message")
}
