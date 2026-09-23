//! 核心生命周期：初始化存储与加密。

use anyhow::{anyhow, Context};
use quinhub_storage::Storage;
use std::sync::{Arc, OnceLock};

static STORAGE: OnceLock<Arc<Storage>> = OnceLock::new();

/// 启动时调用：注入主密钥（base64 的 32B）并打开数据库。
/// db_path 由 Dart 侧 path_provider 提供。
/// 幂等：进程缓存重启（isolate 重建）时重复调用返回 Ok。
pub async fn init_core(db_path: String, master_key_b64: String) -> anyhow::Result<()> {
    quinhub_crypto::set_master_key(&master_key_b64).context("set master key")?;
    if STORAGE.get().is_some() {
        return Ok(());
    }
    let storage = Storage::init(&db_path).await.context("open database")?;
    STORAGE
        .set(Arc::new(storage))
        .map_err(|_| anyhow!("core already initialized"))?;
    Ok(())
}

pub(crate) fn storage() -> anyhow::Result<Arc<Storage>> {
    STORAGE
        .get()
        .cloned()
        .ok_or_else(|| anyhow!("core not initialized"))
}
