import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import WebSocket from "ws";
import type { NotchApproval, NotchFeed } from "./notchState";

export const MOBILE_ORIGIN = "https://relay.shotlin.in";
const MAX_FRAME = 65_536;
const MAX_PLAINTEXT = MAX_FRAME - 28;
const HEX = /^[0-9a-f]{64}$/;
const DEVICE = /^[0-9a-f]{32}$/;
const SESSION = /^[0-9a-f]{32}$/;
const random = (bytes: number) => randomBytes(bytes).toString("hex");

export interface MobileDecision { turn_id: string; call_id: string; revision: string; allow: boolean; choice?: string }
interface Pairing { key: string; name: string; pairedAt: number; push?: string }
interface Pending { key: string; expires: number }
interface Session { id: string; seq: number; feedSeq: number; requests: number; lastFeed?: string }
export interface MobileDevice { id: string; name: string; pairedAt: number; connected: boolean }

const aad = (id: string, from: "mac" | "phone") => Buffer.from(`opscode.mobile.v1|${from}|${id}`);
export function sealMobile(key: string, id: string, from: "mac" | "phone", value: object): Buffer {
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", Buffer.from(key, "hex"), nonce);
  cipher.setAAD(aad(id, from));
  return Buffer.concat([nonce, cipher.update(JSON.stringify(value), "utf8"), cipher.final(), cipher.getAuthTag()]);
}

export function openMobile(key: string, id: string, from: "mac" | "phone", bytes: Buffer): unknown {
  if (bytes.length <= 28 || bytes.length > MAX_FRAME) throw new Error("Invalid mobile message size");
  const cipher = createDecipheriv("aes-256-gcm", Buffer.from(key, "hex"), bytes.subarray(0, 12));
  cipher.setAAD(aad(id, from));
  cipher.setAuthTag(bytes.subarray(-16));
  return JSON.parse(Buffer.concat([cipher.update(bytes.subarray(12, -16)), cipher.final()]).toString("utf8")) as unknown;
}

const object = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;

export function mobileCanAllow(approval: NotchApproval): boolean {
  return approval.summary.trim().length > 0
    && (!!approval.detail || !approval.summary.endsWith("…"))
    && (approval.detail?.length ?? 0) < 1200;
}

export function mobileApprovalRevision(approval: NotchApproval): string {
  const { tool, summary, detail, choices, branch, at } = approval;
  return createHash("sha256").update(JSON.stringify([tool, summary, detail, choices, branch, at])).digest("hex");
}

function prepareFeed(feed: NotchFeed) {
  const sessions = feed.sessions.map(({ title, project, engine, status, line }) => ({
    title: title.slice(0, 400), project: project.slice(0, 400), engine, status, line,
    approvals: [] as object[],
  }));
  const result = { sessions, counts: feed.counts };
  let remaining = MAX_PLAINTEXT - 512 - Buffer.byteLength(JSON.stringify(result));
  for (const [i, session] of feed.sessions.entries()) {
    for (const approval of session.approvals) {
      const { turn_id, call_id, tool, summary, detail, choices } = approval;
      const card = { turn_id, call_id, tool, summary, detail, choices,
        can_allow: mobileCanAllow(approval), revision: mobileApprovalRevision(approval) };
      const size = Buffer.byteLength(JSON.stringify(card)) + 1;
      if (size <= remaining) {
        sessions[i].approvals.push(card);
        remaining -= size;
      }
    }
  }
  return result;
}

export class MobileBridge {
  private readonly devices = new Map<string, Pairing>();
  private readonly sessions = new Map<string, Session>();
  private pending?: Pending;
  private socket?: WebSocket;
  private retry?: NodeJS.Timeout;
  private heartbeat?: NodeJS.Timeout;
  private publishTimer?: NodeJS.Timeout;
  private workspaceTimer?: NodeJS.Timeout;
  private attempt = 0;
  private ready = false;
  private stopped = false;
  private awaitingPong = false;
  private inventory?: Promise<void>;

