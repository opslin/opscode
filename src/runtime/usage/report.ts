// Turns per-file summaries into the "Where tokens go" report. Pure: no disk, no
// clock except the `now` it is given, so tests can feed it fixtures.
//
// All dollar figures are API list prices (see pricing.ts), for comparing habits
// and models. They are not what a plan charges.

import { PRICE, costParts, familyOf } from "./pricing";
import type { Call, ClaudeSummary, CodexSummary, FileSummary, SessionMeta } from "./scan";

export interface SessionLabel { chat_id: string; title: string; workspace_id: string; mode?: string }
export interface ReportOptions { days: number; now: number; labels?: Map<string, SessionLabel>; logs?: { claude_bytes: number; codex_bytes: number; claude_files: number; codex_files: number } }

export interface SessionRow {
  id: string; proj: string; entry?: string; start: number; end: number; active_h: number; calls: number; prompts: number; usd: number;
  avg_ctx_k: number; max_ctx_k: number; start_ctx_k: number; models: Record<string, number>; compacts: number; rewrites: number; multi_day: boolean; first: string; label?: SessionLabel;
}
export interface UsageReport {
  window_days: number;
  generated_at: string;
  note: string;
  claude: null | {
    calls: number; sessions: number; active_days: number; usd: number; out_tokens: number; avg_context: number;
    split: { read: number; write: number; out: number; inp: number };
    models: { model: string; calls: number; usd: number }[];
    projects: { name: string; usd: number; sessions: number }[];
    ctx_over_pct: { k100: number; k200: number; k500: number };
    multi_day: { sessions: number; usd_share: number };
    burners: {
      /** Cache reads above 150k tokens of history: what short chats would not pay. */
      long_chats: number;
      /** Re-reading the starting prompt (system, tools, skills, MCP) on every call. */
      start_prompt: number;
      start_prompt_median_k: number;
      /** Cache rebuilt after a break of more than 5 minutes, after a model switch, or for another reason. */
      rewrites: { breaks: number; switches: number; other: number };
      rewrite_count: number;
      /** Tool output carried through every later call. */
      tool_carry: { tool: string; usd: number; chars: number }[];
      images: number;
      /** Opus or Fable steps that wrote under 300 tokens. */
      small_steps_on_big_models: number;
    };
    /** How big a chat is before you type, by where it ran (claude-desktop, sdk-ts for Opscode workers, ...). */
    start_by_entry: { entry: string; sessions: number; median_k: number }[];
    daily: { day: string; usd: number }[];
    hours: number[];
    top_sessions: SessionRow[];
    opscode: { sessions: number; usd: number };
  };
  codex: null | {
    sessions: number; input: number; cached: number; output: number; reasoning: number;
    models: Record<string, number>; projects: { name: string; tokens: number }[]; sources: Record<string, number>;
    tiny_sessions: number; median_output: number; session_used?: number; weekly_used?: number;
  };
  logs: { claude_bytes: number; codex_bytes: number; claude_files: number; codex_files: number };
}

