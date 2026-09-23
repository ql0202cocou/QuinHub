//! 上下文管理（Agent 化 ContextManager）：发送前的上下文组装。
//! 策略见 doc/agents/decisions.md 决策四：全量存储不丢弃，组装策略可插拔，
//! 默认 auto_summary（接近窗口时滚动摘要旧消息）。

use quinhub_api::{ChatMessage, Role};

/// 模型 context_window 未知时的默认窗口。
pub const DEFAULT_CONTEXT_WINDOW: u32 = 32_000;

/// 粗略 token 估算（决策四：字符近似）：ASCII ≈4 字符/token，CJK 等非 ASCII ≈1 字符/token。
pub fn estimate_tokens(text: &str) -> u64 {
    let mut ascii = 0u64;
    let mut other = 0u64;
    for c in text.chars() {
        if c.is_ascii() {
            ascii += 1;
        } else {
            other += 1;
        }
    }
    ascii / 4 + other
}

/// 估算一组消息的 token（每消息含 4 token 结构开销）。
pub fn estimate_messages(messages: &[ChatMessage]) -> u64 {
    messages
        .iter()
        .map(|m| estimate_tokens(&m.content) + 4)
        .sum()
}

pub enum ContextPlan {
    /// 全部放得下，原样发送。
    Full,
    /// 超预算：to_summarize 需要摘要压缩，keep 原样保留。
    NeedsSummary {
        to_summarize: Vec<ChatMessage>,
        keep: Vec<ChatMessage>,
    },
}

/// 组装计划：从最新往前装，预算外旧消息进摘要。
/// 预算由调用方给出（window - reserve）。单条即超预算时放全量（交给服务商报错）。
pub fn plan_context(messages: &[ChatMessage], budget: u64) -> ContextPlan {
    if estimate_messages(messages) <= budget {
        return ContextPlan::Full;
    }
    let mut keep: Vec<ChatMessage> = Vec::new();
    let mut used = 0u64;
    for m in messages.iter().rev() {
        let t = estimate_tokens(&m.content) + 4;
        if used + t > budget && !keep.is_empty() {
            break;
        }
        used += t;
        keep.push(m.clone());
    }
    keep.reverse();
    let cut = messages.len() - keep.len();
    if cut == 0 {
        return ContextPlan::Full;
    }
    ContextPlan::NeedsSummary {
        to_summarize: messages[..cut].to_vec(),
        keep,
    }
}

/// 摘要请求：把旧消息压缩为上下文摘要（复用当前会话 Provider/模型，费用用户自担）。
pub fn summary_prompt(older: &[ChatMessage]) -> ChatMessage {
    let mut transcript = String::new();
    for m in older {
        let label = match m.role {
            Role::User => "用户",
            Role::Assistant => "助手",
            Role::System => "系统",
        };
        transcript.push_str(&format!("{label}：{}\n\n", m.content));
    }
    ChatMessage::text(
        Role::User,
        format!(
            "请将以下对话历史压缩为一份简洁的上下文摘要，保留关键事实、用户偏好、已做出的决定与未完成的任务，供后续对话使用：\n\n{transcript}"
        ),
    )
}

/// 摘要落地：返回（注入的 system 文本, 保留的最近消息）。
pub fn merge_with_summary(summary: &str, keep: Vec<ChatMessage>) -> (String, Vec<ChatMessage>) {
    (format!("以下是本会话早前内容的摘要：\n{summary}"), keep)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn msg(role: Role, content: &str) -> ChatMessage {
        ChatMessage::text(role, content)
    }

    #[test]
    fn estimate_ascii_and_cjk() {
        assert_eq!(estimate_tokens("abcd"), 1); // 4 ascii ≈ 1 token
        assert_eq!(estimate_tokens("你好"), 2); // CJK ≈ 1 token/字
        assert_eq!(estimate_tokens(""), 0);
    }

    #[test]
    fn full_when_under_budget() {
        let msgs = vec![msg(Role::User, "hello"), msg(Role::Assistant, "hi")];
        assert!(matches!(plan_context(&msgs, 10_000), ContextPlan::Full));
    }

    #[test]
    fn splits_when_over_budget() {
        // 每条中文消息 20 字 ≈ 20+4 token；预算 50 → 只能保留最新 2 条
        let msgs: Vec<ChatMessage> = (0..5)
            .map(|i| {
                msg(
                    if i % 2 == 0 {
                        Role::User
                    } else {
                        Role::Assistant
                    },
                    &"字".repeat(20),
                )
            })
            .collect();
        match plan_context(&msgs, 50) {
            ContextPlan::Full => panic!("should need summary"),
            ContextPlan::NeedsSummary { to_summarize, keep } => {
                assert_eq!(to_summarize.len() + keep.len(), 5);
                assert_eq!(keep.len(), 2);
                assert_eq!(to_summarize.len(), 3);
            }
        }
    }

    #[test]
    fn summary_merge_injects_system_and_keeps_order() {
        let keep = vec![msg(Role::User, "最近问题")];
        let (sys, msgs) = merge_with_summary("早前聊了 A 和 B", keep);
        assert!(sys.contains("早前聊了 A 和 B"));
        assert_eq!(msgs.len(), 1);
        assert_eq!(msgs[0].role, Role::User);
    }

    #[test]
    fn summary_prompt_contains_transcript() {
        let older = vec![msg(Role::User, "第一点"), msg(Role::Assistant, "好的")];
        let prompt = summary_prompt(&older);
        assert!(prompt.content.contains("用户：第一点"));
        assert!(prompt.content.contains("助手：好的"));
    }
}
