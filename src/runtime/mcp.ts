// MCP client: connects to Model Context Protocol servers (a local command over
// stdio, or an HTTP URL), lists their tools, and calls them for the agent.
// Servers run with your permissions, so every MCP tool call asks for approval.

import { type ChildProcessWithoutNullStreams } from "node:child_process";
import { delimiter, PROGRAM_EXTS, spawnProgram, userToolDirs } from "./proc";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import { accessSync, constants, readdirSync } from "node:fs";
import type { McpServerInfo, McpState } from "../shared/protocol";
import { validateBaseUrl } from "./agent/llm";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { isRecord } from "./rpc";

const PROTOCOL = "2024-11-05";
const LIST_TIMEOUT_MS = 20_000;
const CALL_TIMEOUT_MS = 120_000;
const MAX_SERVERS = 32;
const MAX_RESULT_CHARS = 32 * 1024;

export interface McpTool {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

interface Config {
  id: string;
  name: string;
  transport: "stdio" | "http";
  command?: string;
  args?: string[];
  url?: string;
  enabled: boolean;
  /** Set for servers a plugin provides (not saved in mcp.json). */
  plugin?: string;
  /** Keys: environment values (stdio) or HTTP headers. Kept in mcp.json (0600), never sent to the UI. */
  env?: Record<string, string>;
  headers?: Record<string, string>;
  source?: string;
  catalog?: string;
}

const strMap = (v: unknown): Record<string, string> | undefined =>
  isRecord(v) && Object.values(v).every((x) => typeof x === "string") ? (v as Record<string, string>) : undefined;
const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]{0,63}$/;
const HEADER_NAME = /^[A-Za-z0-9-]{1,64}$/;
const BLOCKED_ENV = new Set(["PATH", "HOME", "USER", "SHELL", "NODE_OPTIONS", "LD_PRELOAD", "DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"]);
export function checkSecrets(env?: Record<string, string>, headers?: Record<string, string>): void {
  for (const [k, v] of Object.entries(env ?? {})) {
    if (!ENV_NAME.test(k) || BLOCKED_ENV.has(k.toUpperCase())) throw new Error(`${k} can't be set for a server`);
    if (v.length > 4096 || /[\0\r\n]/.test(v)) throw new Error(`the value for ${k} is not valid`);
  }
  for (const [k, v] of Object.entries(headers ?? {})) {
    if (!HEADER_NAME.test(k) || /^(host|content-length|content-type|accept|mcp-session-id)$/i.test(k)) throw new Error(`header ${k} can't be set`);
    if (v.length > 4096 || /[\0\r\n]/.test(v)) throw new Error(`the value for ${k} is not valid`);
  }
}
const NEEDS_KEY = /\b(401|403)\b|unauthori[sz]ed|forbidden|auth(entication|orization)? (required|failed)|invalid (api )?(key|token)|missing (api )?(key|token)|access token|api key/i;

/** Finds a bare program name (npx, uvx…) also in the usual install places an app launched from the Dock doesn't see. */
function resolveProgram(command: string): { command: string; pathAdd?: string } {
  if (command.includes("/") || command.includes("\\")) return { command };
  const home = process.env.HOME || process.env.USERPROFILE || "";
  const dirs = [...(process.env.PATH ?? "").split(delimiter), "/opt/homebrew/bin", "/usr/local/bin", join(home, ".local/bin"), join(home, ".bun/bin"), join(home, ".cargo/bin"), ...userToolDirs()];
  try {
    const nvm = join(home, ".nvm/versions/node");
    const versions = readdirSync(nvm).filter((v) => /^v\d/.test(v)).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
    for (const v of versions) dirs.push(join(nvm, v, "bin"));
  } catch { /* no nvm */ }
  for (const d of dirs.filter(Boolean)) {
    for (const ext of PROGRAM_EXTS) {
      try {
        accessSync(join(d, `${command}${ext}`), constants.X_OK);
        return { command: join(d, `${command}${ext}`), pathAdd: d };
      } catch { /* keep looking */ }
    }
  }
  return { command };
}

