use crate::frb_generated::StreamSink;
use futures::StreamExt;
use quinhub_api::{ChatEvent, ChatMessage, ChatProvider, ChatRequest, EchoProvider, Role};

/// M1 脚手架验证：把输入经 Rust 核心（EchoProvider）流式回显给 Dart。
pub async fn echo_stream(sink: StreamSink<String>, input: String) {
    let req = ChatRequest {
        model: "echo".into(),
        messages: vec![ChatMessage::text(Role::User, input)],
        ..Default::default()
    };
    match EchoProvider.chat_stream(req).await {
        Ok(mut stream) => {
            while let Some(ev) = stream.next().await {
                let line = match ev {
                    ChatEvent::Delta { text } | ChatEvent::ReasoningDelta { text } => text,
                    ChatEvent::Usage { input, output } => {
                        format!("[usage in={input} out={output}]")
                    }
                    ChatEvent::Done => "[done]".to_string(),
                    ChatEvent::Error { code, message } => format!("[error {code:?}] {message}"),
                };
                if sink.add(line).is_err() {
                    break;
                }
            }
        }
        Err(e) => {
            let _ = sink.add(format!("[error] {e}"));
        }
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    // anyhow 的 backtrace 捕获由 RUST_BACKTRACE 控制；关掉避免错误透传到 Dart 带噪音
    unsafe { std::env::set_var("RUST_BACKTRACE", "0") };
}
