//! SQLite 存储层（sqlx + migrations）。DDL 与约定见 doc/agents/data-model.md。

mod model;

pub use model::{Conversation, Message, NewProfile, ProviderProfile};

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

// ==================== Conversation / Message（M4） ====================

impl Storage {
    pub async fn create_conversation(
        &self,
        profile_id: Option<&str>,
        model_id: Option<&str>,
    ) -> Result<Conversation, StorageError> {
        let id = Uuid::new_v4().to_string();
        let now = now_millis();
        sqlx::query(
            "INSERT INTO conversation (id, profile_id, model_id, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind(&id)
        .bind(profile_id)
        .bind(model_id)
        .bind(now)
        .bind(now)
        .execute(&self.pool)
        .await?;
        self.get_conversation(&id).await
    }

    pub async fn get_conversation(&self, id: &str) -> Result<Conversation, StorageError> {
        sqlx::query_as::<_, Conversation>(
            "SELECT * FROM conversation WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    /// 会话列表：未归档、未删除，置顶在前，按最近更新倒序（data-model.md 第 5 节）。
    pub async fn list_conversations(&self) -> Result<Vec<Conversation>, StorageError> {
        let rows = sqlx::query_as::<_, Conversation>(
            "SELECT * FROM conversation WHERE archived = 0 AND deleted_at IS NULL
             ORDER BY pinned DESC, updated_at DESC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    /// 已归档会话列表（归档页用），按最近更新倒序。
    pub async fn list_archived_conversations(&self) -> Result<Vec<Conversation>, StorageError> {
        let rows = sqlx::query_as::<_, Conversation>(
            "SELECT * FROM conversation WHERE archived = 1 AND deleted_at IS NULL
             ORDER BY pinned DESC, updated_at DESC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    /// 整体替换会话参数 JSON（temperature/top_p/max_tokens/system_prompt 等，'{}' 恢复默认）。
    pub async fn update_conversation_params(
        &self,
        id: &str,
        params: &str,
    ) -> Result<Conversation, StorageError> {
        sqlx::query("UPDATE conversation SET params = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
            .bind(params)
            .bind(now_millis())
            .bind(id)
            .execute(&self.pool)
            .await?;
        self.get_conversation(id).await
    }

    /// 改标题/置顶/归档（None 表示不动该字段）。
    pub async fn update_conversation_meta(
        &self,
        id: &str,
        title: Option<&str>,
        pinned: Option<bool>,
        archived: Option<bool>,
    ) -> Result<Conversation, StorageError> {
        let now = now_millis();
        if let Some(t) = title {
            sqlx::query("UPDATE conversation SET title = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
                .bind(t).bind(now).bind(id).execute(&self.pool).await?;
        }
        if let Some(p) = pinned {
            sqlx::query("UPDATE conversation SET pinned = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
                .bind(p).bind(now).bind(id).execute(&self.pool).await?;
        }
        if let Some(a) = archived {
            sqlx::query("UPDATE conversation SET archived = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
                .bind(a).bind(now).bind(id).execute(&self.pool).await?;
        }
        self.get_conversation(id).await
    }

    pub async fn set_conversation_model(
        &self,
        id: &str,
        profile_id: &str,
        model_id: &str,
    ) -> Result<Conversation, StorageError> {
        sqlx::query("UPDATE conversation SET profile_id = ?, model_id = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
            .bind(profile_id)
            .bind(model_id)
            .bind(now_millis())
            .bind(id)
            .execute(&self.pool)
            .await?;
        self.get_conversation(id).await
    }

    /// 发消息时刷新排序时间戳。
    pub async fn touch_conversation(&self, id: &str) -> Result<(), StorageError> {
        sqlx::query("UPDATE conversation SET updated_at = ?, rev = rev + 1 WHERE id = ?")
            .bind(now_millis())
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 软删会话及其全部消息（墓碑，同事务）。
    pub async fn delete_conversation(&self, id: &str) -> Result<(), StorageError> {
        let now = now_millis();
        let mut tx = self.pool.begin().await?;
        sqlx::query("UPDATE message SET deleted_at = ?, rev = rev + 1 WHERE conversation_id = ? AND deleted_at IS NULL")
            .bind(now)
            .bind(id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("UPDATE conversation SET deleted_at = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
            .bind(now)
            .bind(now)
            .bind(id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    /// 插入消息。status 由调用方给（user=done，assistant 流式起步=streaming）。
    pub async fn insert_message(
        &self,
        conversation_id: &str,
        role: &str,
        content: &str,
        model: Option<&str>,
        status: &str,
    ) -> Result<Message, StorageError> {
        let id = Uuid::new_v4().to_string();
        let now = now_millis();
        sqlx::query(
            "INSERT INTO message (id, conversation_id, role, content, model, status, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&id)
        .bind(conversation_id)
        .bind(role)
        .bind(content)
        .bind(model)
        .bind(status)
        .bind(now)
        .bind(now)
        .execute(&self.pool)
        .await?;
        sqlx::query_as::<_, Message>("SELECT * FROM message WHERE id = ?")
            .bind(&id)
            .fetch_one(&self.pool)
            .await
            .map_err(StorageError::from)
    }

    /// 流式结束/出错/取消时更新消息终态。
    pub async fn finalize_message(
        &self,
        id: &str,
        content: &str,
        status: &str,
        error: Option<&str>,
        tokens_in: Option<i64>,
        tokens_out: Option<i64>,
    ) -> Result<Message, StorageError> {
        sqlx::query(
            "UPDATE message SET content = ?, status = ?, error = ?, tokens_in = ?, tokens_out = ?, updated_at = ?, rev = rev + 1
             WHERE id = ?",
        )
        .bind(content)
        .bind(status)
        .bind(error)
        .bind(tokens_in)
        .bind(tokens_out)
        .bind(now_millis())
        .bind(id)
        .execute(&self.pool)
        .await?;
        sqlx::query_as::<_, Message>("SELECT * FROM message WHERE id = ?")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map_err(StorageError::from)
    }

    /// 会话内消息（正序，未删除；同毫秒用 rowid 决胜，保证插入序稳定）。
    pub async fn list_messages(&self, conversation_id: &str) -> Result<Vec<Message>, StorageError> {
        let rows = sqlx::query_as::<_, Message>(
            "SELECT * FROM message WHERE conversation_id = ? AND deleted_at IS NULL
             ORDER BY created_at ASC, rowid ASC",
        )
        .bind(conversation_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn get_message(&self, id: &str) -> Result<Message, StorageError> {
        sqlx::query_as::<_, Message>("SELECT * FROM message WHERE id = ? AND deleted_at IS NULL")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    /// 软删单条消息。
    pub async fn delete_message(&self, id: &str) -> Result<(), StorageError> {
        sqlx::query("UPDATE message SET deleted_at = ?, updated_at = ?, rev = rev + 1 WHERE id = ? AND deleted_at IS NULL")
            .bind(now_millis())
            .bind(now_millis())
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 软删某条消息之后的所有消息（不含本身）——重新生成/编辑重发用。
    /// 用 rowid 比较（插入序单调），避免 created_at 毫秒精度同毫秒碰撞。
    pub async fn delete_messages_after(
        &self,
        conversation_id: &str,
        after_message_id: &str,
    ) -> Result<(), StorageError> {
        let now = now_millis();
        let res = sqlx::query(
            "UPDATE message SET deleted_at = ?, updated_at = ?, rev = rev + 1
             WHERE conversation_id = ? AND deleted_at IS NULL
               AND rowid > (SELECT rowid FROM message WHERE id = ?)",
        )
        .bind(now)
        .bind(now)
        .bind(conversation_id)
        .bind(after_message_id)
        .execute(&self.pool)
        .await?;
        if res.rows_affected() == 0 && self.get_message(after_message_id).await.is_err() {
            return Err(StorageError::NotFound(after_message_id.to_string()));
        }
        Ok(())
    }
}

#[cfg(test)]
mod conv_tests {
    use super::*;

    async fn setup() -> (Storage, String) {
        let s = Storage::init_memory().await.unwrap();
        // profile_id 有外键，先建真 profile
        let p = s
            .create_profile(NewProfile {
                name: "P".into(),
                provider_type: "openai_compatible".into(),
                base_url: "http://x".into(),
                encrypted_key: "enc".into(),
                is_default: false,
            })
            .await
            .unwrap();
        let c = s
            .create_conversation(Some(&p.id), Some("gpt-4o"))
            .await
            .unwrap();
        (s, c.id)
    }

    #[tokio::test]
    async fn conversation_message_flow() {
        let (s, cid) = setup().await;

        let u = s
            .insert_message(&cid, "user", "你好", None, "done")
            .await
            .unwrap();
        let a = s
            .insert_message(&cid, "assistant", "", Some("gpt-4o"), "streaming")
            .await
            .unwrap();
        let a = s
            .finalize_message(&a.id, "你好！", "done", None, Some(2), Some(2))
            .await
            .unwrap();
        assert_eq!(a.status, "done");
        assert_eq!(a.tokens_in, Some(2));

        let msgs = s.list_messages(&cid).await.unwrap();
        assert_eq!(msgs.len(), 2);
        assert_eq!(msgs[0].id, u.id);

        // 删除 a 之后的（无影响），再从 u 之后删（删掉 a）
        s.delete_messages_after(&cid, &a.id).await.unwrap();
        assert_eq!(s.list_messages(&cid).await.unwrap().len(), 2);
        s.delete_messages_after(&cid, &u.id).await.unwrap();
        assert_eq!(s.list_messages(&cid).await.unwrap().len(), 1);

        // 元信息 + 排序
        s.update_conversation_meta(&cid, Some("测试会话"), Some(true), None)
            .await
            .unwrap();
        let c2 = s.create_conversation(None, None).await.unwrap();
        let list = s.list_conversations().await.unwrap();
        assert_eq!(list[0].id, cid); // pinned 优先
        assert_eq!(list[0].title, "测试会话");

        // 级联软删
        s.delete_conversation(&c2.id).await.unwrap();
        assert_eq!(s.list_conversations().await.unwrap().len(), 1);
        assert!(s.get_conversation(&c2.id).await.is_err());
    }

    #[tokio::test]
    async fn conversation_archive_and_params() {
        let (s, cid) = setup().await;

        // 归档后从普通列表消失、出现在归档列表；取消后恢复
        s.update_conversation_meta(&cid, None, None, Some(true))
            .await
            .unwrap();
        assert!(s.list_conversations().await.unwrap().is_empty());
        assert_eq!(s.list_archived_conversations().await.unwrap().len(), 1);
        s.update_conversation_meta(&cid, None, None, Some(false))
            .await
            .unwrap();
        assert_eq!(s.list_conversations().await.unwrap().len(), 1);
        assert!(s.list_archived_conversations().await.unwrap().is_empty());

        // params 整体替换并持久化
        let c = s
            .update_conversation_params(&cid, r#"{"temperature":0.7}"#)
            .await
            .unwrap();
        assert_eq!(c.params, r#"{"temperature":0.7}"#);
        assert_eq!(
            s.get_conversation(&cid).await.unwrap().params,
            r#"{"temperature":0.7}"#
        );
    }
}

// ==================== Settings KV（M5b） ====================

impl Storage {
    pub async fn get_setting(&self, key: &str) -> Result<Option<String>, StorageError> {
        let row: Option<(String,)> = sqlx::query_as("SELECT value FROM settings WHERE key = ?")
            .bind(key)
            .fetch_optional(&self.pool)
            .await?;
        Ok(row.map(|r| r.0))
    }

    pub async fn set_setting(&self, key: &str, value: &str) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO settings (key, value) VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        )
        .bind(key)
        .bind(value)
        .execute(&self.pool)
        .await?;
        Ok(())
    }
}

#[cfg(test)]
mod settings_tests {
    use super::*;

    #[tokio::test]
    async fn settings_kv_roundtrip() {
        let s = Storage::init_memory().await.unwrap();
        assert_eq!(s.get_setting("theme").await.unwrap(), None);
        s.set_setting("theme", "dark").await.unwrap();
        assert_eq!(
            s.get_setting("theme").await.unwrap().as_deref(),
            Some("dark")
        );
        s.set_setting("theme", "light").await.unwrap();
        assert_eq!(
            s.get_setting("theme").await.unwrap().as_deref(),
            Some("light")
        );
    }
}
