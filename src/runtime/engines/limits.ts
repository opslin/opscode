// Plan usage limits for the coding agents: Claude's 5-hour session and weekly
// windows, Codex's 5-hour and weekly windows, when each resets, and the plan.
//
// Read-only and free: neither check runs a model.
//  - Claude Code: start `claude -p` (stream-json), send the `get_usage` control request.
//  - Codex: start `codex app-server`, call `account/rateLimits/read` and `account/read`.
// Engines also report limits while chats run (Claude's rate_limit_event, Codex's
// account/rateLimits/updated); those update the same store without a new check.

import { spawnProgram } from "../proc";
import { tmpdir } from "node:os";
import { cleanEnv, type EngineStore } from "./detect";
import { startAppServer } from "./codex";
import { DEFAULT_ACCOUNT, type AccountStore } from "./accounts";

export type LimitKind = "session" | "weekly" | "monthly";
export interface LimitWindow {
  id: string;
  kind: LimitKind;
  label: string;
  /** 0-100. */
  used_percent: number;
  /** ISO time the window refills. */
  resets_at?: string;
  window_mins?: number;
}
export interface ResetCredit {
  id: string;
  title: string;
  /** What it resets, as the engine words it ("Full reset (Weekly + 5 hr)"). */
  description?: string;
  granted_at?: string;
  expires_at?: string;
}
export interface EngineLimits {
  engine: "claude-code" | "codex";
  /** The account these numbers belong to ("default" = the Mac's own sign-in). */
  account_id?: string;
  state: "ok" | "unavailable" | "error" | "missing";
  plan?: string;
  windows: LimitWindow[];
  /** Free full resets the account holds (shown, never used here), soonest expiry first. */
  reset_credits?: number;
  reset_credit_list?: ResetCredit[];
  /** Set when the engine says a limit stopped work. */
  reached?: string;
  message?: string;
  checked_at: string;
}

const WEEK = 10_080;
const clamp = (n: number): number => Math.max(0, Math.min(100, Math.round(n * 10) / 10));
const iso = (v: unknown): string | undefined => {
  if (typeof v === "number" && Number.isFinite(v) && v > 0) return new Date(v < 1e12 ? v * 1000 : v).toISOString();
  if (typeof v === "string" && v) { const t = Date.parse(v); return Number.isFinite(t) ? new Date(t).toISOString() : undefined; }
  return undefined;
};
const rec = (v: unknown): Record<string, unknown> | null => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null);
const CLAUDE_WINDOWS: Record<string, { kind: LimitKind; label: string; mins: number }> = {
  five_hour: { kind: "session", label: "5-hour session", mins: 300 },
  seven_day: { kind: "weekly", label: "Weekly", mins: WEEK },
  seven_day_opus: { kind: "weekly", label: "Weekly · Opus", mins: WEEK },
  seven_day_sonnet: { kind: "weekly", label: "Weekly · Sonnet", mins: WEEK },
};

/** Claude Code's get_usage answer -> windows (utilization there is already 0-100). */
export function claudeUsageToLimits(r: Record<string, unknown>, at = new Date()): EngineLimits {
  const base = { engine: "claude-code" as const, checked_at: at.toISOString(), ...(typeof r.subscription_type === "string" ? { plan: r.subscription_type } : {}) };
  const rl = rec(r.rate_limits);
  if (r.rate_limits_available !== true || !rl) return { ...base, state: "unavailable", windows: [], message: "Claude Code doesn't report plan limits for this sign-in (API keys have no 5-hour or weekly limits)." };
  const windows: LimitWindow[] = [];
  for (const [id, def] of Object.entries(CLAUDE_WINDOWS)) {
    const w = rec(rl[id]);
    if (w && typeof w.utilization === "number") windows.push({ id, kind: def.kind, label: def.label, used_percent: clamp(w.utilization), window_mins: def.mins, ...(iso(w.resets_at) ? { resets_at: iso(w.resets_at) } : {}) });
  }
  // Per-model weekly limits (e.g. Fable): [{ display_name, utilization 0-100, resets_at }].
  if (Array.isArray(rl.model_scoped)) {
    for (const raw of rl.model_scoped) {
      const w = rec(raw);
      if (!w || typeof w.display_name !== "string" || typeof w.utilization !== "number") continue;
      const name = w.display_name.slice(0, 40);
      windows.push({ id: `seven_day_${name.toLowerCase().replace(/[^a-z0-9]+/g, "_")}`, kind: "weekly", label: `Weekly · ${name}`, used_percent: clamp(w.utilization), window_mins: WEEK, ...(iso(w.resets_at) ? { resets_at: iso(w.resets_at) } : {}) });
    }
  }
  const extra = rec(rl.extra_usage);
  if (extra?.is_enabled === true && typeof extra.utilization === "number") windows.push({ id: "extra_usage", kind: "monthly", label: "Extra usage this month", used_percent: clamp(extra.utilization) });
  const locked = Object.values(rl).map(rec).find((w) => w && typeof w.locked_reason === "string" && w.locked_reason);
  return { ...base, state: "ok", windows, ...(locked ? { reached: String(locked.locked_reason) } : {}) };
}

