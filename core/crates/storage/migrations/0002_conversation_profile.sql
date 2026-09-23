-- 0002_conversation_profile.sql — 会话关联提供商（模型属于哪个 profile 的 Key）
ALTER TABLE conversation ADD COLUMN profile_id TEXT REFERENCES provider_profile(id);
