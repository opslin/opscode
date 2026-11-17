// Accounts for the coding agents (Claude Code, Codex, Antigravity, Qoder): who is signed in, sign in, sign out, switch, add.
//
// Opscode never sees a password or a token. It starts the programs' own commands and shows the result:
//   Claude Code  `claude auth status | login | logout`   (login opens the browser itself; prints a fallback link)
//   Codex        `codex app-server`: account/read, account/login/start (gives the link), account/login/cancel,
//                and `codex logout`
//   Antigravity  `agy acp` (ACP): session/new answers "Authentication required" when signed out; `authenticate`
//                opens the browser; `logout`. Qoder: `qoder --acp` the same way, `qoder login` for the sign-in.
//   (ACP does not say who is signed in, so these two show "Signed in" without an email.)
// "The Mac's own sign-in" is the default account (id "default"): the same one a terminal uses. Every extra account
// has its own private folder under Opscode's state dir, and the engine is pointed at it with CLAUDE_CONFIG_DIR or
// CODEX_HOME, so accounts never touch each other. (Codex has no built-in account list or switch, so both engines
// work this way.) A chat remembers which account it started on.

import { execProgram, spawnProgram } from "../proc";
import { randomBytes } from "node:crypto";
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { delimiter, join, resolve, sep } from "node:path";
import { AGENT_ENGINES, isAcpEngine, isAgentEngine, type AcpEngineId, type AgentEngineId, type ChatMeta } from "../../shared/protocol";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";
import { cleanEnv, ENGINE_NAMES, type EngineStore } from "./detect";
import { startAppServer } from "./codex";
import { ACP_ARGS, ACP_AUTH_CODE, parseInit, parseSession } from "./acp";

export type AuthEngine = AgentEngineId;
export const AUTH_ENGINES: readonly AuthEngine[] = AGENT_ENGINES;
export const DEFAULT_ACCOUNT = "default";
export const LOGIN_METHODS = ["claudeai", "console", "sso", "chatgpt", "google", "qoder"] as const;
export type LoginMethod = (typeof LOGIN_METHODS)[number];

export interface AccountRecord {
  id: string;
  engine: AuthEngine;
  /** The engine's own config folder for this account; null = the Mac's own sign-in (the default account). */
  home: string | null;
  added_at: string;
  last_used_at?: string;
}
export interface AccountStatus {
  signed_in: boolean;
  email?: string;
  /** pro, max, team, plus, enterprise ... as the engine words it. */
  plan?: string;
  org?: string;
  /** claude.ai, console, sso, chatgpt, api_key ... */
  method?: string;
  expires_at?: string;
  checked_at: string;
  /** Why it could not be read (program missing, did not answer). */
  error?: string;
  /** What the last run read, shown at once while the program is asked again. */
  stale?: true;
}
export interface AccountView {
  id: string;
  engine: AuthEngine;
  is_default: boolean;
  active: boolean;
  added_at: string;
  last_used_at?: string;
  /** null until the first read. */
  status: AccountStatus | null;
}
export interface LoginView {
  id: string;
  engine: AuthEngine;
  account_id: string;
  new_account: boolean;
  method: LoginMethod;
  state: "starting" | "waiting" | "done" | "failed" | "cancelled";
  /** The sign-in page, for when the browser did not open. */
  url?: string;
  /** Claude Code can take the code the browser shows, when the browser could not call back. */
  can_paste: boolean;
  message?: string;
  started_at: string;
}

interface Deps {
  stateDir: string;
  engines: EngineStore;
  notify(method: string, params: unknown): void;
  /** How many chats are running on this account right now. */
  busy?(engine: AuthEngine, accountId: string): number;
  /** An extra account was removed: chats pinned to it must let go. */
  removed?(engine: AuthEngine, accountId: string): void;
  log(line: string): void;
}

const STATUS_TTL_MS = 30_000;
const LOGIN_TIMEOUT_MS = 5 * 60_000;
const rec = (v: unknown): Record<string, unknown> | null => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null);
const str = (v: unknown, max = 200): string | undefined => (typeof v === "string" && v.trim() ? v.trim().slice(0, max) : undefined);
export const isAuthEngine = (e: unknown): e is AuthEngine => isAgentEngine(e);
const engineName = (e: AuthEngine): string => ENGINE_NAMES[e];

