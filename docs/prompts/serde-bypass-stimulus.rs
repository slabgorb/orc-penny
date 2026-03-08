use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ApiKey {
    prefix: String,
    secret: String,
}

impl ApiKey {
    pub fn new(raw: &str) -> Result<Self, ApiKeyError> {
        let (prefix, secret) = raw
            .split_once('_')
            .ok_or(ApiKeyError::InvalidFormat)?;

        if prefix.len() < 2 || prefix.len() > 10 {
            return Err(ApiKeyError::InvalidPrefix);
        }
        if !prefix.chars().all(|c| c.is_ascii_lowercase()) {
            return Err(ApiKeyError::InvalidPrefix);
        }
        if secret.len() < 32 {
            return Err(ApiKeyError::SecretTooShort);
        }

        Ok(Self {
            prefix: prefix.to_string(),
            secret: secret.to_string(),
        })
    }

    pub fn prefix(&self) -> &str {
        &self.prefix
    }
}

impl fmt::Display for ApiKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}_{}", self.prefix, &self.secret[..8])
    }
}

#[derive(Debug)]
pub enum ApiKeyError {
    InvalidFormat,
    InvalidPrefix,
    SecretTooShort,
}

pub struct RateLimitConfig {
    pub max_requests: u32,
    pub window_secs: u64,
    pub burst_size: u32,
    pub allowed_origins: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct WebhookPayload {
    pub event_type: String,
    pub timestamp: u64,
    pub api_key: ApiKey,
    pub source_ip: String,
    pub metadata: serde_json::Value,
}

pub fn process_webhook(payload: &WebhookPayload) -> Result<(), String> {
    if payload.event_type.is_empty() {
        return Err("empty event type".into());
    }

    println!("Processing {} from {}", payload.api_key, payload.source_ip);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_test_key() -> ApiKey {
        ApiKey::new("test_abcdefghijklmnopqrstuvwxyz0123456789").unwrap()
    }

    #[test]
    fn test_valid_api_key() {
        let key = make_test_key();
        assert_eq!(key.prefix(), "test");
    }

    #[test]
    fn test_invalid_prefix_rejected() {
        assert!(ApiKey::new("AB_short").is_err());
        assert!(ApiKey::new("_nosecret").is_err());
    }
}
