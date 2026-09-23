//! 流式对话桥接（DB 驱动）：chat_send / chat_regenerate / chat_edit_resend / chat_cancel。
//! 流程：落库 user 消息 → 读历史 → ContextManager 组装 → Provider 流式 →
//!       delta 推 sink → 终态（done/error/cancelled）落库。
//! 取消：watch 信号 + select!，取消时部分内容和 cancelled 状态正常落库（不用 abort）。

use super::lifecycle::storage;
use crate::frb_generated::StreamSink;
use anyhow::Context;
use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use futures::StreamExt;
use quinhub_api::{
    build_provider, ChatEvent, ChatMessage, ChatProvider, ChatRequest, ImageData, Role,
};
use quinhub_context::{plan_context, ContextPlan};
use quinhub_storage::Storage;
use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex};
use tokio::sync::watch;

/// 传给 Dart 的统一事件（错误码为 snake_case 字符串，见 protocol-mapping.md 第 4 节）。
#[derive(Debug, Clone)]
pub enum ChatEventDto {
    Delta { text: String },
    ReasoningDelta { text: String },
    Usage { input: u64, output: u64 },
    Done,
    Error { code: String, message: String },
}

/// 新消息附带的图片（Dart 侧压缩后传入；file_path 已落盘 files/ 相对路径）。
pub struct ImageInput {
    pub mime: String,
    pub data: String,
    pub file_path: String,
}

static CHAT_CANCELS: LazyLock<Mutex<HashMap<String, watch::Sender<bool>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

type DriveFut = std::pin::Pin<Box<dyn std::future::Future<Output = anyhow::Result<()>> + Send>>;

/// 发送新消息并流式回推（user_text 为 None 时按现有历史重发）。
pub async fn chat_send(
    sink: StreamSink<ChatEventDto>,
    chat_id: String,
    conversation_id: String,
    user_text: Option<String>,
    user_images: Vec<ImageInput>,
) {
    spawn_chat(sink, chat_id, conversation_id, move |st, conv, sink, rx| {
        Box::pin(async move {
            if let Some(text) = user_text {
                let content = build_user_content(&text, &user_images);
                st.insert_message(&conv, "user", &content, None, "done")
                    .await
                    .context("insert user message")?;
                st.touch_conversation(&conv).await.ok();
                auto_title(&st, &conv, &text).await;
            }
            drive_chat(&st, &conv, &sink, rx).await
        })
    })
    .await;
}

/// 重新生成：删除最后一条 assistant 消息后重发。
pub async fn chat_regenerate(
    sink: StreamSink<ChatEventDto>,
    chat_id: String,
    conversation_id: String,
) {
    spawn_chat(sink, chat_id, conversation_id, move |st, conv, sink, rx| {
        Box::pin(async move {
            let msgs = st.list_messages(&conv).await?;
            if let Some(last) = msgs.last() {
                if last.role == "assistant" {
                    st.delete_message(&last.id).await?;
                }
            }
            drive_chat(&st, &conv, &sink, rx).await
        })
    })
    .await;
}

/// 编辑重发：改 user 消息内容，删除其后续，重发。
pub async fn chat_edit_resend(
    sink: StreamSink<ChatEventDto>,
    chat_id: String,
    conversation_id: String,
    message_id: String,
    new_text: String,
) {
    spawn_chat(sink, chat_id, conversation_id, move |st, conv, sink, rx| {
        Box::pin(async move {
            let m = st.get_message(&message_id).await?;
            let (_, parts) = super::message::parse_content(&m.content);
            let content = rebuild_content(&new_text, &parts);
            st.finalize_message(&m.id, &content, "done", None, m.tokens_in, m.tokens_out)
                .await
                .context("update message")?;
            st.delete_messages_after(&conv, &message_id)
                .await
                .context("delete following messages")?;
            drive_chat(&st, &conv, &sink, rx).await
        })
    })
    .await;
}

/// 中止进行中的对话（无此 chat_id 时静默忽略）。
pub fn chat_cancel(chat_id: String) {
    if let Ok(map) = CHAT_CANCELS.lock() {
        if let Some(tx) = map.get(&chat_id) {
            let _ = tx.send(true);
        }
    }
}