/** A failure that means "sign in again" (not a plan limit, not a code bug). */
const AUTH_RE = /not logged in|not signed in|please (?:run )?\/?login|run `?claude (?:auth )?login|invalid (?:api key|authentication|credentials|token)|authentication[ _-]?(?:error|failed|required)|unauthori[sz]ed|\b401\b|token (?:has )?expired|refresh token|log ?in again|sign in again|requires? (?:openai )?auth/i;
export const isAuthError = (msg: string | undefined): boolean => !!msg && AUTH_RE.test(msg);

/** The environment for an engine's auth commands: nothing from a surrounding Claude Code session. */
function authEnv(base: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const env = { ...base };
  for (const k of Object.keys(env)) if (k === "CLAUDECODE" || k.startsWith("CLAUDE_CODE_ENTRYPOINT")) delete env[k];
  return env;
}

/** Opens a sign-in page in the person's browser (https only). */
function openInBrowser(url: string): boolean {
  let u: URL;
  try { u = new URL(url); } catch { return false; }
  if (u.protocol !== "https:") return false;
  const bin = process.env.OPSCODE_OPEN_BIN || (process.platform === "darwin" ? "open" : process.platform === "win32" ? "explorer" : "xdg-open");
  execProgram(bin, [url], {}, () => {});
  return true;
}
const CODEX_HOSTS = /(^|\.)(openai\.com|chatgpt\.com)$/i;
/** Where each program's sign-in page may be: a link anywhere else is never shown or opened by Opscode. */
const LOGIN_HOSTS: Partial<Record<AuthEngine, RegExp>> = { antigravity: /(^|\.)google\.com$/i, qoder: /(^|\.)qoder\.(com|ai)$/i };
/** The credentials a program may also read from the environment. An added account must not inherit them, or it would not be its own account. */
const AUTH_ENV: Partial<Record<AuthEngine, string[]>> = { qoder: ["QODER_PERSONAL_ACCESS_TOKEN"], antigravity: ["GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS"] };
const loginUrlOk = (engine: AuthEngine, url: string): boolean => {
  try { const u = new URL(url); return u.protocol === "https:" && !u.username && !u.password && (LOGIN_HOSTS[engine]?.test(u.hostname) ?? false); } catch { return false; }
};

function run(bin: string, args: string[], env: NodeJS.ProcessEnv, timeout = 15_000): Promise<{ code: number | null; out: string; err: string }> {
  return new Promise((res) => {
    execProgram(bin, args, { env, timeout, maxBuffer: 1 << 20, cwd: tmpdir() }, (e, out, err) => {
      const code = e ? (typeof (e as { code?: unknown }).code === "number" ? (e as unknown as { code: number }).code : null) : 0;
      res({ code, out: String(out), err: String(err) || (e ? e.message : "") });
    });
  });
}

/** claude auth status (JSON; exit 1 with the same JSON when signed out). */
export function parseClaudeStatus(out: string, at = new Date()): AccountStatus {
  let j: Record<string, unknown> | null = null;
  try { j = rec(JSON.parse(out)); } catch { j = null; }
  if (!j) return { signed_in: false, checked_at: at.toISOString(), error: "Claude Code did not answer in a way Opscode understands (it may be too old: update it)." };
  const signed = j.loggedIn === true;
  const method = str(j.authMethod, 40);
  return {
    signed_in: signed, checked_at: at.toISOString(),
    ...(signed && str(j.email) ? { email: str(j.email) } : {}),
    ...(signed && (str(j.subscriptionType, 40) || str(j.planTier, 40)) ? { plan: (str(j.subscriptionType, 40) ?? str(j.planTier, 40))!.toLowerCase() } : {}),
    ...(signed && str(j.orgName) ? { org: str(j.orgName) } : {}),
    ...(signed && method && method !== "none" ? { method } : {}),
    ...(signed && str(j.loginExpiresAt, 40) ? { expires_at: str(j.loginExpiresAt, 40) } : {}),
  };
}

/** Codex account/read -> status. */
export function parseCodexAccount(r: Record<string, unknown>, at = new Date()): AccountStatus {
  const a = rec(r.account);
  if (!a) return { signed_in: false, checked_at: at.toISOString() };
  if (a.type === "chatgpt") {
    return { signed_in: true, checked_at: at.toISOString(), method: "chatgpt", ...(str(a.email) ? { email: str(a.email) } : {}), ...(str(a.planType, 60) ? { plan: str(a.planType, 60)!.toLowerCase() } : {}), ...(str(a.workspaceName) ? { org: str(a.workspaceName) } : {}) };
  }
  return { signed_in: true, checked_at: at.toISOString(), method: a.type === "apiKey" ? "api_key" : String(a.type ?? "other").slice(0, 30) };
}

interface LoginRun {
  view: LoginView;
  cancel(): void;
  paste?(code: string): boolean;
  timer: ReturnType<typeof setTimeout>;
  finished: boolean;
  /** We closed the helper program on purpose (sign-in over, or cancelled): its exit is not a failure. */
  closing?: boolean;
}

export class AccountStore {
  private readonly file: string;
  private readonly root: string;
  private extra: AccountRecord[] = [];
  private activeIds: Partial<Record<AuthEngine, string>> = {};
  private cache = new Map<string, AccountStatus>();
  private inflight = new Map<string, Promise<AccountStatus>>();
  private login: LoginRun | null = null;
  private lastSeen = new Map<string, number>();
  /** The last answers, read from disk at start (0600): who is signed in is known the moment the window opens. */
  private persisted = new Map<string, AccountStatus>();
  private persistTimer: NodeJS.Timeout | null = null;
  private changedTimer: NodeJS.Timeout | null = null;
  private readonly statusFile: string;

  constructor(private readonly d: Deps) {
    ensurePrivateDir(d.stateDir);
    this.file = join(d.stateDir, "accounts.json");
    this.statusFile = join(d.stateDir, "accounts-status.json");
    this.root = join(d.stateDir, "accounts");
    const raw = readJson(this.file);
    if (isRecord(raw)) {
      if (Array.isArray(raw.accounts)) {
        for (const a of raw.accounts) {
          if (isRecord(a) && isAuthEngine(a.engine) && typeof a.id === "string" && /^a-[0-9a-f]{8}$/.test(a.id) && typeof a.added_at === "string") {
            const home = this.homeFor(a.engine, a.id);
            this.extra.push({ id: a.id, engine: a.engine, home, added_at: a.added_at, ...(typeof a.last_used_at === "string" ? { last_used_at: a.last_used_at } : {}) });
          }
        }
      }
      if (isRecord(raw.active)) for (const e of AUTH_ENGINES) if (typeof raw.active[e] === "string") this.activeIds[e] = raw.active[e] as string;
    }
    for (const e of AUTH_ENGINES) if (this.activeIds[e] && !this.find(e, this.activeIds[e]!)) delete this.activeIds[e];
    this.loadStatuses();
  }

  private loadStatuses(): void {
    const raw = readJson(this.statusFile);
    if (!isRecord(raw) || raw.version !== 1 || !isRecord(raw.statuses)) return;
    for (const a of this.records()) {
      const s = raw.statuses[this.key(a.engine, a.id)];
      if (!isRecord(s) || typeof s.signed_in !== "boolean" || typeof s.checked_at !== "string") continue;
      const status: AccountStatus = { signed_in: s.signed_in, checked_at: s.checked_at };
      for (const k of ["email", "plan", "org", "method", "expires_at"] as const) { const v = str(s[k]); if (v) status[k] = v; }
      this.persisted.set(this.key(a.engine, a.id), status);
    }
  }
  private persistSoon(): void {
    if (this.persistTimer) return;
    this.persistTimer = setTimeout(() => {
      this.persistTimer = null;
      const statuses: Record<string, AccountStatus> = {};
      for (const a of this.records()) { const s = this.cache.get(this.key(a.engine, a.id)) ?? this.persisted.get(this.key(a.engine, a.id)); if (s && !s.error) { const { stale: _s, ...rest } = s; void _s; statuses[this.key(a.engine, a.id)] = rest; } }
      try { writeJsonAtomic(this.statusFile, { version: 1, statuses }); } catch { /* only a speed-up */ }
    }, 400);
    this.persistTimer.unref();
  }

  // ---- records ---------------------------------------------------------------------------------------------
  private homeFor(engine: AuthEngine, id: string): string { return join(this.root, engine, id); }
  private save(): void {
    writeJsonAtomic(this.file, { version: 1, accounts: this.extra.map(({ id, engine, added_at, last_used_at }) => ({ id, engine, added_at, ...(last_used_at ? { last_used_at } : {}) })), active: this.activeIds });
  }
  private defaultRecord(engine: AuthEngine): AccountRecord { return { id: DEFAULT_ACCOUNT, engine, home: null, added_at: "" }; }
  find(engine: AuthEngine, id: string): AccountRecord | undefined {
    return id === DEFAULT_ACCOUNT ? this.defaultRecord(engine) : this.extra.find((a) => a.engine === engine && a.id === id);
  }
  records(engine?: AuthEngine): AccountRecord[] {
    return (engine ? [engine] : [...AUTH_ENGINES]).flatMap((e) => [this.defaultRecord(e), ...this.extra.filter((a) => a.engine === e)]);
  }
  /** The account new chats use on this engine. */
  active(engine: AuthEngine): string { return this.activeIds[engine] ?? DEFAULT_ACCOUNT; }
  /** The account a chat runs on: the one it was pinned to, else the legacy default for a chat that already has a session, else the active one. */
  resolve(engine: AuthEngine, chat?: ChatMeta): string {
    const pinned = chat?.accounts?.[engine];
    if (pinned && this.find(engine, pinned)) return pinned;
    const hasSession = !!chat && !!(chat.engine_sessions?.[engine] || (chat.engine === engine && chat.engine_session));
    return hasSession ? DEFAULT_ACCOUNT : this.active(engine);
  }
  /** Every account folder that holds session logs: for the usage scan. */
  homes(): { engine: "claude-code" | "codex"; id: string; home: string }[] {
    // Only Claude Code and Codex keep session logs the usage scan can read.
    return this.extra.flatMap((a) => (a.home && (a.engine === "claude-code" || a.engine === "codex") ? [{ engine: a.engine, id: a.id, home: a.home }] : []));
  }
  touch(engine: AuthEngine, id: string): void {
    const a = this.extra.find((x) => x.engine === engine && x.id === id);
    if (!a) return;
    const k = `${engine}:${id}`;
    if (Date.now() - (this.lastSeen.get(k) ?? 0) < 60_000) return;
    this.lastSeen.set(k, Date.now());
    a.last_used_at = new Date().toISOString();
    try { this.save(); } catch { /* recency is cosmetic */ }
  }

  /** The environment an engine process runs with for this account. */
  env(engine: AuthEngine, id: string = DEFAULT_ACCOUNT): NodeJS.ProcessEnv {
    const env = cleanEnv();
    const a = this.find(engine, id);
    // Antigravity has no setting for its folder: its home folder is the account (a few dotfiles are linked in, see linkShared).
    if (a?.home) {
      env[engine === "claude-code" ? "CLAUDE_CONFIG_DIR" : engine === "codex" ? "CODEX_HOME" : engine === "qoder" ? "QODER_CONFIG_DIR" : "HOME"] = a.home;
      for (const k of AUTH_ENV[engine] ?? []) delete env[k];
    }
    return env;
  }

  private bin(engine: AuthEngine): string | null { return this.d.engines.pathOf(engine); }

  // ---- status ------------------------------------------------------------------------------------------------
  private key = (engine: AuthEngine, id: string): string => `${engine}:${id}`;

  async status(engine: AuthEngine, id: string, force = false): Promise<AccountStatus> {
    const k = this.key(engine, id);
    const have = this.cache.get(k);
    if (!force && have && Date.now() - Date.parse(have.checked_at) < STATUS_TTL_MS) return have;
    const running = this.inflight.get(k);
    if (running) return running;
    const p = this.probe(engine, id).then((s) => { this.cache.set(k, s); this.persisted.set(k, s); this.persistSoon(); return s; }).finally(() => this.inflight.delete(k));
    this.inflight.set(k, p);
    return p;
  }

  private async probe(engine: AuthEngine, id: string): Promise<AccountStatus> {
    const at = new Date();
    const bin = this.bin(engine);
    if (!bin) return { signed_in: false, checked_at: at.toISOString(), error: `${engineName(engine)} isn't installed on this computer.` };
    const env = authEnv(this.env(engine, id));
    if (isAcpEngine(engine)) return this.probeAcp(engine, bin, env, at, this.active(engine) === id);
    if (engine === "claude-code") {
      const r = await run(bin, ["auth", "status"], env);
      if (r.code === null && !r.out.trim()) return { signed_in: false, checked_at: at.toISOString(), error: `Claude Code didn't answer${r.err ? `: ${r.err.split("\n")[0].slice(0, 120)}` : ""}.` };
      return parseClaudeStatus(r.out, at);
    }
    const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => {}, env);
    const within = <T>(p: Promise<T>): Promise<T> => Promise.race([p, new Promise<never>((_, rej) => setTimeout(() => rej(new Error("Codex didn't answer in 15 seconds.")), 15_000).unref())]);
    try {
      await within(rpc.call("initialize", { clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" }, capabilities: null }));
      rpc.notify("initialized");
      return parseCodexAccount(await within(rpc.call("account/read", { refreshToken: false })), at);
    } catch (e) {
      return { signed_in: false, checked_at: at.toISOString(), error: e instanceof Error ? e.message.slice(0, 160) : "Codex didn't answer." };
    } finally {
      rpc.close();
    }
  }

  /** ACP agents do not say who is signed in; they answer "Authentication required" when nobody is. A session start is free (no model call). */
  private async probeAcp(engine: AcpEngineId, bin: string, env: NodeJS.ProcessEnv, at: Date, active: boolean): Promise<AccountStatus> {
    const name = engineName(engine);
    const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => {}, env, ACP_ARGS[engine], name);
    const within = <T>(p: Promise<T>): Promise<T> => Promise.race([p, new Promise<never>((_, rej) => setTimeout(() => rej(new Error(`${name} didn't answer in 20 seconds.`)), 20_000).unref())]);
    try {
      await within(rpc.call("initialize", { protocolVersion: 1, clientCapabilities: {} }));
      const s = parseSession(await within(rpc.call("session/new", { cwd: tmpdir(), mcpServers: [] })));
      if (s.models.length && active) this.d.engines.setAcpModels(engine, s.models.map((m, i) => ({ id: m.id, label: m.label, ...(i >= 5 ? { more: true } : {}) })));
      return { signed_in: true, method: engine === "antigravity" ? "google" : "qoder", checked_at: at.toISOString() };
    } catch (e) {
      if ((e as { rpcCode?: unknown }).rpcCode === ACP_AUTH_CODE || isAuthError(e instanceof Error ? e.message : "")) {
        if (active) this.d.engines.setAcpModels(engine, []); // the models listed are the account new chats use
        return { signed_in: false, checked_at: at.toISOString() };
      }
      return { signed_in: false, checked_at: at.toISOString(), error: e instanceof Error ? e.message.slice(0, 160) : `${name} didn't answer.` };
    } finally {
      rpc.close();
    }
  }

  /** Forget what was read (after a failed chat said "sign in", or a sign-in/out), and tell every window. */
  async invalidate(engine: AuthEngine, id: string): Promise<void> {
    this.cache.delete(this.key(engine, id));
    await this.status(engine, id, true).catch(() => undefined);
    this.changed();
  }

  views(): AccountView[] {
    return this.records().map((a) => {
      const k = this.key(a.engine, a.id);
      const old = this.persisted.get(k);
      return {
        id: a.id, engine: a.engine, is_default: a.id === DEFAULT_ACCOUNT, active: this.active(a.engine) === a.id, added_at: a.added_at,
        ...(a.last_used_at ? { last_used_at: a.last_used_at } : {}), status: this.cache.get(k) ?? (old ? { ...old, stale: true as const } : null),
      };
    });
  }
  /**
   * Who is signed in. Asking the programs takes seconds (each is started, some ask the network), so what the last run read is
   * answered at once (marked stale) and asked again in the background; the windows hear every answer as `accounts.changed`.
   * `refresh: true` waits until every program has answered anew.
   */
  async list(refresh = false): Promise<AccountView[]> {
    const recs = this.records();
    const known = recs.every((a) => this.cache.has(this.key(a.engine, a.id)) || this.persisted.has(this.key(a.engine, a.id)));
    const ask = Promise.all(recs.map((a) => this.status(a.engine, a.id, refresh).then(() => this.changedSoon()).catch(() => undefined)));
    if (!refresh && known) { void ask; return this.views(); }
    await ask;
    return this.views();
  }
  /** Tells the windows soon, once for a burst of answers. */
  private changedSoon(): void {
    if (this.changedTimer) return;
    this.changedTimer = setTimeout(() => { this.changedTimer = null; this.changed(); }, 80);
    this.changedTimer.unref();
  }
  loginView(): LoginView | null { return this.login ? { ...this.login.view } : null; }
  private changed(): void { this.d.notify("accounts.changed", { accounts: this.views(), login: this.loginView() }); }
  private publish(): void { this.d.notify("accounts.login", { login: this.loginView() }); }

  // ---- switch ----------------------------------------------------------------------------------------------------
  async switchTo(engine: AuthEngine, id: string): Promise<void> {
    if (!this.find(engine, id)) throw new Error("that account no longer exists");
    const s = await this.status(engine, id);
    if (!s.signed_in) throw new Error("Sign in to that account first.");
    if (id === DEFAULT_ACCOUNT) delete this.activeIds[engine]; else this.activeIds[engine] = id;
    this.save();
    this.changed();
  }

  // ---- sign in -----------------------------------------------------------------------------------------------------
  /** Starts a browser sign-in. `newAccount` adds another account beside the existing ones; otherwise it signs `accountId` in (again). */
  async loginStart(o: { engine: AuthEngine; accountId?: string; newAccount?: boolean; method?: LoginMethod; email?: string }): Promise<LoginView> {
    if (this.login && !this.login.finished) throw new Error("A sign-in is already open. Finish it or cancel it first.");
    const bin = this.bin(o.engine);
    if (!bin) throw new Error(`${engineName(o.engine)} isn't installed on this computer.`);
    const method: LoginMethod = o.engine === "codex" ? "chatgpt" : o.engine === "antigravity" ? "google" : o.engine === "qoder" ? "qoder" : o.method && o.method !== "chatgpt" && o.method !== "google" && o.method !== "qoder" ? o.method : "claudeai";
    if (o.email !== undefined && (!/^[^\s@]{1,64}@[^\s@]{1,190}$/.test(o.email) || o.engine !== "claude-code")) throw new Error("that is not an email address");
    let accountId = o.accountId ?? this.active(o.engine);
    if (o.newAccount) {
      if (this.extra.filter((a) => a.engine === o.engine).length >= 6) throw new Error("At most 6 extra accounts per program. Sign one out first.");
      accountId = `a-${randomBytes(4).toString("hex")}`;
      const home = this.homeFor(o.engine, accountId);
      ensurePrivateDir(home);
      this.linkShared(o.engine, home);
      this.extra.push({ id: accountId, engine: o.engine, home, added_at: new Date().toISOString() });
      this.save();
    } else if (!this.find(o.engine, accountId)) throw new Error("that account no longer exists");
    const view: LoginView = { id: randomBytes(6).toString("hex"), engine: o.engine, account_id: accountId, new_account: !!o.newAccount, method, state: "starting", can_paste: false, started_at: new Date().toISOString() };
    const run: LoginRun = { view, cancel: () => {}, timer: setTimeout(() => this.endLogin(run, "failed", "Sign-in took too long and was closed. Try again."), LOGIN_TIMEOUT_MS), finished: false };
    run.timer.unref();
    this.login = run;
    this.d.log(`accounts: sign-in started (${o.engine}, ${o.newAccount ? "new account" : "existing"})`);
    const env = authEnv(this.env(o.engine, accountId));
    try {
      if (o.engine === "claude-code") this.claudeLogin(run, bin, env, method, o.email);
      else if (o.engine === "codex") void this.codexLogin(run, bin, env);
      else if (o.engine === "antigravity") void this.acpLogin(run, bin, env, o.engine);
      else this.cliLogin(run, bin, ["login"], env, engineName(o.engine));
    } catch (e) {
      this.endLogin(run, "failed", e instanceof Error ? e.message : String(e));
    }
    this.publish();
    return { ...view };
  }

  private claudeLogin(run: LoginRun, bin: string, env: NodeJS.ProcessEnv, method: LoginMethod, email?: string): void {
    const args = ["auth", "login", method === "console" ? "--console" : method === "sso" ? "--sso" : "--claudeai", ...(email ? ["--email", email] : [])];
    const child = spawnProgram(bin, args, { env, cwd: tmpdir(), stdio: ["pipe", "pipe", "pipe"] });
    let out = "";
    const onData = (d: Buffer): void => {
      out = (out + d.toString("utf8")).slice(-8000);
      const m = /https:\/\/[^\s"'<>]+/.exec(out);
      const v = run.view;
      let touched = false;
      if (m && !v.url) { v.url = m[0].replace(/[.,;)]+$/, ""); touched = true; }
      if (v.state === "starting" && (v.url || /opening browser|sign in/i.test(out))) { v.state = "waiting"; touched = true; }
      if (!v.can_paste && /paste code/i.test(out)) { v.can_paste = true; touched = true; }
      if (touched) this.publish();
    };
    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.stdin.on("error", () => {});
    child.on("error", (e) => this.endLogin(run, "failed", `could not start Claude Code: ${e.message}`));
    child.on("close", (code) => {
      if (run.finished) return;
      if (code === 0) void this.verifyLogin(run);
      else this.endLogin(run, "failed", out.trim().split("\n").filter((l) => l.trim() && !/^https:/.test(l.trim()) && !/paste code/i.test(l)).at(-1)?.slice(0, 200) || "Sign-in did not finish.");
    });
    run.cancel = () => { try { child.kill("SIGTERM"); } catch { /* already gone */ } };
    // The code the browser shows, for when it could not call back to this Mac. It goes to the program and is not kept.
    run.paste = (code) => { if (!run.view.can_paste || child.stdin.destroyed) return false; child.stdin.write(`${code}\n`); return true; };
  }

  /** A folder with an `open` that also writes the link it was given to a file, so a sign-in that opens the browser itself can still show the link. */
  private openShim(): string {
    const dir = join(this.root, "shims");
    const file = join(dir, "open");
    // Windows programs open the browser through PowerShell, not an `open` on PATH: nothing to put in front of it (the
    // program opens the browser itself; the paste-a-code box still works).
    if (process.platform === "win32") { mkdirSync(dir, { recursive: true }); return dir; }
    if (!existsSync(file)) {
      mkdirSync(dir, { recursive: true, mode: 0o700 });
      writeFileSync(file, '#!/bin/sh\numask 077\n[ -n "$OPSCODE_LOGIN_URL_FILE" ] && printf %s "$1" > "$OPSCODE_LOGIN_URL_FILE"\nexec "${OPSCODE_REAL_OPEN:-/usr/bin/open}" "$@"\n', { mode: 0o700 });
      chmodSync(file, 0o700);
    }
    return dir;
  }

  /** The sign-in link a program gave to `open`, once it has. Shows it as the link to use if the browser did not open. */
  private watchLoginUrl(run: LoginRun, urlFile: string): () => void {
    const t = setInterval(() => {
      if (run.finished || run.view.url) return;
      let u = "";
      try { u = readFileSync(urlFile, "utf8").trim().slice(0, 4000); } catch { return; }
      if (!loginUrlOk(run.view.engine, u)) return;
      run.view.url = u;
      run.view.state = "waiting";
      this.publish();
    }, 300);
    t.unref();
    return () => { clearInterval(t); try { rmSync(urlFile, { force: true }); } catch { /* gone */ } };
  }
  /** The file a sign-in's link is passed through: inside Opscode's private (0700) folder, never in a shared temp folder, as the link carries a one-time token. */
  private loginFile(run: LoginRun): string {
    const dir = join(this.root, "login");
    ensurePrivateDir(dir);
    return join(dir, `${run.view.id}.url`);
  }
  private loginEnv(env: NodeJS.ProcessEnv, urlFile: string): NodeJS.ProcessEnv {
    return { ...env, PATH: `${this.openShim()}${delimiter}${env.PATH ?? ""}`, OPSCODE_LOGIN_URL_FILE: urlFile, ...(process.env.OPSCODE_OPEN_BIN ? { OPSCODE_REAL_OPEN: process.env.OPSCODE_OPEN_BIN } : {}) };
  }

  /** Antigravity: ACP `authenticate` opens the browser and answers when the person has signed in. */
  private async acpLogin(run: LoginRun, bin: string, env: NodeJS.ProcessEnv, engine: AcpEngineId): Promise<void> {
    const name = engineName(engine);
    const urlFile = this.loginFile(run);
    const stop = this.watchLoginUrl(run, urlFile);
    const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => { if (!run.finished && !run.closing) this.endLogin(run, "failed", `${name} stopped before the sign-in finished.`); }, this.loginEnv(env, urlFile), ACP_ARGS[engine], name);
    run.cancel = () => { run.closing = true; stop(); rpc.close(); };
    try {
      const init = parseInit(await rpc.call("initialize", { protocolVersion: 1, clientCapabilities: {} }));
      const method = init.authMethods.find((m) => /oauth-personal|google|browser/i.test(`${m.id} ${m.name}`)) ?? init.authMethods[0];
      if (!method) throw new Error(`${name} did not offer a way to sign in.`);
      run.view.state = "waiting";
      this.publish();
      await rpc.call("authenticate", { methodId: method.id });
      run.closing = true;
      stop();
      rpc.close();
      await this.verifyLogin(run);
    } catch (e) {
      run.closing = true;
      stop();
      rpc.close();
      this.endLogin(run, "failed", e instanceof Error ? e.message.slice(0, 200) : String(e));
    }
  }

  /** A program with its own `login` command (Qoder): it opens the browser itself and exits when done. */
  private cliLogin(run: LoginRun, bin: string, args: string[], env: NodeJS.ProcessEnv, name: string): void {
    const urlFile = this.loginFile(run);
    const stop = this.watchLoginUrl(run, urlFile);
    const child = spawnProgram(bin, args, { env: this.loginEnv(env, urlFile), cwd: tmpdir(), stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    const onData = (d: Buffer): void => {
      out = (out + d.toString("utf8")).slice(-8000);
      const m = /https:\/\/[^\s"'<>]+/.exec(out);
      let touched = false;
      if (m && !run.view.url && loginUrlOk(run.view.engine, m[0].replace(/[.,;)]+$/, ""))) { run.view.url = m[0].replace(/[.,;)]+$/, ""); touched = true; }
      if (run.view.state === "starting" && (run.view.url || /browser|sign in|log ?in/i.test(out))) { run.view.state = "waiting"; touched = true; }
      if (touched) this.publish();
    };
    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.on("error", (e) => this.endLogin(run, "failed", `could not start ${name}: ${e.message}`));
    child.on("close", (code) => {
      stop();
      if (run.finished) return;
      if (code === 0) void this.verifyLogin(run);
      else this.endLogin(run, "failed", out.trim().split("\n").filter((l) => l.trim() && !/^https:/.test(l.trim())).at(-1)?.slice(0, 200) || "Sign-in did not finish.");
    });
    run.cancel = () => { stop(); try { child.kill("SIGTERM"); } catch { /* already gone */ } };
  }

  private async codexLogin(run: LoginRun, bin: string, env: NodeJS.ProcessEnv): Promise<void> {
    let loginId = "";
    const hold: { early: { success: boolean; error?: string } | null } = { early: null };
    const rpc = startAppServer(bin, tmpdir(), (method, p) => {
      if (method !== "account/login/completed" || run.finished) return;
      if (loginId && p.loginId !== loginId) return;
      const r = { success: p.success === true, ...(typeof p.error === "string" ? { error: p.error } : {}) };
      if (!loginId) hold.early = r; else void this.codexDone(run, rpc, r);
    }, async () => ({}), () => { if (!run.finished && !run.closing) this.endLogin(run, "failed", "Codex stopped before the sign-in finished."); }, env);
    run.cancel = () => { run.closing = true; if (loginId) void rpc.call("account/login/cancel", { loginId }).catch(() => undefined); rpc.close(); };
    try {
      await rpc.call("initialize", { clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" }, capabilities: null });
      rpc.notify("initialized");
      const r = await rpc.call("account/login/start", { type: "chatgpt" });
      loginId = String(r.loginId ?? "");
      const url = typeof r.authUrl === "string" ? r.authUrl : "";
      if (!loginId || !url) throw new Error("Codex did not give a sign-in link.");
      run.view.url = url;
      run.view.state = "waiting";
      this.publish();
      let host = "";
      try { host = new URL(url).hostname; } catch { /* checked below */ }
      if (!CODEX_HOSTS.test(host) || !openInBrowser(url)) run.view.message = "Open the link to sign in.";
      this.publish();
      if (hold.early) void this.codexDone(run, rpc, hold.early);
    } catch (e) {
      run.closing = true;
      rpc.close();
      this.endLogin(run, "failed", e instanceof Error ? e.message : String(e));
    }
  }

  private async codexDone(run: LoginRun, rpc: { close(): void }, r: { success: boolean; error?: string }): Promise<void> {
    run.closing = true;
    rpc.close();
    if (run.finished) return;
    if (r.success) await this.verifyLogin(run);
    else this.endLogin(run, "failed", (r.error ?? "Sign-in did not finish.").replace(/^Login server error:\s*/i, "").slice(0, 200));
  }

  /** The program says it finished: check it really shows a signed-in account, and that it is not one already added. */
  private async verifyLogin(run: LoginRun): Promise<void> {
    const { engine, account_id: id } = run.view;
    const s = await this.status(engine, id, true).catch(() => null);
    if (!s?.signed_in) return this.endLogin(run, "failed", "The sign-in finished but this Mac still shows no account. Try again.");
    if (run.view.new_account && s.email) {
      for (const other of this.records(engine)) {
        if (other.id === id) continue;
        const o = this.cache.get(this.key(engine, other.id));
        if (o?.signed_in && o.email?.toLowerCase() === s.email.toLowerCase() && (o.org ?? "") === (s.org ?? "") && (o.plan ?? "") === (s.plan ?? "")) {
          this.removeRecord(engine, id, true);
          return this.endLogin(run, "done", "That account is already added, so nothing new was added.", other.id);
        }
      }
    }
    if (run.view.new_account) { this.activeIds[engine] = id; this.save(); }
    this.endLogin(run, "done");
  }

  private endLogin(run: LoginRun, state: "done" | "failed" | "cancelled", message?: string, activate?: string): void {
    if (run.finished) return;
    run.finished = true;
    clearTimeout(run.timer);
    run.view.state = state;
    if (message) run.view.message = message; else delete run.view.message;
    if (activate) { this.activeIds[run.view.engine] = activate; this.save(); }
    if (state !== "done" && run.view.new_account) this.removeRecord(run.view.engine, run.view.account_id, true);
    if (state !== "done") try { run.cancel(); } catch { /* process may be gone */ }
    this.d.log(`accounts: sign-in ${state} (${run.view.engine})`);
    // A finished sign-in keeps the status it just verified, so the pushed update already says who is signed in.
    if (state !== "done") this.cache.delete(this.key(run.view.engine, run.view.account_id));
    this.publish();
    this.changed();
    if (state === "done") this.enginesChanged(run.view.engine);
  }

  /** Antigravity and Qoder tell their models once someone is signed in: let the windows re-read the engine list. */
  private enginesChanged(engine: AuthEngine): void {
    if (!isAcpEngine(engine)) return;
    void this.d.engines.list(true).then((engines) => this.d.notify("engines.changed", { engines, settings: this.d.engines.settings() })).catch(() => undefined);
  }

  loginCancel(loginId: string): void {
    if (!this.login || this.login.view.id !== loginId || this.login.finished) return;
    this.endLogin(this.login, "cancelled", "Sign-in cancelled.");
  }
  loginCode(loginId: string, code: string): void {
    const l = this.login;
    if (!l || l.view.id !== loginId || l.finished) throw new Error("that sign-in is not open any more");
    if (!l.paste?.(code)) throw new Error("This sign-in does not take a code. Finish it in the browser.");
  }

  // ---- sign out -----------------------------------------------------------------------------------------------------
  async logout(engine: AuthEngine, id: string): Promise<void> {
    if (!this.find(engine, id)) throw new Error("that account no longer exists");
    if (this.login && !this.login.finished) throw new Error("Finish or cancel the open sign-in first.");
    const n = this.d.busy?.(engine, id) ?? 0;
    if (n) throw new Error(`${n === 1 ? "A chat is" : `${n} chats are`} running on this account. Stop ${n === 1 ? "it" : "them"} first.`);
    const bin = this.bin(engine);
    if (!bin) throw new Error(`${engineName(engine)} isn't installed on this computer.`);
    // An added Antigravity or Qoder account is a folder of its own: signing out is removing that folder (nothing else holds its sign-in).
    if (isAcpEngine(engine) && id !== DEFAULT_ACCOUNT) {
      this.removeRecord(engine, id, true);
      this.d.log(`accounts: removed an added account (${engine})`);
      this.changed();
      return;
    }
    let r: { err: string };
    if (engine === "antigravity") r = await this.acpLogout(bin, authEnv(this.env(engine, id)));
    else r = await run(bin, engine === "claude-code" ? ["auth", "logout"] : ["logout"], authEnv(this.env(engine, id)));
    this.cache.delete(this.key(engine, id));
    const after = await this.status(engine, id, true);
    if (after.signed_in) throw new Error(`The program did not sign out${r.err.trim() ? `: ${r.err.trim().split("\n")[0].slice(0, 120)}` : ""}.${engine === "qoder" ? " Open Qoder in a terminal and type /logout." : ""}`);
    // An added account is only a sign-in: signed out, it leaves the list. The Mac's own stays, signed out.
    if (id !== DEFAULT_ACCOUNT) this.removeRecord(engine, id, true);
    this.d.log(`accounts: signed out (${engine}${id === DEFAULT_ACCOUNT ? ", the Mac's own" : ""})`);
    this.changed();
    this.enginesChanged(engine);
  }

  /** Antigravity signs out through ACP. */
  private async acpLogout(bin: string, env: NodeJS.ProcessEnv): Promise<{ err: string }> {
    const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => {}, env, ACP_ARGS.antigravity, "Antigravity");
    try {
      await rpc.call("initialize", { protocolVersion: 1, clientCapabilities: {} });
      await rpc.call("logout", {});
      return { err: "" };
    } catch (e) {
      return { err: e instanceof Error ? e.message : String(e) };
    } finally {
      rpc.close();
    }
  }

  private removeRecord(engine: AuthEngine, id: string, deleteHome: boolean): void {
    const i = this.extra.findIndex((a) => a.engine === engine && a.id === id);
    if (i < 0) return;
    const [a] = this.extra.splice(i, 1);
    if (this.activeIds[engine] === id) delete this.activeIds[engine];
    this.cache.delete(this.key(engine, id));
    this.persisted.delete(this.key(engine, id));
    try { this.save(); } catch { /* next save retries */ }
    // Only ever delete inside Opscode's own accounts folder.
    if (deleteHome && a.home && resolve(a.home).startsWith(resolve(this.root) + sep)) { try { rmSync(a.home, { recursive: true, force: true }); } catch { /* leftover folder is harmless */ } }
    this.d.removed?.(engine, id);
  }

  /** Settings the new account should share with the Mac's own, so it behaves the same (skills, CLAUDE.md, config). Sign-in is never shared. */
  private linkShared(engine: AuthEngine, home: string): void {
    if (engine === "antigravity") {
      // The home folder IS the account, so the agent's own tools (git, ssh, npm, the shell) need the usual dotfiles. ~/.gemini is never shared: it holds the sign-in.
      for (const n of [".gitconfig", ".ssh", ".npmrc", ".config", ".zshrc", ".zprofile", ".bashrc", ".nvm", ".cargo", ".rustup", ".bun", ".pyenv"]) {
        const from = join(homedir(), n);
        if (!existsSync(from)) continue;
        try { symlinkSync(from, join(home, n)); } catch (e) { this.d.log(`accounts: could not share ${n}: ${String(e)}`); }
      }
      return;
    }
    if (engine === "qoder") {
      const src = process.env.QODER_CONFIG_DIR || join(homedir(), ".qoder");
      for (const n of ["settings.json", "agents", "plugins"]) {
        const from = join(src, n);
        if (!existsSync(from)) continue;
        try { symlinkSync(from, join(home, n)); } catch (e) { this.d.log(`accounts: could not share ${n}: ${String(e)}`); }
      }
      return;
    }
    const src = engine === "claude-code" ? (process.env.OPSCODE_CLAUDE_HOME || process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude")) : (process.env.OPSCODE_CODEX_HOME || process.env.CODEX_HOME || join(homedir(), ".codex"));
    const names = engine === "claude-code" ? ["settings.json", "CLAUDE.md", "skills", "agents", "commands"] : ["config.toml", "AGENTS.md", "skills", "prompts"];
    for (const n of names) {
      const from = join(src, n);
      if (!existsSync(from)) continue;
      try { symlinkSync(from, join(home, n)); } catch (e) { this.d.log(`accounts: could not share ${n}: ${String(e)}`); }
    }
  }
}
