// "Where tokens go": finds Claude Code and Codex session logs, reads the new or
// changed ones in a worker thread, keeps a per-file cache, and builds reports.
//
// Read-only: it never changes or deletes those logs. Roots can be overridden for
// tests with OPSCODE_CLAUDE_LOGS and OPSCODE_CODEX_LOGS.

import { readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Worker } from "node:worker_threads";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";
import { buildReport } from "./report";
import type { ReportOptions, SessionLabel, UsageReport } from "./report";
import type { FileSummary } from "./scan";

const MAX_WINDOW_DAYS = 90;
const CACHE_VERSION = 1;
interface Entry { size: number; mtime: number; summary: FileSummary }
interface FileRef { path: string; kind: "claude" | "codex"; size: number; mtime: number; account: string }
/** An extra account's folder: its Claude logs are <home>/projects, its Codex logs <home>/sessions. */
export interface AccountHome { engine: "claude-code" | "codex"; id: string; home: string }

function walk(dir: string, out: string[], depth = 0): void {
  let names: string[];
  try { names = readdirSync(dir); } catch { return; }
  for (const n of names) {
    const p = join(dir, n);
    let st;
    try { st = statSync(p); } catch { continue; }
    if (st.isDirectory()) { if (depth < 8) walk(p, out, depth + 1); }
    else if (n.endsWith(".jsonl")) out.push(p);
  }
}

export class UsageService {
  private readonly file: string;
  private cache = new Map<string, Entry>();
  private logs = { claude_bytes: 0, codex_bytes: 0, claude_files: 0, codex_files: 0 };
  private scannedAt = 0;
  private running: Promise<void> | null = null;
  progress = { done: 0, total: 0 };

  /** Which account each scanned file belongs to (not cached on disk: it follows from where the file lives). */
  private accountOf = new Map<string, string>();

