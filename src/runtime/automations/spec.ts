// Automation files: YAML in <project>/.opscode/automations/<name>.yaml (shared
// through git) or the person's own in Opscode's data folder. An automation runs
// steps: an agent (or inline prompt) on an engine, a shell command, or a wait.
//
// version: 1
// description: One line
// on: { schedule: { at: "09:00", weekdays: [mon, fri] } }   # or { every: 6h }; absent = by hand
// inputs: { brief: { description: What to build, required: true } }
// budget: { tokens: 2000000, turns: 40 }
// steps:
//   plan:  { agent: planner, engine: claude-code, model: frontier, approve: true }
//   build: { agent: builder, needs: [plan], model: base, access: edit,
//            checks: ["npm test", { agent: reviewer }], retries: 2, escalate: frontier }
//   ui:    { prompt: "Build the screens", engine: codex, if: { plan: ready } }

import { parse, YAMLParseError } from "yaml";

export type EngineId = "api" | "claude-code" | "codex";
export type ModelClass = "fast" | "base" | "frontier";
export type Access = "read" | "edit" | "full";

export interface Check {
  run?: string;
  agent?: string;
}
export interface Rung {
  engine?: EngineId;
  model?: string;
}
export interface Step {
  name: string;
  kind: "agent" | "prompt" | "run" | "wait";
  agent?: string;
  prompt?: string;
  run?: string;
  wait_ms?: number;
  engine?: EngineId;
  model?: string;
  effort?: string;
  access: Access;
  needs: string[];
  if?: Record<string, string>;
  decides?: string[];
  checks: Check[];
  retries: number;
  escalate: Rung[];
  approve: boolean;
  timeout_ms: number;
}
export interface Schedule {
  at?: string; // "HH:MM" local time
  weekdays?: number[]; // 0=Sun..6=Sat
  every_ms?: number;
}
export interface Automation {
  name: string;
  description: string;
  on: { schedule?: Schedule };
  inputs: Record<string, { description: string; required: boolean; default?: string }>;
  budget: { tokens?: number; turns?: number };
  steps: Step[];
}
export interface Diagnostic {
  line: number;
  message: string;
}

export const NAME = /^[a-z][a-z0-9_-]{0,39}$/;
const ENGINES: EngineId[] = ["api", "claude-code", "codex"];
const EFFORTS = ["low", "medium", "high", "xhigh", "max"];
const DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

export function parseDuration(v: unknown): number | null {
  const m = /^(\d+)\s*(s|m|h|d)$/.exec(String(v ?? "").trim());
  if (!m) return null;
  return Number(m[1]) * { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 }[m[2] as "s" | "m" | "h" | "d"];
}

/** Line of a top-level or step key in the YAML text (best effort, for messages). */
function lineOf(text: string, key: string, after = 0): number {
  const lines = text.split("\n");
  for (let i = after; i < lines.length; i++) if (new RegExp(`^\\s*${key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*:`).test(lines[i])) return i + 1;
  return 1;
}