const r2 = (n: number): number => Math.round(n * 100) / 100;
const median = (a: number[]): number => { if (!a.length) return 0; const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length / 2)]; };
const dayKey = (t: number): string => { const d = new Date(t); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
const ctxOf = (c: Call): number => c[2] + c[3] + c[4];
const tk = (c: Call) => ({ inp: c[2], cw: c[3], cr: c[4], out: c[5], h1: (c[6] & 1) === 1 });

function mergeMeta(into: SessionMeta, m: SessionMeta): void {
  if (into.proj === "?" && m.proj !== "?") into.proj = m.proj;
  into.entry ??= m.entry;
  if (!into.first) into.first = m.first;
  into.prompts += m.prompts; into.compacts += m.compacts; into.images += m.images;
  for (const r of m.results) into.results.push(r);
}

export function buildReport(files: FileSummary[], o: ReportOptions): UsageReport {
  const since = o.now - o.days * 86_400_000;
  const claude = files.filter((f): f is ClaudeSummary => f.kind === "claude");
  const codex = files.filter((f): f is CodexSummary => f.kind === "codex");
  const rep: UsageReport = {
    window_days: o.days, generated_at: new Date(o.now).toISOString(),
    note: "Dollar figures are API list prices, to compare habits and models. They are not what your plan charges.",
    claude: null, codex: null,
    logs: o.logs ?? { claude_bytes: 0, codex_bytes: 0, claude_files: 0, codex_files: 0 },
  };

  // ---- Claude: de-duplicate by message id, group by session ----
  const seen = new Set<string>();
  const bySession = new Map<string, Call[]>();
  const meta = new Map<string, SessionMeta>();
  for (const f of claude) {
    for (const c of f.calls) {
      if (seen.has(c[7])) continue;
      seen.add(c[7]);
      let a = bySession.get(c[8]);
      if (!a) bySession.set(c[8], (a = []));
      a.push(c);
    }
    for (const [sid, m] of Object.entries(f.sessions)) {
      const have = meta.get(sid);
      if (have) mergeMeta(have, m); else meta.set(sid, { ...m, results: [...m.results] });
    }
  }
  if (bySession.size) {
    let calls = 0, out = 0, ctxSum = 0, over100 = 0, over200 = 0, over500 = 0, longChats = 0, startPrompt = 0, small = 0, rewriteCount = 0;
    const split = { read: 0, write: 0, out: 0, inp: 0 };
    const models = new Map<string, { calls: number; usd: number }>();
    const projects = new Map<string, { usd: number; sessions: number }>();
    const daily = new Map<string, number>();
    const hours = new Array<number>(24).fill(0);
    const rewrites = { breaks: 0, switches: 0, other: 0 };
    const carry = new Map<string, { usd: number; chars: number }>();
    const rows: SessionRow[] = [];
    const startCtx: number[] = [];
    const startByEntry = new Map<string, number[]>();
    let images = 0, multiSessions = 0, multiUsd = 0, total = 0, opscodeUsd = 0, opscodeSessions = 0;
    const activeDays = new Set<string>();

    for (const [sid, all] of bySession) {
      all.sort((a, b) => a[0] - b[0]);
      const base = ctxOf(all[0]); // the first call of the whole session: system prompt, tools, skills, MCP
      const inWin = all.filter((c) => c[0] >= since && c[0] <= o.now);
      if (!inWin.length) continue;
      const m = meta.get(sid);
      let usd = 0, ctxs = 0, maxCtx = 0, active = 0, rw = 0;
      const fam: Record<string, number> = {};
      const crPrice = (name: string): number => { const f = familyOf(name); return f ? PRICE[f][1] : 0; };
      for (let i = 0; i < inWin.length; i++) {
        const c = inWin[i];
        const t = tk(c);
        const parts = costParts(c[1], t);
        const cc = parts.read + parts.write + parts.out + parts.inp;
        usd += cc; total += cc;
        split.read += parts.read; split.write += parts.write; split.out += parts.out; split.inp += parts.inp;
        calls++; out += c[5];
        const ctx = ctxOf(c);
        ctxSum += ctx; ctxs += ctx; maxCtx = Math.max(maxCtx, ctx);
        if (ctx > 100_000) over100++;
        if (ctx > 200_000) over200++;
        if (ctx > 500_000) over500++;
        if (ctx > 150_000) longChats += parts.read * (1 - 150_000 / ctx);
        const f = familyOf(c[1]);
        if (f) {
          startPrompt += (Math.min(base, ctx) * PRICE[f][1]) / 1e6;
          if ((f === "opus" || f === "fable") && c[5] < 300) small += cc * 0.6;
          fam[f] = (fam[f] ?? 0) + 1;
        }
        const md = models.get(c[1]) ?? { calls: 0, usd: 0 };
        md.calls++; md.usd += cc; models.set(c[1], md);
        const day = dayKey(c[0]);
        daily.set(day, (daily.get(day) ?? 0) + cc); activeDays.add(day);
        hours[new Date(c[0]).getHours()]++;
        const prev = i > 0 ? inWin[i - 1] : null;
        if (prev) {
          const gap = (c[0] - prev[0]) / 60_000;
          if (gap < 15) active += gap;
          if (c[3] > 40_000) {
            rw++; rewriteCount++;
            if (familyOf(prev[1]) !== familyOf(c[1])) rewrites.switches += parts.write;
            else if (gap > 5) rewrites.breaks += parts.write;
            else rewrites.other += parts.write;
          }
        }
      }
      // Tool output stays in the chat: its tokens are re-read on every later call.
      for (const [ts, tool, chars] of m?.results ?? []) {
        if (ts < since || ts > o.now) continue;
        let later = 0;
        for (const c of inWin) if (c[0] > ts) later++;
        const usdCarry = ((chars / 4) * later * crPrice(inWin.at(-1)![1])) / 1e6;
        const e = carry.get(tool) ?? { usd: 0, chars: 0 };
        e.usd += usdCarry; e.chars += chars; carry.set(tool, e);
      }
      images += m?.images ?? 0;
      startCtx.push(base);
      { const key = `${m?.entry ?? "unknown"}${(all[0][6] & 2) !== 0 ? " (sub-agent)" : ""}`; (startByEntry.get(key) ?? startByEntry.set(key, []).get(key)!).push(base); }
      const proj = m?.proj ?? "?";
      const pj = projects.get(proj) ?? { usd: 0, sessions: 0 };
      pj.usd += usd; pj.sessions++; projects.set(proj, pj);
      const span = dayKey(inWin[0][0]) !== dayKey(inWin.at(-1)![0]);
      if (span) { multiSessions++; multiUsd += usd; }
      const label = o.labels?.get(sid);
      if (label) { opscodeUsd += usd; opscodeSessions++; }
      rows.push({ id: sid.slice(0, 8), proj, ...(m?.entry ? { entry: m.entry } : {}), start: inWin[0][0], end: inWin.at(-1)![0], active_h: r2(active / 60), calls: inWin.length, prompts: m?.prompts ?? 0, usd: r2(usd), avg_ctx_k: Math.round(ctxs / inWin.length / 1000), max_ctx_k: Math.round(maxCtx / 1000), start_ctx_k: Math.round(base / 1000), models: fam, compacts: m?.compacts ?? 0, rewrites: rw, multi_day: span, first: m?.first ?? "", ...(label ? { label } : {}) });
    }
    rows.sort((a, b) => b.usd - a.usd);
    rep.claude = {
      calls, sessions: rows.length, active_days: activeDays.size, usd: r2(total), out_tokens: out, avg_context: calls ? Math.round(ctxSum / calls) : 0,
      split: { read: r2(split.read), write: r2(split.write), out: r2(split.out), inp: r2(split.inp) },
      models: [...models].map(([model, v]) => ({ model, calls: v.calls, usd: r2(v.usd) })).sort((a, b) => b.usd - a.usd),
      projects: [...projects].map(([name, v]) => ({ name, usd: r2(v.usd), sessions: v.sessions })).sort((a, b) => b.usd - a.usd).slice(0, 12),
      ctx_over_pct: { k100: calls ? Math.round((over100 / calls) * 100) : 0, k200: calls ? Math.round((over200 / calls) * 100) : 0, k500: calls ? Math.round((over500 / calls) * 100) : 0 },
      multi_day: { sessions: multiSessions, usd_share: total ? Math.round((multiUsd / total) * 100) : 0 },
      burners: {
        long_chats: r2(longChats), start_prompt: r2(startPrompt), start_prompt_median_k: Math.round(median(startCtx) / 1000),
        rewrites: { breaks: r2(rewrites.breaks), switches: r2(rewrites.switches), other: r2(rewrites.other) },
        rewrite_count: rewriteCount,
        tool_carry: [...carry].map(([tool, v]) => ({ tool, usd: r2(v.usd), chars: v.chars })).sort((a, b) => b.usd - a.usd).slice(0, 6),
        images, small_steps_on_big_models: r2(small),
      },
      start_by_entry: [...startByEntry].map(([entry, v]) => ({ entry, sessions: v.length, median_k: Math.round(median(v) / 1000) })).sort((a, b) => b.sessions - a.sessions),
      daily: [...daily].map(([day, usd]) => ({ day, usd: r2(usd) })).sort((a, b) => a.day.localeCompare(b.day)),
      hours,
      top_sessions: rows.slice(0, 15),
      opscode: { sessions: opscodeSessions, usd: r2(opscodeUsd) },
    };
  }

  // ---- Codex ----
  const cx = codex.filter((c) => c.last >= since && c.last <= o.now);
  if (cx.length) {
    const models: Record<string, number> = {}, sources: Record<string, number> = {};
    const projects = new Map<string, number>();
    const outs: number[] = [];
    let input = 0, cached = 0, output = 0, reasoning = 0, tiny = 0;
    for (const c of cx) {
      input += c.input; cached += c.cached; output += c.output; reasoning += c.reasoning;
      models[c.model ?? "unknown"] = (models[c.model ?? "unknown"] ?? 0) + 1;
      sources[c.originator ?? "unknown"] = (sources[c.originator ?? "unknown"] ?? 0) + 1;
      projects.set(c.proj, (projects.get(c.proj) ?? 0) + c.input + c.output);
      outs.push(c.output);
      if (c.output < 2000) tiny++;
    }
    const latest = [...cx].sort((a, b) => b.last - a.last).find((c) => c.weekly_used !== undefined);
    rep.codex = { sessions: cx.length, input, cached, output, reasoning, models, sources, projects: [...projects].map(([name, tokens]) => ({ name, tokens })).sort((a, b) => b.tokens - a.tokens).slice(0, 8), tiny_sessions: tiny, median_output: median(outs), ...(latest ? { session_used: latest.session_used, weekly_used: latest.weekly_used } : {}) };
  }
  return rep;
}
