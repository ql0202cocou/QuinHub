//! SQLite 存储层（sqlx + migrations）。DDL 与约定见 doc/agents/data-model.md。

mod model;

pub use model::{NewProfile, ProviderProfile};

use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum StorageError {
    #[error("sqlite: {0}")]
    Sqlx(#[from] sqlx::Error),
    #[error("migration: {0}")]
    Migrate(#[from] sqlx::migrate::MigrateError),
    #[error("not found: {0}")]
    NotFound(String),
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub struct Storage {
    pool: SqlitePool,
}

impl Storage {
    /// 打开（必要时创建）指定路径的数据库并执行迁移。
    pub async fn init(path: &str) -> Result<Self, StorageError> {
        let opts = SqliteConnectOptions::new()
            .filename(path)
            .create_if_missing(true);
        let pool = SqlitePoolOptions::new().connect_with(opts).await?;
        sqlx::migrate!("./migrations").run(&pool).await?;
        Ok(Self { pool })
    }

    /// 内存库（测试用；单连接避免多连接各自建库）。
    #[cfg(test)]
    async fn init_memory() -> Result<Self, StorageError> {
        let opts = SqliteConnectOptions::new().filename(":memory:");
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(opts)
            .await?;
        sqlx::migrate!("./migrations").run(&pool).await?;
        Ok(Self { pool })
    }

    pub async fn create_profile(&self, new: NewProfile) -> Result<ProviderProfile, StorageError> {
        let id = Uuid::new_v4().to_string();
        let now = now_millis();
        let mut tx = self.pool.begin().await?;
        if new.is_default {
            sqlx::query("UPDATE provider_profile SET is_default = 0 WHERE deleted_at IS NULL")
                .execute(&mut *tx)
                .await?;
        }
        sqlx::query(
            "INSERT INTO provider_profile (id, name, type, base_url, encrypted_key, is_default, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&id)
        .bind(&new.name)
        .bind(&new.provider_type)
        .bind(&new.base_url)
        .bind(&new.encrypted_key)
        .bind(new.is_default)
        .bind(now)
        .bind(now)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        self.get_profile(&id).await
    }

    pub async fn get_profile(&self, id: &str) -> Result<ProviderProfile, StorageError> {
        sqlx::query_as::<_, ProviderProfile>(
            "SELECT * FROM provider_profile WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    /// 含墓碑记录（同步层用）。
    pub async fn get_profile_any(&self, id: &str) -> Result<ProviderProfile, StorageError> {
        sqlx::query_as::<_, ProviderProfile>("SELECT * FROM provider_profile WHERE id = ?")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    pub async fn list_profiles(&self) -> Result<Vec<ProviderProfile>, StorageError> {
        let rows = sqlx::query_as::<_, ProviderProfile>(
            "SELECT * FROM provider_profile WHERE deleted_at IS NULL
             ORDER BY is_default DESC, created_at ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn update_profile(
        &self,
        id: &str,
        name: &str,
        base_url: &str,
        encrypted_key: Option<&str>,
        is_default: bool,
        enabled_models: &str,
    ) -> Result<ProviderProfile, StorageError> {
        let now = now_millis();
        let mut tx = self.pool.begin().await?;
        if is_default {
            sqlx::query("UPDATE provider_profile SET is_default = 0 WHERE deleted_at IS NULL")
                .execute(&mut *tx)
                .await?;
        }
        let res = if let Some(key) = encrypted_key {
            sqlx::query(
                "UPDATE provider_profile SET name = ?, base_url = ?, encrypted_key = ?, is_default = ?, enabled_models = ?, updated_at = ?, rev = rev + 1
                 WHERE id = ? AND deleted_at IS NULL",
            )
            .bind(name)
            .bind(base_url)
            .bind(key)
            .bind(is_default)
            .bind(enabled_models)
            .bind(now)
            .bind(id)
            .execute(&mut *tx)
            .await?
        } else {
            sqlx::query(
                "UPDATE provider_profile SET name = ?, base_url = ?, is_default = ?, enabled_models = ?, updated_at = ?, rev = rev + 1
                 WHERE id = ? AND deleted_at IS NULL",
            )
            .bind(name)
            .bind(base_url)
            .bind(is_default)
            .bind(enabled_models)
            .bind(now)
            .bind(id)
            .execute(&mut *tx)
            .await?
        };
        tx.commit().await?;
        if res.rows_affected() == 0 {
            return Err(StorageError::NotFound(id.to_string()));
        }
        self.get_profile(id).await
    }

    /// 软删除（保留墓碑供同步）。
    pub async fn delete_profile(&self, id: &str) -> Result<(), StorageError> {
        let res = sqlx::query(
            "UPDATE provider_profile SET deleted_at = ?, updated_at = ?, rev = rev + 1
             WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(now_millis())
        .bind(now_millis())
        .bind(id)
        .execute(&self.pool)
        .await?;
        if res.rows_affected() == 0 {
            return Err(StorageError::NotFound(id.to_string()));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(name: &str, is_default: bool) -> NewProfile {
        NewProfile {
            name: name.to_string(),
            provider_type: "openai_compatible".to_string(),
            base_url: "https://api.openai.com/v1".to_string(),
            encrypted_key: "enc:xxx".to_string(),
            is_default,
        }
    }

    #[tokio::test]
    async fn profile_crud_roundtrip() {
        let s = Storage::init_memory().await.unwrap();

        let a = s.create_profile(sample("A", true)).await.unwrap();
        let b = s.create_profile(sample("B", false)).await.unwrap();

        // 列表：默认在前
        let list = s.list_profiles().await.unwrap();
        assert_eq!(list.len(), 2);
        assert_eq!(list[0].name, "A");

        // 更新（含换 key），rev 递增
        let updated = s
            .update_profile(
                &b.id,
                "B2",
                "https://x",
                Some("enc:new"),
                true,
                "[\"gpt-4o\"]",
            )
            .await
            .unwrap();
        assert_eq!(updated.name, "B2");
        assert_eq!(updated.encrypted_key, "enc:new");
        assert!(updated.is_default);
        assert_eq!(updated.rev, b.rev + 1);

        // 设为默认后 A 自动取消默认
        let a_after = s.get_profile(&a.id).await.unwrap();
        assert!(!a_after.is_default);

        // 软删除：列表消失、墓碑仍在
        s.delete_profile(&a.id).await.unwrap();
        assert_eq!(s.list_profiles().await.unwrap().len(), 1);
        let tomb = s.get_profile_any(&a.id).await.unwrap();
        assert!(tomb.deleted_at.is_some());
        assert!(s.get_profile(&a.id).await.is_err());
    }

    #[tokio::test]
    async fn update_without_key_keeps_old() {
        let s = Storage::init_memory().await.unwrap();
        let a = s.create_profile(sample("A", false)).await.unwrap();
        let updated = s
            .update_profile(&a.id, "A2", "https://y", None, false, "[]")
            .await
            .unwrap();
        assert_eq!(updated.encrypted_key, "enc:xxx");
        assert_eq!(updated.name, "A2");
    }
}