/** Parses and checks an automation file. Returns the automation, or the problems (with lines). */
export function parseAutomation(name: string, text: string): { automation?: Automation; diagnostics: Diagnostic[] } {
  const d: Diagnostic[] = [];
  const fail = (line: number, message: string): void => void d.push({ line, message });
  if (!NAME.test(name)) fail(1, "the file name is lowercase letters, digits, - and _, starting with a letter, at most 40 characters");
  let raw: unknown;
  try {
    raw = parse(text, { maxAliasCount: 50 });
  } catch (e) {
    const line = e instanceof YAMLParseError ? (e.linePos?.[0]?.line ?? 1) : 1;
    return { diagnostics: [{ line, message: `not valid YAML: ${(e as Error).message.split("\n")[0]}` }] };
  }
  if (!isObj(raw)) return { diagnostics: [{ line: 1, message: "the file must be a mapping with steps:" }] };
  for (const k of Object.keys(raw)) if (!["version", "description", "on", "inputs", "budget", "steps"].includes(k)) fail(lineOf(text, k), `unknown key ${k}`);
  if (raw.version !== undefined && raw.version !== 1) fail(lineOf(text, "version"), "version must be 1");
  const description = typeof raw.description === "string" ? raw.description.trim().slice(0, 300) : "";

  // trigger
  const on: Automation["on"] = {};
  if (raw.on !== undefined) {
    if (!isObj(raw.on)) fail(lineOf(text, "on"), "on: must be a mapping, like on: { schedule: { at: \"09:00\" } }");
    else {
      for (const k of Object.keys(raw.on)) if (k !== "schedule") fail(lineOf(text, k), `on.${k} is not supported here; use schedule, or leave on: out to run by hand`);
      const s = raw.on.schedule;
      if (s !== undefined) {
        if (!isObj(s)) fail(lineOf(text, "schedule"), "schedule must be a mapping");
        else {
          const sch: Schedule = {};
          if (s.every !== undefined) {
            const ms = parseDuration(s.every);
            if (ms === null || ms < 5 * 60_000) fail(lineOf(text, "every"), "every: is a duration of at least 5m, like 30m or 6h");
            else sch.every_ms = ms;
          }
          if (s.at !== undefined) {
            if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(String(s.at))) fail(lineOf(text, "at"), "at: is a 24-hour time in quotes, like \"09:00\"");
            else sch.at = String(s.at);
          }
          if (s.weekdays !== undefined) {
            const list = Array.isArray(s.weekdays) ? s.weekdays.map((x) => DAYS.indexOf(String(x).toLowerCase().slice(0, 3))) : [];
            if (!list.length || list.some((x) => x < 0)) fail(lineOf(text, "weekdays"), "weekdays: is a list like [mon, tue, wed, thu, fri]");
            else sch.weekdays = [...new Set(list)].sort();
          }
          if (s.timezone !== undefined) fail(lineOf(text, "timezone"), "schedules use this computer's time zone; remove timezone:");
          if (!sch.at && !sch.every_ms) fail(lineOf(text, "schedule"), "a schedule needs at: \"HH:MM\" or every: 30m");
          if (sch.at && sch.every_ms) fail(lineOf(text, "schedule"), "use at: or every:, not both");
          on.schedule = sch;
        }
      }
    }
  }

  // inputs
  const inputs: Automation["inputs"] = {};
  if (raw.inputs !== undefined) {
    if (!isObj(raw.inputs)) fail(lineOf(text, "inputs"), "inputs: must be a mapping");
    else for (const [k, v] of Object.entries(raw.inputs)) {
      if (!NAME.test(k)) fail(lineOf(text, k), `input name ${k}: lowercase letters, digits, - and _`);
      const o = isObj(v) ? v : {};
      inputs[k] = { description: String(o.description ?? k).slice(0, 200), required: o.required === true, ...(o.default !== undefined ? { default: String(o.default) } : {}) };
    }
  }

  // budget
  const budget: Automation["budget"] = {};
  if (raw.budget !== undefined) {
    if (!isObj(raw.budget)) fail(lineOf(text, "budget"), "budget: is a mapping like { tokens: 2000000, turns: 40 }");
    else {
      for (const k of Object.keys(raw.budget)) if (k !== "tokens" && k !== "turns") fail(lineOf(text, k), `budget.${k}: use tokens and turns (subscription engines have no per-call price)`);
      if (raw.budget.tokens !== undefined) { const n = Number(raw.budget.tokens); if (!Number.isInteger(n) || n < 1000) fail(lineOf(text, "tokens"), "budget.tokens is a whole number of at least 1000"); else budget.tokens = n; }
      if (raw.budget.turns !== undefined) { const n = Number(raw.budget.turns); if (!Number.isInteger(n) || n < 1 || n > 500) fail(lineOf(text, "turns"), "budget.turns is 1 to 500"); else budget.turns = n; }
    }
  }

  // steps
  const steps: Step[] = [];
  const stepsLine = lineOf(text, "steps");
  if (!isObj(raw.steps) || Object.keys(raw.steps).length === 0) fail(stepsLine, "steps: needs at least one step");
  else {
    const names = Object.keys(raw.steps);
    if (names.length > 20) fail(stepsLine, "at most 20 steps");
    for (const [sname, sv] of Object.entries(raw.steps)) {
      const at = lineOf(text, sname, stepsLine);
      if (!NAME.test(sname)) fail(at, `step name ${sname}: lowercase letters, digits, - and _`);
      if (!isObj(sv)) { fail(at, `step ${sname} must be a mapping`); continue; }
      const allowed = ["agent", "prompt", "run", "wait", "engine", "model", "effort", "access", "needs", "if", "decides", "checks", "retries", "escalate", "approve", "timeout"];
      for (const k of Object.keys(sv)) if (!allowed.includes(k)) fail(lineOf(text, k, at - 1), `step ${sname}: unknown key ${k}`);
      // An agent step may carry its own prompt (the task); otherwise exactly one kind.
      const kinds = ["agent", "prompt", "run", "wait"].filter((k) => sv[k] !== undefined && !(k === "prompt" && sv.agent !== undefined));
      if (kinds.length !== 1) fail(at, `step ${sname} needs exactly one of agent, prompt, run or wait (an agent step may also have a prompt)`);
      const kind = (kinds[0] ?? "prompt") as Step["kind"];
      const st: Step = { name: sname, kind, access: "read", needs: [], checks: [], retries: 0, escalate: [], approve: false, timeout_ms: 30 * 60_000 };
      if (kind === "agent") { if (!NAME.test(String(sv.agent))) fail(at, `step ${sname}: agent is an agent name`); st.agent = String(sv.agent); }
      if (kind === "prompt") { if (typeof sv.prompt !== "string" || !sv.prompt.trim()) fail(at, `step ${sname}: prompt is the instructions`); st.prompt = String(sv.prompt ?? "").slice(0, 20_000); }
      if (kind === "run") { if (typeof sv.run !== "string" || !sv.run.trim() || /[\r\n]/.test(sv.run.trim())) fail(at, `step ${sname}: run is one command line (chain with &&)`); st.run = String(sv.run ?? "").trim(); }
      if (kind === "wait") { const ms = parseDuration(sv.wait); if (ms === null || ms > 168 * 3_600_000) fail(at, `step ${sname}: wait is a duration up to 168h, like 30m`); else st.wait_ms = ms; }
      if (sv.prompt !== undefined && kind === "agent") st.prompt = String(sv.prompt);
      if (sv.engine !== undefined) { if (!ENGINES.includes(sv.engine as EngineId)) fail(at, `step ${sname}: engine is claude-code, codex or api`); else st.engine = sv.engine as EngineId; }
      if (sv.model !== undefined) st.model = String(sv.model);
      if (sv.effort !== undefined) { if (!EFFORTS.includes(String(sv.effort))) fail(at, `step ${sname}: effort is ${EFFORTS.join(", ")}`); else st.effort = String(sv.effort); }
      if (sv.access !== undefined) { if (!["read", "edit", "full"].includes(String(sv.access))) fail(at, `step ${sname}: access is read, edit or full`); else st.access = sv.access as Access; }
      if (sv.needs !== undefined) { const n = Array.isArray(sv.needs) ? sv.needs.map(String) : [String(sv.needs)]; st.needs = n; }
      if (sv.if !== undefined) { if (!isObj(sv.if)) fail(at, `step ${sname}: if is like { triage: implement }`); else st.if = Object.fromEntries(Object.entries(sv.if).map(([k, v]) => [k, String(v)])); }
      if (sv.decides !== undefined) { const v = Array.isArray(sv.decides) ? sv.decides.map(String) : []; if (!v.length || v.some((x) => !NAME.test(x) || ["failed", "succeeded", "skipped", "cancelled"].includes(x))) fail(at, `step ${sname}: decides is a list of words, like [implement, needs_info]`); else st.decides = v; }
      if (sv.checks !== undefined) {
        const list = Array.isArray(sv.checks) ? sv.checks : [sv.checks];
        for (const c of list) {
          if (typeof c === "string" && c.trim() && !/[\r\n]/.test(c)) st.checks.push({ run: c.trim() });
          else if (isObj(c) && typeof c.agent === "string" && NAME.test(c.agent)) st.checks.push({ agent: c.agent });
          else fail(at, `step ${sname}: a check is a command ("npm test") or { agent: reviewer }`);
        }
        if (st.kind === "run" || st.kind === "wait") fail(at, `step ${sname}: checks belong on agent and prompt steps`);
      }
      if (sv.retries !== undefined) { const n = Number(sv.retries); if (!Number.isInteger(n) || n < 0 || n > 3) fail(at, `step ${sname}: retries is 0 to 3`); else st.retries = n; }
      if (sv.escalate !== undefined) {
        const list = Array.isArray(sv.escalate) ? sv.escalate : [sv.escalate];
        for (const r of list) {
          if (typeof r === "string") st.escalate.push({ model: r });
          else if (isObj(r) && (r.engine === undefined || ENGINES.includes(r.engine as EngineId))) st.escalate.push({ ...(r.engine ? { engine: r.engine as EngineId } : {}), ...(r.model ? { model: String(r.model) } : {}) });
          else fail(at, `step ${sname}: escalate is a model class (frontier) or a list like [{ engine: codex, model: frontier }]`);
        }
        if (!st.retries) fail(at, `step ${sname}: escalate needs retries`);
      }
      if (sv.approve !== undefined) st.approve = sv.approve === true || (isObj(sv.approve));
      if (sv.timeout !== undefined) { const ms = parseDuration(sv.timeout); if (ms === null || ms > 4 * 3_600_000) fail(at, `step ${sname}: timeout is up to 4h, like 30m`); else st.timeout_ms = ms; }
      steps.push(st);
    }
    // references
    const names2 = new Set(steps.map((s) => s.name));
    const deciders = new Map(steps.map((s) => [s.name, s]));
    steps.forEach((s, i) => {
      const at = lineOf(text, s.name, stepsLine);
      for (const n of s.needs) if (!names2.has(n)) fail(at, `step ${s.name}: needs ${n}, which is not a step`);
        else if (steps.findIndex((x) => x.name === n) >= i) fail(at, `step ${s.name}: needs ${n}, which comes later; put it first`);
      for (const [k, v] of Object.entries(s.if ?? {})) {
        const src = deciders.get(k);
        if (!src || steps.indexOf(src) >= i) fail(at, `step ${s.name}: if tests ${k}, which is not an earlier step`);
        else if (v !== "failed" && !(src.decides ?? []).includes(v)) fail(at, `step ${s.name}: ${k} never decides ${v}${src.decides ? ` (it decides ${src.decides.join(", ")})` : "; give it decides: [...]"}`);
      }
    });
  }
  if (d.length) return { diagnostics: d };
  return { automation: { name, description, on, inputs, budget, steps }, diagnostics: [] };
}

