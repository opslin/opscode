// Browser-side session client. Mirrors src/shared/protocol.ts by hand (the
// renderer is plain ES modules, not compiled TS).
//
// Browsers cannot set an Authorization header on a WebSocket, so the token is
// offered as a second subprotocol ("base64url.bearer.<token>"); the runtime
// echoes only "opscode.session.v1". The page's Origin (opscode://app) is
// checked server-side too.

const SUBPROTOCOL = "opscode.session.v1";
const BEARER_PREFIX = "base64url.bearer.";
const CLIENT_REVISION = 1;

const base64url = (s) => btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/** Error carrying the protocol error code. */
export class RpcError extends Error {
  constructor(code, message, data) {
    super(message);
    this.code = code;
    this.data = data;
  }
}

/**
 * Opens a self-healing session: connects, completes runtime.hello, and
 * reconnects with backoff when the socket drops (e.g. runtime restart).
 * States: "connecting" -> "ready" -> "offline" -> "connecting" ... ; "closed".
 */
export function connectRuntime(endpoint, { onState } = {}) {
  let ws = null;
  let state = "connecting";
  let hello = null;
  let closed = false;
  let delay = 250;
  let nextId = 1;
  const pending = new Map();
  const listeners = new Map();
  const readyWaiters = [];

  const setState = (next) => {
    state = next;
    onState?.(state, hello);
    if (state === "ready") readyWaiters.splice(0).forEach((w) => w.resolve());
  };

  function rawCall(method, params, timeoutMs = 10_000) {
    return new Promise((resolve, reject) => {
      if (!ws || ws.readyState !== WebSocket.OPEN) return reject(new Error("not connected"));
      const id = nextId++;
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`${method} timed out`));
      }, timeoutMs);
      pending.set(id, { resolve, reject, timer });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  function open() {
    if (closed) return;
    setState("connecting");
    const socket = new WebSocket(endpoint.url, [SUBPROTOCOL, BEARER_PREFIX + base64url(endpoint.token)]);
    ws = socket;

    socket.onopen = async () => {
      delay = 250;
      try {
        hello = await rawCall("runtime.hello", { client_revision: CLIENT_REVISION });
        setState("ready");
      } catch {
        socket.close();
      }
    };

    socket.onmessage = (event) => {
      let msg;
      try {
        msg = JSON.parse(event.data);
      } catch {
        return;
      }
      if (msg.id !== undefined && msg.id !== null && pending.has(msg.id)) {
        const p = pending.get(msg.id);
        pending.delete(msg.id);
        clearTimeout(p.timer);
        if (msg.error) p.reject(new RpcError(msg.error.code, msg.error.message, msg.error.data));
        else p.resolve(msg.result);
      } else if (typeof msg.method === "string") {
        for (const fn of listeners.get(msg.method) ?? []) {
          try {
            fn(msg.params);
          } catch (err) {
            console.error(`listener for ${msg.method} threw`, err);
          }
        }
      }
    };

    socket.onclose = () => {
      for (const p of pending.values()) {
        clearTimeout(p.timer);
        p.reject(new Error("connection closed"));
      }
      pending.clear();
      if (closed) return;
      setState("offline");
      setTimeout(open, delay);
      delay = Math.min(delay * 2, 5000);
    };
  }

  // Defer the first connect so the caller has the returned handle before any
  // onState callback runs (a synchronous callback would hit the caller's TDZ).
  queueMicrotask(open);

  return {
    get state() {
      return state;
    },
    get hello() {
      return hello;
    },
    /** Waits for "ready", then calls. */
    async call(method, params = {}, { timeoutMs } = {}) {
      if (state !== "ready") await new Promise((resolve, reject) => readyWaiters.push({ resolve, reject }));
      return rawCall(method, params, timeoutMs);
    },
    /** Subscribes to a server notification; returns an unsubscribe function. */
    on(method, fn) {
      if (!listeners.has(method)) listeners.set(method, new Set());
      listeners.get(method).add(fn);
      return () => listeners.get(method)?.delete(fn);
    },
    close() {
      closed = true;
      setState("closed");
      ws?.close();
    },
  };
}
