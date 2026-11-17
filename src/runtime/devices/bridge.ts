// The runtime has no browser of its own. Opscode's main process (Electron) owns
// the pages and registers here as the "device host"; the runtime sends it
// requests as notifications and main answers with devices.reply.

import { randomUUID } from "node:crypto";
import type { RpcNotification } from "../../shared/protocol";

export const DEVICE_REQUEST = "devices.request";

interface Pending {
  resolve(v: unknown): void;
  reject(e: Error): void;
  timer: NodeJS.Timeout;
}

export class DeviceBridge {
  private host: string | undefined;
  private readonly pending = new Map<string, Pending>();

  constructor(private readonly notify: (sessionId: string, n: RpcNotification) => void) {}

  /** Main's session says it hosts the browser pages. The newest registration wins. */
  register(sessionId: string): void {
    this.host = sessionId;
  }

  sessionClosed(sessionId: string): void {
    if (this.host !== sessionId) return;
    this.host = undefined;
    for (const [rid, p] of this.pending) {
      clearTimeout(p.timer);
      p.reject(new Error("Opscode's window closed while the browser was busy."));
      this.pending.delete(rid);
    }
  }

  available(): boolean {
    return this.host !== undefined;
  }

  request<T>(device: "browser", op: string, args: Record<string, unknown>, timeoutMs = 45_000): Promise<T> {
    const host = this.host;
    if (!host) return Promise.reject(new Error("The browser is not available: Opscode's window is not running."));
    const rid = randomUUID();
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(rid);
        reject(new Error(`The browser did not answer within ${Math.round(timeoutMs / 1000)}s.`));
      }, timeoutMs);
      this.pending.set(rid, { resolve: resolve as (v: unknown) => void, reject, timer });
      this.notify(host, { method: DEVICE_REQUEST, params: { rid, device, op, args } });
    });
  }

  /** main's answer; only the registered host may answer. */
  reply(sessionId: string, rid: string, result: unknown, error: string | undefined): boolean {
    if (sessionId !== this.host) return false;
    const p = this.pending.get(rid);
    if (!p) return false;
    this.pending.delete(rid);
    clearTimeout(p.timer);
    if (error !== undefined) p.reject(new Error(error));
    else p.resolve(result);
    return true;
  }
}
