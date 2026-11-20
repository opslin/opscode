use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;
use worker::Method;

pub const VERSION: u8 = 1;
pub const DEVICE_ID_BYTES: usize = 16;
pub const HEADER_SIZE: usize = 1 + DEVICE_ID_BYTES;
pub const MAX_PAYLOAD: usize = 64 * 1024;
pub const INVITE_LIFETIME_MS: u64 = 120_000;
pub const MAX_PHONES: u32 = 16;
// A stream using one frame every 20 ms sends 50 frames per second.
pub const PHONE_FRAMES_PER_SECOND: u64 = 120;
pub const PHONE_BYTES_PER_SECOND: u64 = 512 * 1024;

#[derive(Default)]
pub struct FrameBudget {
    last_ms: u64,
    frames: u64,
    bytes: u64,
}

impl FrameBudget {
    pub fn allows(&mut self, now_ms: u64, size: usize) -> bool {
        // Count tokens in thousandths to keep subsecond refill exact.
        let elapsed = now_ms.saturating_sub(self.last_ms).min(1_000);
        self.last_ms = now_ms;
        self.frames =
            (self.frames + elapsed * PHONE_FRAMES_PER_SECOND).min(1_000 * PHONE_FRAMES_PER_SECOND);
        self.bytes =
            (self.bytes + elapsed * PHONE_BYTES_PER_SECOND).min(1_000 * PHONE_BYTES_PER_SECOND);
        let bytes = size as u64 * 1_000;
        if self.frames < 1_000 || self.bytes < bytes {
            return false;
        }
        self.frames -= 1_000;
        self.bytes -= bytes;
        true
    }
}

pub enum Route<'a> {
    Health,
    Invite,
    Pair,
    Devices,
    Revoke(&'a str),
    Disconnect,
    Mac,
    Phone,
}

impl<'a> Route<'a> {
    pub fn parse(method: Method, path: &'a str) -> Option<Self> {
        Some(match (method, path) {
            (Method::Get, "/health") => Self::Health,
            (Method::Post, "/v1/invite") => Self::Invite,
            (Method::Post, "/v1/pair") => Self::Pair,
            (Method::Get, "/v1/devices") => Self::Devices,
            (Method::Delete, "/v1/device") => Self::Disconnect,
            (Method::Get, "/v1/socket/mac") => Self::Mac,
            (Method::Get, "/v1/socket/phone") => Self::Phone,
            (Method::Delete, path) => {
                let id = path.strip_prefix("/v1/devices/")?;
                if !valid_hex(id, DEVICE_ID_BYTES) {
                    return None;
                }
                Self::Revoke(id)
            }
            _ => return None,
        })
    }

    pub fn is_socket(&self) -> bool {
        matches!(self, Self::Mac | Self::Phone)
    }
}

pub fn valid_hex(value: &str, bytes: usize) -> bool {
    value.len() == bytes * 2
        && value
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

pub fn digest(secret: &str) -> String {
    hex::encode(Sha256::digest(secret.as_bytes()))
}

pub fn matches_digest(secret: &str, expected: &str) -> bool {
    digest(secret).as_bytes().ct_eq(expected.as_bytes()).into()
}

pub fn frame(device_id: &str, payload: &[u8]) -> Option<Vec<u8>> {
    let mut id = [0; DEVICE_ID_BYTES];
    hex::decode_to_slice(device_id, &mut id).ok()?;
    let mut message = Vec::with_capacity(HEADER_SIZE + payload.len());
    message.push(VERSION);
    message.extend_from_slice(&id);
    message.extend_from_slice(payload);
    Some(message)
}

pub fn decode_frame(message: &[u8]) -> Option<(String, &[u8])> {
    let (header, payload) = message.split_at_checked(HEADER_SIZE)?;
    if header[0] == VERSION && (1..=MAX_PAYLOAD).contains(&payload.len()) {
        Some((hex::encode(&header[1..]), payload))
    } else {
        None
    }
}
