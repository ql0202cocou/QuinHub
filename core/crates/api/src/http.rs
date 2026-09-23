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

/// 请求建立阶段的重试（指数退避，最多 2 次）。
/// 仅 network/interrupted/rate_limit/server 可重试，见 protocol-mapping.md 第 5 节。
/// 注意：一旦开始流式接收（本函数返回 Ok 后）不再重试，避免重复内容。
pub async fn send_with_retry<F, Fut>(mut send: F) -> Result<reqwest::Response, ApiError>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<reqwest::Response, reqwest::Error>>,
{
    const MAX_RETRY: u32 = 2;
    let mut attempt = 0u32;
    let mut delay = Duration::from_millis(500);
    loop {
        match send().await {
            Ok(resp) => {
                let status = resp.status().as_u16();
                // 响应层面的 429/5xx 尚未进入流式，可以安全重试
                if attempt < MAX_RETRY && matches!(status, 429 | 500..=599) {
                    tokio::time::sleep(delay).await;
                    attempt += 1;
                    delay *= 2;
                    continue;
                }
                return Ok(resp);
            }
            Err(e) => {
                let retryable = e.is_connect() || e.is_timeout();
                if attempt < MAX_RETRY && retryable {
                    tokio::time::sleep(delay).await;
                    attempt += 1;
                    delay *= 2;
                    continue;
                }
                let code = if e.is_connect() || e.is_timeout() {
                    ErrorCode::Network
                } else {
                    ErrorCode::Unknown
                };
                return Err(ApiError::new(code, e.to_string()));
            }
        }
    }
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