  constructor(private readonly options: {
    origin?: string;
    token: string;
    path: string;
    label: string;
    feed: () => NotchFeed | null;
    decide: (value: MobileDecision) => Promise<boolean>;
    push?: (token: string) => Promise<"sent" | "invalid">;
    onPaired?: () => void;
    workspace?: (device: string, value: Record<string, unknown>) => Promise<object>;
    onRevoked?: (device: string) => void;
    log: (line: string) => void;
  }) {
    if (!HEX.test(options.token)) throw new Error("Invalid Opscode relay credential.");
    try {
      const data = JSON.parse(readFileSync(options.path, "utf8"));
      for (const [id, entry] of Object.entries(data.devices ?? {})) {
        const row = object(entry);
        if (DEVICE.test(id) && typeof row?.key === "string" && HEX.test(row.key) &&
          typeof row.name === "string" && typeof row.pairedAt === "number") this.devices.set(id, row as unknown as Pairing);
      }
      if (typeof data.pending?.key === "string" && HEX.test(data.pending.key) && data.pending.expires > Date.now()) {
        this.pending = data.pending as Pending;
      }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") options.log("mobile: saved relay devices could not be read");
    }
  }

  get online(): boolean { return this.ready; }

  list(): MobileDevice[] {
    return [...this.devices].map(([id, { name, pairedAt }]) => ({
      id, name, pairedAt, connected: this.sessions.has(id),
    }));
  }

  async invite(): Promise<{ url: string; expires: number }> {
    const previous = this.pending;
    const key = random(32);
    // Store the QR-only key before showing the invite. A process restart can finish enrollment.
    this.pending = { key, expires: Date.now() + 12 * 60_000 };
    try {
      this.persist();
      const { token, expires_at_ms: expires } = await this.request("/v1/invite", "POST");
      if (typeof token !== "string" || !HEX.test(token) || typeof expires !== "number") throw new Error("Invalid relay invitation");
      const params = new URLSearchParams({ code: token, key, label: this.options.label });
      return { url: `opscode-pair://v2/connect?${params}`, expires };
    } catch (error) {
      this.pending = previous;
      this.persist();
      throw error;
    }
  }

  async revoke(id: string): Promise<void> {
    await this.request(`/v1/devices/${id}`, "DELETE");
    this.sessions.delete(id);
    this.options.onRevoked?.(id);
    if (this.devices.delete(id)) this.persist();
  }

  start(): void {
    if (this.stopped || this.socket) return;
    clearTimeout(this.retry);
    const path = new URL("/v1/socket/mac", this.options.origin ?? MOBILE_ORIGIN);
    if (path.protocol === "https:") path.protocol = "wss:";
    else if (path.protocol === "http:" && path.hostname === "127.0.0.1") path.protocol = "ws:";
    else throw new Error("The Opscode relay requires TLS.");
    const ws = new WebSocket(path, {
      headers: { Authorization: `Bearer ${this.options.token}` },
      handshakeTimeout: 8_000, maxPayload: MAX_FRAME + 17, perMessageDeflate: false,
    });
    this.socket = ws;
    ws.on("error", () => ws.terminate());
    ws.on("close", () => {
      if (this.socket !== ws) return;
      this.reset();
      if (this.stopped) return;
      const delay = Math.min(12_000, 500 * 2 ** Math.min(this.attempt++, 5));
      this.retry = setTimeout(() => this.start(), delay * (.8 + Math.random() * .4));
    });
    ws.on("open", () => {
      if (this.socket !== ws) return;
      this.heartbeat = setInterval(() => {
        if (this.awaitingPong) ws.terminate();
        else if (ws.readyState === WebSocket.OPEN) {
          this.awaitingPong = true;
          ws.send("ping");
        }
      }, 15_000);
    });
    ws.on("message", (data, binary) => {
      if (this.socket !== ws || !Buffer.isBuffer(data)) return;
      if (!binary) {
        if (data.toString() === "pong") this.awaitingPong = false;
        else {
          try { this.relayEvent(object(JSON.parse(data.toString("utf8")))); } catch { /* invalid relay event */ }
        }
        return;
      }
      if (data.length <= 17 || data[0] !== 1) return;
      void this.receive(data.subarray(1, 17).toString("hex"), data.subarray(17)).catch(() => {
        this.options.log("mobile: authenticated request could not be completed");
      });
    });
  }

  reconnect(): void {
    const old = this.socket;
    this.reset();
    old?.terminate();
    this.attempt = 0;
    this.start();
  }

