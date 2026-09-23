//! OpenAI 兼容接口（/chat/completions、/models），自定义 base_url 可接 DeepSeek 等。
//! 字段映射见 doc/agents/protocol-mapping.md 第 2 节。

use crate::http::{build_client, map_http_error, normalize_base_url, send_with_retry};
use crate::{ApiError, ChatEvent, ChatProvider, ChatRequest, ErrorCode, Role};
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::stream::{self, BoxStream, StreamExt};
use serde_json::{json, Value};

pub const DEFAULT_OPENAI_BASE_URL: &str = "https://api.openai.com/v1";

pub struct OpenAiCompatibleProvider {
    base_url: String,
    api_key: String,
    client: reqwest::Client,
}

impl OpenAiCompatibleProvider {
    pub fn new(base_url: &str, api_key: &str) -> Result<Self, ApiError> {
        let base = if base_url.is_empty() {
            DEFAULT_OPENAI_BASE_URL
        } else {
            base_url
        };
        Ok(Self {
            base_url: normalize_base_url(base),
            api_key: api_key.to_string(),
            client: build_client()?,
        })
    }
}

/// 构造 /chat/completions 请求体（system 作为首条 system 消息）。
pub(crate) fn build_request(req: &ChatRequest) -> Value {
    let mut messages = Vec::new();
    if let Some(sys) = &req.system {
        messages.push(json!({"role": "system", "content": sys}));
    }
    for m in &req.messages {
        messages.push(json!({
            "role": role_str(m.role),
            "content": m.content,
        }));
    }
    // stream_options.include_usage：否则流式响应不给 token 用量（protocol-mapping.md）
    let mut body = json!({
        "model": req.model,
        "messages": messages,
        "stream": true,
        "stream_options": {"include_usage": true},
    });
    if let Some(t) = req.temperature {
        body["temperature"] = json!(t);
    }
    if let Some(p) = req.top_p {
        body["top_p"] = json!(p);
    }
    if let Some(mt) = req.max_tokens {
        body["max_tokens"] = json!(mt);
    }
    body
}

fn role_str(role: Role) -> &'static str {
    match role {
        Role::System => "system",
        Role::User => "user",
        Role::Assistant => "assistant",
    }
}

/// 单个 SSE data 载荷 → 统一事件（`[DONE]` / delta / reasoning / usage / finish_reason）。
pub(crate) fn map_chunk(data: &str) -> Result<Vec<ChatEvent>, ApiError> {
    let data = data.trim();
    if data == "[DONE]" {
        return Ok(vec![ChatEvent::Done]);
    }
    if data.is_empty() {
        return Ok(vec![]);
    }
    let v: Value = serde_json::from_str(data)
        .map_err(|e| ApiError::new(ErrorCode::Unknown, format!("parse chunk: {e}")))?;
    let mut out = Vec::new();
    if let Some(usage) = v.get("usage").filter(|u| !u.is_null()) {
        out.push(ChatEvent::Usage {
            input: usage["prompt_tokens"].as_u64().unwrap_or(0),
            output: usage["completion_tokens"].as_u64().unwrap_or(0),
        });
    }
    if let Some(choice) = v["choices"].as_array().and_then(|c| c.first()) {
        if let Some(text) = choice
            .pointer("/delta/content")
            .and_then(|c| c.as_str())
            .filter(|s| !s.is_empty())
        {
            out.push(ChatEvent::Delta {
                text: text.to_string(),
            });
        }
        if let Some(text) = choice
            .pointer("/delta/reasoning_content")
            .and_then(|c| c.as_str())
            .filter(|s| !s.is_empty())
        {
            out.push(ChatEvent::ReasoningDelta {
                text: text.to_string(),
            });
        }
        if choice["finish_reason"].is_string() {
            out.push(ChatEvent::Done);
        }
    }
    Ok(out)
}

/// 解析 GET /models 响应：{"data": [{"id": "gpt-4o", ...}]}
fn parse_models(body: &str) -> Result<Vec<String>, ApiError> {
    let v: Value = serde_json::from_str(body)
        .map_err(|e| ApiError::new(ErrorCode::Unknown, format!("parse models: {e}")))?;
    let ids = v["data"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|m| m["id"].as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    Ok(ids)
}

fn to_event_stream(resp: reqwest::Response) -> BoxStream<'static, ChatEvent> {
    let sse = resp.bytes_stream().eventsource();
    sse.flat_map(|res| match res {
        Ok(ev) => match map_chunk(&ev.data) {
            Ok(events) => stream::iter(events),
            Err(e) => stream::iter(vec![ChatEvent::Error {
                code: e.code,
                message: e.message,
            }]),
        },
        Err(e) => stream::iter(vec![ChatEvent::Error {
            code: ErrorCode::Interrupted,
            message: e.to_string(),
        }]),
    })
    .boxed()
}

