//! ProviderProfile 桥接：CRUD + 连通性测试。
//! 明文 Key 只在本层短暂存在（加密后落库），不回传 Dart。

use super::lifecycle::storage;
use super::BridgeError;
use anyhow::Context;
use quinhub_api::build_provider;
use quinhub_storage::{NewProfile, ProviderProfile};

/// anyhow → 干净字符串（错误链，无 backtrace 噪音）。
fn clean(e: anyhow::Error) -> BridgeError {
    BridgeError(format!("{e:#}"))
}

/// 传给 Dart 的 Profile 视图（不含密钥密文）。
pub struct ProfileDto {
    pub id: String,
    pub name: String,
    pub provider_type: String,
    pub base_url: String,
    pub is_default: bool,
    pub enabled_models: Vec<String>,
    pub created_at: i64,
}

fn to_dto(p: ProviderProfile) -> ProfileDto {
    ProfileDto {
        id: p.id,
        name: p.name,
        provider_type: p.provider_type,
        base_url: p.base_url,
        is_default: p.is_default,
        enabled_models: serde_json::from_str(&p.enabled_models).unwrap_or_default(),
        created_at: p.created_at,
    }
}

pub async fn profile_create(
    name: String,
    provider_type: String,
    base_url: String,
    api_key: String,
    is_default: bool,
) -> Result<ProfileDto, BridgeError> {
    let encrypted = quinhub_crypto::encrypt(&api_key)
        .context("encrypt key")
        .map_err(clean)?;
    let p = storage()
        .map_err(clean)?
        .create_profile(NewProfile {
            name,
            provider_type,
            base_url,
            encrypted_key: encrypted,
            is_default,
        })
        .await
        .context("create profile")
        .map_err(clean)?;
    Ok(to_dto(p))
}

pub async fn profile_list() -> Result<Vec<ProfileDto>, BridgeError> {
    let rows = storage()
        .map_err(clean)?
        .list_profiles()
        .await
        .context("list profiles")
        .map_err(clean)?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn profile_get(id: String) -> Result<ProfileDto, BridgeError> {
    let p = storage()
        .map_err(clean)?
        .get_profile(&id)
        .await
        .context("get profile")
        .map_err(clean)?;
    Ok(to_dto(p))
}

/// api_key 传 None 表示不改密钥。
pub async fn profile_update(
    id: String,
    name: String,
    base_url: String,
    api_key: Option<String>,
    is_default: bool,
    enabled_models: Vec<String>,
) -> Result<ProfileDto, BridgeError> {
    let encrypted = match api_key {
        Some(k) => Some(
            quinhub_crypto::encrypt(&k)
                .context("encrypt key")
                .map_err(clean)?,
        ),
        None => None,
    };
    let models_json = serde_json::to_string(&enabled_models)
        .context("serialize models")
        .map_err(clean)?;
    let p = storage()
        .map_err(clean)?
        .update_profile(
            &id,
            &name,
            &base_url,
            encrypted.as_deref(),
            is_default,
            &models_json,
        )
        .await
        .context("update profile")
        .map_err(clean)?;
    Ok(to_dto(p))
}

pub async fn profile_delete(id: String) -> Result<(), BridgeError> {
    storage()
        .map_err(clean)?
        .delete_profile(&id)
        .await
        .context("delete profile")
        .map_err(clean)
}

/// 连通性测试：解密 Key → 构造 Provider → 拉取模型列表。
pub async fn profile_test(id: String) -> Result<Vec<String>, BridgeError> {
    let p = storage()
        .map_err(clean)?
        .get_profile(&id)
        .await
        .context("get profile")
        .map_err(clean)?;
    let key = quinhub_crypto::decrypt(&p.encrypted_key)
        .context("decrypt key")
        .map_err(clean)?;
    let provider = build_provider(&p.provider_type, &p.base_url, &key)
        .context("build provider")
        .map_err(clean)?;
    let models = provider
        .list_models()
        .await
        .map_err(|e| BridgeError(format!("{e}")))?;
    Ok(models)
}