async fn spawn_chat(
    sink: StreamSink<ChatEventDto>,
    chat_id: String,
    conversation_id: String,
    f: impl FnOnce(Arc<Storage>, String, StreamSink<ChatEventDto>, watch::Receiver<bool>) -> DriveFut
        + Send
        + 'static,
) {
    let (tx, rx) = watch::channel(false);
    if let Ok(mut map) = CHAT_CANCELS.lock() {
        map.insert(chat_id.clone(), tx);
    }
    tokio::spawn(async move {
        let result = match storage() {
            Ok(st) => f(st, conversation_id, sink.clone(), rx).await,
            Err(e) => Err(e),
        };
        if let Err(e) = result {
            let _ = sink.add(ChatEventDto::Error {
                code: "unknown".to_string(),
                message: format!("{e:#}"),
            });
        }
        if let Ok(mut map) = CHAT_CANCELS.lock() {
            map.remove(&chat_id);
        }
    });
}

/// 首条消息自动生成会话标题（前 20 字符）。
async fn auto_title(st: &Storage, conversation_id: &str, text: &str) {
    if let Ok(c) = st.get_conversation(conversation_id).await {
        if c.title.is_empty() {
            let title: String = text.chars().take(20).collect();
            let _ = st
                .update_conversation_meta(conversation_id, Some(&title), None, None)
                .await;
        }
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

/// 主驱动：组装 → 流式 → 落库；watch 收到取消信号时以 cancelled 终态落库。
async fn drive_chat(
    st: &Storage,
    conversation_id: &str,
    sink: &StreamSink<ChatEventDto>,
    mut cancel_rx: watch::Receiver<bool>,
) -> anyhow::Result<()> {
    let conv = st
        .get_conversation(conversation_id)
        .await
        .context("get conversation")?;
    let profile_id = conv
        .profile_id
        .clone()
        .context("conversation has no provider")?;
    let model = conv.model_id.clone().context("conversation has no model")?;
    let params: serde_json::Value =
        serde_json::from_str(&conv.params).unwrap_or(serde_json::json!({}));

    let profile = st.get_profile(&profile_id).await.context("get profile")?;
    let key = quinhub_crypto::decrypt(&profile.encrypted_key).context("decrypt key")?;
    let provider = build_provider(&profile.provider_type, &profile.base_url, &key)
        .context("build provider")?;

    // 崩溃恢复：历史里残留的 streaming 消息标记为 cancelled，且不进入上下文
    let history = st.list_messages(conversation_id).await?;
    let mut usable: Vec<ChatMessage> = Vec::new();
    for m in &history {
        if m.status == "streaming" {
            let _ = st
                .finalize_message(&m.id, &m.content, "cancelled", None, None, None)
                .await;
            continue;
        }
        if m.status != "done" {
            continue; // error/cancelled 不进上下文
        }
        let role = match m.role.as_str() {
            "assistant" => Role::Assistant,
            "system" => Role::System,
            _ => Role::User,
        };
        let (text, parts) = super::message::parse_content(&m.content);
        let images: Vec<ImageData> = parts.iter().filter_map(|p| read_image(p).ok()).collect();
        usable.push(ChatMessage {
            role,
            content: text,
            images,
        });
    }

    // 上下文组装（决策四 auto_summary）：预算 = window - max_tokens - 10% 缓冲
    let window = params
        .get("context_window")
        .and_then(|v| v.as_u64())
        .map(|v| v as u32)
        .unwrap_or(quinhub_context::DEFAULT_CONTEXT_WINDOW) as u64;
    let max_tokens = params
        .get("max_tokens")
        .and_then(|v| v.as_u64())
        .map(|v| v as u32);
    let reserve = max_tokens.unwrap_or(4096) as u64 + window / 10;
    let budget = window.saturating_sub(reserve);
    let system_prompt = params
        .get("system_prompt")
        .and_then(|v| v.as_str())
        .map(str::to_string);
    let (msgs, system) = match plan_context(&usable, budget) {
        ContextPlan::Full => (usable, system_prompt),
        ContextPlan::NeedsSummary { to_summarize, keep } => {
            let summary = summarize(provider.as_ref(), &model, &to_summarize).await?;
            let (summary_sys, keep) = quinhub_context::merge_with_summary(&summary, keep);
            (keep, combine_system(system_prompt, Some(summary_sys)))
        }
    };

    // assistant 占位（streaming），结束后 finalize
    let placeholder = st
        .insert_message(conversation_id, "assistant", "", Some(&model), "streaming")
        .await
        .context("insert assistant placeholder")?;

    let req = ChatRequest {
        model: model.clone(),
        messages: msgs,
        system,
        temperature: params
            .get("temperature")
            .and_then(|v| v.as_f64())
            .map(|v| v as f32),
        top_p: params
            .get("top_p")
            .and_then(|v| v.as_f64())
            .map(|v| v as f32),
        max_tokens,
    };

    let mut acc = String::new();
    let mut usage: Option<(i64, i64)> = None;
    let mut failed: Option<(String, String)> = None;
    let mut cancelled = false;

    match provider.chat_stream(req).await {
        Ok(mut stream) => loop {
            tokio::select! {
                _ = cancel_rx.changed() => {
                    cancelled = true;
                    break;
                }
                item = stream.next() => {
                    let Some(ev) = item else { break };
                    match &ev {
                        ChatEvent::Delta { text } => acc.push_str(text),
                        ChatEvent::Usage { input, output } => {
                            usage = Some((*input as i64, *output as i64))
                        }
                        ChatEvent::Error { code, message } => {
                            failed = Some((format!("{code:?}").to_lowercase(), message.clone()))
                        }
                        _ => {}
                    }
                    if sink.add(to_dto(ev)).is_err() {
                        cancelled = true; // Dart 侧已断开（页面关闭/取消订阅）
                        break;
                    }
                }
            }
        },
        Err(e) => {
            failed = Some((format!("{:?}", e.code).to_lowercase(), e.message.clone()));
        }
    }

    let (status, error_json) = if cancelled {
        ("cancelled", None)
    } else if let Some((code, message)) = &failed {
        (
            "error",
            Some(serde_json::json!({"code": code, "message": message}).to_string()),
        )
    } else {
        ("done", None)
    };
    st.finalize_message(
        &placeholder.id,
        &acc,
        status,
        error_json.as_deref(),
        usage.map(|u| u.0),
        usage.map(|u| u.1),
    )
    .await
    .context("finalize assistant message")?;
    st.touch_conversation(conversation_id).await.ok();

    if cancelled {
        // 部分内容的 cancelled 状态已落库，以 Done 收尾让 Dart 正常结束监听
        let _ = sink.add(ChatEventDto::Done);
    } else if let Some((code, message)) = &failed {
        let _ = sink.add(ChatEventDto::Error {
            code: code.clone(),
            message: message.clone(),
        });
    } else {
        let _ = sink.add(ChatEventDto::Done);
    }
    Ok(())
}

fn combine_system(user_system: Option<String>, summary_system: Option<String>) -> Option<String> {
    match (user_system, summary_system) {
        (Some(a), Some(b)) => Some(format!("{a}\n\n{b}")),
        (Some(a), None) => Some(a),
        (None, Some(b)) => Some(b),
        (None, None) => None,
    }
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
            ChatEvent::Error { message, .. } => anyhow::bail!("summary failed: {message}"),
            _ => {}
        }
    }
    if out.trim().is_empty() {
        anyhow::bail!("summary returned empty");
    }
    Ok(out)
}

