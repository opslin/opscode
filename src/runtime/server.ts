// HTTP server on loopback with one WebSocket endpoint: /session/v1.
// Upgrade is refused unless the path, Origin and bearer token all check out.
// After upgrade, frames are JSON requests dispatched to the method registry.

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import type { Duplex } from "node:stream";
import WebSocket, { WebSocketServer, type RawData } from "ws";
import {
  ALLOWED_ORIGINS,
  BEARER_PREFIX,
  ErrorCode,
  MAX_FRAME_BYTES,
  SESSION_PATH,
  SUBPROTOCOL,
  type Bootstrap,
  type RequestId,
  type RpcNotification,
  type RpcResponse,
} from "../shared/protocol";
import { RpcFailure, type AnyMethod, type CallContext } from "./methods";

export type Log = (line: string) => void;

/** Token from `Authorization: Bearer` (Node clients) or the bearer subprotocol (browsers). */
export function bearerOf(req: IncomingMessage): string | undefined {
  const auth = req.headers.authorization;
  if (auth?.startsWith("Bearer ")) return auth.slice(7).trim();
  const offered = (req.headers["sec-websocket-protocol"] ?? "")
    .split(",")
    .map((p) => p.trim())
    .find((p) => p.startsWith(BEARER_PREFIX));
  return offered ? Buffer.from(offered.slice(BEARER_PREFIX.length), "base64url").toString("utf8") : undefined;
}

