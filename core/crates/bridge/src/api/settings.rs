//! 设置 KV 桥接（theme / language 等 UI 偏好持久化）。

use super::lifecycle::storage;
use super::BridgeError;

fn clean(e: anyhow::Error) -> BridgeError {
    BridgeError(format!("{e:#}"))
}

pub async fn settings_get(key: String) -> Result<Option<String>, BridgeError> {
    storage()
        .map_err(clean)?
        .get_setting(&key)
        .await
        .map_err(|e| clean(e.into()))
}

pub async fn settings_set(key: String, value: String) -> Result<(), BridgeError> {
    storage()
        .map_err(clean)?
        .set_setting(&key, &value)
        .await
        .map_err(|e| clean(e.into()))
}
