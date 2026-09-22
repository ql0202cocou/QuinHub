# QuinHub 移动端 — 协议映射约定（OpenAI 兼容 / Anthropic）

版本：v0.1（骨架，M3 实现时以此为准并回写差异）
关联文档：[plan.md](./plan.md)、[decisions.md](./decisions.md)

## 1. 统一内部模型

```rust
// 请求
ChatRequest {
    model: String,
    messages: Vec<ChatMessage>,   // role: user | assistant
    system: Option<String>,       // 会话级 system prompt
    temperature: Option<f32>,
    top_p: Option<f32>,
    max_tokens: Option<u32>,
    stream: bool,                 // 恒为 true（本期只支持流式）
}

// 事件（两家协议都映射到这一套，UI 只认它）
ChatEvent {
    Delta { text: String },
    ReasoningDelta { text: String },  // 预留：Anthropic thinking / OpenAI o 系 reasoning
    Usage { input: u64, output: u64 },
    Done,
    Error { code: ErrorCode, message: String },
}
```

## 2. OpenAI 兼容接口

- 端点：`POST {base_url}/chat/completions`，默认 base_url `https://api.openai.com/v1`（可自定义，如 DeepSeek、Moonshot、本地 vLLM 等兼容服务）。
- 认证：`Authorization: Bearer <key>`。
- 请求体：
  - `system` 作为 `role: "system"` 消息置于 messages 头部；
  - `stream: true`，且必须带 `stream_options: { "include_usage": true }`（否则流式响应不给 token 用量）；
  - `temperature` / `top_p` / `max_tokens` 有值才透传。
- 响应 SSE：
  - 每帧 `data: {...chunk...}`；`choices[0].delta.content` → `Delta`；
  - `choices[0].delta.reasoning_content`（部分兼容服务）→ `ReasoningDelta`；
  - `choices[0].finish_reason` 非空 → `Done`；
  - `usage` 字段出现在最后一帧 → `Usage`；
  - `data: [DONE]` → 流终止。
- 错误：非 2xx 时直接返回 JSON `{ "error": { "message", "type", "code" } }` → `Error`；SSE 中途断开 → `Error(interrupted)`。

## 3. Anthropic API

- 端点：`POST {base_url}/v1/messages`，默认 base_url `https://api.anthropic.com`。
- 认证：`x-api-key: <key>`；**必须**带请求头 `anthropic-version: 2023-06-01`。
- 请求体：
  - `system` 是独立顶层字段（不在 messages 里）；
  - `max_tokens` **必填**（会话未设置时默认 4096）；
  - `messages` 仅含 user/assistant，且**角色严格交替、首条必须为 user** —— 发送前需规范化（合并连续同角色消息）；
  - `stream: true`；`temperature` / `top_p` 有值才透传。
- 响应 SSE（`event:` + `data:` 双行格式）：
  | SSE 事件 | 映射 |
  |---|---|
  | `message_start` | `message.usage.input_tokens` → `Usage.input` |
  | `content_block_delta`（`text_delta`） | `text_delta.text` → `Delta` |
  | `content_block_delta`（`thinking_delta`） | → `ReasoningDelta`（预留） |
  | `message_delta` | `usage.output_tokens` → `Usage.output`；`delta.stop_reason` → 结束依据 |
  | `message_stop` | `Done` |
  | `ping` | 忽略 |
  | `error` | `Error` |
  | `content_block_start` / `content_block_stop` | 无映射（结构标记） |

## 4. 错误码归一化

| HTTP 状态 / 场景 | ErrorCode | UI 文案方向 |
|---|---|---|
| 401 | `auth` | Key 无效或已过期 |
| 403 | `forbidden` | 无权限（模型未开通 / 地区限制） |
| 404 | `not_found` | 模型名错误或 base_url 配置有误 |
| 429 | `rate_limit` | 触发限流，请稍后重试 |
| 500 / 502 / 503 | `server` | 服务商故障，请稍后重试 |
| 连接失败 / 超时 | `network` | 网络异常，请检查网络或 base_url |
| SSE 中途断开 | `interrupted` | 连接中断，可重试 |
| 其他 | `unknown` | 透传原始 message |

约定：`Error.message` 保留服务商原始错误信息，供调试；UI 按 `code` 显示统一文案 + 可展开原始信息。

## 5. 其他约定
- 超时：连接 15s；流式整体无硬超时，空闲 60s 无数据视为 `interrupted`。
- 重试：仅对 `network` / `interrupted` / `rate_limit` / `server` 自动重试（指数退避，最多 2 次）；`auth` / `forbidden` / `not_found` 不重试。
- 测试：两家各录制 ≥3 个 SSE 样本（正常、含 usage、中途错误），存 `core/crates/api/tests/fixtures/`，单测回放验证映射。
