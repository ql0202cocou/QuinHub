//! API Key 加解密：AES-256-GCM。
//! 主密钥由 flutter_secure_storage 存平台 Keystore/Keychain，启动时注入内存（`set_master_key`）。
//! 密文格式：base64(nonce(12B) || ciphertext)。

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use rand::RngCore;
use std::sync::OnceLock;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("master key not set")]
    KeyNotSet,
    #[error("invalid master key length: {0}")]
    BadKeyLength(usize),
    #[error("encrypt failed")]
    Encrypt,
    #[error("decrypt failed")]
    Decrypt,
    #[error("invalid encoding: {0}")]
    Encoding(String),
}

static MASTER_KEY: OnceLock<[u8; 32]> = OnceLock::new();

/// 注入主密钥（base64 编码的 32 字节）。启动时调用一次。
pub fn set_master_key(key_b64: &str) -> Result<(), CryptoError> {
    let raw = B64
        .decode(key_b64)
        .map_err(|e| CryptoError::Encoding(e.to_string()))?;
    let key: [u8; 32] = raw
        .as_slice()
        .try_into()
        .map_err(|_| CryptoError::BadKeyLength(raw.len()))?;
    MASTER_KEY.set(key).map_err(|_| CryptoError::KeyNotSet)?;
    Ok(())
}

fn cipher() -> Result<Aes256Gcm, CryptoError> {
    let key = MASTER_KEY.get().ok_or(CryptoError::KeyNotSet)?;
    Ok(Aes256Gcm::new(key.into()))
}

/// 加密明文，返回 base64(nonce || ciphertext)。
pub fn encrypt(plaintext: &str) -> Result<String, CryptoError> {
    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let ct = cipher()?
        .encrypt(Nonce::from_slice(&nonce_bytes), plaintext.as_bytes())
        .map_err(|_| CryptoError::Encrypt)?;
    let mut out = Vec::with_capacity(12 + ct.len());
    out.extend_from_slice(&nonce_bytes);
    out.extend_from_slice(&ct);
    Ok(B64.encode(out))
}

/// 解密 base64(nonce || ciphertext)。
pub fn decrypt(encoded: &str) -> Result<String, CryptoError> {
    let raw = B64
        .decode(encoded)
        .map_err(|e| CryptoError::Encoding(e.to_string()))?;
    if raw.len() < 12 {
        return Err(CryptoError::Encoding("ciphertext too short".into()));
    }
    let (nonce, ct) = raw.split_at(12);
    let plain = cipher()?
        .decrypt(Nonce::from_slice(nonce), ct)
        .map_err(|_| CryptoError::Decrypt)?;
    String::from_utf8(plain).map_err(|e| CryptoError::Encoding(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_key() -> String {
        B64.encode([42u8; 32])
    }

    #[test]
    fn encrypt_decrypt_roundtrip() {
        set_master_key(&test_key()).ok();
        let ct = encrypt("sk-test-你好").unwrap();
        assert_ne!(ct, "sk-test-你好");
        assert_eq!(decrypt(&ct).unwrap(), "sk-test-你好");
    }

    #[test]
    fn decrypt_wrong_data_fails() {
        set_master_key(&test_key()).ok();
        assert!(decrypt("aGVsbG8td29ybGQtaGVsbG8=").is_err());
    }

    #[test]
    fn encrypt_uses_random_nonce() {
        set_master_key(&test_key()).ok();
        let a = encrypt("same").unwrap();
        let b = encrypt("same").unwrap();
        assert_ne!(a, b);
    }
}
