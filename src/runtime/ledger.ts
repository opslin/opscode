// Task ledger (hand-off slice H1): what happened in a chat, kept by Opscode itself,
// independent of the engine. Built only from the turn and tool events Opscode already
// sees, so it costs no model tokens and still works when an engine stopped mid-turn
// (stopped by the user, failed, or out of its plan limit).
//
// Later slices build the hand-off pack from it (docs/cross-engine-handoff-plan.md).
// Stored per chat in <state>/ledger/<chat id>.json (0600).

import { existsSync, lstatSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";

export interface LedgerCommand {
  cmd: string;
  ok: boolean;
  exit: number | null;
  /** The end of the output: the last 20 lines when it failed, the last 3 when it passed. */
  tail: string;
  engine: string;
  at: string;
}

export interface LedgerFile { path: string; count: number; engine: string; at: string }

export interface LedgerTurn {
  turn_id: string;
  engine: string;
  model?: string;
  effort?: string;
  status: "running" | "complete" | "interrupted" | "failed";
  at: string;
  ended_at?: string;
  error?: string;
}

export type PlanStatus = "pending" | "in_progress" | "done";
export interface PlanStep { step: string; status: PlanStatus }
/** Who wrote something: the engine, and the model when known ("codex/gpt-6.1-sol"). */
export interface ByLine { text: string; by: string; at: string }

export interface Ledger {
  version: 1;
  chat_id: string;
  /** The project folder (for the plan file). */
  root?: string;
  /** The task plan: from task_checkpoint, or the engine's own plan (Codex turn/plan/updated, Claude TodoWrite). */
  plan?: { steps: PlanStep[]; by: string; at: string; explanation?: string };
  /** Decisions made (the next engine should not redo them). */
  decisions: ByLine[];
  next?: ByLine;
  notes?: ByLine;
  /** The first thing the user asked in this chat, word for word (clipped). */
  goal: string;
  /** The user's last messages, word for word: they carry the user's rules and style. */
  user_messages: { text: string; at: string }[];
  files_changed: LedgerFile[];
  files_read: LedgerFile[];
  commands: LedgerCommand[];
  /** Things the user said no to (so the next engine does not try them again). */
  denied: { summary: string; at: string }[];
  /** The tool call that was still running when the last turn stopped or failed. */
  in_flight?: { tool: string; summary: string; detail?: string; engine: string; at: string; why: "interrupted" | "failed" };
  turns: LedgerTurn[];
  /** The end of the last assistant reply. */
  last_reply: string;
  updated_at: string;
}

/** A ledger as read: with the commands that still fail (no later passing run of the same command). */
export type LedgerView = Ledger & { open_errors: LedgerCommand[] };

const CAP = { steps: 30, step: 300, decisions: 12, decision: 400, next: 600, notes: 1500, files: 80, commands: 12, users: 6, turns: 20, denied: 6, goal: 1200, user: 1500, reply: 2000, detail: 400 } as const;

const READ_TOOLS = new Set(["Read", "read_file"]);
const WRITE_TOOLS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit", "write_file"]);
const CMD_TOOLS = new Set(["Bash", "run_command"]);

const SECRET_PATTERNS: [RegExp, string][] = [
  [/\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{8,}/g, "$1 [hidden]"],
  [/\b(sk-[A-Za-z0-9_-]{12,}|sk-ant-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[abpr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,})\b/g, "[hidden]"],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(-----END [A-Z ]*PRIVATE KEY-----|$)/g, "[private key hidden]"],
  [/\b([A-Za-z_]*(?:api[_-]?key|token|secret|passw(?:or)?d|pwd|auth)[A-Za-z_]*)(\s*[:=]\s*)(["']?)[^\s"'&]{4,}\3/gi, "$1$2[hidden]"],
  [/(\/\/[^/\s:@]+:)[^@\s/]+@/g, "$1[hidden]@"],
];

/** Hides things that look like keys, tokens and passwords. Not a guarantee; it keeps the obvious ones out of the pack. */
export function redact(s: string): string {
  let out = s;
  for (const [re, to] of SECRET_PATTERNS) out = out.replace(re, to);
  return out;
}

const now = (): string => new Date().toISOString();
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);
const clipEnd = (s: string, n: number): string => (s.length > n ? `…${s.slice(-n)}` : s);
const lastLines = (s: string, n: number, max: number): string => clipEnd(s.trimEnd().split("\n").slice(-n).join("\n"), max);

/** A sub-agent's card reads "helper › Read x" or "<agent> › Read x": the part after the last "›". */
const bare = (summary: string): string => summary.replace(/^.*›\s*/, "");

/** Codex wraps commands as `/bin/zsh -lc "…"`. */
export function unwrapCommand(cmd: string): string {
  const m = /^\/bin\/(?:z|ba)?sh -lc (["'])([\s\S]*)\1$/.exec(cmd.trim());
  return (m ? m[2].replace(/\\"/g, '"') : cmd).trim();
}

/** The exit code in a command's output: Codex's "(exit N)" or Claude Code's "Exit code N". */
export function exitCode(output: string): number | null {
  const m = /\(exit (-?\d+)\)\s*$/.exec(output) ?? /^Exit code (-?\d+)/m.exec(output);
  return m ? Number(m[1]) : null;
}

/** Which files a writing or reading card is about ("Edit a.ts, b.ts", "Write x", "Read y"). */
export function pathsOf(summary: string): string[] {
  const s = bare(summary).replace(/^(Read|Write|Edit)\s+/, "");
  if (!s || s === "files") return [];
  return s.split(/,\s+/).map((x) => x.trim()).filter(Boolean).slice(0, 20);
}

interface Pending { tool: string; summary: string; detail?: string; engine: string; at: string }

const ID = /^[A-Za-z0-9_-]{1,80}$/;

/** Plan step status from any engine's words. */
export function planStatus(v: unknown): PlanStatus {
  const s = String(v ?? "").toLowerCase().replace(/[\s-]/g, "_");
  if (["done", "completed", "complete", "finished"].includes(s)) return "done";
  if (["in_progress", "inprogress", "active", "doing", "started", "running"].includes(s)) return "in_progress";
  return "pending";
}

/**
 * A plan written as a list in a reply (a model that planned but did not call task_checkpoint).
 * Numbered top-level items win over bullets; indented lines are details, not steps. [] when fewer than 2.
 */
export function planFromReply(text: string): string[] {
  const numbered: string[] = [];
  const bullets: string[] = [];
  const clean = (x: string): string => x.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1").replace(/\*\*|__|`/g, "").replace(/\s+/g, " ").trim();
  for (const line of text.split("\n")) {
    const n = /^(\d{1,2})[.)]\s+(.+)/.exec(line);
    const b = /^[-*•]\s+(.+)/.exec(line);
    if (n) numbered.push(clean(n[2]));
    else if (b) bullets.push(clean(b[1]));
  }
  const pick = numbered.length >= 2 ? numbered : bullets.length >= 2 ? bullets : [];
  return pick.filter(Boolean).slice(0, CAP.steps).map((x) => clip(x, CAP.step));
}

/** Where a chat's plan file lives, relative to the project. */
export const planFileRel = (chatId: string): string => `.opscode/tasks/${chatId}/plan.md`;

/** The plan file both engines can read: the ledger's plan, decisions, next step and notes. */
export function planMarkdown(l: Ledger): string {
  const mark = (s: PlanStatus): string => (s === "done" ? "[x]" : "[ ]");
  return [
    "# Task plan",
    "",
    "Kept by Opscode from the chat's checkpoints. Any engine (Claude Code, Codex) may continue the task from here.",
    "",
    `Goal: ${l.goal || "(not stated)"}`,
    "",
    "## Plan",
    ...(l.plan?.steps.length ? l.plan.steps.map((p, i) => `${i + 1}. ${mark(p.status)} ${p.step}${p.status === "in_progress" ? " (in progress)" : ""}`) : ["(no plan yet)"]),
    ...(l.plan?.explanation ? ["", l.plan.explanation] : []),
    ...(l.decisions.length ? ["", "## Decisions (do not redo)", ...l.decisions.map((d) => `- ${d.text} (${d.by})`)] : []),
    ...(l.next ? ["", "## Next step", l.next.text] : []),
    ...(l.notes ? ["", "## Notes", l.notes.text] : []),
    "",
    `_Updated ${l.updated_at}${l.plan ? `; plan by ${l.plan.by}` : ""}_`,
    "",
  ].join("\n");
}

export class LedgerStore {
  private readonly dir: string;
  private readonly cache = new Map<string, Ledger>();
  /** Started tool calls by chat, then call id (in memory only). */
  private readonly pending = new Map<string, Map<string, Pending>>();
  /** The engine (and model) of each chat's running turn. */
  private readonly engineOf = new Map<string, string>();
  private readonly byOf = new Map<string, string>();
  /** Chats whose plan was set during the running turn. */
  private readonly planTouched = new Set<string>();
  private readonly dirty = new Set<string>();
  private timer: NodeJS.Timeout | undefined;

  constructor(stateDir: string, private readonly log: (line: string) => void = () => {}) {
    this.dir = join(stateDir, "ledger");
    ensurePrivateDir(this.dir);
  }

  private file(chatId: string): string {
    return join(this.dir, `${chatId}.json`);
  }

  private load(chatId: string, create: boolean): Ledger | undefined {
    if (!ID.test(chatId)) return undefined;
    const hit = this.cache.get(chatId);
    if (hit) return hit;
    const raw = readJson(this.file(chatId)) as Ledger | undefined;
    let l: Ledger | undefined = raw && raw.version === 1 && raw.chat_id === chatId ? raw : undefined;
    if (!l && create) l = { version: 1, chat_id: chatId, goal: "", decisions: [], user_messages: [], files_changed: [], files_read: [], commands: [], denied: [], turns: [], last_reply: "", updated_at: now() };
    if (l) { l.decisions ??= []; this.cache.set(chatId, l); }
    return l;
  }

  private touch(chatId: string, l: Ledger, soon = true): void {
    l.updated_at = now();
    this.dirty.add(chatId);
    if (!soon) return this.flush();
    if (!this.timer) {
      this.timer = setTimeout(() => this.flush(), 300);
      this.timer.unref?.();
    }
  }

  /** Writes changed ledgers now. */
  flush(): void {
    if (this.timer) { clearTimeout(this.timer); this.timer = undefined; }
    for (const id of this.dirty) {
      const l = this.cache.get(id);
      if (!l) continue;
      try { writeJsonAtomic(this.file(id), l); } catch (e) { this.log(`ledger: could not save ${id}: ${String(e)}`); }
    }
    this.dirty.clear();
  }

  /** A copy of the chat's ledger, or undefined when nothing has happened in it yet. */
  get(chatId: string): LedgerView | undefined {
    const l = this.load(chatId, false);
    if (!l) return undefined;
    const copy = JSON.parse(JSON.stringify(l)) as Ledger;
    const open: LedgerCommand[] = [];
    copy.commands.forEach((c, i) => {
      if (!c.ok && !copy.commands.slice(i + 1).some((d) => d.cmd === c.cmd && d.ok)) open.push(c);
    });
    return { ...copy, open_errors: open };
  }

  turnStart(chatId: string, t: { turn_id: string; engine: string; model?: string; effort?: string; text: string; event?: boolean; root?: string }): void {
    const l = this.load(chatId, true);
    if (!l) return;
    if (t.root) l.root = t.root;
    this.engineOf.set(chatId, t.engine);
    this.byOf.set(chatId, t.model ? `${t.engine}/${t.model}` : t.engine);
    this.planTouched.delete(chatId);
    this.pending.set(chatId, new Map());
    if (!t.event && t.text.trim()) {
      const text = redact(t.text.trim());
      if (!l.goal) l.goal = clip(text, CAP.goal);
      l.user_messages.push({ text: clip(text, CAP.user), at: now() });
      if (l.user_messages.length > CAP.users) l.user_messages.splice(0, l.user_messages.length - CAP.users);
    }
    l.turns.push({ turn_id: t.turn_id, engine: t.engine, ...(t.model ? { model: t.model } : {}), ...(t.effort ? { effort: t.effort } : {}), status: "running", at: now() });
    if (l.turns.length > CAP.turns) l.turns.splice(0, l.turns.length - CAP.turns);
    this.touch(chatId, l);
  }

  toolStart(chatId: string, c: { call_id: string; tool: string; summary: string; detail?: string }): void {
    const p = this.pending.get(chatId);
    if (!p) return;
    p.set(c.call_id, { tool: c.tool, summary: c.summary, ...(c.detail ? { detail: c.detail } : {}), engine: this.engineOf.get(chatId) ?? "unknown", at: now() });
  }

  toolEnd(chatId: string, callId: string, r: { output: string; is_error: boolean; denied?: boolean }): void {
    const call = this.pending.get(chatId)?.get(callId);
    if (!call) return;
    this.pending.get(chatId)?.delete(callId);
    const l = this.load(chatId, true);
    if (!l) return;
    const at = now();
    if (r.denied) {
      l.denied.push({ summary: redact(clip(bare(call.summary), 200)), at });
      if (l.denied.length > CAP.denied) l.denied.splice(0, l.denied.length - CAP.denied);
      return this.touch(chatId, l);
    }
    if (WRITE_TOOLS.has(call.tool)) {
      if (!r.is_error) for (const path of pathsOf(call.summary)) this.addFile(l.files_changed, path, call.engine, at);
    } else if (READ_TOOLS.has(call.tool)) {
      if (!r.is_error) for (const path of pathsOf(call.summary)) this.addFile(l.files_read, path, call.engine, at);
    } else if (CMD_TOOLS.has(call.tool)) {
      const cmd = redact(clip(unwrapCommand(call.detail || bare(call.summary).replace(/^Run\s+/, "")), 500));
      if (!cmd) return;
      const exit = exitCode(r.output);
      const ok = !r.is_error && (exit === null || exit === 0);
      const out = r.output.replace(/\n?\(exit -?\d+\)\s*$/, "");
      l.commands.push({ cmd, ok, exit, tail: redact(ok ? lastLines(out, 3, 300) : lastLines(out, 20, 1500)), engine: call.engine, at });
      if (l.commands.length > CAP.commands) l.commands.splice(0, l.commands.length - CAP.commands);
    } else return;
    this.touch(chatId, l);
  }

  private addFile(list: LedgerFile[], path: string, engine: string, at: string): void {
    const i = list.findIndex((f) => f.path === path);
    const count = i >= 0 ? list[i].count + 1 : 1;
    if (i >= 0) list.splice(i, 1);
    list.push({ path, count, engine, at });
    if (list.length > CAP.files) list.splice(0, list.length - CAP.files);
  }

  turnEnd(chatId: string, t: { turn_id: string; status: string; reply: string; error?: string }): void {
    const l = this.load(chatId, true);
    if (!l) return;
    const turn = l.turns.find((x) => x.turn_id === t.turn_id);
    const status = (t.status === "complete" || t.status === "interrupted" || t.status === "failed" ? t.status : "failed") as LedgerTurn["status"];
    if (turn) {
      turn.status = status;
      turn.ended_at = now();
      if (t.error) turn.error = clip(redact(t.error), 300);
    }
    if (t.reply.trim()) l.last_reply = redact(clipEnd(t.reply.trim(), CAP.reply));
    // What was still running when the turn stopped is the step the next engine must check first.
    const left = [...(this.pending.get(chatId)?.values() ?? [])];
    const last = left[left.length - 1];
    if (last && (status === "interrupted" || status === "failed")) {
      l.in_flight = { tool: last.tool, summary: redact(clip(bare(last.summary), 200)), ...(last.detail ? { detail: redact(clip(last.detail, CAP.detail)) } : {}), engine: last.engine, at: last.at, why: status };
    } else if (status === "complete") delete l.in_flight;
    // A model that planned in words but saved no plan: keep its list as the plan (no model call). Never
    // replaces a plan that exists, so a closing summary cannot overwrite a real plan.
    if (status === "complete" && !l.plan && !this.planTouched.has(chatId)) {
      const steps = planFromReply(redact(t.reply));
      if (steps.length) {
        l.plan = { steps: steps.map((step) => ({ step, status: "pending" as const })), by: `${this.byOf.get(chatId) ?? "unknown"} (from its reply)`, at: now() };
        this.writePlanFile(l);
      }
    }
    this.planTouched.delete(chatId);
    this.pending.delete(chatId);
    this.engineOf.delete(chatId);
    this.byOf.delete(chatId);
    this.touch(chatId, l, false);
  }

  /** The engine's own plan (Codex turn/plan/updated, Claude TodoWrite): replaces the plan. */
  setPlan(chatId: string, steps: { step: string; status: unknown }[], explanation?: string): void {
    const l = this.load(chatId, true);
    if (!l) return;
    const clean = steps.map((x) => ({ step: redact(clip(String(x.step ?? "").trim(), CAP.step)), status: planStatus(x.status) })).filter((x) => x.step).slice(0, CAP.steps);
    if (!clean.length) return;
    this.planTouched.add(chatId);
    l.plan = { steps: clean, by: this.byOf.get(chatId) ?? "unknown", at: now(), ...(explanation?.trim() ? { explanation: redact(clip(explanation.trim(), CAP.notes)) } : {}) };
    this.touch(chatId, l);
    this.writePlanFile(l);
  }

  /** task_checkpoint: the model saves the plan, decisions, next step and notes. Returns the plan file's path (relative), if written. */
  checkpoint(chatId: string, c: { plan?: unknown; decisions?: unknown; next?: unknown; notes?: unknown }): { saved: string[]; file?: string } {
    const l = this.load(chatId, true);
    if (!l) throw new Error("no such chat");
    const by = this.byOf.get(chatId) ?? "unknown";
    const at = now();
    const saved: string[] = [];
    if (Array.isArray(c.plan)) {
      const steps = c.plan.map((x) => (typeof x === "string" ? { step: x, status: "pending" } : { step: String((x as Record<string, unknown>)?.step ?? ""), status: (x as Record<string, unknown>)?.status }));
      const clean = steps.map((x) => ({ step: redact(clip(x.step.trim(), CAP.step)), status: planStatus(x.status) })).filter((x) => x.step).slice(0, CAP.steps);
      if (clean.length) { l.plan = { steps: clean, by, at }; this.planTouched.add(chatId); saved.push(`plan (${clean.length} steps)`); }
    }
    const decisions = Array.isArray(c.decisions) ? c.decisions : typeof c.decisions === "string" ? [c.decisions] : [];
    for (const d of decisions) {
      const text = redact(clip(String(d ?? "").trim(), CAP.decision));
      if (!text || l.decisions.some((x) => x.text === text)) continue;
      l.decisions.push({ text, by, at });
      saved.push("decision");
    }
    if (l.decisions.length > CAP.decisions) l.decisions.splice(0, l.decisions.length - CAP.decisions);
    if (typeof c.next === "string" && c.next.trim()) { l.next = { text: redact(clip(c.next.trim(), CAP.next)), by, at }; saved.push("next step"); }
    if (typeof c.notes === "string" && c.notes.trim()) { l.notes = { text: redact(clip(c.notes.trim(), CAP.notes)), by, at }; saved.push("notes"); }
    if (!saved.length) throw new Error("nothing to save: give plan, decisions, next or notes");
    this.touch(chatId, l);
    return { saved, ...(this.writePlanFile(l) ? { file: planFileRel(chatId) } : {}) };
  }

  /** Writes <project>/.opscode/tasks/<chat>/plan.md (git-ignored). Refuses links. False when it could not. */
  private writePlanFile(l: Ledger): boolean {
    if (!l.root || !(l.plan || l.decisions.length || l.next || l.notes)) return false;
    try {
      const od = join(l.root, ".opscode");
      const tasks = join(od, "tasks");
      const dir = join(tasks, l.chat_id);
      for (const p of [od, tasks, dir]) if (existsSync(p) && lstatSync(p).isSymbolicLink()) throw new Error(`${p} is a link`);
      mkdirSync(dir, { recursive: true, mode: 0o700 });
      const ig = join(tasks, ".gitignore");
      if (!existsSync(ig)) writeFileSync(ig, "*\n");
      const file = join(dir, "plan.md");
      if (existsSync(file) && lstatSync(file).isSymbolicLink()) throw new Error("plan.md is a link");
      writeFileSync(file, planMarkdown(l), { mode: 0o600 });
      return true;
    } catch (e) {
      this.log(`ledger: plan file not written: ${String(e)}`);
      return false;
    }
  }

  remove(chatId: string): void {
    if (!ID.test(chatId)) return;
    const root = this.load(chatId, false)?.root;
    if (root) {
      const dir = join(root, ".opscode", "tasks", chatId);
      try { if (existsSync(dir) && !lstatSync(dir).isSymbolicLink()) rmSync(dir, { recursive: true, force: true }); } catch (e) { this.log(`ledger: plan folder not removed: ${String(e)}`); }
    }
    this.cache.delete(chatId);
    this.pending.delete(chatId);
    this.dirty.delete(chatId);
    rmSync(this.file(chatId), { force: true });
  }

  /** Deletes ledgers of chats that no longer exist. */
  sweep(alive: Set<string>): number {
    let n = 0;
    let names: string[] = [];
    try { names = readdirSync(this.dir); } catch { return 0; }
    for (const name of names) {
      const id = name.replace(/\.json$/, "");
      if (name.endsWith(".json") && !alive.has(id)) { this.remove(id); n++; }
    }
    return n;
  }
}