/** "npx -y @acme/mcp" -> ["npx","-y","@acme/mcp"]; honours simple quotes, no shell. */
export function splitCommand(line: string): string[] {
  const out: string[] = [];
  let cur = "";
  let quote: string | null = null;
  let has = false;
  for (const ch of line.trim()) {
    if (quote) {
      if (ch === quote) quote = null;
      else cur += ch;
    } else if (ch === '"' || ch === "'") {
      quote = ch;
      has = true;
    } else if (/\s/.test(ch)) {
      if (cur || has) out.push(cur);
      cur = "";
      has = false;
    } else cur += ch;
  }
  if (quote) throw new Error("unclosed quote in the command");
  if (cur || has) out.push(cur);
  return out;
}

/** Small environment: tokens and Electron flags do not leak into servers. */
function serverEnv(): Record<string, string> {
  const env: Record<string, string> = {};
  const keep = ["PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR", "SHELL"];
  // Windows programs need the system's own variables to start at all.
  if (process.platform === "win32") keep.push("SystemRoot", "windir", "ComSpec", "PATHEXT", "USERPROFILE", "USERNAME", "APPDATA", "LOCALAPPDATA", "ProgramData", "ProgramFiles", "ProgramFiles(x86)", "TEMP", "TMP", "HOMEDRIVE", "HOMEPATH", "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE");
  for (const k of keep) {
    if (process.env[k] !== undefined) env[k] = process.env[k] as string;
  }
  return env;
}

interface Client {
  listTools(): Promise<McpTool[]>;
  callTool(name: string, args: Record<string, unknown>, signal: AbortSignal): Promise<{ text: string; is_error: boolean }>;
  close(): void;
}

function toolResult(res: unknown): { text: string; is_error: boolean } {
  const r = isRecord(res) ? res : {};
  const parts = Array.isArray(r.content) ? r.content : [];
  let text = parts
    .map((p) => (isRecord(p) && p.type === "text" && typeof p.text === "string" ? p.text : isRecord(p) ? `[${String(p.type)} content]` : ""))
    .filter(Boolean)
    .join("\n");
  if (text.length > MAX_RESULT_CHARS) text = `${text.slice(0, MAX_RESULT_CHARS)}\n… (output shortened)`;
  return { text: text || "(no output)", is_error: r.isError === true };
}

const parseTools = (res: unknown): McpTool[] => {
  const list = isRecord(res) && Array.isArray(res.tools) ? res.tools : [];
  const out: McpTool[] = [];
  for (const t of list) {
    if (isRecord(t) && typeof t.name === "string") {
      out.push({ name: t.name, description: typeof t.description === "string" ? t.description : "", inputSchema: isRecord(t.inputSchema) ? t.inputSchema : { type: "object", properties: {} } });
    }
  }
  return out;
};

// ---- stdio ---------------------------------------------------------------------

class StdioClient implements Client {
  private child: ChildProcessWithoutNullStreams;
  private nextId = 1;
  private readonly pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  private buf = "";
  private stderrTail = "";
  private dead: Error | null = null;

  private constructor(command: string, args: string[], cwd: string, extraEnv: Record<string, string> = {}) {
    const found = resolveProgram(command);
    const env = { ...serverEnv(), ...extraEnv };
    if (found.pathAdd) env.PATH = `${found.pathAdd}:${env.PATH ?? ""}`;
    this.child = spawnProgram(found.command, args, { cwd, env, stdio: ["pipe", "pipe", "pipe"] });
    this.child.stdout.on("data", (d: Buffer) => this.onData(d.toString("utf8")));
    this.child.stderr.on("data", (d: Buffer) => (this.stderrTail = (this.stderrTail + d.toString("utf8")).slice(-400)));
    this.child.on("error", (e) => this.die(new Error(`could not start "${command}": ${e.message}`)));
    this.child.on("close", (code) => this.die(new Error(`server exited (code ${code})${this.stderrTail ? `: ${this.stderrTail.trim()}` : ""}`)));
    this.child.stdin.on("error", () => {});
  }

  static async start(command: string, args: string[], cwd: string, env?: Record<string, string>): Promise<StdioClient> {
    const c = new StdioClient(command, args, cwd, env);
    try {
      await c.request("initialize", { protocolVersion: PROTOCOL, capabilities: {}, clientInfo: { name: "opscode", version: "0.0.1" } }, LIST_TIMEOUT_MS);
      c.notify("notifications/initialized");
    } catch (e) {
      c.close();
      throw e;
    }
    return c;
  }

