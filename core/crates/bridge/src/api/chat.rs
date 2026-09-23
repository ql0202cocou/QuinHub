//! 流式对话桥接：chat_send（StreamSink 回推）+ chat_cancel（按 chat_id 中止）。
//! 取消机制：Dart 调 chat_cancel → abort 对应 tokio 任务 → reqwest 请求被丢弃中断。

use super::lifecycle::storage;
use crate::frb_generated::StreamSink;
use anyhow::Context;
use futures::StreamExt;
use quinhub_api::{build_provider, ChatEvent, ChatMessage, ChatProvider, ChatRequest, Role};
use quinhub_context::{plan_context, ContextPlan};
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

/// 传给 Dart 的统一事件（错误码为 snake_case 字符串，见 protocol-mapping.md 第 4 节）。
#[derive(Debug, Clone)]
pub enum ChatEventDto {
    Delta { text: String },
    ReasoningDelta { text: String },
    Usage { input: u64, output: u64 },
    Done,
    Error { code: String, message: String },
}

pub struct ChatMessageDto {
    pub role: String,
    pub content: String,
}

static CHAT_TASKS: LazyLock<Mutex<HashMap<String, tokio::task::JoinHandle<()>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// 发起流式对话。事件通过 sink 回推；流被 Dart 侧取消时任务随之结束。
#[allow(clippy::too_many_arguments)]
pub async fn chat_send(
    sink: StreamSink<ChatEventDto>,
    chat_id: String,
    profile_id: String,
    model: String,
    messages: Vec<ChatMessageDto>,
    system: Option<String>,
    temperature: Option<f32>,
    top_p: Option<f32>,
    max_tokens: Option<u32>,
    context_window: Option<u32>,
) {
    let handle = tokio::spawn(run_chat(
        chat_id.clone(),
        profile_id,
        model,
        messages,
        system,
        temperature,
        top_p,
        max_tokens,
        context_window,
        sink,
    ));
    if let Ok(mut map) = CHAT_TASKS.lock() {
        map.insert(chat_id, handle);
    }
}

/// 中止进行中的对话（无此 chat_id 时静默忽略）。
pub fn chat_cancel(chat_id: String) {
    if let Ok(mut map) = CHAT_TASKS.lock() {
        if let Some(handle) = map.remove(&chat_id) {
            handle.abort();
        }
    }
}

fn parse_role(role: &str) -> Role {
    match role {
        "assistant" => Role::Assistant,
        "system" => Role::System,
        _ => Role::User,
    }
}

fn to_dto(ev: ChatEvent) -> ChatEventDto {
    match ev {
        ChatEvent::Delta { text } => ChatEventDto::Delta { text },
        ChatEvent::ReasoningDelta { text } => ChatEventDto::ReasoningDelta { text },
        ChatEvent::Usage { input, output } => ChatEventDto::Usage { input, output },
        ChatEvent::Done => ChatEventDto::Done,
        ChatEvent::Error { code, message } => ChatEventDto::Error {
            code: serde_json::to_string(&code)
                .unwrap_or_else(|_| "\"unknown\"".into())
                .trim_matches('"')
                .to_string(),
            message,
        },
    }
}

/// 摘要后注入的 system 文本与用户的 system prompt 合并。
fn combine_system(user_system: Option<String>, summary_system: Option<String>) -> Option<String> {
    match (user_system, summary_system) {
        (Some(a), Some(b)) => Some(format!("{a}\n\n{b}")),
        (Some(a), None) => Some(a),
        (None, Some(b)) => Some(b),
        (None, None) => None,
    }
}

#[allow(clippy::too_many_arguments)]
async fn run_chat(
    chat_id: String,
    profile_id: String,
    model: String,
    messages: Vec<ChatMessageDto>,
    system: Option<String>,
    temperature: Option<f32>,
    top_p: Option<f32>,
    max_tokens: Option<u32>,
    context_window: Option<u32>,
    sink: StreamSink<ChatEventDto>,
) {
    let result = run_chat_inner(
        &profile_id,
        &model,
        messages,
        system,
        temperature,
        top_p,
        max_tokens,
        context_window,
        &sink,
    )
    .await;
    if let Err(e) = result {
        let _ = sink.add(ChatEventDto::Error {
            code: "unknown".to_string(),
            message: format!("{e:#}"),
        });
    }
    if let Ok(mut map) = CHAT_TASKS.lock() {
        map.remove(&chat_id);
    }
}

#[allow(clippy::too_many_arguments)]
async fn run_chat_inner(
    profile_id: &str,
    model: &str,
    messages: Vec<ChatMessageDto>,
    system: Option<String>,
    temperature: Option<f32>,
    top_p: Option<f32>,
    max_tokens: Option<u32>,
    context_window: Option<u32>,
    sink: &StreamSink<ChatEventDto>,
) -> anyhow::Result<()> {
    let p = storage()?
        .get_profile(profile_id)
        .await
        .context("get profile")?;
    let key = quinhub_crypto::decrypt(&p.encrypted_key).context("decrypt key")?;
    let provider = build_provider(&p.provider_type, &p.base_url, &key).context("build provider")?;

    let msgs: Vec<ChatMessage> = messages
        .into_iter()
        .map(|m| ChatMessage {
            role: parse_role(&m.role),
            content: m.content,
        })
        .collect();

    // 上下文组装（决策四 auto_summary）：预算 = window - max_tokens - 10% 缓冲
    let window = context_window.unwrap_or(quinhub_context::DEFAULT_CONTEXT_WINDOW) as u64;
    let reserve = max_tokens.unwrap_or(4096) as u64 + window / 10;
    let budget = window.saturating_sub(reserve);
    let (msgs, system) = match plan_context(&msgs, budget) {
        ContextPlan::Full => (msgs, system),
        ContextPlan::NeedsSummary { to_summarize, keep } => {
            let summary = summarize(provider.as_ref(), model, &to_summarize).await?;
            let (summary_sys, keep) = quinhub_context::merge_with_summary(&summary, keep);
            (keep, combine_system(system, Some(summary_sys)))
        }
    };

    let req = ChatRequest {
        model: model.to_string(),
        messages: msgs,
        system,
        temperature,
        top_p,
        max_tokens,
    };
    let mut stream = provider
        .chat_stream(req)
        .await
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    while let Some(ev) = stream.next().await {
        if sink.add(to_dto(ev)).is_err() {
            break; // Dart 侧已断开（页面关闭/取消订阅）
        }
    }
    Ok(())
}

/// 滚动摘要：复用当前 Provider/模型，收集完整摘要文本。
async fn summarize(
    provider: &dyn ChatProvider,
    model: &str,
    older: &[ChatMessage],
) -> anyhow::Result<String> {
    let req = ChatRequest {
        model: model.to_string(),
        messages: vec![quinhub_context::summary_prompt(older)],
        ..Default::default()
    };
    let mut stream = provider
        .chat_stream(req)
        .await
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    let mut out = String::new();
    while let Some(ev) = stream.next().await {
        match ev {
            ChatEvent::Delta { text } => out.push_str(&text),
            ChatEvent::Error { message, .. } => {
                anyhow::bail!("summary failed: {message}")
            }
            _ => {}
        }
    }
    if out.trim().is_empty() {
        anyhow::bail!("summary returned empty");
    }
    Ok(out)
}
