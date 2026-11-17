// Minimal Node-side session client for main (smoke checks now; later, main's
// own calls such as quit-time checks). Authenticates with an Authorization
// header and sends no Origin, which the runtime treats as a non-browser client.

import WebSocket, { type RawData } from "ws";
import { PROTOCOL_REVISION, SUBPROTOCOL, type Hello, type RpcResponse } from "../shared/protocol";
import type { Endpoint } from "./runtime";

interface Pending {
  resolve(value: unknown): void;
  reject(err: Error): void;
  timer: NodeJS.Timeout;
}

export class RpcCallError extends Error {
  constructor(
    readonly code: number,
    message: string,
    readonly data?: unknown,
  ) {
    super(message);
  }
}

export class MainRpcClient {
  private ws: WebSocket | undefined;
  private nextId = 1;
  private readonly pending = new Map<number, Pending>();
  private readonly listeners = new Map<string, Set<(params: unknown) => void>>();

  constructor(private readonly endpoint: Endpoint) {}

  /** Subscribe to a server notification; returns an unsubscribe function. */
  on<P = unknown>(method: string, fn: (params: P) => void): () => void {
    const set = this.listeners.get(method) ?? new Set();
    set.add(fn as (params: unknown) => void);
    this.listeners.set(method, set);
    return () => set.delete(fn as (params: unknown) => void);
  }

  /** Connects and completes the hello handshake. */
  async open(): Promise<Hello> {
    const ws = new WebSocket(this.endpoint.url, [SUBPROTOCOL], {
      headers: { authorization: `Bearer ${this.endpoint.token}` },
    });
    this.ws = ws;
    await new Promise<void>((resolve, reject) => {
      ws.once("open", () => resolve());
      ws.once("error", reject);
      ws.once("unexpected-response", (_req, res) => reject(new Error(`upgrade refused: HTTP ${res.statusCode}`)));
    });
    ws.on("message", (data: RawData) => this.onMessage(data));
    ws.on("close", () => {
      for (const p of this.pending.values()) {
        clearTimeout(p.timer);
        p.reject(new Error("connection closed"));
      }
      this.pending.clear();
    });
    return this.call<Hello>("runtime.hello", { client_revision: PROTOCOL_REVISION });
  }

  call<T = unknown>(method: string, params: unknown = {}, timeoutMs = 10_000): Promise<T> {
    const ws = this.ws;
    if (!ws || ws.readyState !== WebSocket.OPEN) return Promise.reject(new Error("not connected"));
    const id = this.nextId++;
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} timed out`));
      }, timeoutMs);
      this.pending.set(id, { resolve: resolve as (v: unknown) => void, reject, timer });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  close(): void {
    this.ws?.close();
  }

  /** Resolves when the connection is gone (runtime restart, close()). */
  closed(): Promise<void> {
    const ws = this.ws;
    return new Promise((resolve) => {
      if (!ws || ws.readyState === WebSocket.CLOSED) return resolve();
      ws.once("close", () => resolve());
    });
  }

  private onMessage(data: RawData): void {
    let msg: RpcResponse & { method?: unknown; params?: unknown };
    try {
      msg = JSON.parse(data.toString()) as RpcResponse & { method?: unknown; params?: unknown };
    } catch {
      return;
    }
    if (typeof msg.id !== "number") {
      if (typeof msg.method === "string") {
        for (const fn of this.listeners.get(msg.method) ?? []) fn(msg.params);
      }
      return;
    }
    const p = this.pending.get(msg.id);
    if (!p) return;
    this.pending.delete(msg.id);
    clearTimeout(p.timer);
    if (msg.error) p.reject(new RpcCallError(msg.error.code, msg.error.message, msg.error.data));
    else p.resolve(msg.result);
  }
}