  stop(): void {
    this.stopped = true;
    clearTimeout(this.retry);
    clearTimeout(this.publishTimer);
    clearTimeout(this.workspaceTimer);
    const old = this.socket;
    this.reset();
    old?.terminate();
  }

  publish(): void {
    if (!this.sessions.size || this.publishTimer) return;
    this.publishTimer = setTimeout(() => {
      this.publishTimer = undefined;
      const raw = this.options.feed();
      const feed = raw ? prepareFeed(raw) : null;
      const signature = JSON.stringify(feed);
      for (const [id, session] of this.sessions) this.sendFeed(id, session, feed, signature);
    }, 85);
  }

  notifyApproval(): void {
    for (const [id, device] of this.devices) this.pushApproval(id, device);
  }

  workspaceChanged(): void {
    if (!this.options.workspace || !this.sessions.size || this.workspaceTimer) return;
    this.workspaceTimer = setTimeout(() => {
      this.workspaceTimer = undefined;
      for (const [id, session] of this.sessions) this.send(id, { type: "workspace.changed", session: session.id });
    }, 350);
  }

  private reset(): void {
    this.socket = undefined;
    this.ready = false;
    this.awaitingPong = false;
    clearInterval(this.heartbeat);
    this.sessions.clear();
  }

  private relayEvent(event: Record<string, unknown> | null): void {
    if (event?.type === "relay.ready" && event.protocol === 1) {
      this.ready = true;
      this.attempt = 0;
      this.reconcile();
    }
    if ((event?.type === "relay.presence" && event.online === false || event?.type === "relay.unavailable")
      && typeof event.device_id === "string") {
      this.sessions.delete(event.device_id);
      if (this.devices.has(event.device_id)) this.reconcile();
    }
  }

  private reconcile(): void {
    if (this.inventory) return;
    this.inventory = this.request("/v1/devices").then(({ devices }) => {
      if (!Array.isArray(devices)) return;
      const relayIds = new Set(devices.map((entry) => object(entry)?.device_id));
      let changed = false;
      for (const id of this.devices.keys()) {
        if (relayIds.has(id) || this.sessions.has(id)) continue;
        this.devices.delete(id);
        this.options.onRevoked?.(id);
        changed = true;
      }
      if (changed) this.persist();
    }).catch(() => {}).finally(() => { this.inventory = undefined; });
  }

  private async receive(id: string, bytes: Buffer): Promise<void> {
    const known = this.devices.get(id);
    const pending = this.pending && this.pending.expires > Date.now() ? this.pending : undefined;
    const key = known?.key ?? pending?.key;
    if (!key) return;
    let message: Record<string, unknown> | null;
    try { message = object(openMobile(key, id, "phone", bytes)); }
    catch { return; }
    if (!message) return;
    if (message.type === "hello") {
      const { challenge, name } = message;
      if (typeof challenge !== "string" || !SESSION.test(challenge) || typeof name !== "string" ||
        !name.trim() || name.length > 100 || /[\x00-\x1f\x7f]/.test(name)) return;
      if (!known) {
        this.devices.set(id, { key, name, pairedAt: Date.now() });
        this.pending = undefined;
        try { this.persist(); }
        catch (error) {
          this.devices.delete(id);
          this.pending = pending;
          throw error;
        }
      }
      const session = { id: random(16), seq: 0, feedSeq: 0, requests: 0 };
      this.sessions.set(id, session);
      this.send(id, { type: "welcome", challenge, session: session.id, workspace: !!this.options.workspace });
      const raw = this.options.feed();
      this.sendFeed(id, session, raw ? prepareFeed(raw) : null);
      if (!known) this.options.onPaired?.();
      return;
    }
    const session = this.sessions.get(id);
    if (!known || !session || message.session !== session.id || typeof message.seq !== "number" ||
      !Number.isSafeInteger(message.seq) || message.seq <= session.seq) return;
    const seq = message.seq;
    session.seq = seq;
    if (message.type === "sync") {
      const raw = this.options.feed();
      this.sendFeed(id, session, raw ? prepareFeed(raw) : null);
      return;
    }
    if (message.type === "workspace") {
      const body = object(message.body);
      const reply = { type: "workspace.result", session: session.id, seq };
      if (session.requests >= 4) {
        this.send(id, { ...reply, error: "The Mac is busy. Try again shortly." });
        return;
      }
      session.requests++;
      try {
        if (!body || !this.options.workspace) throw new Error("Update Opscode on your Mac to use mobile projects.");
        const data = await this.options.workspace(id, body);
        if (this.sessions.get(id) === session && !this.send(id, { ...reply, data })) {
          this.send(id, { ...reply, error: "The Mac response was too large." });
        }
      } catch (error) {
        if (this.sessions.get(id) === session) this.send(id, {
          ...reply, error: error instanceof Error ? error.message.slice(0, 500) : "The Mac could not complete that action.",
        });
      } finally { session.requests--; }
      return;
    }
    let status = 400;
    try {
      if (message.type === "decision") {
        const body = validateDecision(object(message.body));
        if (body) status = await this.options.decide(body) ? 200 : 409;
      } else if (message.type === "push") {
        const token = object(message.body)?.token;
        if (typeof token === "string" && /^[A-Za-z0-9_:.\-]{20,2048}$/.test(token)) {
          if (known.push !== token) {
            const previous = known.push;
            known.push = token;
            try { this.persist(); }
            catch (error) { known.push = previous; throw error; }
            if (this.options.feed()?.counts.needs) this.pushApproval(id, known);
          }
          status = 200;
        }
      }
    } catch { status = 503; }
    if (this.sessions.get(id) === session) this.send(id, { type: "result", session: session.id, seq, status });
  }