#[async_trait]
impl ChatProvider for OpenAiCompatibleProvider {
    async fn chat_stream(
        &self,
        req: ChatRequest,
    ) -> Result<BoxStream<'static, ChatEvent>, ApiError> {
        let body = build_request(&req);
        let url = format!("{}/chat/completions", self.base_url);
        let resp = send_with_retry(|| {
            self.client
                .post(&url)
                .bearer_auth(&self.api_key)
                .json(&body)
                .send()
        })
        .await?;
        if !resp.status().is_success() {
            let status = resp.status().as_u16();
            let text = resp
                .text()
                .await
                .map_err(|e| ApiError::new(ErrorCode::Network, e.to_string()))?;
            return Err(map_http_error(status, &text));
        }
        Ok(to_event_stream(resp))
    }

    async fn list_models(&self) -> Result<Vec<String>, ApiError> {
        let resp = self
            .client
            .get(format!("{}/models", self.base_url))
            .bearer_auth(&self.api_key)
            .send()
            .await
            .map_err(|e| {
                ApiError::new(
                    if e.is_connect() || e.is_timeout() {
                        ErrorCode::Network
                    } else {
                        ErrorCode::Unknown
                    },
                    e.to_string(),
                )
            })?;
        let status = resp.status().as_u16();
        let body = resp
            .text()
            .await
            .map_err(|e| ApiError::new(ErrorCode::Network, e.to_string()))?;
        if status != 200 {
            return Err(map_http_error(status, &body));
        }
        parse_models(&body)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ChatMessage;

    fn msg(role: Role, content: &str) -> ChatMessage {
        ChatMessage {
            role,
            content: content.to_string(),
        }
    }

    #[test]
    fn request_puts_system_first_and_passes_params() {
        let body = build_request(&ChatRequest {
            model: "gpt-4o".into(),
            messages: vec![msg(Role::User, "hi")],
            system: Some("be brief".into()),
            temperature: Some(0.7),
            top_p: None,
            max_tokens: Some(1024),
        });
        assert_eq!(body["messages"][0]["role"], "system");
        assert_eq!(body["messages"][0]["content"], "be brief");
        assert_eq!(body["messages"][1]["role"], "user");
        assert_eq!(body["stream_options"]["include_usage"], true);
        assert_eq!(body["max_tokens"], 1024);
        assert!(body.get("top_p").is_none());
    }

    #[test]
    fn parses_models_response() {
        let body = r#"{"object":"list","data":[{"id":"gpt-4o"},{"id":"gpt-4o-mini"}]}"#;
        assert_eq!(parse_models(body).unwrap(), vec!["gpt-4o", "gpt-4o-mini"]);
    }

    #[test]
    fn maps_delta_chunk() {
        let data = r#"{"choices":[{"index":0,"delta":{"content":"你好"},"finish_reason":null}]}"#;
        let events = map_chunk(data).unwrap();
        assert_eq!(
            events,
            vec![ChatEvent::Delta {
                text: "你好".into()
            }]
        );
    }

    #[test]
    fn maps_reasoning_chunk() {
        let data = r#"{"choices":[{"index":0,"delta":{"reasoning_content":"think"},"finish_reason":null}]}"#;
        assert!(matches!(
            map_chunk(data).unwrap().first(),
            Some(ChatEvent::ReasoningDelta { .. })
        ));
    }

    #[test]
    fn maps_finish_reason_to_done() {
        let data = r#"{"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#;
        assert!(matches!(
            map_chunk(data).unwrap().last(),
            Some(ChatEvent::Done)
        ));
    }

    #[test]
    fn maps_usage_frame() {
        // include_usage 开启后的末帧：choices 为空，usage 有值
        let data = r#"{"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":34}}"#;
        assert_eq!(
            map_chunk(data).unwrap(),
            vec![ChatEvent::Usage {
                input: 12,
                output: 34
            }]
        );
    }

    #[test]
    fn maps_done_marker() {
        assert_eq!(map_chunk("[DONE]").unwrap(), vec![ChatEvent::Done]);
    }

    #[test]
    fn skips_role_field_in_delta() {
        // 首帧常只有 role 无 content，不应产生 Delta
        let data = r#"{"choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}"#;
        assert_eq!(map_chunk(data).unwrap(), Vec::<ChatEvent>::new());
    }

    #[test]
    fn default_base_url_when_empty() {
        let p = OpenAiCompatibleProvider::new("", "k").unwrap();
        assert_eq!(p.base_url, DEFAULT_OPENAI_BASE_URL);
    }
}