/// 用户消息落库 content：纯文本保持纯文本（向后兼容），带图则 JSON parts。
fn build_user_content(text: &str, images: &[ImageInput]) -> String {
    if images.is_empty() {
        return text.to_string();
    }
    let mut parts = Vec::new();
    if !text.is_empty() {
        parts.push(serde_json::json!({"type": "text", "text": text}));
    }
    for img in images {
        parts.push(serde_json::json!({
            "type": "image",
            "mime": img.mime,
            "file": img.file_path,
        }));
    }
    serde_json::to_string(&parts).unwrap_or_else(|_| text.to_string())
}

/// 编辑重发时重建 content（保留原图片 parts）。
fn rebuild_content(new_text: &str, parts: &[super::message::ImagePart]) -> String {
    if parts.is_empty() {
        return new_text.to_string();
    }
    let mut out = vec![serde_json::json!({"type": "text", "text": new_text})];
    for p in parts {
        out.push(serde_json::json!({"type": "image", "mime": p.mime, "file": p.path}));
    }
    serde_json::to_string(&out).unwrap_or_else(|_| new_text.to_string())
}

/// 历史回放：从 files/ 读图片为 base64。
fn read_image(part: &super::message::ImagePart) -> anyhow::Result<ImageData> {
    let dir = super::lifecycle::app_dir()?;
    let bytes = std::fs::read(format!("{dir}/{}", part.path))?;
    Ok(ImageData {
        mime: part.mime.clone(),
        data: B64.encode(bytes),
    })
}
