mod protocol;

use std::{
    cell::{Cell, RefCell},
    collections::HashMap,
};

use protocol::{
    DEVICE_ID_BYTES, FrameBudget, INVITE_LIFETIME_MS, MAX_PAYLOAD, MAX_PHONES, Route, VERSION,
    decode_frame, digest, frame, matches_digest, valid_hex,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use wasm_bindgen::JsCast;
use web_sys::{WebSocket as BrowserSocket, WorkerGlobalScope};
use worker::{
    Context, DurableObject, Env, Request, Response, Result, SqlStorage, State, WebSocket,
    WebSocketIncomingMessage, WebSocketPair, WebSocketRequestResponsePair, console_error,
    durable_object, event, js_sys,
};

const ROOM: &str = "opscode-personal-mac-v1";
const MAC_SECRET: &str = "OPSCODE_MAC_TOKEN";
const MAC_TAG: &str = "mac";
const PHONE_TAG: &str = "phone";
const TOKEN_BYTES: usize = 32;
const CLOSE_REPLACED: u16 = 4001;
const CLOSE_REVOKED: u16 = 4003;
const CLOSE_RATE_LIMITED: u16 = 4029;

#[event(fetch)]
pub async fn relay_fetch(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let path = req.path();
    let Some(route) = Route::parse(req.method(), &path) else {
        return failure(404, "not_found");
    };
    if req.url()?.query().is_some() {
        return failure(400, "query_not_supported");
    }
    if matches!(route, Route::Health) {
        return respond(200, json!({ "ok": true, "protocol": VERSION }));
    }
    let header = req.headers().get("authorization")?.unwrap_or_default();
    let Some(token) = bearer(&header) else {
        return failure(401, "unauthorized");
    };
    match route {
        Route::Phone | Route::Disconnect if phone_token(token).is_none() => {
            return failure(401, "unauthorized");
        }
        Route::Pair if !valid_hex(token, TOKEN_BYTES) => return failure(401, "invalid_invite"),
        Route::Phone | Route::Pair | Route::Disconnect => (),
        _ => {
            let Ok(secret) = env.secret(MAC_SECRET) else {
                return failure(503, "relay_unconfigured");
            };
            let secret = secret.to_string();
            if !valid_hex(&secret, TOKEN_BYTES) {
                return failure(503, "relay_unconfigured");
            }
            if !valid_hex(token, TOKEN_BYTES) || !matches_digest(token, &digest(&secret)) {
                return failure(401, "unauthorized");
            }
        }
    }
    if route.is_socket() && !websocket_upgrade(&req)? {
        return failure(426, "websocket_required");
    }
    if matches!(route, Route::Phone | Route::Pair | Route::Disconnect) {
        // Cloudflare supplies this header on ingress. Use a shared fallback for local requests.
        let ip = req
            .headers()
            .get("cf-connecting-ip")?
            .unwrap_or_else(|| "unknown".to_owned());
        let scope = if matches!(route, Route::Pair) {
            "pair"
        } else {
            "phone"
        };
        let allowed = env
            .rate_limiter("CONNECT_LIMIT")?
            .limit(format!("opscode-relay:{scope}:{ip}"))
            .await?;
        if !allowed.success {
            let mut response = failure(429, "rate_limited")?;
            response.headers_mut().set("Retry-After", "10")?;
            return Ok(response);
        }
    }
    env.durable_object("RELAY")?
        .id_from_name(ROOM)?
        .get_stub()?
        .fetch_with_request(req)
        .await
}

#[derive(Serialize, Deserialize)]
enum Peer {
    Mac,
    Phone(String),
}

impl Peer {
    fn tag(&self) -> &str {
        match self {
            Self::Mac => MAC_TAG,
            Self::Phone(id) => id,
        }
    }
}

#[derive(Deserialize)]
struct Invite {
    token_digest: String,
    expires_at_ms: u64,
}

#[derive(Deserialize)]
struct StoredCredential {
    token_digest: String,
}

#[derive(Deserialize)]
struct StoredDevice {
    device_id: String,
    paired_at_ms: u64,
}

#[derive(Deserialize)]
struct DeviceCount {
    total: u32,
}

#[durable_object]
pub struct Relay {
    state: State,
    schema_ready: Cell<bool>,
    phone_budgets: RefCell<HashMap<String, FrameBudget>>,
}

impl DurableObject for Relay {
    fn new(state: State, _env: Env) -> Self {
        if let Ok(heartbeat) = WebSocketRequestResponsePair::new("ping", "pong") {
            state.set_websocket_auto_response(&heartbeat);
        }
        Self {
            state,
            schema_ready: Cell::new(false),
            phone_budgets: RefCell::new(HashMap::new()),
        }
    }

    async fn fetch(&self, req: Request) -> Result<Response> {
        match self.handle(&req) {
            Ok(response) => Ok(response),
            Err(_) => {
                console_error!("Opscode relay request failed");
                failure(500, "relay_unavailable")
            }
        }
    }

    async fn websocket_message(
        &self,
        socket: WebSocket,
        message: WebSocketIncomingMessage,
    ) -> Result<()> {
        if socket.as_ref().ready_state() != BrowserSocket::OPEN {
            return Ok(());
        }
        let Some(peer) = socket.deserialize_attachment::<Peer>()? else {
            return socket.close(Some(1008), Some("Unknown peer"));
        };
        let WebSocketIncomingMessage::Binary(bytes) = message else {
            return socket.close(Some(1003), Some("Expected binary"));
        };

        match peer {
            Peer::Mac => {
                if bytes.len() > MAX_PAYLOAD + protocol::HEADER_SIZE {
                    return socket.close(Some(1009), Some("Frame too large"));
                }
                let Some((device, payload)) = decode_frame(&bytes) else {
                    return socket.close(Some(1002), Some("Invalid routing frame"));
                };
                if !self.forward(&device, payload) {
                    let _ =
                        socket.send(&json!({ "type": "relay.unavailable", "device_id": device }));
                }
            }
            Peer::Phone(device) => {
                if bytes.len() > MAX_PAYLOAD {
                    return socket.close(Some(1009), Some("Frame too large"));
                }
                if bytes.is_empty() {
                    return socket.close(Some(1002), Some("Empty frame"));
                }
                if !self
                    .phone_budgets
                    .borrow_mut()
                    .entry(device.clone())
                    .or_default()
                    .allows(now(), bytes.len())
                {
                    return socket.close(Some(CLOSE_RATE_LIMITED), Some("Frame rate exceeded"));
                }
                let Some(routed) = frame(&device, &bytes) else {
                    return socket.close(Some(1008), Some("Invalid device"));
                };
                if !self.forward(MAC_TAG, &routed) {
                    let _ = socket.send(&json!({ "type": "relay.unavailable", "peer": MAC_TAG }));
                }
            }
        }
        Ok(())
    }

    async fn websocket_close(
        &self,
        socket: WebSocket,
        code: usize,
        _reason: String,
        _was_clean: bool,
    ) -> Result<()> {
        // Acknowledge a pending close. Abnormal transport loss has no Close frame.
        if socket.as_ref().ready_state() == BrowserSocket::CLOSING && code != 1006 {
            let reply = ((1000..5000).contains(&code) && !matches!(code, 1004 | 1005 | 1015))
                .then_some(code as u16);
            let _ = socket.close::<&str>(reply, None);
        }
        self.disconnected(&socket)
    }

    async fn websocket_error(&self, socket: WebSocket, _error: worker::Error) -> Result<()> {
        let _ = socket.close(Some(1011), Some("Connection failed"));
        Ok(())
    }
}

impl Relay {
    fn handle(&self, req: &Request) -> Result<Response> {
        let path = req.path();
        let Some(route) = Route::parse(req.method(), &path) else {
            return failure(404, "not_found");
        };
        // This Durable Object is reachable only through the Worker binding.
        // The public Worker authenticates all Mac routes before forwarding.
        match route {
            Route::Invite => self.invite(),
            Route::Devices => self.devices(),
            Route::Revoke(id) => self.revoke(id),
            Route::Mac => self.join(Peer::Mac),
            Route::Pair | Route::Phone | Route::Disconnect => {
                let header = req.headers().get("authorization")?.unwrap_or_default();
                let Some(token) = bearer(&header) else {
                    return failure(401, "unauthorized");
                };
                if matches!(route, Route::Pair) {
                    return self.pair(token);
                }
                let Some(id) = self.authenticate_phone(token)? else {
                    return failure(401, "unauthorized");
                };
                if matches!(route, Route::Disconnect) {
                    return self.revoke(&id);
                }
                self.join(Peer::Phone(id))
            }
            Route::Health => failure(404, "not_found"),
        }
    }

    fn db(&self) -> Result<SqlStorage> {
        let db = self.state.storage().sql();
        if !self.schema_ready.get() {
            db.exec(
                "CREATE TABLE IF NOT EXISTS invite (
                    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                    token_digest TEXT NOT NULL,
                    expires_at_ms INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS devices (
                    device_id TEXT PRIMARY KEY,
                    token_digest TEXT NOT NULL,
                    paired_at_ms INTEGER NOT NULL
                );
                CREATE TRIGGER IF NOT EXISTS consume_invite AFTER INSERT ON devices
                BEGIN DELETE FROM invite WHERE singleton = 1; END;",
                None,
            )?;
            self.schema_ready.set(true);
        }
        Ok(db)
    }

    fn invite(&self) -> Result<Response> {
        let token = random_hex::<TOKEN_BYTES>()?;
        let expires_at_ms = now() + INVITE_LIFETIME_MS;
        self.db()?.exec(
            "INSERT OR REPLACE INTO invite (singleton, token_digest, expires_at_ms) VALUES (1, ?, ?)",
            vec![digest(&token).into(), (expires_at_ms as i64).into()],
        )?;
        respond(
            201,
            json!({ "token": token, "expires_at_ms": expires_at_ms }),
        )
    }

    fn pair(&self, token: &str) -> Result<Response> {
        if !valid_hex(token, TOKEN_BYTES) {
            return failure(401, "invalid_invite");
        }
        let db = self.db()?;
        let time = now();
        let invite = db
            .exec(
                "SELECT token_digest, expires_at_ms FROM invite WHERE singleton = 1",
                None,
            )?
            .next::<Invite>()
            .next()
            .transpose()?;
        if !invite.is_some_and(|invite| {
            invite.expires_at_ms > time && matches_digest(token, &invite.token_digest)
        }) {
            return failure(401, "invalid_invite");
        }
        let count: DeviceCount = db
            .exec("SELECT COUNT(*) AS total FROM devices", None)?
            .one()?;
        if count.total >= MAX_PHONES {
            return failure(409, "device_limit");
        }
        // No async boundary between validating the invite and inserting the device.
        // The SQLite trigger consumes the invite in the same write.
        let id = random_hex::<DEVICE_ID_BYTES>()?;
        let secret = random_hex::<TOKEN_BYTES>()?;
        db.exec(
            "INSERT INTO devices (device_id, token_digest, paired_at_ms) VALUES (?, ?, ?)",
            vec![
                id.as_str().into(),
                digest(&secret).into(),
                (time as i64).into(),
            ],
        )?;
        respond(
            201,
            json!({ "device_id": id, "token": format!("{id}.{secret}") }),
        )
    }

    fn authenticate_phone(&self, token: &str) -> Result<Option<String>> {
        let Some((id, secret)) = phone_token(token) else {
            return Ok(None);
        };
        let credential = self
            .db()?
            .exec(
                "SELECT token_digest FROM devices WHERE device_id = ?",
                vec![id.into()],
            )?
            .next::<StoredCredential>()
            .next()
            .transpose()?;
        Ok(credential
            .filter(|record| matches_digest(secret, &record.token_digest))
            .map(|_| id.to_owned()))
    }

    fn devices(&self) -> Result<Response> {
        let rows = self.db()?.exec(
            "SELECT device_id, paired_at_ms FROM devices ORDER BY paired_at_ms, device_id",
            None,
        )?;
        let devices = rows
            .next::<StoredDevice>()
            .map(|row| {
                let row = row?;
                Ok(json!({
                    "device_id": row.device_id,
                    "paired_at_ms": row.paired_at_ms,
                    "online": !self.open_sockets(&row.device_id).is_empty(),
                }))
            })
            .collect::<Result<Vec<_>>>()?;
        respond(200, json!({ "devices": devices }))
    }

    fn revoke(&self, id: &str) -> Result<Response> {
        let removed = self
            .db()?
            .exec("DELETE FROM devices WHERE device_id = ?", vec![id.into()])?
            .rows_written();
        self.phone_budgets.borrow_mut().remove(id);
        for socket in self.open_sockets(id) {
            let _ = socket.close(Some(CLOSE_REVOKED), Some("Device revoked"));
        }
        respond(200, json!({ "revoked": removed > 0 }))
    }

    fn join(&self, peer: Peer) -> Result<Response> {
        let tag = peer.tag();
        let previous = self.open_sockets(tag);
        let tags = match &peer {
            Peer::Mac => vec![MAC_TAG],
            Peer::Phone(_) => vec![PHONE_TAG, tag],
        };
        let pair = WebSocketPair::new()?;
        self.state.accept_websocket_with_tags(&pair.server, &tags);
        pair.server.serialize_attachment(&peer)?;

        let ready = match &peer {
            Peer::Mac => {
                let phone_ids = self
                    .open_sockets(PHONE_TAG)
                    .into_iter()
                    .filter_map(|ws| match ws.deserialize_attachment::<Peer>() {
                        Ok(Some(Peer::Phone(id))) => Some(id),
                        _ => None,
                    })
                    .collect::<Vec<_>>();
                json!({ "type": "relay.ready", "protocol": VERSION, "online_phone_ids": phone_ids })
            }
            Peer::Phone(_) => {
                json!({ "type": "relay.ready", "protocol": VERSION, "mac_online": !self.open_sockets(MAC_TAG).is_empty() })
            }
        };
        pair.server.send(&ready)?;
        for old in &previous {
            let _ = old.close(Some(CLOSE_REPLACED), Some("Connection replaced"));
        }
        // A replacement Mac starts with a fresh in-memory app session. Tell connected phones
        // to establish a new encrypted session even when the prior Mac socket was still open.
        if previous.is_empty() || matches!(peer, Peer::Mac) {
            self.presence(&peer, true);
        }
        Response::from_websocket(pair.client)
    }

    fn disconnected(&self, socket: &WebSocket) -> Result<()> {
        let Some(peer) = socket.deserialize_attachment::<Peer>()? else {
            return Ok(());
        };
        if !self
            .open_sockets(peer.tag())
            .iter()
            .any(|current| current != socket)
        {
            self.presence(&peer, false);
        }
        Ok(())
    }

    fn presence(&self, peer: &Peer, online: bool) {
        let (tag, event) = match peer {
            Peer::Mac => (
                PHONE_TAG,
                json!({ "type": "relay.presence", "peer": MAC_TAG, "online": online }),
            ),
            Peer::Phone(id) => (
                MAC_TAG,
                json!({ "type": "relay.presence", "peer": PHONE_TAG, "device_id": id, "online": online }),
            ),
        };
        for target in self.open_sockets(tag) {
            let _ = target.send(&event);
        }
    }

    fn open_sockets(&self, tag: &str) -> Vec<WebSocket> {
        self.state
            .get_websockets_with_tag(tag)
            .into_iter()
            .filter(|socket| socket.as_ref().ready_state() == BrowserSocket::OPEN)
            .collect()
    }

    fn forward(&self, tag: &str, bytes: &[u8]) -> bool {
        self.state
            .get_websockets_with_tag(tag)
            .into_iter()
            .any(|socket| {
                socket.as_ref().ready_state() == BrowserSocket::OPEN
                    && socket.send_with_bytes(bytes).is_ok()
            })
    }
}

fn now() -> u64 {
    js_sys::Date::now() as u64
}

fn random_hex<const N: usize>() -> Result<String> {
    let global: WorkerGlobalScope = js_sys::global().unchecked_into();
    let mut bytes = [0_u8; N];
    global
        .crypto()?
        .get_random_values_with_u8_array(&mut bytes)?;
    Ok(hex::encode(bytes))
}

fn bearer(header: &str) -> Option<&str> {
    let (scheme, token) = header.split_once(' ')?;
    scheme.eq_ignore_ascii_case("bearer").then_some(token)
}

fn phone_token(token: &str) -> Option<(&str, &str)> {
    let (id, secret) = token.split_once('.')?;
    (valid_hex(id, DEVICE_ID_BYTES) && valid_hex(secret, TOKEN_BYTES)).then_some((id, secret))
}

fn websocket_upgrade(req: &Request) -> Result<bool> {
    Ok(req
        .headers()
        .get("upgrade")?
        .is_some_and(|value| value.eq_ignore_ascii_case("websocket")))
}

fn respond(status: u16, body: Value) -> Result<Response> {
    let mut response = Response::from_json(&body)?.with_status(status);
    response.headers_mut().set("Cache-Control", "no-store")?;
    Ok(response)
}

fn failure(status: u16, code: &str) -> Result<Response> {
    respond(status, json!({ "error": code }))
}
