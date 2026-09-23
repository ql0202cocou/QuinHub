//! 端到端集成测试：本地 mock SSE 服务器 + 真实 HTTP，回放录制样本。
//! 样本见 tests/fixtures/（protocol-mapping.md 第 5 节约定）。

use futures::StreamExt;
use quinhub_api::{
    AnthropicProvider, ChatEvent, ChatMessage, ChatProvider, ChatRequest, ErrorCode,
    OpenAiCompatibleProvider, Role,
};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

/// 起 HTTP 服务器（accept 循环，支持重试产生的多次连接），返回 base_url。
async fn serve_once(status: &'static str, body: &'static str) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move {
        loop {
            let Ok((mut conn, _)) = listener.accept().await else {
                break;
            };
            tokio::spawn(async move {
                let mut buf = vec![0u8; 8192];
                let mut read = 0;
                // 读完整请求（headers + body），否则服务器侧提前关闭会 RST 丢掉响应
                let header_end = loop {
                    if read >= buf.len() {
                        return;
                    }
                    match conn.read(&mut buf[read..]).await {
                        Ok(0) | Err(_) => return,
                        Ok(n) => {
                            read += n;
                            if let Some(pos) = buf[..read].windows(4).position(|w| w == b"\r\n\r\n")
                            {
                                break pos + 4;
                            }
                        }
                    }
                };
                let headers = String::from_utf8_lossy(&buf[..header_end]);
                let content_length: usize = headers
                    .lines()
                    .find_map(|l| {
                        l.to_ascii_lowercase()
                            .strip_prefix("content-length:")
                            .and_then(|v| v.trim().parse().ok())
                    })
                    .unwrap_or(0);
                while read < header_end + content_length {
                    match conn.read(&mut buf[read..]).await {
                        Ok(0) | Err(_) => break,
                        Ok(n) => read += n,
                    }
                }
                let resp = format!(
                    "{status}\r\ncontent-type: text/event-stream\r\nconnection: close\r\n\r\n{body}"
                );
                let _ = conn.write_all(resp.as_bytes()).await;
                let _ = conn.shutdown().await;
            });
        }
    });
    format!("http://{addr}")
}

fn req() -> ChatRequest {
    ChatRequest {
        model: "test-model".into(),
        messages: vec![ChatMessage {
            role: Role::User,
            content: "hi".into(),
        }],
        ..Default::default()
    }
}

async fn collect(stream: futures::stream::BoxStream<'static, ChatEvent>) -> Vec<ChatEvent> {
    stream.collect().await
}

#[tokio::test]
async fn openai_stream_end_to_end() {
    let base = serve_once(
        "HTTP/1.1 200 OK",
        include_str!("fixtures/openai_stream.sse"),
    )
    .await;
    let provider = OpenAiCompatibleProvider::new(&base, "sk-test").unwrap();
    let events = collect(provider.chat_stream(req()).await.expect("chat_stream ok")).await;

    let text: String = events
        .iter()
        .filter_map(|e| match e {
            ChatEvent::Delta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(text, "你好");
    assert!(events.iter().any(|e| matches!(
        e,
        ChatEvent::Usage {
            input: 5,
            output: 2
        }
    )));
    assert!(matches!(events.last(), Some(ChatEvent::Done)));
}

#[tokio::test]
async fn anthropic_stream_end_to_end() {
    let base = serve_once(
        "HTTP/1.1 200 OK",
        include_str!("fixtures/anthropic_stream.sse"),
    )
    .await;
    let provider = AnthropicProvider::new(&base, "sk-ant-test").unwrap();
    let events = collect(provider.chat_stream(req()).await.expect("chat_stream ok")).await;

    let text: String = events
        .iter()
        .filter_map(|e| match e {
            ChatEvent::Delta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(text, "你好");
    assert!(events.iter().any(|e| matches!(
        e,
        ChatEvent::Usage {
            input: 9,
            output: 2
        }
    )));
    assert!(matches!(events.last(), Some(ChatEvent::Done)));
}

#[tokio::test]
async fn openai_401_maps_to_auth() {
    let base = serve_once(
        "HTTP/1.1 401 Unauthorized",
        r#"{"error":{"message":"Incorrect API key provided"}}"#,
    )
    .await;
    let provider = OpenAiCompatibleProvider::new(&base, "bad-key").unwrap();
    let err = match provider.chat_stream(req()).await {
        Ok(_) => panic!("should fail"),
        Err(e) => e,
    };
    assert_eq!(err.code, ErrorCode::Auth);
    assert!(err.message.contains("Incorrect API key"));
}

#[tokio::test]
async fn anthropic_429_maps_to_rate_limit() {
    let base = serve_once(
        "HTTP/1.1 429 Too Many Requests",
        r#"{"type":"error","error":{"type":"rate_limit_error","message":"Too many requests"}}"#,
    )
    .await;
    let provider = AnthropicProvider::new(&base, "k").unwrap();
    let err = match provider.chat_stream(req()).await {
        Ok(_) => panic!("should fail"),
        Err(e) => e,
    };
    assert_eq!(err.code, ErrorCode::RateLimit);
}
