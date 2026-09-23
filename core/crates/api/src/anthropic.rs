//! Anthropic API（/v1/messages、/v1/models）。
//! 字段映射见 doc/agents/protocol-mapping.md 第 3 节。

use crate::http::{build_client, map_http_error, normalize_base_url, send_with_retry};
use crate::{ApiError, ChatEvent, ChatMessage, ChatProvider, ChatRequest, ErrorCode, Role};
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::stream::{self, BoxStream, StreamExt};
use serde_json::{json, Value};

pub const DEFAULT_ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";
pub const ANTHROPIC_VERSION: &str = "2023-06-01";
/// Anthropic 的 max_tokens 必填；会话未设置时的默认值。
pub const DEFAULT_MAX_TOKENS: u32 = 4096;

pub struct AnthropicProvider {
    base_url: String,
    api_key: String,
    client: reqwest::Client,
}

impl AnthropicProvider {
    pub fn new(base_url: &str, api_key: &str) -> Result<Self, ApiError> {
        let base = if base_url.is_empty() {
            DEFAULT_ANTHROPIC_BASE_URL
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

/// 消息 → Anthropic content parts（图片在前，文本在后）。
fn message_parts(m: &ChatMessage) -> Vec<Value> {
    let mut parts: Vec<Value> = m
        .images
        .iter()
        .map(|img| {
            json!({
                "type": "image",
                "source": {"type": "base64", "media_type": img.mime, "data": img.data},
            })
        })
        .collect();
    if !m.content.is_empty() {
        parts.push(json!({"type": "text", "text": m.content}));
    }
    parts
}

/// 消息规范化：滤掉 system（走顶层字段）、合并连续同角色（parts 数组合并）、
/// 确保首条为 user。纯文本消息保持字符串形式。
pub(crate) fn normalize_messages(messages: &[ChatMessage]) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    for m in messages.iter().filter(|m| m.role != Role::System) {
        let role = role_str(m.role);
        let parts = message_parts(m);
        if let Some(last) = out.last_mut() {
            if last["role"] == role {
                let prev = match last["content"].take() {
                    Value::String(s) => vec![json!({"type": "text", "text": s})],
                    Value::Array(a) => a,
                    _ => vec![],
                };
                let mut merged = prev;
                merged.extend(parts);
                *last = json!({"role": role, "content": merged});
                continue;
            }
        }
        let content = if parts.len() == 1 && parts[0]["type"] == "text" {
            json!(parts[0]["text"])
        } else {
            json!(parts)
        };
        out.push(json!({"role": role, "content": content}));
    }
    if out.first().is_some_and(|m| m["role"] != "user") {
        out.insert(0, json!({"role": "user", "content": "…"}));
    }
    out
}

/// 构造 /v1/messages 请求体（system 顶层、max_tokens 必填）。
pub(crate) fn build_request(req: &ChatRequest) -> Value {
    let mut body = json!({
        "model": req.model,
        "max_tokens": req.max_tokens.unwrap_or(DEFAULT_MAX_TOKENS),
        "messages": normalize_messages(&req.messages),
        "stream": true,
    });
    if let Some(sys) = &req.system {
        body["system"] = json!(sys);
    }
    if let Some(t) = req.temperature {
        body["temperature"] = json!(t);
    }
    if let Some(p) = req.top_p {
        body["top_p"] = json!(p);
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

/// Anthropic SSE 事件 → 统一事件。usage 分两段到达，input 先暂存。
#[derive(Default)]
pub(crate) struct AnthropicMapper {
    input_tokens: u64,
}

impl AnthropicMapper {
    pub fn handle(&mut self, event: &str, data: &str) -> Result<Vec<ChatEvent>, ApiError> {
        let parse = |d: &str| -> Result<Value, ApiError> {
            serde_json::from_str(d)
                .map_err(|e| ApiError::new(ErrorCode::Unknown, format!("parse event: {e}")))
        };
        Ok(match event {
            "message_start" => {
                self.input_tokens = parse(data)?
                    .pointer("/message/usage/input_tokens")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                vec![]
            }
            "content_block_delta" => {
                let v = parse(data)?;
                match v.pointer("/delta/type").and_then(|t| t.as_str()) {
                    Some("text_delta") => v
                        .pointer("/delta/text")
                        .and_then(|t| t.as_str())
                        .filter(|s| !s.is_empty())
                        .map(|t| {
                            vec![ChatEvent::Delta {
                                text: t.to_string(),
                            }]
                        })
                        .unwrap_or_default(),
                    Some("thinking_delta") => v
                        .pointer("/delta/thinking")
                        .and_then(|t| t.as_str())
                        .filter(|s| !s.is_empty())
                        .map(|t| {
                            vec![ChatEvent::ReasoningDelta {
                                text: t.to_string(),
                            }]
                        })
                        .unwrap_or_default(),
                    _ => vec![],
                }
            }
            "message_delta" => {
                let output = parse(data)?
                    .pointer("/usage/output_tokens")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                vec![ChatEvent::Usage {
                    input: self.input_tokens,
                    output,
                }]
            }
            "message_stop" => vec![ChatEvent::Done],
            "error" => {
                let v = parse(data)?;
                let err_type = v
                    .pointer("/error/type")
                    .and_then(|t| t.as_str())
                    .unwrap_or_default();
                let message = v
                    .pointer("/error/message")
                    .and_then(|t| t.as_str())
                    .unwrap_or("unknown anthropic error")
                    .to_string();
                let code = match err_type {
                    "overloaded_error" => ErrorCode::Server,
                    "rate_limit_error" => ErrorCode::RateLimit,
                    "authentication_error" => ErrorCode::Auth,
                    "permission_error" => ErrorCode::Forbidden,
                    "not_found_error" => ErrorCode::NotFound,
                    _ => ErrorCode::Unknown,
                };
                vec![ChatEvent::Error { code, message }]
            }
            // ping / content_block_start / content_block_stop / message 等结构标记忽略
            _ => vec![],
        })
    }
}

/// 解析 GET /v1/models 响应。
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

#[async_trait]
impl ChatProvider for AnthropicProvider {
    async fn chat_stream(
        &self,
        req: ChatRequest,
    ) -> Result<BoxStream<'static, ChatEvent>, ApiError> {
        let body = build_request(&req);
        let url = format!("{}/v1/messages", self.base_url);
        let resp = send_with_retry(|| {
            self.client
                .post(&url)
                .header("x-api-key", &self.api_key)
                .header("anthropic-version", ANTHROPIC_VERSION)
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
        let sse = resp.bytes_stream().eventsource();
        let stream = sse
            .scan(AnthropicMapper::default(), |mapper, res| {
                let events = match res {
                    Ok(ev) => match mapper.handle(&ev.event, &ev.data) {
                        Ok(events) => events,
                        Err(e) => vec![ChatEvent::Error {
                            code: e.code,
                            message: e.message,
                        }],
                    },
                    Err(e) => vec![ChatEvent::Error {
                        code: ErrorCode::Interrupted,
                        message: e.to_string(),
                    }],
                };
                std::future::ready(Some(events))
            })
            .flat_map(stream::iter)
            .boxed();
        Ok(stream)
    }

    async fn list_models(&self) -> Result<Vec<String>, ApiError> {
        let resp = self
            .client
            .get(format!("{}/v1/models", self.base_url))
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", ANTHROPIC_VERSION)
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

    fn msg(role: Role, content: &str) -> ChatMessage {
        ChatMessage::text(role, content)
    }

    #[test]
    fn normalize_merges_consecutive_and_filters_system() {
        let messages = vec![
            msg(Role::System, "sys"),
            msg(Role::User, "a"),
            msg(Role::User, "b"),
            msg(Role::Assistant, "c"),
            msg(Role::User, "d"),
        ];
        let out = normalize_messages(&messages);
        assert_eq!(out.len(), 3);
        // 连续同角色合并为 parts 数组
        let merged = out[0]["content"].as_array().unwrap();
        assert_eq!(merged[0]["text"], "a");
        assert_eq!(merged[1]["text"], "b");
        assert_eq!(out[1]["role"], "assistant");
        assert_eq!(out[2]["content"], "d");
    }

    #[test]
    fn normalize_prepends_user_if_first_is_assistant() {
        let out = normalize_messages(&[msg(Role::Assistant, "hi")]);
        assert_eq!(out[0]["role"], "user");
        assert_eq!(out[1]["role"], "assistant");
    }

    #[test]
    fn request_has_system_top_level_and_default_max_tokens() {
        let body = build_request(&ChatRequest {
            model: "claude-sonnet-4-5".into(),
            messages: vec![msg(Role::User, "hi")],
            system: Some("be brief".into()),
            temperature: Some(0.5),
            top_p: None,
            max_tokens: None,
        });
        assert_eq!(body["system"], "be brief");
        assert_eq!(body["max_tokens"], DEFAULT_MAX_TOKENS);
        assert_eq!(body["messages"][0]["role"], "user");
        assert!(body["messages"].get(1).is_none());
    }

    #[test]
    fn maps_full_event_sequence() {
        let mut m = AnthropicMapper::default();
        // message_start：暂存 input tokens
        assert!(m
            .handle(
                "message_start",
                r#"{"type":"message_start","message":{"usage":{"input_tokens":21}}}"#
            )
            .unwrap()
            .is_empty());
        // text delta
        let ev = m
            .handle(
                "content_block_delta",
                r#"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"你好"}}"#,
            )
            .unwrap();
        assert_eq!(
            ev,
            vec![ChatEvent::Delta {
                text: "你好".into()
            }]
        );
        // thinking delta → ReasoningDelta
        let ev = m
            .handle(
                "content_block_delta",
                r#"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"想一想"}}"#,
            )
            .unwrap();
        assert!(matches!(ev.first(), Some(ChatEvent::ReasoningDelta { .. })));
        // message_delta：Usage 合并两段
        let ev = m
            .handle(
                "message_delta",
                r#"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}"#,
            )
            .unwrap();
        assert_eq!(
            ev,
            vec![ChatEvent::Usage {
                input: 21,
                output: 7
            }]
        );
        // message_stop → Done
        assert_eq!(
            m.handle("message_stop", r#"{"type":"message_stop"}"#)
                .unwrap(),
            vec![ChatEvent::Done]
        );
        // ping 忽略
        assert!(m.handle("ping", r#"{"type":"ping"}"#).unwrap().is_empty());
    }

    #[test]
    fn maps_error_event() {
        let mut m = AnthropicMapper::default();
        let ev = m
            .handle(
                "error",
                r#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#,
            )
            .unwrap();
        assert_eq!(
            ev,
            vec![ChatEvent::Error {
                code: ErrorCode::Server,
                message: "Overloaded".into()
            }]
        );
    }

    #[test]
    fn parses_models_response() {
        let body = r#"{"data":[{"type":"model","id":"claude-sonnet-4-5"}],"has_more":false}"#;
        assert_eq!(parse_models(body).unwrap(), vec!["claude-sonnet-4-5"]);
    }

    #[test]
    fn request_with_images_uses_base64_source() {
        let mut m = msg(Role::User, "看图");
        m.images.push(crate::ImageData {
            mime: "image/jpeg".into(),
            data: "AAAA".into(),
        });
        let body = build_request(&ChatRequest {
            model: "claude-sonnet-4-5".into(),
            messages: vec![m],
            ..Default::default()
        });
        let parts = body["messages"][0]["content"].as_array().unwrap();
        assert_eq!(parts[0]["type"], "image");
        assert_eq!(parts[0]["source"]["media_type"], "image/jpeg");
        assert_eq!(parts[0]["source"]["data"], "AAAA");
        assert_eq!(parts[1]["type"], "text");
    }

    #[test]
    fn default_base_url_when_empty() {
        let p = AnthropicProvider::new("", "k").unwrap();
        assert_eq!(p.base_url, DEFAULT_ANTHROPIC_BASE_URL);
    }
}