/** Next time a schedule fires after `from` (local time), or null for none. */
export function nextFire(s: Schedule | undefined, from: Date, last?: Date): Date | null {
  if (!s) return null;
  if (s.every_ms) return new Date((last ?? from).getTime() + s.every_ms);
  if (!s.at) return null;
  const [hh, mm] = s.at.split(":").map(Number);
  const d = new Date(from);
  d.setSeconds(0, 0);
  d.setHours(hh, mm);
  if (d <= from) d.setDate(d.getDate() + 1);
  for (let i = 0; i < 8; i++) {
    if (!s.weekdays || s.weekdays.includes(d.getDay())) return d;
    d.setDate(d.getDate() + 1);
  }
  return null;
}

export function triggerText(a: Automation): string {
  const s = a.on.schedule;
  if (!s) return "By hand";
  if (s.every_ms) {
    const m = s.every_ms / 60_000;
    return `Every ${m % 60 === 0 ? `${m / 60}h` : `${m}m`}`;
  }
  const days = s.weekdays;
  const dayText = !days ? "Every day" : days.join() === "1,2,3,4,5" ? "Weekdays" : days.map((x) => DAYS[x][0].toUpperCase() + DAYS[x].slice(1)).join(", ");
  return `${dayText} at ${s.at}`;
}

/** Model classes per engine (a pinned id passes through). */
export function resolveModel(engine: EngineId, model: string | undefined, effort: string | undefined): { model?: string; effort?: string } {
  const cls = model as ModelClass | undefined;
  if (engine === "claude-code") {
    const map: Record<ModelClass, string> = { fast: "haiku", base: "sonnet", frontier: "opus" };
    return { ...(cls && cls in map ? { model: map[cls] } : model ? { model } : {}), ...(effort ? { effort } : {}) };
  }
  if (engine === "codex") {
    // Codex: one model, the class sets how hard it thinks.
    const eff: Record<ModelClass, string> = { fast: "low", base: "medium", frontier: "high" };
    if (cls && cls in eff) return { effort: effort ?? eff[cls] };
    return { ...(model ? { model } : {}), ...(effort ? { effort } : {}) };
  }
  return {};
}