/** Codex's account/rateLimits/read answer -> windows (primary = 5 hours, secondary = weekly). */
export function codexLimitsToLimits(r: Record<string, unknown>, plan?: string, at = new Date()): EngineLimits {
  const snap = rec(r.rateLimits) ?? r;
  const windows: LimitWindow[] = [];
  for (const [id, raw] of [["primary", snap.primary], ["secondary", snap.secondary]] as const) {
    const w = rec(raw);
    if (!w || typeof w.usedPercent !== "number") continue;
    const mins = typeof w.windowDurationMins === "number" ? w.windowDurationMins : id === "primary" ? 300 : WEEK;
    const kind: LimitKind = mins >= 1440 ? "weekly" : "session";
    windows.push({ id, kind, label: kind === "weekly" ? (mins === WEEK ? "Weekly" : `${Math.round(mins / 1440)}-day`) : mins === 300 ? "5-hour session" : `${Math.round(mins / 60)}-hour session`, used_percent: clamp(w.usedPercent), window_mins: mins, ...(iso(w.resetsAt) ? { resets_at: iso(w.resetsAt) } : {}) });
  }
  const credits = rec(r.rateLimitResetCredits);
  const available = typeof credits?.availableCount === "number" ? credits.availableCount : undefined;
  const list: ResetCredit[] = (Array.isArray(credits?.credits) ? (credits.credits as unknown[]) : [])
    .map(rec)
    .filter((c): c is Record<string, unknown> => !!c && (c.status === undefined || c.status === "available"))
    .map((c) => ({ id: String(c.id ?? "").slice(0, 80), title: String(c.title ?? "Reset").slice(0, 80), ...(typeof c.description === "string" ? { description: c.description.slice(0, 200) } : {}), ...(iso(c.grantedAt) ? { granted_at: iso(c.grantedAt) } : {}), ...(iso(c.expiresAt) ? { expires_at: iso(c.expiresAt) } : {}) }))
    .sort((a, b) => (a.expires_at ?? "9").localeCompare(b.expires_at ?? "9"));
  const p = plan ?? (typeof snap.planType === "string" ? snap.planType : undefined);
  return {
    engine: "codex", checked_at: at.toISOString(), state: windows.length ? "ok" : "unavailable", windows,
    ...(p ? { plan: p } : {}), ...(available !== undefined ? { reset_credits: available } : {}), ...(list.length ? { reset_credit_list: list } : {}),
    ...(typeof snap.rateLimitReachedType === "string" ? { reached: snap.rateLimitReachedType } : {}),
    ...(windows.length ? {} : { message: "Codex doesn't report plan limits for this sign-in (API keys have none)." }),
  };
}

