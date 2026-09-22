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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: Role,
    pub content: String,
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
