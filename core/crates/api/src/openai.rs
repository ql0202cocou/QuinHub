//! OpenAI 兼容接口（/chat/completions、/models），自定义 base_url 可接 DeepSeek 等。
//! 字段映射见 doc/agents/protocol-mapping.md 第 2 节。

use crate::http::{build_client, map_http_error, normalize_base_url};
use crate::{ApiError, ChatEvent, ChatProvider, ChatRequest, ErrorCode};
use async_trait::async_trait;
use futures::stream::BoxStream;

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

/// 解析 GET /models 响应：{"data": [{"id": "gpt-4o", ...}]}
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
impl ChatProvider for OpenAiCompatibleProvider {
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

    #[test]
    fn parses_models_response() {
        let body = r#"{"object":"list","data":[{"id":"gpt-4o","object":"model"},{"id":"gpt-4o-mini","object":"model"}]}"#;
        assert_eq!(parse_models(body).unwrap(), vec!["gpt-4o", "gpt-4o-mini"]);
    }

    #[test]
    fn parses_empty_models() {
        assert_eq!(
            parse_models(r#"{"data":[]}"#).unwrap(),
            Vec::<String>::new()
        );
    }

    #[test]
    fn default_base_url_when_empty() {
        let p = OpenAiCompatibleProvider::new("", "k").unwrap();
        assert_eq!(p.base_url, DEFAULT_OPENAI_BASE_URL);
    }
}
