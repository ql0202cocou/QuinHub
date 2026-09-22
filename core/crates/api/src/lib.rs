//! 聊天 Provider 抽象与统一事件模型。
//! 协议映射约定见 doc/agents/protocol-mapping.md。

mod echo;
mod error;
mod event;
mod provider;

pub use echo::EchoProvider;
pub use error::ApiError;
pub use event::{ChatEvent, ErrorCode};
pub use provider::{ChatMessage, ChatProvider, ChatRequest, Role};