  private die(e: Error): void {
    if (this.dead) return;
    this.dead = e;
    for (const p of this.pending.values()) p.reject(e);
    this.pending.clear();
  }

  private onData(chunk: string): void {
    this.buf += chunk;
    let i: number;
    while ((i = this.buf.indexOf("\n")) >= 0) {
      const line = this.buf.slice(0, i).trim();
      this.buf = this.buf.slice(i + 1);
      if (!line) continue;
      let msg: unknown;
      try {
        msg = JSON.parse(line);
      } catch {
        continue;
      }
      if (isRecord(msg) && typeof msg.id === "number" && this.pending.has(msg.id)) {
        const p = this.pending.get(msg.id)!;
        this.pending.delete(msg.id);
        if (isRecord(msg.error)) p.reject(new Error(String(msg.error.message ?? "server error")));
        else p.resolve(msg.result);
      } else if (isRecord(msg) && typeof msg.method === "string" && msg.id !== undefined) {
        // Server-initiated requests (sampling, roots) are not supported: answer so it doesn't hang.
        this.send({ jsonrpc: "2.0", id: msg.id, error: { code: -32601, message: "not supported by this client" } });
      }
    }
    if (this.buf.length > 4 * 1024 * 1024) this.die(new Error("server sent an oversized line"));
  }

  private send(m: unknown): void {
    if (!this.dead) this.child.stdin.write(`${JSON.stringify(m)}\n`);
  }
  private notify(method: string): void {
    this.send({ jsonrpc: "2.0", method });
  }

