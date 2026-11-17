// Reads one Claude Code or Codex session log (JSONL) into a compact summary.
// Streams the file line by line, parses only the lines that matter, and never
// keeps message text beyond a short label for the session's first prompt.

import { createReadStream } from "node:fs";
import { basename } from "node:path";
import { createInterface } from "node:readline";

/** [time ms, model, input, cache write, cache read, output, flags (1 = 1-hour cache, 2 = sub-agent), message id, session id] */
export type Call = [number, string, number, number, number, number, number, string, string];

export interface SessionMeta {
  /** Project label: the worktree name, else the folder name. */
  proj: string;
  /** Where it ran from: claude-desktop, sdk-cli, sdk-ts, ... */
  entry?: string;
  first: string;
  prompts: number;
  compacts: number;
  images: number;
  /** Tool results as [time ms, tool name, characters]. */
  results: [number, string, number][];
}
export interface ClaudeSummary { kind: "claude"; calls: Call[]; sessions: Record<string, SessionMeta> }
export interface CodexSummary {
  kind: "codex";
  sid: string;
  model: string | null;
  proj: string;
  originator: string | null;
  first: number;
  last: number;
  input: number;
  cached: number;
  output: number;
  reasoning: number;
  weekly_used?: number;
  session_used?: number;
}
export type FileSummary = ClaudeSummary | CodexSummary;

export const projectName = (cwd: unknown): string => {
  if (typeof cwd !== "string" || !cwd) return "?";
  const w = /worktrees\/([^/]+)/.exec(cwd);
  if (w) return w[1];
  const base = cwd.replace(/\/+$/, "").split("/").pop();
  return base || cwd;
};
const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);

async function* lines(path: string): AsyncGenerator<string> {
  const rl = createInterface({ input: createReadStream(path, { encoding: "utf8", highWaterMark: 1 << 20 }), crlfDelay: Infinity });
  let n = 0;
  for await (const line of rl) {
    yield line;
    // Let the thread breathe on huge files.
    if (++n % 4000 === 0) await new Promise((r) => setImmediate(r));
  }
}

export async function scanClaude(path: string): Promise<ClaudeSummary> {
  const calls: Call[] = [];
  const sessions: Record<string, SessionMeta> = {};
  const pending = new Map<string, string>(); // tool_use id -> tool name
  const sess = (sid: string): SessionMeta => (sessions[sid] ??= { proj: "?", first: "", prompts: 0, compacts: 0, images: 0, results: [] });
  for await (const line of lines(path)) {
    if (!line.includes('"sessionId"')) continue;
    let d: Record<string, unknown>;
    try { d = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
    const sid = typeof d.sessionId === "string" ? d.sessionId : "";
    const ts = typeof d.timestamp === "string" ? Date.parse(d.timestamp) : NaN;
    if (!sid || !Number.isFinite(ts)) continue;
    const s = sess(sid);
    if (typeof d.cwd === "string" && s.proj === "?") s.proj = projectName(d.cwd);
    if (typeof d.entrypoint === "string") s.entry = d.entrypoint;
    const type = d.type;
    const msg = (d.message ?? {}) as Record<string, unknown>;
    if (type === "system" && d.subtype === "compact_boundary") s.compacts++;
    else if (type === "assistant") {
      const content = Array.isArray(msg.content) ? (msg.content as Record<string, unknown>[]) : [];
      for (const c of content) if (c && c.type === "tool_use" && typeof c.id === "string") pending.set(c.id, String(c.name ?? "?").startsWith("mcp__") ? "mcp" : String(c.name ?? "?"));
      const u = msg.usage as Record<string, unknown> | undefined;
      const model = typeof msg.model === "string" ? msg.model : "";
      const mid = typeof msg.id === "string" ? msg.id : typeof d.requestId === "string" ? d.requestId : "";
      if (!u || !mid || !model || model.startsWith("<")) continue;
      const cc = (u.cache_creation ?? {}) as Record<string, unknown>;
      calls.push([ts, model, num(u.input_tokens), num(u.cache_creation_input_tokens), num(u.cache_read_input_tokens), num(u.output_tokens), (num(cc.ephemeral_1h_input_tokens) > 0 ? 1 : 0) | (d.isSidechain === true ? 2 : 0), mid, sid]);
    } else if (type === "user" && d.isMeta !== true) {
      const content = msg.content;
      const text = (t: string): void => { if (!t.startsWith("<")) { s.prompts++; if (!s.first) s.first = t.slice(0, 140).replace(/\s+/g, " "); } };
      if (typeof content === "string") text(content);
      else if (Array.isArray(content)) {
        for (const x of content as Record<string, unknown>[]) {
          if (!x) continue;
          if (x.type === "text" && typeof x.text === "string") text(x.text);
          else if (x.type === "tool_result") {
            let n = 0;
            const cc = x.content;
            if (typeof cc === "string") n = cc.length;
            else if (Array.isArray(cc)) for (const y of cc as Record<string, unknown>[]) { if (y?.type === "text" && typeof y.text === "string") n += y.text.length; else if (y?.type === "image") { s.images++; n += 6000; } }
            s.results.push([ts, pending.get(String(x.tool_use_id)) ?? "?", n]);
          }
        }
      }
    }
  }
  return { kind: "claude", calls, sessions };
}

export async function scanCodex(path: string): Promise<CodexSummary> {
  const out: CodexSummary = { kind: "codex", sid: basename(path, ".jsonl"), model: null, proj: "?", originator: null, first: 0, last: 0, input: 0, cached: 0, output: 0, reasoning: 0 };
  for await (const line of lines(path)) {
    const meta = line.includes('"session_meta"');
    const turn = !meta && line.includes('"turn_context"');
    const count = !meta && !turn && line.includes('"token_count"');
    if (!meta && !turn && !count) continue;
    let d: Record<string, unknown>;
    try { d = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
    const p = (d.payload ?? {}) as Record<string, unknown>;
    const ts = typeof d.timestamp === "string" ? Date.parse(d.timestamp) : 0;
    if (meta) {
      if (typeof p.id === "string") out.sid = p.id;
      if (typeof p.originator === "string") out.originator = p.originator;
      if (typeof p.cwd === "string") out.proj = projectName(p.cwd);
      if (ts && !out.first) out.first = ts;
    } else if (turn) {
      if (typeof p.model === "string") out.model = p.model;
      if (typeof p.cwd === "string" && out.proj === "?") out.proj = projectName(p.cwd);
    } else {
      const info = p.info as Record<string, unknown> | null | undefined;
      const total = info?.total_token_usage as Record<string, unknown> | undefined;
      if (total) {
        out.input = num(total.input_tokens); out.cached = num(total.cached_input_tokens); out.output = num(total.output_tokens); out.reasoning = num(total.reasoning_output_tokens);
        out.last = ts || out.last;
        if (!out.first) out.first = ts;
      }
      const rl = p.rate_limits as Record<string, Record<string, unknown>> | undefined;
      if (rl?.primary && typeof rl.primary.used_percent === "number") out.session_used = rl.primary.used_percent;
      if (rl?.secondary && typeof rl.secondary.used_percent === "number") out.weekly_used = rl.secondary.used_percent;
    }
  }
  return out;
}