/** Constant-time comparison on equal-length buffers. */
export function sameToken(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/** No Origin = non-browser client (allowed); otherwise it must be the app's own. */
export const originAllowed = (origin: string | undefined): boolean =>
  origin === undefined || ALLOWED_ORIGINS.includes(origin);

function refuse(socket: Duplex, status: number, reason: string): void {
  socket.write(`HTTP/1.1 ${status} ${reason}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
  socket.destroy();
}

interface Session {
  ws: WebSocket;
  ctx: CallContext & { helloed: boolean };
}

export interface RunningServer {
  port: number;
  broadcast(notification: RpcNotification): void;
  close(): Promise<void>;
}

/** What method implementations may use to reach clients. */
export interface Hub {
  /** To every session that completed hello. */
  broadcast(notification: RpcNotification): void;
  /** To one session (no-op if it is gone or has not said hello). */
  notify(sessionId: string, notification: RpcNotification): void;
  /** Called with a session id when its socket closes. */
  onSessionClosed(listener: (sessionId: string) => void): void;
  /** Serves one plain-HTTP path (the handler does its own authentication). */
  onHttp(path: string, handler: (req: IncomingMessage, res: ServerResponse) => void): void;
}

export function startServer(
  boot: Bootstrap,
  methodsFor: (hub: Hub) => Map<string, AnyMethod>,
  log: Log,
): Promise<RunningServer> {
  const sessions = new Map<string, Session>();
  const closedListeners: Array<(sessionId: string) => void> = [];
  const httpRoutes = new Map<string, (req: IncomingMessage, res: ServerResponse) => void>();

  const deliver = (s: Session, frame: string): void => {
    if (s.ctx.helloed && s.ws.readyState === WebSocket.OPEN) s.ws.send(frame);
  };
  const broadcast = (notification: RpcNotification): void => {
    const frame = JSON.stringify(notification);
    for (const s of sessions.values()) deliver(s, frame);
  };
  const hub: Hub = {
    broadcast,
    notify(sessionId, notification) {
      const s = sessions.get(sessionId);
      if (s) deliver(s, JSON.stringify(notification));
    },
    onSessionClosed(listener) {
      closedListeners.push(listener);
    },
    onHttp(path, handler) {
      httpRoutes.set(path, handler);
    },
  };
  const methods = methodsFor(hub);

  const http = createServer((req, res) => {
    const route = httpRoutes.get(new URL(req.url ?? "/", "http://127.0.0.1").pathname);
    if (route) return route(req, res);
    // Otherwise plain HTTP is not part of the surface; say nothing useful.
    res.statusCode = req.url?.startsWith(SESSION_PATH) ? 426 : 404;
    res.end();
  });

  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: MAX_FRAME_BYTES,
    perMessageDeflate: false,
    // Echo only our subprotocol, never the bearer entry.
    handleProtocols: (protocols) => (protocols.has(SUBPROTOCOL) ? SUBPROTOCOL : false),
  });

  http.on("upgrade", (req, socket, head) => {
    const path = new URL(req.url ?? "/", "http://127.0.0.1").pathname;
    if (path !== SESSION_PATH) return refuse(socket, 404, "Not Found");
    if (!originAllowed(req.headers.origin)) {
      log(`refused upgrade: origin ${JSON.stringify(req.headers.origin)}`);
      return refuse(socket, 403, "Forbidden");
    }
    const bearer = bearerOf(req);
    if (bearer === undefined || !sameToken(bearer, boot.token)) return refuse(socket, 401, "Unauthorized");
    wss.handleUpgrade(req, socket, head, (ws) => onConnection(ws));
  });

  function send(ws: WebSocket, frame: RpcResponse): void {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(frame));
  }

  function onConnection(ws: WebSocket): void {
    const session: Session = {
      ws,
      ctx: {
        sessionId: randomUUID(),
        helloed: false,
        markHello() {
          session.ctx.helloed = true;
        },
      },
    };
    sessions.set(session.ctx.sessionId, session);
    log(`session ${session.ctx.sessionId} opened (${sessions.size} open)`);

    ws.on("message", (data: RawData, isBinary: boolean) => void onFrame(session, data, isBinary));
    ws.on("close", () => {
      sessions.delete(session.ctx.sessionId);
      log(`session ${session.ctx.sessionId} closed (${sessions.size} open)`);
      for (const listener of closedListeners) {
        try {
          listener(session.ctx.sessionId);
        } catch (err) {
          log(`session-closed listener failed: ${err instanceof Error ? err.message : String(err)}`);
        }
      }
    });
    ws.on("error", (err) => log(`session ${session.ctx.sessionId} error: ${err.message}`));
  }

  async function onFrame(session: Session, data: RawData, isBinary: boolean): Promise<void> {
    const { ws, ctx } = session;
    if (isBinary) {
      return send(ws, { id: null, error: { code: ErrorCode.INVALID_REQUEST, message: "binary frames are not supported" } });
    }

    let msg: unknown;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return send(ws, { id: null, error: { code: ErrorCode.PARSE_ERROR, message: "invalid JSON" } });
    }

    if (typeof msg !== "object" || msg === null) {
      return send(ws, { id: null, error: { code: ErrorCode.INVALID_REQUEST, message: "expected { id, method, params? }" } });
    }
    const req = msg as { id?: unknown; method?: unknown; params?: unknown };
    const validId = typeof req.id === "number" || typeof req.id === "string";
    if (!validId || typeof req.method !== "string") {
      return send(ws, {
        id: validId ? (req.id as RequestId) : null,
        error: { code: ErrorCode.INVALID_REQUEST, message: "expected { id, method, params? }" },
      });
    }
    const id = req.id as RequestId;

    const handler = methods.get(req.method);
    if (!handler) {
      return send(ws, { id, error: { code: ErrorCode.METHOD_NOT_FOUND, message: `unknown method ${req.method}` } });
    }
    if (handler.requiresHello && !ctx.helloed) {
      return send(ws, { id, error: { code: ErrorCode.HELLO_REQUIRED, message: "call runtime.hello first" } });
    }

    try {
      const result = await handler.handle(req.params, ctx);
      send(ws, { id, result });
    } catch (err) {
      if (err instanceof RpcFailure) {
        send(ws, { id, error: { code: err.code, message: err.message, ...(err.data === undefined ? {} : { data: err.data }) } });
      } else {
        log(`method ${req.method} failed: ${err instanceof Error ? err.stack ?? err.message : String(err)}`);
        send(ws, { id, error: { code: ErrorCode.INTERNAL, message: "internal error" } });
      }
    }
  }

  return new Promise((resolve, reject) => {
    http.once("error", reject);
    http.listen(boot.port, boot.host, () => {
      http.off("error", reject);
      const address = http.address();
      const port = typeof address === "object" && address ? address.port : boot.port;
      resolve({
        port,
        broadcast,
        close: () =>
          new Promise<void>((done) => {
            for (const s of sessions.values()) s.ws.close(1001, "runtime stopping");
            for (const client of wss.clients) client.terminate();
            wss.close();
            http.close(() => done());
            http.closeAllConnections?.();
          }),
      });
    });
  });
}