  private request(method: string, params: unknown, timeoutMs: number, signal?: AbortSignal): Promise<unknown> {
    return new Promise((resolve, reject) => {
      if (this.dead) return reject(this.dead);
      const id = this.nextId++;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} timed out`));
      }, timeoutMs);
      const done = (fn: () => void): void => {
        clearTimeout(timer);
        fn();
      };
      this.pending.set(id, { resolve: (v) => done(() => resolve(v)), reject: (e) => done(() => reject(e)) });
      signal?.addEventListener("abort", () => {
        if (this.pending.delete(id)) done(() => reject(new Error("stopped")));
      }, { once: true });
      this.send({ jsonrpc: "2.0", id, method, params });
    });
  }

  async listTools(): Promise<McpTool[]> {
    return parseTools(await this.request("tools/list", {}, LIST_TIMEOUT_MS));
  }
  async callTool(name: string, args: Record<string, unknown>, signal: AbortSignal): Promise<{ text: string; is_error: boolean }> {
    return toolResult(await this.request("tools/call", { name, arguments: args }, CALL_TIMEOUT_MS, signal));
  }
  close(): void {
    this.die(new Error("closed"));
    try {
      this.child.kill("SIGTERM");
      setTimeout(() => this.child.kill("SIGKILL"), 1500).unref();
    } catch { /* already gone */ }
  }
}

// ---- HTTP (streamable) --------------------------------------------------------

class HttpClient implements Client {
  private session: string | undefined;
  private nextId = 1;
  constructor(private readonly url: string, private readonly extraHeaders: Record<string, string> = {}) {}

  static async start(url: string, headers?: Record<string, string>): Promise<HttpClient> {
    const c = new HttpClient(url, headers);
    await c.rpc("initialize", { protocolVersion: PROTOCOL, capabilities: {}, clientInfo: { name: "opscode", version: "0.0.1" } }, LIST_TIMEOUT_MS);
    await c.rpc("notifications/initialized", undefined, LIST_TIMEOUT_MS, true);
    return c;
  }

  private async rpc(method: string, params: unknown, timeoutMs: number, notification = false, signal?: AbortSignal): Promise<unknown> {
    const id = notification ? undefined : this.nextId++;
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    signal?.addEventListener("abort", () => ctl.abort(), { once: true });
    try {
      const res = await fetch(this.url, {
        method: "POST",
        headers: { ...this.extraHeaders, "content-type": "application/json", accept: "application/json, text/event-stream", ...(this.session ? { "mcp-session-id": this.session } : {}) },
        body: JSON.stringify({ jsonrpc: "2.0", ...(id !== undefined ? { id } : {}), method, ...(params !== undefined ? { params } : {}) }),
        signal: ctl.signal,
        redirect: "error",
      });
      const sid = res.headers.get("mcp-session-id");
      if (sid) this.session = sid;
      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
      if (notification) return undefined;
      const type = res.headers.get("content-type") ?? "";
      const text = (await res.text()).slice(0, 8 * 1024 * 1024);
      let msg: unknown;
      if (type.includes("text/event-stream")) {
        for (const block of text.split(/\r?\n\r?\n/)) {
          const data = block.split(/\r?\n/).filter((l) => l.startsWith("data:")).map((l) => l.slice(5).trim()).join("\n");
          if (!data) continue;
          try {
            const m = JSON.parse(data);
            if (isRecord(m) && m.id === id) { msg = m; break; }
          } catch { /* skip */ }
        }
      } else msg = JSON.parse(text);
      if (!isRecord(msg)) throw new Error("no response from server");
      if (isRecord(msg.error)) throw new Error(String(msg.error.message ?? "server error"));
      return msg.result;
    } catch (e) {
      if (ctl.signal.aborted) throw new Error(signal?.aborted ? "stopped" : `${method} timed out`);
      throw e;
    } finally {
      clearTimeout(timer);
    }
  }

  async listTools(): Promise<McpTool[]> {
    return parseTools(await this.rpc("tools/list", {}, LIST_TIMEOUT_MS));
  }
  async callTool(name: string, args: Record<string, unknown>, signal: AbortSignal): Promise<{ text: string; is_error: boolean }> {
    return toolResult(await this.rpc("tools/call", { name, arguments: args }, CALL_TIMEOUT_MS, false, signal));
  }
  close(): void { /* stateless */ }
}

// ---- manager -----------------------------------------------------------------------

interface Live {
  state: McpState;
  error?: string;
  tools: McpTool[];
  client?: Client;
  connecting?: Promise<void>;
}

const slug = (s: string): string => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 24) || "server";

export class McpManager {
  private readonly file: string;
  private configs: Config[];
  private external: Config[] = [];
  private readonly live = new Map<string, Live>();

  constructor(stateDir: string, private readonly cwd: string, private readonly onChange: () => void) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "mcp.json");
    this.configs = this.load();
  }

  private load(): Config[] {
    const raw = readJson(this.file);
    if (!Array.isArray(raw)) return [];
    const out: Config[] = [];
    for (const c of raw) {
      if (!isRecord(c) || typeof c.id !== "string" || typeof c.name !== "string" || typeof c.enabled !== "boolean") continue;
      const extra = { ...(strMap(c.env) ? { env: strMap(c.env) } : {}), ...(strMap(c.headers) ? { headers: strMap(c.headers) } : {}), ...(typeof c.source === "string" ? { source: c.source } : {}), ...(typeof c.catalog === "string" ? { catalog: c.catalog } : {}) };
      if (c.transport === "stdio" && typeof c.command === "string" && Array.isArray(c.args) && c.args.every((a) => typeof a === "string")) {
        out.push({ id: c.id, name: c.name, transport: "stdio", command: c.command, args: c.args as string[], enabled: c.enabled, ...extra });
      } else if (c.transport === "http" && typeof c.url === "string") out.push({ id: c.id, name: c.name, transport: "http", url: c.url, enabled: c.enabled, ...extra });
    }
    return out;
  }
  private save(): void {
    writeJsonAtomic(this.file, this.configs);
  }

  private all(): Config[] {
    return [...this.configs, ...this.external];
  }

  /** Replaces the plugin-provided servers (called when plugins change). */
  setExternal(list: { plugin: string; id: string; name: string; transport: "stdio" | "http"; command?: string; args?: string[]; url?: string }[]): void {
    const next: Config[] = list.map((x) => ({ id: x.id, name: x.name, transport: x.transport, command: x.command, args: x.args, url: x.url, enabled: true, plugin: x.plugin }));
    const keep = new Set(next.map((c) => c.id));
    for (const c of this.external) if (!keep.has(c.id)) this.drop(c.id);
    const prev = new Map(this.external.map((c) => [c.id, c]));
    this.external = next;
    for (const c of next) {
      const old = prev.get(c.id);
      const same = old && old.command === c.command && JSON.stringify(old.args) === JSON.stringify(c.args) && old.url === c.url;
      if (!same) void this.connect(c.id);
    }
    this.onChange();
  }

  list(): McpServerInfo[] {
    return this.all().map((c) => {
      const l = this.live.get(c.id);
      return {
        id: c.id,
        name: c.name,
        transport: c.transport,
        target: c.transport === "stdio" ? [c.command, ...(c.args ?? [])].join(" ") : (c.url ?? ""),
        enabled: c.enabled,
        ...(c.plugin ? { plugin: c.plugin } : {}),
        state: c.enabled ? (l?.state ?? "off") : "off",
        ...(l?.error ? { error: l.error } : {}),
        ...(l?.error && NEEDS_KEY.test(l.error) ? { needs_key: true } : {}),
        ...(c.env || c.headers ? { secrets: [...Object.keys(c.env ?? {}), ...Object.keys(c.headers ?? {})] } : {}),
        ...(c.source ? { source: c.source } : {}),
        ...(c.catalog ? { catalog: c.catalog } : {}),
        tools: (l?.tools ?? []).map((t) => ({ name: t.name, description: t.description })),
      };
    });
  }

  /** input: a URL, or the command that starts the server. */
  add(input: string, name?: string): McpServerInfo {
    if (this.configs.length >= MAX_SERVERS) throw new Error(`at most ${MAX_SERVERS} servers`);
    const text = input.trim();
    if (!text) throw new Error("enter a URL or a command");
    let cfg: Config;
    if (/^https?:\/\//i.test(text)) {
      const url = validateBaseUrl(text);
      cfg = { id: randomUUID(), name: (name ?? new URL(url).hostname).trim() || "server", transport: "http", url, enabled: true };
    } else {
      const argv = splitCommand(text);
      if (argv.length === 0) throw new Error("enter a URL or a command");
      cfg = { id: randomUUID(), name: (name ?? argv[argv.length === 1 ? 0 : argv[0] === "npx" || argv[0] === "uvx" ? argv.findIndex((a, i) => i > 0 && !a.startsWith("-")) : 0] ?? argv[0]).split("/").pop()!.trim() || "server", transport: "stdio", command: argv[0], args: argv.slice(1), enabled: true };
    }
    if (cfg.name.length > 60) cfg.name = cfg.name.slice(0, 60);
    this.configs.push(cfg);
    this.save();
    void this.connect(cfg.id);
    return this.list().find((s) => s.id === cfg.id)!;
  }

  /** Adds a server from structured fields (no command-line parsing). */
  addServer(spec: { name: string; command?: string; args?: string[]; url?: string; enabled: boolean; env?: Record<string, string>; headers?: Record<string, string>; source?: string; catalog?: string }): McpServerInfo {
    if (this.configs.length >= MAX_SERVERS) throw new Error(`at most ${MAX_SERVERS} servers`);
    checkSecrets(spec.env, spec.headers);
    const name = spec.name.trim().slice(0, 60) || "server";
    const extra = { ...(spec.env && Object.keys(spec.env).length ? { env: spec.env } : {}), ...(spec.headers && Object.keys(spec.headers).length ? { headers: spec.headers } : {}), ...(spec.source ? { source: spec.source } : {}), ...(spec.catalog ? { catalog: spec.catalog } : {}) };
    let cfg: Config;
    if (spec.url) cfg = { id: randomUUID(), name, transport: "http", url: validateBaseUrl(spec.url), enabled: spec.enabled, ...extra };
    else if (spec.command) cfg = { id: randomUUID(), name, transport: "stdio", command: spec.command, args: spec.args ?? [], enabled: spec.enabled, ...extra };
    else throw new Error("a server needs a URL or a command");
    this.configs.push(cfg);
    this.save();
    if (cfg.enabled) void this.connect(cfg.id);
    else this.onChange();
    return this.list().find((s) => s.id === cfg.id)!;
  }

  /** Replaces a server's keys (values given) and reconnects it. Names not given are left as they are. */
  setSecrets(id: string, patch: { env?: Record<string, string>; headers?: Record<string, string> }): boolean {
    if (this.external.some((c) => c.id === id)) throw new Error("this server comes from a plugin");
    const c = this.configs.find((x) => x.id === id);
    if (!c) return false;
    checkSecrets(patch.env, patch.headers);
    if (patch.env) c.env = { ...(c.env ?? {}), ...patch.env };
    if (patch.headers) c.headers = { ...(c.headers ?? {}), ...patch.headers };
    this.save();
    if (c.enabled) void this.connect(id);
    return true;
  }

  remove(id: string): boolean {
    if (this.external.some((c) => c.id === id)) throw new Error("this server comes from a plugin; uninstall the plugin to remove it");
    const i = this.configs.findIndex((c) => c.id === id);
    if (i < 0) return false;
    this.configs.splice(i, 1);
    this.save();
    this.drop(id);
    this.onChange();
    return true;
  }

  setEnabled(id: string, enabled: boolean): boolean {
    if (this.external.some((c) => c.id === id)) throw new Error("this server comes from a plugin; disable the plugin instead");
    const c = this.configs.find((x) => x.id === id);
    if (!c) return false;
    c.enabled = enabled;
    this.save();
    if (enabled) void this.connect(id);
    else {
      this.drop(id);
      this.onChange();
    }
    return true;
  }

  has(id: string): boolean {
    return this.all().some((c) => c.id === id);
  }

  private drop(id: string): void {
    this.live.get(id)?.client?.close();
    this.live.delete(id);
  }

  /** (Re)connects and lists tools. Never throws: failures show as state "error". */
  connect(id: string): Promise<void> {
    const c = this.all().find((x) => x.id === id);
    if (!c || !c.enabled) return Promise.resolve();
    const existing = this.live.get(id);
    if (existing?.connecting) return existing.connecting;
    this.live.get(id)?.client?.close();
    const l: Live = { state: "connecting", tools: [] };
    this.live.set(id, l);
    this.onChange();
    l.connecting = (async () => {
      try {
        l.client = c.transport === "stdio" ? await StdioClient.start(c.command!, c.args ?? [], this.cwd, c.env) : await HttpClient.start(c.url!, c.headers);
        l.tools = await l.client.listTools();
        l.state = "ready";
      } catch (e) {
        l.state = "error";
        l.error = e instanceof Error ? e.message : String(e);
        l.client?.close();
        l.client = undefined;
      } finally {
        l.connecting = undefined;
        if (this.live.get(id) === l) this.onChange();
      }
    })();
    return l.connecting;
  }

  /** Connects every enabled server that is not yet ready (bounded wait). */
  async ensureReady(maxMs = 8000): Promise<void> {
    const jobs = this.all().filter((c) => c.enabled && this.live.get(c.id)?.state !== "ready").map((c) => this.connect(c.id));
    if (jobs.length) await Promise.race([Promise.all(jobs), new Promise((r) => setTimeout(r, maxMs).unref())]);
  }

  /** Tools of ready servers, with provider-safe unique names. */
  agentTools(): { name: string; server: string; tool: McpTool }[] {
    const out: { name: string; server: string; tool: McpTool }[] = [];
    const used = new Set<string>();
    for (const c of this.all()) {
      const l = this.live.get(c.id);
      if (!c.enabled || l?.state !== "ready") continue;
      for (const t of l.tools) {
        let name = `mcp__${slug(c.name)}__${t.name.replace(/[^a-zA-Z0-9_-]/g, "_")}`.slice(0, 64);
        for (let n = 2; used.has(name); n++) name = `${name.slice(0, 60)}_${n}`;
        used.add(name);
        out.push({ name, server: c.id, tool: t });
      }
    }
    return out;
  }

  async call(serverId: string, tool: string, args: Record<string, unknown>, signal: AbortSignal): Promise<{ text: string; is_error: boolean }> {
    const l = this.live.get(serverId);
    if (!l?.client || l.state !== "ready") throw new Error("the server is not connected");
    return l.client.callTool(tool, args, signal);
  }

  closeAll(): void {
    for (const id of [...this.live.keys()]) this.drop(id);
  }
}