  constructor(stateDir: string, private readonly notify: (method: string, params: unknown) => void, private readonly labels: () => Map<string, SessionLabel>, private readonly homes: () => AccountHome[] = () => []) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "usage-cache.json");
  }

  private loaded = false;
  private idle: ReturnType<typeof setTimeout> | null = null;
  /** The cache is read from disk when first needed and dropped from memory after 5 idle minutes. */
  private ensure(): void {
    if (!this.loaded) {
      this.loaded = true;
      const raw = readJson(this.file);
      if (isRecord(raw) && raw.version === CACHE_VERSION && isRecord(raw.files)) {
        for (const [p, e] of Object.entries(raw.files)) if (isRecord(e) && typeof e.size === "number" && typeof e.mtime === "number" && isRecord(e.summary)) this.cache.set(p, e as unknown as Entry);
      }
    }
    if (this.idle) clearTimeout(this.idle);
    this.idle = setTimeout(() => { if (!this.running) { this.cache.clear(); this.loaded = false; } }, 5 * 60_000);
    this.idle.unref();
  }

  roots(): { claude: string; codex: string } {
    return { claude: process.env.OPSCODE_CLAUDE_LOGS || join(homedir(), ".claude", "projects"), codex: process.env.OPSCODE_CODEX_LOGS || join(homedir(), ".codex", "sessions") };
  }
  get scanning(): boolean { return this.running !== null; }
  get lastScan(): number { return this.scannedAt; }

  private list(): FileRef[] {
    const { claude, codex } = this.roots();
    const refs: FileRef[] = [];
    this.logs = { claude_bytes: 0, codex_bytes: 0, claude_files: 0, codex_files: 0 };
    this.accountOf = new Map();
    // The Mac's own sign-in first, then each extra account's folder.
    const roots: [string, "claude" | "codex", string][] = [[claude, "claude", "default"], [codex, "codex", "default"]];
    for (const a of this.homes()) roots.push(a.engine === "claude-code" ? [join(a.home, "projects"), "claude", a.id] : [join(a.home, "sessions"), "codex", a.id]);
    for (const [root, kind, account] of roots) {
      const found: string[] = [];
      walk(root, found);
      for (const path of found) {
        let st;
        try { st = statSync(path); } catch { continue; }
        this.logs[`${kind}_bytes`] += st.size;
        this.logs[`${kind}_files`]++;
        this.accountOf.set(path, account);
        // Only files touched inside the longest window matter.
        if (Date.now() - st.mtimeMs <= (MAX_WINDOW_DAYS + 1) * 86_400_000) refs.push({ path, kind, size: st.size, mtime: Math.round(st.mtimeMs), account });
      }
    }
    return refs;
  }

  /** Reads what is new or changed. Resolves when the cache is current. */
  scan(force = false): Promise<void> {
    if (this.running) return this.running;
    this.ensure();
    this.running = (async () => {
      const refs = this.list();
      const live = new Set(refs.map((r) => r.path));
      for (const p of [...this.cache.keys()]) if (!live.has(p)) this.cache.delete(p);
      const todo = refs.filter((r) => force || !this.cache.has(r.path) || this.cache.get(r.path)!.size !== r.size || this.cache.get(r.path)!.mtime !== r.mtime);
      this.progress = { done: 0, total: todo.length };
      this.notify("usage.progress", { ...this.progress });
      if (todo.length) await this.readInWorker(todo);
      this.scannedAt = Date.now();
      try { writeJsonAtomic(this.file, { version: CACHE_VERSION, files: Object.fromEntries(this.cache) }); } catch { /* cache is optional */ }
      this.notify("usage.ready", { scanned_at: this.scannedAt });
    })().finally(() => { this.running = null; });
    return this.running;
  }

  private readInWorker(todo: FileRef[]): Promise<void> {
    return new Promise((resolve) => {
      const byPath = new Map(todo.map((r) => [r.path, r]));
      const w = new Worker(join(__dirname, "worker.js"), { workerData: { jobs: todo.map((r) => ({ path: r.path, kind: r.kind })) } });
      let finished = false;
      const end = (): void => { if (!finished) { finished = true; resolve(); } };
      w.on("message", (m: { type: string; path?: string; summary?: FileSummary | null; done?: number }) => {
        if (m.type === "file" && m.path) {
          const ref = byPath.get(m.path);
          if (ref && m.summary) this.cache.set(m.path, { size: ref.size, mtime: ref.mtime, summary: m.summary });
          this.progress.done++;
        } else if (m.type === "progress") this.notify("usage.progress", { ...this.progress });
        else if (m.type === "done") { void w.terminate(); end(); }
      });
      w.on("error", end);
      w.on("exit", end);
    });
  }

  /** The report for every account, or for one ("default" = the Mac's own sign-in). */
  report(days: number, now = Date.now(), account?: string): UsageReport {
    this.ensure();
    const opts: ReportOptions = { days: Math.min(MAX_WINDOW_DAYS, Math.max(1, Math.round(days))), now, labels: this.labels(), logs: this.logs };
    const files = [...this.cache.entries()].filter(([p]) => account === undefined || (this.accountOf.get(p) ?? "default") === account).map(([, e]) => e.summary);
    return buildReport(files, opts);
  }

  /** One headline per account that has logs: for the account picker on the tokens tab. */
  perAccount(days: number, now = Date.now()): { account: string; claude_usd: number; claude_sessions: number; codex_sessions: number; codex_tokens: number }[] {
    this.ensure();
    const ids = new Set<string>(["default"]);
    for (const a of this.homes()) ids.add(a.id);
    return [...ids].map((account) => {
      const r = this.report(days, now, account);
      return { account, claude_usd: r.claude?.usd ?? 0, claude_sessions: r.claude?.sessions ?? 0, codex_sessions: r.codex?.sessions ?? 0, codex_tokens: r.codex ? r.codex.input + r.codex.output : 0 };
    });
  }
}
