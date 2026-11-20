# Opscode public relay

This Cloudflare Worker connects one Mac with up to 16 paired phones over the public internet. Rust handles authentication, pairing, and binary WebSocket routing. A SQLite-backed Durable Object stores device credential digests and manages hibernatable connections. The Mac runs Whisper, Kitten, chat, and coding workers.

## Run it locally

Install Node.js 22.12 or newer, Rust 1.91 or newer, the `wasm32-unknown-unknown` target, and `wasm-bindgen-cli` matching the version in `Cargo.lock` (currently 0.2.130). The [wasm-bindgen release](https://github.com/wasm-bindgen/wasm-bindgen/releases/tag/0.2.130) has prebuilt binaries. Run these commands from this directory.

```sh
rustup target add wasm32-unknown-unknown
# Use a disposable local credential and storage for the integration test.
umask 077
test -f .dev.vars || printf 'OPSCODE_MAC_TOKEN=%s\n' "$(openssl rand -hex 32)" > .dev.vars
WRANGLER_SEND_METRICS=false npx wrangler@4.165.0 dev --local
```

In a second terminal, run the test from this directory after installing the repository’s npm dependencies. It pairs and revokes temporary devices in the local relay.

```sh
OPSCODE_TEST_MAC_TOKEN="$(sed -n 's/^OPSCODE_MAC_TOKEN=//p' .dev.vars)" node --test tests/relay.mjs
```

The suite tests single-use pairing under concurrency, credential isolation, device revocation, transport loss, and traffic limits. The stress case sends one 640-byte frame every 20 ms from each of 16 phones. It verifies ordered delivery in both directions for 9,600 round trips and reports relay echo percentiles and reconnect time. Measure voice latency again on cellular after integrating the Mac and Android clients.

## HTTP API

Use HTTPS for the public deployment and send the credential in the `Authorization: Bearer …` header. Requests can use empty bodies.

| Request | Credential | Result |
| --- | --- | --- |
| `GET /health` | Public | Protocol version |
| `POST /v1/invite` | Mac | New single-use invitation with a two-minute expiry. Replaces the previous invitation. |
| `POST /v1/pair` | Invitation | Paired device ID and its phone credential |
| `GET /v1/devices` | Mac | Paired devices and connection state |
| `DELETE /v1/devices/{id}` | Mac | Revokes the credential and closes its active connection |
| `DELETE /v1/device` | Phone | Revokes only the calling phone’s credential and closes its active connection |
| `GET /v1/socket/mac` | Mac | Upgrades to a WebSocket |
| `GET /v1/socket/phone` | Phone | Upgrades to a WebSocket |

The Mac credential is the 32-byte hex `OPSCODE_MAC_TOKEN` secret configured for the Worker. The Android client should keep its issued credential in Keystore-backed storage. Use a one-time invitation for the QR or pairing link. Keep the Mac secret on the Mac.

## WebSocket protocol

- On connection, the relay sends a JSON `relay.ready` event with `protocol: 1`. The phone receives `mac_online` and the Mac receives `online_phone_ids`.
- The relay sends `relay.presence` when a peer connects or disconnects, including when a new Mac socket replaces an existing one. Events include `peer` and `online`, plus `device_id` for a phone. A text `ping` returns `pong` without waking the Durable Object.
- The phone sends binary payloads as-is. The Mac sends and receives a binary frame with one version byte (`0x01`), the 16 raw bytes of the phone ID, then the payload. The relay adds the routing header on the way to the Mac and removes it on the way to the phone. Payloads must be between 1 and 65,536 bytes.
- If the destination is offline, the sender receives `relay.unavailable`. The relay keeps no payload backlog. The latest connection for a peer replaces its earlier connection with close code `4001`. Revocation closes it with `4003`.
- The edge rate-limits pairing and phone upgrade requests, with separate per-IP counters for each route. On HTTP `429`, honor `Retry-After`. An active phone has a refillable budget of 120 frames and 512 KiB per second with one second of burst capacity. Excess traffic closes that phone with `4029`. A normal voice stream at 20 ms per frame needs 50 frames per second.
- Reopen a disconnected WebSocket using the saved credential. The Mac and Android clients establish a fresh encrypted session using the key from the pairing QR and send the current activity snapshot after reconnecting. Cloudflare terminates the outer HTTPS and WSS connections. Approval details, snapshots and decisions are encrypted inside the binary frames.

## Deploy and integrate

The Wrangler config declares the SQLite Durable Object migration and the Opscode custom domain, `https://relay.shotlin.in`. Use this HTTPS base URL in both clients and the same hostname with WSS for WebSocket connections. Use `npx wrangler@4.165.0 deploy --dry-run` to validate the bundle without publishing it. For a hosted installation, deploy with the intended Cloudflare account and set `OPSCODE_MAC_TOKEN` through Wrangler’s secret store.

1. Connect the Mac app to the relay and issue invitations from Settings. Replace the Android pairing entry with the relay URL and phone credential. Reopen the app on mobile data and confirm a pending task without a new QR.
2. Route approvals and project chat through a scoped Mac API. Resume from the last confirmed update and use unique action IDs so retries apply once.
3. Add the Voice Mode session and binary audio frames. Send files using a separate resumable transfer. The Mac continues to run transcription, synthesis, and coding.
