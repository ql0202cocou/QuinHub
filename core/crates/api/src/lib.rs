//! 聊天 Provider 抽象与统一事件模型。
//! 协议映射约定见 doc/agents/protocol-mapping.md。

mod anthropic;
mod caps;
mod echo;
mod error;
mod event;
mod http;
mod openai;
mod provider;

pub use anthropic::{AnthropicProvider, DEFAULT_ANTHROPIC_BASE_URL};
pub use caps::model_supports_vision;
pub use echo::EchoProvider;
pub use error::ApiError;
pub use event::{ChatEvent, ErrorCode};
pub use openai::{OpenAiCompatibleProvider, DEFAULT_OPENAI_BASE_URL};
pub use provider::{build_provider, ChatMessage, ChatProvider, ChatRequest, ImageData, Role};
