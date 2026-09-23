use crate::{ApiError, ChatEvent};
use async_trait::async_trait;
use futures::stream::BoxStream;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    System,
    User,
    Assistant,
}

/// 图片内容（base64）。mime 如 image/jpeg。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageData {
    pub mime: String,
    pub data: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: Role,
    pub content: String,
    #[serde(default)]
    pub images: Vec<ImageData>,
}

impl ChatMessage {
    /// 纯文本消息快捷构造。
    pub fn text(role: Role, content: impl Into<String>) -> Self {
        Self {
            role,
            content: content.into(),
            images: vec![],
        }
    }
}

/// 统一聊天请求，序列化为各协议请求体的差异由各 Provider 实现处理。
#[derive(Debug, Clone, Default)]
pub struct ChatRequest {
    pub model: String,
    pub messages: Vec<ChatMessage>,
    pub system: Option<String>,
    pub temperature: Option<f32>,
    pub top_p: Option<f32>,
    pub max_tokens: Option<u32>,
}

#[async_trait]
pub trait ChatProvider: Send + Sync {
    /// 发起流式对话，返回统一事件流。
    async fn chat_stream(
        &self,
        req: ChatRequest,
    ) -> Result<BoxStream<'static, ChatEvent>, ApiError>;

    /// 拉取可用模型列表（连通性测试用）。
    async fn list_models(&self) -> Result<Vec<String>, ApiError>;
}

/// ProviderProfile.type 的合法取值。
pub const TYPE_OPENAI_COMPATIBLE: &str = "openai_compatible";
pub const TYPE_ANTHROPIC: &str = "anthropic";

/// 按 profile 类型构造 Provider。
pub fn build_provider(
    provider_type: &str,
    base_url: &str,
    api_key: &str,
) -> Result<Box<dyn ChatProvider>, ApiError> {
    match provider_type {
        TYPE_OPENAI_COMPATIBLE => Ok(Box::new(crate::OpenAiCompatibleProvider::new(
            base_url, api_key,
        )?)),
        TYPE_ANTHROPIC => Ok(Box::new(crate::AnthropicProvider::new(base_url, api_key)?)),
        other => Err(ApiError::new(
            crate::ErrorCode::Unknown,
            format!("unknown provider type: {other}"),
        )),
    }
}
