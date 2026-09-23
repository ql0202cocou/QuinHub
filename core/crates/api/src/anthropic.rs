//! Anthropic API（/v1/messages、/v1/models）。
//! 字段映射见 doc/agents/protocol-mapping.md 第 3 节。

use crate::http::{build_client, map_http_error, normalize_base_url};
use crate::{ApiError, ChatEvent, ChatProvider, ChatRequest, ErrorCode};
use async_trait::async_trait;
use futures::stream::BoxStream;

pub const DEFAULT_ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";
pub const ANTHROPIC_VERSION: &str = "2023-06-01";

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

/// 解析 GET /v1/models 响应：{"data": [{"id": "claude-...", "display_name": ...}]}
fn parse_models(body: &str) -> Result<Vec<String>, ApiError> {
    let v: serde_json::Value = serde_json::from_str(body)
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
        _req: ChatRequest,
    ) -> Result<BoxStream<'static, ChatEvent>, ApiError> {
        // M3 实现 SSE 流式对话
        Err(ApiError::new(ErrorCode::Unknown, "chat_stream: M3"))
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

    #[test]
    fn parses_models_response() {
        let body = r#"{"data":[{"type":"model","id":"claude-sonnet-4-5","display_name":"Claude Sonnet 4.5"}],"has_more":false}"#;
        assert_eq!(parse_models(body).unwrap(), vec!["claude-sonnet-4-5"]);
    }

    #[test]
    fn default_base_url_when_empty() {
        let p = AnthropicProvider::new("", "k").unwrap();
        assert_eq!(p.base_url, DEFAULT_ANTHROPIC_BASE_URL);
    }
}
