use serde::{Deserialize, Serialize};

/// 归一化错误码，取值与 doc/agents/protocol-mapping.md 第 4 节一致。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    Auth,
    Forbidden,
    NotFound,
    RateLimit,
    Server,
    Network,
    Interrupted,
    Unknown,
}

/// 统一流式事件，两家协议（OpenAI 兼容 / Anthropic）都映射到这一套。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ChatEvent {
    Delta {
        text: String,
    },
    /// 预留：Anthropic thinking / OpenAI 兼容服务的 reasoning_content。
    ReasoningDelta {
        text: String,
    },
    Usage {
        input: u64,
        output: u64,
    },
    Done,
    Error {
        code: ErrorCode,
        message: String,
    },
}
