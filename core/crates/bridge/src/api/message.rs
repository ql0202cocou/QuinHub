//! 消息桥接：列表查询。content 为 JSON parts（text/image），DTO 拆成 text + images。

use super::lifecycle::storage;
use super::BridgeError;
use anyhow::Context;

fn clean(e: anyhow::Error) -> BridgeError {
    BridgeError(format!("{e:#}"))
}
use quinhub_storage::Message;

/// content JSON 中的图片部分。
pub struct ImagePart {
    pub path: String,
    pub mime: String,
}

pub struct MessageDto {
    pub id: String,
    pub role: String,
    /// 文本部分（多段 text 以空行拼接）。
    pub text: String,
    /// 图片相对路径（app_dir/files/...）。
    pub images: Vec<String>,
    pub model: Option<String>,
    pub status: String,
    pub error: Option<String>,
    pub tokens_in: Option<i64>,
    pub tokens_out: Option<i64>,
    pub created_at: i64,
}

/// 解析 content JSON parts；旧数据为纯文本时原样返回（向后兼容）。
pub(crate) fn parse_content(content: &str) -> (String, Vec<ImagePart>) {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(content) else {
        return (content.to_string(), vec![]);
    };
    let Some(parts) = v.as_array() else {
        return (content.to_string(), vec![]);
    };
    let mut texts = Vec::new();
    let mut images = Vec::new();
    for p in parts {
        match p["type"].as_str() {
            Some("text") => {
                if let Some(t) = p["text"].as_str() {
                    texts.push(t);
                }
            }
            Some("image") => {
                if let Some(f) = p["file"].as_str() {
                    images.push(ImagePart {
                        path: f.to_string(),
                        mime: p["mime"].as_str().unwrap_or("image/jpeg").to_string(),
                    });
                }
            }
            _ => {}
        }
    }
    (texts.join("\n\n"), images)
}

fn to_dto(m: Message) -> MessageDto {
    let (text, images) = parse_content(&m.content);
    let images = images.into_iter().map(|i| i.path).collect();
    MessageDto {
        id: m.id,
        role: m.role,
        text,
        images,
        model: m.model,
        status: m.status,
        error: m.error,
        tokens_in: m.tokens_in,
        tokens_out: m.tokens_out,
        created_at: m.created_at,
    }
}

pub async fn message_list(conversation_id: String) -> Result<Vec<MessageDto>, BridgeError> {
    let rows = storage()
        .map_err(clean)?
        .list_messages(&conversation_id)
        .await
        .context("list messages")
        .map_err(clean)?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn message_delete(id: String) -> Result<(), BridgeError> {
    storage()
        .map_err(clean)?
        .delete_message(&id)
        .await
        .context("delete message")
        .map_err(clean)
}
