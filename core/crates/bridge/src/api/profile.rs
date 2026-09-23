//! ProviderProfile 桥接：CRUD + 连通性测试。
//! 明文 Key 只在本层短暂存在（加密后落库），不回传 Dart。

use super::lifecycle::storage;
use anyhow::Context;
use quinhub_api::build_provider;
use quinhub_storage::{NewProfile, ProviderProfile};

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
) -> anyhow::Result<ProfileDto> {
    let encrypted = quinhub_crypto::encrypt(&api_key).context("encrypt key")?;
    let p = storage()?
        .create_profile(NewProfile {
            name,
            provider_type,
            base_url,
            encrypted_key: encrypted,
            is_default,
        })
        .await
        .context("create profile")?;
    Ok(to_dto(p))
}

pub async fn profile_list() -> anyhow::Result<Vec<ProfileDto>> {
    let rows = storage()?.list_profiles().await.context("list profiles")?;
    Ok(rows.into_iter().map(to_dto).collect())
}

pub async fn profile_get(id: String) -> anyhow::Result<ProfileDto> {
    let p = storage()?.get_profile(&id).await.context("get profile")?;
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
) -> anyhow::Result<ProfileDto> {
    let encrypted = match api_key {
        Some(k) => Some(quinhub_crypto::encrypt(&k).context("encrypt key")?),
        None => None,
    };
    let models_json = serde_json::to_string(&enabled_models).context("serialize models")?;
    let p = storage()?
        .update_profile(
            &id,
            &name,
            &base_url,
            encrypted.as_deref(),
            is_default,
            &models_json,
        )
        .await
        .context("update profile")?;
    Ok(to_dto(p))
}

pub async fn profile_delete(id: String) -> anyhow::Result<()> {
    storage()?
        .delete_profile(&id)
        .await
        .context("delete profile")
}

/// 连通性测试：解密 Key → 构造 Provider → 拉取模型列表。
pub async fn profile_test(id: String) -> anyhow::Result<Vec<String>> {
    let p = storage()?.get_profile(&id).await.context("get profile")?;
    let key = quinhub_crypto::decrypt(&p.encrypted_key).context("decrypt key")?;
    let provider = build_provider(&p.provider_type, &p.base_url, &key).context("build provider")?;
    let models = provider
        .list_models()
        .await
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    Ok(models)
}
