# Opscode: early build log (phases 1 to 5)

> This is the original README, kept as history. The current overview is [../../README.md](../../README.md).

A desktop coding-agent shell, built from scratch. Original app: it reuses the
general *architecture* studied in private research notes (Electron shell +
local runtime + WebSocket JSON-RPC), but its own name, code, design, and assets.

> **Working name.** "Opscode" is a placeholder (from the project folder). Change
> it in `package.json` (`name`, `productName`), `APP_SCHEME` + channel prefix in
> `src/shared/ipc.ts`, and `SUBPROTOCOL` in `src/shared/protocol.ts` +
> `src/renderer/rpc.js`.

## Status

### Phase 1 — Electron shell ✅
- **Privileged scheme** `opscode://app/` serving `dist/renderer` with a strict CSP,
  path-traversal containment, `nosniff`, `X-Frame-Options: DENY`.
- **Hardened window** — `sandbox`, `contextIsolation`, `nodeIntegration: false`;
  navigation locked to the app origin; external links to the OS browser;
  `<webview>` forced into an isolated partition with no preload.
- **Sender-gated IPC** — every handler checks `isOwnFrame(senderFrame.url)`.
- **contextBridge preload** exposing a small typed `window.opscode`. Bundled with
  esbuild, because a sandboxed preload cannot `require` local files.

### Phase 2 — Local runtime + WebSocket JSON-RPC ✅
- **Supervisor** (`src/main/runtime.ts`) — free loopback port + 32-byte token per
  launch; spawns the runtime (Electron binary in Node mode for dev); passes the
  bootstrap **on fd 3 only** (never argv/env); waits for a READY line; restarts
  with backoff (gives up after 5 crashes/min); stops the whole process group on quit.
  The runtime also exits by itself if the app process disappears.
- **Runtime** (`src/runtime/`) — `ws://127.0.0.1:<port>/session/v1`. Upgrade is
  refused unless path, **Origin** (`opscode://app` or none) and **bearer token**
  (header, or `base64url.bearer.` subprotocol for browsers; constant-time compare)
  all check out. Only the `opscode.session.v1` subprotocol is echoed.
- **Protocol** (`src/shared/protocol.ts`) — `runtime.hello` handshake (revision
  gate) before any other call; JSON-RPC-style requests, error codes
  (`-32700/-32600/-32601/-32602/-32603/-32002/-32003`), server-push notifications,
  2 MiB frame cap.
- **Methods so far** — `runtime.hello`, `runtime.ping`, `settings.get`,
  `settings.set` (validated, persisted atomically to a `0600` file in a `0700`
  state dir, broadcast as `settings.changed` to every session).
- **Clients** — main (`src/main/rpcClient.ts`, Authorization header) and renderer
  (`src/renderer/rpc.js`, subprotocol token, auto-reconnect with backoff).
- **UI** — titlebar runtime status, runtime facts, RPC ping, settings form; the
  theme toggle round-trips through the runtime.

**Improvement over the researched app:** its session socket authorized on the
token alone. Ours also pins `Origin`, so a token leak to a web page is not enough.

### Phase 3 — Core methods ✅
- **Workspaces** (`src/runtime/workspaces.ts`) — `workspace.add/list/remove`;
  stored by real path (deduplicated), persisted `0600`, `workspace.changed` pushed
  to every window. Refuses relative paths, files, and `/`.
- **Files, sandboxed to the project** (`src/runtime/paths.ts`, `files.ts`) —
  `fs.list/read/write`. Every path is client-relative and checked twice: the
  lexical join must stay inside the project (blocks `../`), and so must the
  realpath (blocks symlinks pointing out). Writes are refused under any `.git`
  segment and onto broken symlinks; inside-symlinks are written through. Writes
  are atomic (`O_EXCL|O_NOFOLLOW` temp file + rename) and keep file modes. Reads
  detect binary (→ base64), support `max_bytes`, and are capped at 1 MiB.
- **Terminals — real PTYs** (`src/runtime/terminals.ts`, node-pty 1.1.0) —
  `term.open/write/resize/attach/detach/close/list`. Login shell (or a command) in
  the project folder; output batched and sent only to attached windows; 256 KB
  scrollback for re-attach; keep running across window reloads; capped at 32;
  `ELECTRON_RUN_AS_NODE` is stripped from their environment; all are killed when
  the runtime stops or the project is removed.
- **Chat turns** (`src/runtime/turns.ts`) — `turn.submit/interrupt/history`,
  streamed as `turn.event` (`started → delta* → completed | interrupted | failed`),
  one turn per project. **The engine is a stub (`echo`)** behind an `Engine`
  interface; Phase 5 plugs the real agent in. Transcripts are in memory for now.
- **UI** — sidebar project list (add via native picker, remove), Files panel with
  breadcrumbs and a text preview.
- **Native-module note** — node-pty 1.1.0's macOS `spawn-helper` ships without
  the execute bit (terminals fail with `posix_spawnp failed`);
  `scripts/ensure-native.mjs` fixes it on install and on every build.

Next: Phase 4 — the real UI (chat, terminal, diff, file surfaces) in our own design.

## Run

```bash
npm install
npm start            # build + open the window
npm test             # 22 protocol + 79 Phase 3 checks against the runtime (plain Node)
npm run smoke        # headless end-to-end in Electron, throwaway profile:
                     # load, main + renderer RPC, crash recovery, PTY, Files panel
```

## Layout

```
src/
  shared/
    ipc.ts           scheme/origin, IPC channels, isOwnFrame, shared types
    protocol.ts      session protocol constants, frames, error codes, settings
  main/
    index.ts         lifecycle, supervisor wiring, shutdown, smoke mode
    scheme.ts        privileged scheme + CSP asset server
    window.ts        hardened BrowserWindow + webview/nav/popup gates
    ipc.ts           sender-gated IPC handlers (RUNTIME hands out the endpoint)
    runtime.ts       RuntimeSupervisor (spawn, fd3 bootstrap, restart, stop)
    rpcClient.ts     Node session client for main
  runtime/
    index.ts         entry: fd3 bootstrap, parent watch, SIGTERM, shutdown
    server.ts        HTTP + WS upgrade auth (path, Origin, token), dispatch, hub
    rpc.ts           failures, method wrapper, param schema (object/str/int/...)
    methods.ts       method registry (runtime/settings/workspace/fs/term/turn)
    settings.ts      settings store (validated, atomic, 0600)
    workspaces.ts    project store
    paths.ts         project-sandbox path resolution (the security boundary)
    files.ts         fs.list/read/write
    terminals.ts     PTY terminal manager
    turns.ts         turn manager + Engine interface + EchoEngine stub
    jsonFile.ts      private dir + atomic JSON
  preload/index.ts   contextBridge -> window.opscode (bundled by esbuild)
  renderer/          index.html, styles.css, app.js, rpc.js
scripts/
  copy-renderer.mjs  build step
  ensure-native.mjs  fixes node-pty spawn-helper exec bit (postinstall + build)
  smoke.mjs          runs the Electron smoke with a wrapper-owned temp profile
  lib/harness.mjs    test harness (spawn runtime via fd3, clients)
  test-runtime.mjs   Phase 2 protocol suite
  test-phase3.mjs    Phase 3 suite (workspaces, fs escapes, PTY, turns)
```
