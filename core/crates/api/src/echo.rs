use crate::{ApiError, ChatEvent, ChatProvider, ChatRequest};
use async_trait::async_trait;
use futures::stream::{self, BoxStream, StreamExt};
use std::time::Duration;

/// M1 脚手架用：不回上游，把最后一条用户消息逐字符回显。
pub struct EchoProvider;

#[async_trait]
impl ChatProvider for EchoProvider {
    async fn chat_stream(
        &self,
        req: ChatRequest,
    ) -> Result<BoxStream<'static, ChatEvent>, ApiError> {
        let text = req
            .messages
            .last()
            .map(|m| m.content.clone())
            .unwrap_or_default();
        let deltas: Vec<ChatEvent> = text
            .chars()
            .map(|c| ChatEvent::Delta {
                text: c.to_string(),
            })
            .collect();
        let stream = stream::iter(deltas)
            .then(|ev| async {
                tokio::time::sleep(Duration::from_millis(20)).await;
                ev
            })
            .chain(stream::iter(vec![
                ChatEvent::Usage {
                    input: text.chars().count() as u64,
                    output: text.chars().count() as u64,
                },
                ChatEvent::Done,
            ]));
        Ok(stream.boxed())
    }

    async fn list_models(&self) -> Result<Vec<String>, ApiError> {
        Ok(vec!["echo".to_string()])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{ChatMessage, Role};

    #[tokio::test]
    async fn echo_stream_echoes_last_message() {
        let provider = EchoProvider;
        let req = ChatRequest {
            model: "echo".into(),
            messages: vec![ChatMessage::text(Role::User, "你好")],
            ..Default::default()
        };
        let events: Vec<ChatEvent> = provider.chat_stream(req).await.unwrap().collect().await;

        let text: String = events
            .iter()
            .filter_map(|e| match e {
                ChatEvent::Delta { text } => Some(text.as_str()),
                _ => None,
            })
            .collect();
        assert_eq!(text, "你好");
        assert!(matches!(
            events.iter().find(|e| matches!(e, ChatEvent::Usage { .. })),
            Some(ChatEvent::Usage {
                input: 2,
                output: 2
            })
        ));
        assert!(matches!(events.last(), Some(ChatEvent::Done)));
    }
}