  private sendFeed(id: string, session: Session, feed: ReturnType<typeof prepareFeed> | null, signature?: string): void {
    if (signature !== undefined && session.lastFeed === signature) return;
    if (this.send(id, { type: "feed", session: session.id, version: ++session.feedSeq, feed })) {
      session.lastFeed = signature ?? JSON.stringify(feed);
    }
  }

  private send(id: string, message: object): boolean {
    const ws = this.socket;
    const key = this.devices.get(id)?.key;
    if (!key || ws?.readyState !== WebSocket.OPEN) return false;
    if (ws.bufferedAmount > MAX_FRAME * 4) {
      ws.terminate(); // Reconnect and send the newest feed, rather than accumulating stale snapshots.
      return false;
    }
    const bytes = sealMobile(key, id, "mac", message);
    if (bytes.length > MAX_FRAME) return false;
    ws.send(Buffer.concat([Buffer.from([1]), Buffer.from(id, "hex"), bytes]));
    return true;
  }

  private pushApproval(id: string, device: Pairing): void {
    if (!device.push || !this.options.push) return;
    const token = device.push;
    void this.options.push(token).then((status) => {
      if (status === "invalid" && this.devices.get(id) === device && device.push === token) {
        delete device.push;
        try { this.persist(); }
        catch (error) { device.push = token; throw error; }
      }
    }).catch(() => this.options.log("mobile: approval push could not be delivered"));
  }

  private persist(): void {
    const temp = `${this.options.path}.${random(8)}.tmp`;
    try {
      writeFileSync(temp, JSON.stringify({ devices: Object.fromEntries(this.devices), pending: this.pending }), { mode: 0o600, flag: "wx" });
      renameSync(temp, this.options.path);
    } finally { rmSync(temp, { force: true }); }
  }

  private async request(path: string, method = "GET"): Promise<Record<string, unknown>> {
    const response = await fetch(new URL(path, this.options.origin ?? MOBILE_ORIGIN), {
      method, headers: { Authorization: `Bearer ${this.options.token}` },
      redirect: "error", signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      await response.body?.cancel();
      if (response.status === 401) throw new Error("The Mac’s Opscode relay credential was rejected.");
      throw new Error(`Opscode relay returned HTTP ${response.status}.`);
    }
    const value = object(await response.json());
    if (!value) throw new Error("Invalid Opscode relay reply.");
    return value;
  }
}

function validateDecision(value: Record<string, unknown> | null): MobileDecision | null {
  if (!value) return null;
  const { turn_id, call_id, revision, allow, choice } = value;
  const id = (v: unknown, max: number): v is string => typeof v === "string" && v.length > 0 && v.length <= max;
  if (!id(turn_id, 200) || !id(call_id, 200) || typeof revision !== "string" || !HEX.test(revision) || typeof allow !== "boolean") return null;
  if (choice !== undefined && (!allow || !id(choice, 32))) return null;
  return { turn_id, call_id, revision, allow, ...(choice === undefined ? {} : { choice }) };
}
