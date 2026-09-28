//! 模型能力启发式判断。
//! BYOK 场景拿不到官方 capabilities 元数据，按 model id 模式匹配主流多模态型号；
//! 未命中一律视为不支持（宁可藏入口，不可放进去必报错）。

/// 是否支持图片输入（vision）。
pub fn model_supports_vision(model_id: &str) -> bool {
    let m = model_id.to_lowercase();
    const PATTERNS: &[&str] = &[
        "vision", // gpt-4-vision / llama-3.2-vision / grok-2-vision 等
        "gpt-4o",
        "gpt-4.1",
        "gpt-5",
        "chatgpt-4o",
        "o1-",
        "o3-",
        "o4-",
        "claude-3",
        "claude-sonnet-4",
        "claude-opus-4",
        "claude-haiku-4",
        "gemini",
        "pixtral",
        "qwen-vl",
        "qwen2-vl",
        "qwen3-vl",
        "glm-4v",
        "llava",
        "minicpm-v",
        "grok-4",
    ];
    PATTERNS.iter().any(|p| m.contains(p))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vision_models_detected() {
        for m in [
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-4.1-2025-04-14",
            "gpt-5",
            "o4-mini",
            "claude-3-5-sonnet-20241022",
            "claude-sonnet-4-20250514",
            "claude-opus-4-1",
            "gemini-2.5-pro",
            "qwen-vl-max",
            "qwen2-vl-72b",
            "llava-1.5-7b",
        ] {
            assert!(model_supports_vision(m), "{m}");
        }
    }

    #[test]
    fn text_only_models_rejected() {
        for m in [
            "gpt-3.5-turbo",
            "text-embedding-3-large",
            "deepseek-v3",
            "qwen-turbo",
            "claude-2.1",
            "glm-4",
        ] {
            assert!(!model_supports_vision(m), "{m}");
        }
    }
}
