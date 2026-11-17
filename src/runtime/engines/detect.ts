// Coding-agent engines installed on this computer: Claude Code (`claude`), Codex
// (`codex`, also shipped inside the ChatGPT app), Antigravity (`agy`) and Qoder (`qoder`).
// They run with your own sign-in, so chats on them use your Claude, ChatGPT, Google or
// Qoder plan, not an API key.

import { execProgram, PROGRAM_EXTS, userToolDirs } from "../proc";
import { accessSync, constants, statSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, isAbsolute, join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";

import { AGENT_ENGINES, type AgentEngineId } from "../../shared/protocol";
const AGENT_IDS = AGENT_ENGINES;

export type EngineId = "api" | AgentEngineId;
export const ENGINE_IDS: readonly EngineId[] = ["api", "claude-code", "codex", "antigravity", "qoder"];
/** Display names. */
export const ENGINE_NAMES: Record<AgentEngineId, string> = { "claude-code": "Claude Code", codex: "Codex", antigravity: "Antigravity", qoder: "Qoder" };
export const EFFORTS = ["low", "medium", "high", "xhigh", "max"] as const;

export interface EngineModel {
  id: string;
  label: string;
  efforts?: string[];
  smart?: number;
  price?: number;
  more?: boolean;
  description?: string;
}
export interface EngineInfo {
  id: AgentEngineId;
  label: string;
  found: boolean;
  path: string | null;
  version: string | null;
  /** Set when the program was found but did not answer --version. */
  error?: string;
  models: EngineModel[];
}

export interface EngineSettings {
  claude_path: string;
  codex_path: string;
  /** Antigravity's `agy` and Qoder's `qoder` programs: empty = look for them. */
  antigravity_path: string;
  qoder_path: string;
  /** Claude Code: skip your MCP servers (they add tens of thousands of tokens to every request). */
  claude_lean: boolean;
  /** How lean a Chief's Claude Code workers start: standard, lean (no skills) or leanest (also no user-level settings). Normal chats are never affected. */
  worker_start: "standard" | "lean" | "leanest";
  default_engine: EngineId;
  default_model: string;
  default_effort: string;
  /** H4: when Claude Code or Codex runs out of its plan limit, a Normal chat continues on the other one. Off by default. */
  auto_switch: boolean;
}
const DEFAULTS: EngineSettings = { claude_path: "", codex_path: "", antigravity_path: "", qoder_path: "", claude_lean: true, worker_start: "lean", default_engine: "api", default_model: "", default_effort: "", auto_switch: false };

/** Claude models offered for Claude Code. The renderer adds bars and price from public benchmark facts; "more" ones sit under More models. */
const CLAUDE_MODELS: EngineModel[] = [
  { id: "claude-opus-5-5", label: "Opus 5.5", description: "The most capable; for plans, reviews and hard problems." },
  { id: "claude-sonnet-5-5", label: "Sonnet 5.5", description: "Strong and quicker; good for most coding." },
  { id: "claude-fable-5-2", label: "Fable 5.2", description: "Newest Fable." },
  { id: "claude-haiku-5-5", label: "Haiku 5.5", description: "Fast and cheap; for small jobs and summaries." },
  ...([["claude-fable-5-1", "Fable 5.1"], ["claude-fable-5", "Fable 5"], ["claude-opus-5", "Opus 5"], ["claude-opus-4-8", "Opus 4.8"], ["claude-opus-4-7", "Opus 4.7"], ["claude-opus-4-6", "Opus 4.6"], ["claude-opus-4-5", "Opus 4.5"], ["claude-sonnet-5", "Sonnet 5"], ["claude-sonnet-4-6", "Sonnet 4.6"], ["claude-haiku-4-5", "Haiku 4.5"]] as const).map(([id, label]) => ({ id, label, more: true })),
];

function executable(p: string): boolean {
  try {
    if (!statSync(p).isFile()) return false;
    accessSync(p, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/** First executable named `name` on PATH or in the extra places. */
export function findProgram(name: string, extra: string[]): string | null {
  const dirs = [...(process.env.PATH ?? "").split(delimiter), ...extra, ...userToolDirs()].filter(Boolean);
  for (const d of dirs) {
    // Windows: claude.exe / claude.cmd (never the extension-less script npm also leaves there); elsewhere: the plain name.
    for (const ext of PROGRAM_EXTS) {
      const base = ext && d.toLowerCase().endsWith(`${name.toLowerCase()}${ext}`) ? d : join(d, `${name}${ext}`);
      if (executable(base)) return base;
    }
  }
  return null;
}

const version = (path: string): Promise<{ version: string | null; error?: string }> =>
  new Promise((resolve) => {
    execProgram(path, ["--version"], { timeout: 8000, env: cleanEnv() }, (err, out) => {
      if (err) resolve({ version: null, error: err.message.split("\n")[0] });
      else resolve({ version: String(out).trim().split("\n")[0].slice(0, 80) });
    });
  });

/** The environment for engine processes: ours minus Electron's switch and our own bootstrap details. */
export function cleanEnv(): NodeJS.ProcessEnv {
  const env = { ...process.env };
  delete env.ELECTRON_RUN_AS_NODE;
  for (const k of Object.keys(env)) if (k.startsWith("OPSCODE_") && !k.startsWith("OPSCODE_FAKE_")) delete env[k];
  return env;
}

export class EngineStore {
  private readonly file: string;
  private readonly cacheFile: string;
  private persistTimer: NodeJS.Timeout | null = null;
  /** What the last run found (programs, versions, models), read from disk at start so the picker is never empty while the programs are asked again. */
  private snapshot: EngineInfo[] | null = null;
  private s: EngineSettings;
  private cache: { at: number; list: EngineInfo[] } | null = null;
  private codexModels: EngineModel[] | null = null;
  private acp: Partial<Record<AgentEngineId, EngineModel[]>> = {};

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "engines.json");
    this.cacheFile = join(stateDir, "engines-cache.json");
    this.loadSnapshot();
    const raw = readJson(this.file);
    this.s = { ...DEFAULTS };
    if (isRecord(raw)) {
      for (const k of Object.keys(DEFAULTS) as (keyof EngineSettings)[]) {
        if (typeof raw[k] === typeof DEFAULTS[k]) (this.s as unknown as Record<string, unknown>)[k] = raw[k];
      }
    }
  }

  /** The last known engine list from disk (stale until the programs are asked again), or null the very first time. */
  cached(): EngineInfo[] | null {
    return this.cache?.list ?? this.snapshot;
  }

  private loadSnapshot(): void {
    const raw = readJson(this.cacheFile);
    if (!isRecord(raw) || raw.version !== 1 || !Array.isArray(raw.engines)) return;
    const list: EngineInfo[] = [];
    for (const e of raw.engines) {
      if (!isRecord(e) || !(AGENT_IDS as readonly unknown[]).includes(e.id) || typeof e.label !== "string" || typeof e.found !== "boolean" || !Array.isArray(e.models)) continue;
      const models = (e.models as unknown[]).filter((m): m is EngineModel => isRecord(m) && typeof m.id === "string" && typeof m.label === "string").slice(0, 200).map((m) => ({ ...m }));
      list.push({ id: e.id as AgentEngineId, label: e.label, found: e.found, path: typeof e.path === "string" ? e.path : null, version: typeof e.version === "string" ? e.version : null, models });
    }
    if (!list.length) return;
    this.snapshot = list;
    for (const e of list) { if (e.id === "codex") this.codexModels = e.models; else if (e.id === "antigravity" || e.id === "qoder") this.acp[e.id] = e.models; }
  }

  /** Remembers the list for the next start (soon after the last change, so a burst of updates writes once). */
  private persist(list: EngineInfo[]): void {
    this.snapshot = list;
    if (this.persistTimer) return;
    this.persistTimer = setTimeout(() => {
      this.persistTimer = null;
      try { writeJsonAtomic(this.cacheFile, { version: 1, saved_at: new Date().toISOString(), engines: this.snapshot }); } catch { /* the cache is only a speed-up */ }
    }, 250);
    this.persistTimer.unref();
  }

  settings(): EngineSettings {
    return { ...this.s };
  }

  update(patch: Partial<EngineSettings>): EngineSettings {
    const PATH_NAMES = { claude_path: "Claude Code", codex_path: "Codex", antigravity_path: "Antigravity", qoder_path: "Qoder" } as const;
    for (const k of Object.keys(PATH_NAMES) as (keyof typeof PATH_NAMES)[]) {
      const v = patch[k];
      if (v !== undefined && v !== "" && (!isAbsolute(v) || !executable(v))) throw new Error(`${PATH_NAMES[k]}: ${v} is not a program on this computer`);
    }
    if (patch.default_engine !== undefined && !ENGINE_IDS.includes(patch.default_engine)) throw new Error("unknown engine");
    if (patch.worker_start !== undefined && !["standard", "lean", "leanest"].includes(patch.worker_start)) throw new Error("unknown worker start level");
    if (patch.default_effort !== undefined && patch.default_effort !== "" && !(EFFORTS as readonly string[]).includes(patch.default_effort)) throw new Error("unknown effort");
    this.s = { ...this.s, ...patch };
    writeJsonAtomic(this.file, this.s);
    this.cache = null;
    return this.settings();
  }

  claudePath(): string | null {
    return process.env.OPSCODE_CLAUDE_BIN || this.s.claude_path || findProgram("claude", [join(homedir(), ".local/bin"), join(homedir(), ".claude/local"), "/opt/homebrew/bin", "/usr/local/bin", join(homedir(), ".claude", "local", "node_modules", ".bin")]);
  }

  codexPath(): string | null {
    return process.env.OPSCODE_CODEX_BIN || this.s.codex_path || findProgram("codex", [
      join(homedir(), ".local/bin"), "/opt/homebrew/bin", "/usr/local/bin",
      "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin",
      "/Applications/Codex.app/Contents/Resources/codex-cli/bin",
      join(homedir(), "Applications/ChatGPT.app/Contents/Resources/codex-cli/bin"),
      join(homedir(), ".codex", "bin"),
      join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "codex"),
      join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "Codex", "bin"),
    ]);
  }

  /** Antigravity's command-line program (`agy`, installed under ~/.gemini/bin). */
  antigravityPath(): string | null {
    return process.env.OPSCODE_AGY_BIN || this.s.antigravity_path || findProgram("agy", [join(homedir(), ".gemini/bin"), join(homedir(), ".local/bin"), "/opt/homebrew/bin", "/usr/local/bin", join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "Antigravity", "bin")]);
  }

  /** Qoder's command-line program (`qoder`; the installer's own name for it is `qodercli`). */
  qoderPath(): string | null {
    const extra = [join(homedir(), ".local/bin"), join(homedir(), ".qoder/bin"), "/opt/homebrew/bin", "/usr/local/bin", join(homedir(), ".npm-global/bin"), join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "Qoder", "bin")];
    return process.env.OPSCODE_QODER_BIN || this.s.qoder_path || findProgram("qoder", extra) || findProgram("qodercli", extra);
  }

  /** The program for an engine, or null. */
  pathOf(engine: AgentEngineId): string | null {
    return engine === "claude-code" ? this.claudePath() : engine === "codex" ? this.codexPath() : engine === "antigravity" ? this.antigravityPath() : this.qoderPath();
  }

  /** Models an ACP agent reported (Antigravity, Qoder); empty until it was asked. */
  acpModels(engine: AgentEngineId): EngineModel[] { return this.acp[engine] ?? []; }
  setAcpModels(engine: AgentEngineId, list: EngineModel[]): void {
    this.acp[engine] = list;
    this.cache = null;
    if (this.snapshot) this.persist(this.snapshot.map((e) => (e.id === engine ? { ...e, models: list } : e)));
  }

  /** Codex model ids this computer's Codex reported (empty until it was asked). */
  codexModelIds(): string[] { return (this.codexModels ?? []).map((m) => m.id); }
  setCodexModels(list: EngineModel[]): void {
    this.codexModels = list;
    this.cache = null;
    if (this.snapshot) this.persist(this.snapshot.map((e) => (e.id === "codex" ? { ...e, models: list } : e)));
  }

  async list(refresh = false): Promise<EngineInfo[]> {
    if (!refresh && this.cache && Date.now() - this.cache.at < 60_000) return this.cache.list;
    // Every program is asked for its version at the same time (each answer takes a moment to start up).
    const ids: AgentEngineId[] = ["claude-code", "codex", "antigravity", "qoder"];
    const out = await Promise.all(ids.map(async (id): Promise<EngineInfo> => {
      const p = this.pathOf(id);
      const v = p ? await version(p) : { version: null };
      const models = id === "claude-code" ? CLAUDE_MODELS.map((m) => ({ ...m, efforts: [...EFFORTS] })) : id === "codex" ? this.codexModels ?? [] : this.acpModels(id);
      return { id, label: ENGINE_NAMES[id], found: !!p && !!v.version, path: p, version: v.version, ...(v.error ? { error: v.error } : {}), models };
    }));
    this.cache = { at: Date.now(), list: out };
    this.persist(out);
    return out;
  }

}
