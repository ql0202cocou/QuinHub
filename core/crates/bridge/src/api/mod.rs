pub mod chat;
pub mod conversation;
pub mod echo;
pub mod lifecycle;
pub mod message;
pub mod profile;

/// 桥接错误：Display 只含错误链（无 backtrace 噪音，M5a 降噪）。
#[derive(Debug)]
pub struct BridgeError(pub String);

impl std::fmt::Display for BridgeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for BridgeError {}
