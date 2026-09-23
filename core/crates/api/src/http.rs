use crate::{ApiError, ErrorCode};
use std::time::Duration;

/// 超时约定见 protocol-mapping.md 第 5 节：连接 15s。
pub fn build_client() -> Result<reqwest::Client, ApiError> {
    reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(15))
        .timeout(Duration::from_secs(60))
        .build()
        .map_err(|e| ApiError::new(ErrorCode::Unknown, e.to_string()))
}

/// HTTP 状态码 → 归一化错误码（protocol-mapping.md 第 4 节）。
pub fn map_http_error(status: u16, body: &str) -> ApiError {
    let code = match status {
        401 => ErrorCode::Auth,
        403 => ErrorCode::Forbidden,
        404 => ErrorCode::NotFound,
        429 => ErrorCode::RateLimit,
        500..=599 => ErrorCode::Server,
        _ => ErrorCode::Unknown,
    };
    ApiError::new(code, extract_error_message(body))
}

/// 从错误响应体提取 message（OpenAI: {"error":{"message":...}}，Anthropic 同构），
/// 失败则截断原样返回。
fn extract_error_message(body: &str) -> String {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(body) {
        if let Some(msg) = v
            .pointer("/error/message")
            .or_else(|| v.pointer("/message"))
            .and_then(|m| m.as_str())
        {
            return msg.to_string();
        }
    }
    body.chars().take(500).collect()
}

/// base_url 归一化：去尾部斜杠。
pub fn normalize_base_url(base: &str) -> String {
    base.trim_end_matches('/').to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_status_to_error_code() {
        assert_eq!(map_http_error(401, "{}").code, ErrorCode::Auth);
        assert_eq!(map_http_error(429, "{}").code, ErrorCode::RateLimit);
        assert_eq!(map_http_error(503, "{}").code, ErrorCode::Server);
        assert_eq!(map_http_error(418, "{}").code, ErrorCode::Unknown);
    }

    #[test]
    fn extracts_nested_error_message() {
        let body = r#"{"error":{"message":"Incorrect API key","type":"auth"}}"#;
        assert_eq!(map_http_error(401, body).message, "Incorrect API key");
    }

    #[test]
    fn falls_back_to_truncated_body() {
        let err = map_http_error(500, "Internal Server Error");
        assert_eq!(err.message, "Internal Server Error");
    }

    #[test]
    fn normalizes_base_url() {
        assert_eq!(normalize_base_url("https://a.com/v1/"), "https://a.com/v1");
        assert_eq!(normalize_base_url("https://a.com/v1"), "https://a.com/v1");
    }
}