function probeClaude(bin: string, baseEnv: NodeJS.ProcessEnv = cleanEnv()): Promise<EngineLimits> {
  return new Promise((resolve) => {
    const env = { ...baseEnv };
    for (const k of Object.keys(env)) if (k === "CLAUDECODE" || k.startsWith("CLAUDE_CODE_ENTRYPOINT")) delete env[k];
    const child = spawnProgram(bin, ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose", "--strict-mcp-config"], { cwd: tmpdir(), env, stdio: ["pipe", "pipe", "pipe"] });
    let done = false;
    let buf = "";
    let err = "";
    const finish = (v: EngineLimits): void => { if (done) return; done = true; clearTimeout(timer); resolve(v); child.stdin.end(); setTimeout(() => { if (child.exitCode === null) child.kill("SIGTERM"); }, 500).unref(); };
    const fail = (message: string): void => finish({ engine: "claude-code", state: "error", windows: [], message, checked_at: new Date().toISOString() });
    const timer = setTimeout(() => fail("Claude Code didn't answer in 25 seconds."), 25_000);
    const send = (o: unknown): void => { if (!child.stdin.destroyed) child.stdin.write(`${JSON.stringify(o)}\n`); };
    child.on("error", (e) => fail(`could not start Claude Code: ${e.message}`));
    child.on("close", () => fail(err.trim().split("\n").at(-1)?.slice(0, 200) || "Claude Code stopped before answering."));
    child.stdin.on("error", () => {});
    child.stderr.on("data", (d: Buffer) => (err = (err + d.toString("utf8")).slice(-2000)));
    child.stdout.on("data", (d: Buffer) => {
      buf += d.toString("utf8");
      let i: number;
      while ((i = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 1);
        let m: Record<string, unknown>;
        try { m = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
        if (m.type !== "control_response") continue;
        const r = rec(m.response);
        if (!r) continue;
        if (r.request_id === "opscode-init") send({ type: "control_request", request_id: "opscode-usage", request: { subtype: "get_usage", skip_behaviors: true } });
        else if (r.request_id === "opscode-usage") {
          if (r.subtype !== "success") fail(String(r.error ?? "Claude Code couldn't read the limits (it may be too old: update it)."));
          else finish(claudeUsageToLimits(rec(r.response) ?? {}));
        }
      }
    });
    send({ type: "control_request", request_id: "opscode-init", request: { subtype: "initialize" } });
  });
}

async function probeCodex(bin: string, env: NodeJS.ProcessEnv = cleanEnv()): Promise<EngineLimits> {
  const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => {}, env);
  const timeout = <T>(p: Promise<T>): Promise<T> => Promise.race([p, new Promise<never>((_, rej) => setTimeout(() => rej(new Error("Codex didn't answer in 20 seconds.")), 20_000).unref())]);
  try {
    await timeout(rpc.call("initialize", { clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" }, capabilities: null }));
    rpc.notify("initialized");
    const [limits, account] = await Promise.all([timeout(rpc.call("account/rateLimits/read", {})), timeout(rpc.call("account/read", { refreshToken: false })).catch(() => ({}))]);
    const plan = rec((account as Record<string, unknown>).account)?.planType;
    return codexLimitsToLimits(limits, typeof plan === "string" ? plan : undefined);
  } catch (e) {
    return { engine: "codex", state: "error", windows: [], message: e instanceof Error ? e.message : String(e), checked_at: new Date().toISOString() };
  } finally {
    rpc.close();
  }
}

export class LimitsStore {
  /** Keyed by "<engine>:<account>". */
  private data = new Map<string, EngineLimits>();
  private inflight = new Map<string, Promise<EngineLimits>>();

  constructor(private readonly engines: EngineStore, private readonly accounts: AccountStore | undefined, private readonly changed: (all: EngineLimits[], byAccount: EngineLimits[]) => void) {}

  private key = (engine: "claude-code" | "codex", account: string): string => `${engine}:${account}`;
  private activeOf = (engine: "claude-code" | "codex"): string => this.accounts?.active(engine) ?? DEFAULT_ACCOUNT;
  private tag(v: EngineLimits, account: string): EngineLimits { return { ...v, account_id: account }; }

  /** What the rest of the app reads: the numbers for the account new chats use, one entry per engine. */
  all(): EngineLimits[] {
    return (["claude-code", "codex"] as const).flatMap((e) => { const v = this.data.get(this.key(e, this.activeOf(e))); return v ? [v] : []; });
  }
  /** Every account's numbers. */
  everything(): EngineLimits[] { return [...this.data.values()]; }
  /** The numbers for one account, or undefined when not read yet. */
  forAccount(engine: "claude-code" | "codex", account: string): EngineLimits | undefined { return this.data.get(this.key(engine, account)); }
  private emit(): void { this.changed(this.all(), this.everything()); }

  /** Checks the active account of each engine (each at most once a minute unless forced); `allAccounts` also checks the others. */
  async refresh(force = false, allAccounts = false): Promise<EngineLimits[]> {
    const jobs: Promise<EngineLimits>[] = [];
    for (const e of ["claude-code", "codex"] as const) {
      const ids = allAccounts && this.accounts ? this.accounts.records(e).map((a) => a.id) : [this.activeOf(e)];
      for (const id of ids) jobs.push(this.check(e, id, force));
    }
    await Promise.all(jobs);
    return this.all();
  }

  /** Checks one account (at most once a minute unless forced). */
  refreshAccount(engine: "claude-code" | "codex", account: string, force = false): Promise<EngineLimits> { return this.check(engine, account, force); }

  /** Forget an account's numbers (it was removed). */
  drop(engine: "claude-code" | "codex", account: string): void {
    if (this.data.delete(this.key(engine, account))) this.emit();
  }

  private check(engine: "claude-code" | "codex", account: string, force: boolean): Promise<EngineLimits> {
    const k = this.key(engine, account);
    const have = this.data.get(k);
    if (!force && have && have.state !== "error" && Date.now() - Date.parse(have.checked_at) < 60_000) return Promise.resolve(have);
    const running = this.inflight.get(k);
    if (running) return running;
    const bin = engine === "claude-code" ? this.engines.claudePath() : this.engines.codexPath();
    const env = this.accounts ? this.accounts.env(engine, account) : cleanEnv();
    const p = (bin ? (engine === "claude-code" ? probeClaude(bin, env) : probeCodex(bin, env)) : Promise.resolve<EngineLimits>({ engine, state: "missing", windows: [], message: `${engine === "claude-code" ? "Claude Code" : "Codex"} isn't installed on this computer.`, checked_at: new Date().toISOString() }))
      .then((v0) => {
        const v = this.tag(v0, account);
        // Keep the last good windows if a check fails, but say it failed.
        const prev = this.data.get(k);
        const next = v.state === "error" && prev?.windows.length ? { ...prev, message: v.message, state: "error" as const, checked_at: v.checked_at } : v;
        this.data.set(k, next);
        this.emit();
        return next;
      })
      .finally(() => this.inflight.delete(k));
    this.inflight.set(k, p);
    return p;
  }

  /** Claude's rate_limit_event during a chat: { rateLimitType, utilization 0-1, resetsAt (s), status }. */
  fromClaudeEvent(info: Record<string, unknown>, account: string = DEFAULT_ACCOUNT): void {
    const type = String(info.rateLimitType ?? "");
    const def = CLAUDE_WINDOWS[type];
    if (!def || typeof info.utilization !== "number") return;
    this.merge("claude-code", account, { id: type, kind: def.kind, label: def.label, used_percent: clamp(info.utilization * 100), window_mins: def.mins, ...(iso(info.resetsAt) ? { resets_at: iso(info.resetsAt) } : {}) }, info.status === "rejected" ? type : undefined);
  }

  /** Codex's account/rateLimits/updated during a chat. */
  fromCodexUpdate(params: Record<string, unknown>, account: string = DEFAULT_ACCOUNT): void {
    const k = this.key("codex", account);
    const v = codexLimitsToLimits(params, this.data.get(k)?.plan);
    if (!v.windows.length) return;
    const prev = this.data.get(k);
    this.data.set(k, this.tag({ ...v, ...(prev?.reset_credits !== undefined && v.reset_credits === undefined ? { reset_credits: prev.reset_credits, ...(prev.reset_credit_list ? { reset_credit_list: prev.reset_credit_list } : {}) } : {}) }, account));
    this.emit();
  }

  private merge(engine: "claude-code" | "codex", account: string, w: LimitWindow, reached?: string): void {
    const k = this.key(engine, account);
    const prev = this.data.get(k) ?? { engine, account_id: account, state: "ok" as const, windows: [], checked_at: new Date().toISOString() };
    const windows = [...prev.windows.filter((x) => x.id !== w.id), w].sort((a, b) => (a.window_mins ?? 0) - (b.window_mins ?? 0));
    this.data.set(k, { ...prev, account_id: account, state: "ok", windows, checked_at: new Date().toISOString(), ...(reached ? { reached } : {}) });
    this.emit();
  }
}
