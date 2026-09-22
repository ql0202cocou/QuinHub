//! 云同步抽象。服务端后期单独立项（Docker 部署），本期仅接口 + no-op 实现。
//! 方向性约定见 doc/agents/engineering.md 第 7 节。

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SyncError {
    #[error("network: {0}")]
    Network(String),
    #[error("server: {0}")]
    Server(String),
    #[error("conflict: {0}")]
    Conflict(String),
}

/// 一次增量同步的变更批次（按 rev 游标）。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ChangeBatch {
    pub entity: String,
    pub since_rev: i64,
    pub records: Vec<serde_json::Value>,
}

#[async_trait]
pub trait SyncBackend: Send + Sync {
    /// 推送本地变更。
    async fn push(&self, batch: ChangeBatch) -> Result<(), SyncError>;
    /// 拉取 since_rev 之后的远端变更。
    async fn pull(&self, entity: &str, since_rev: i64) -> Result<ChangeBatch, SyncError>;
}

/// 本期占位实现：什么都不做。
pub struct NoopSync;

#[async_trait]
impl SyncBackend for NoopSync {
    async fn push(&self, _batch: ChangeBatch) -> Result<(), SyncError> {
        Ok(())
    }

    async fn pull(&self, entity: &str, since_rev: i64) -> Result<ChangeBatch, SyncError> {
        Ok(ChangeBatch {
            entity: entity.to_string(),
            since_rev,
            records: vec![],
        })
    }
}
