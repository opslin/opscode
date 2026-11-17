// The Chief: a coordinator chat that starts, steers and follows worker chats
// and keeps a board. Its own turns run through TurnManager like any chat (in a
// private "chief:<id>" home folder); worker turn events come back through
// TurnManager's observer and wake it with <chat_update> lines.

import { importPaths, isImagePath, isRef, resolveAttached } from "../attachments";
import { randomBytes } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ChatMessage, ChatMeta, PermissionMode, TurnEvent, Workspace } from "../../shared/protocol";
import type { ChatStore } from "../chats";
import type { Tool } from "../agent/tools";
import type { ChiefBrain } from "../turns";
import { resolveModel } from "../automations/spec";
import { boardText, crewContract, readReport, systemPrompt } from "./prompt";
import { chiefTools } from "./tools";
import { workerExtras } from "./pack";
import { FILE_KINDS, skillFor } from "./skills";
import { shortTitle } from "./title";
import { MODES, isMode, pickFor, type ModeId } from "./modes";
import { bandOf, limitsLine, opusBlocked, route, usageOf, type Band, type Usage } from "./route";
import { newStages, pipelineLines, slug, stageText, stageTitle, type Pipeline, type StageId } from "./pipeline";
import type { EngineLimits } from "../engines/limits";
import { ChiefStore, DEFAULT_SOUL, MODE_SOUL, newId, type Access, type ChiefProfile, type Item, type ItemChat, type StartSpec, type WorkerEngine, MASCOTS } from "./store";

export const HOME_PREFIX = "chief:";
const MODE: Record<Access, PermissionMode> = { read: "read", edit: "auto_edits", full: "full" };
const RANK: Record<Access, number> = { read: 0, edit: 1, full: 2 };
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
const attr = (s: string): string => s.replace(/"/g, "'").replace(/\s+/g, " ");
const today = (): string => new Date().toISOString().slice(0, 10);

/** True when at least one file path named in a Check line exists inside the project (images, SVGs, documents). */
export function filesExist(check: string, root: string | undefined): boolean {
  if (!root) return false;
  const paths = check.match(/[\w@./-]+\.(?:png|jpe?g|webp|gif|svg|md|json|pdf)\b/gi) ?? [];
  return paths.some((x) => {
    const abs = x.startsWith("/") ? x : join(root, x.replace(/^\.\//, ""));
    return abs.startsWith(root + "/") && existsSync(abs);
  });
}

export interface AutomationInfo { name: string; scope: "project" | "me"; description: string; inputs: Record<string, { description: string; required: boolean; default?: string }>; ok: boolean }

export interface ChiefDeps {
  stateDir: string;
  /** The Library of the person's existing apps (read-only for the Chief). */
  library?: import("../library").LibraryService;
  chats: ChatStore;
  turns: {
    submit(workspaceId: string, chatId: string, text: string, opts?: { engineText?: string; event?: boolean }): { turn_id: string };
    interrupt(turnId: string): { interrupted: boolean };
    deleteChat(chatId: string): boolean;
    history(chatId: string): ChatMessage[];
  };
  workspaces(): Workspace[];
  /** Why an engine cannot be used right now, or undefined when it can. */
  engineProblem(engine: WorkerEngine): string | undefined;
  defaultWorkerEngine(): WorkerEngine;
  memory: { prompt(workspaceId: string): string; remember(scope: string, text: string): void };
  automations: {
    list(workspaceId: string): AutomationInfo[];
    start(workspaceId: string, scope: "project" | "me", name: string, inputs: Record<string, string>): { id: string; status: string };
  };
  mcpUrl(): string;
  broadcast(method: string, params: unknown): void;
  log(line: string): void;
  /** The plan limits Opscode reads for free (Usage page). Conductors route workers by them. */
  limits?: { all(): EngineLimits[]; refresh(force?: boolean): Promise<unknown>; forAccount?(engine: "claude-code" | "codex", account: string): EngineLimits | undefined; refreshAccount?(engine: "claude-code" | "codex", account: string, force?: boolean): Promise<unknown> };
  /** Does this account exist (and is it for this engine)? A Chief can only be set to one that does. */
  accountExists?(engine: "claude-code" | "codex", account: string): boolean;
  /** Model ids this computer's Codex offers (a mode's Codex pick is used only when listed; empty = not known yet, use Codex's default). */
  codexModelIds?: () => string[];
}

type Lim = { band: Band; usage: Usage | null };

interface Inbox { notes: string[]; updates: string[]; attached: string[]; timer?: NodeJS.Timeout }

export class ChiefManager {
  readonly store: ChiefStore;
  private readonly running = new Map<string, string>(); // chat -> turn in progress
  private readonly sendLater = new Map<string, string[]>(); // worker chat -> messages for its next turn
  private readonly stoppedByChief = new Set<string>(); // turn ids the Chief stopped
  private readonly inbox = new Map<string, Inbox>(); // chief -> waiting input
  private readonly tokens = new Map<string, { chiefId: string; turnId: string; tools: Tool[] }>();
  private timer: NodeJS.Timeout | null = null;
  private bands: { claude: Band; codex: Band } = { claude: "normal", codex: "normal" };
  private lastKick = 0;
  /** At most one limits refresh per this long (three ticks; a minute by default). */
  private kickEvery = 60_000;
  /** Pipelines whose running stage was cut off by a restart; their Conductors are woken once the ticker starts. */
  private readonly resumeStages = new Set<string>();

  constructor(private readonly d: ChiefDeps) {
    this.store = new ChiefStore(d.stateDir);
    // Work that was running when Opscode stopped did not finish. Items that still hold chats to
    // start go back to waiting (the ticker starts them); a pipeline stage is resumed by its Conductor.
    for (const i of this.store.all()) {
      for (const c of i.chats) if (c.state === "running" || c.state === "needs_you") c.state = "stopped";
      if (i.state === "running" || (i.state === "needs_you" && !i.ask)) {
        if (i.pending?.length) { i.state = "waiting"; i.detail = "Opscode stopped while it ran; the rest starts by itself"; }
        else if (i.pipeline) { i.state = "queued"; i.detail = "Opscode stopped while it ran; its Conductor resumes it"; this.resumeStages.add(i.pipeline.id); }
        else { i.state = "failed"; i.detail = "Opscode stopped while it ran"; }
      }
    }
    this.store.saveBoard();
  }

  // ---- profiles -------------------------------------------------------------------------------
  /** The private folder a Chief's own chat runs in. */
  home(chiefId: string): Workspace | undefined {
    const p = this.store.get(chiefId);
    if (!p) return undefined;
    const dir = join(this.d.stateDir, "chiefs", p.id);
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    return { id: HOME_PREFIX + p.id, name: p.name, path: realpathSync(dir), added_at: p.created_at };
  }
  homeWorkspace(workspaceId: string): Workspace | undefined {
    return workspaceId.startsWith(HOME_PREFIX) ? this.home(workspaceId.slice(HOME_PREFIX.length)) : undefined;
  }

  create(o: { name?: string; brain?: ChiefProfile["brain"]; mode?: ModeId; project_id?: string }): ChiefProfile {
    if (o.mode !== undefined && !isMode(o.mode)) throw new Error("unknown mode");
    if (o.mode) {
      const problem = this.d.engineProblem("claude-code");
      if (problem) throw new Error(`${MODES[o.mode].name} runs on Claude Code. ${problem}`);
      if (o.project_id && !this.d.workspaces().some((w) => w.id === o.project_id)) throw new Error("no such project");
    }
    const id = newId("chief");
    const mode = o.mode ? MODES[o.mode] : undefined;
    const brain = mode ? { ...mode.brain } : o.brain ?? (this.d.engineProblem("claude-code") ? { engine: "api" as const } : { engine: "claude-code" as const, model: "sonnet" });
    const wid = HOME_PREFIX + id;
    const chat = this.d.chats.create(wid, "read");
    const t = new Date().toISOString();
    const name = (o.name ?? "").trim().slice(0, 40) || (mode ? mode.name : this.store.list().length ? `Manager ${this.store.list().length + 1}` : "Manager");
    const taken = new Set(this.store.list().map((x) => x.avatar));
    const avatar = MASCOTS.find((m) => !taken.has(m)) ?? MASCOTS[0];
    const p = this.store.add({
      id, name, ...(mode ? { mode: mode.id } : { avatar }), brain, soul: mode ? MODE_SOUL : DEFAULT_SOUL, autonomy: 2, updates: mode ? "milestones" : "results", worker_access: "edit", worker_engine: mode ? "claude-code" : this.d.defaultWorkerEngine(),
      project_ids: o.project_id ? [o.project_id] : [], max_parallel: mode ? mode.max_parallel : 3, daily_chats: mode ? mode.daily_chats : 30, ask_wait_minutes: 15, chat_id: chat.id, created_at: t, updated_at: t,
    });
    this.d.chats.setChief(chat.id, { id, role: "home" }, name);
    this.syncBrain(p);
    this.changed(id, true);
    return p;
  }

  update(id: string, patch: Partial<Pick<ChiefProfile, "mode" | "name" | "title" | "avatar" | "brain" | "soul" | "autonomy" | "updates" | "worker_access" | "worker_engine" | "project_ids" | "max_parallel" | "daily_chats" | "ask_wait_minutes" | "accounts">>): ChiefProfile {
    if (patch.accounts) {
      for (const [e, a] of Object.entries(patch.accounts)) {
        if (a === undefined || a === "") continue;
        if ((e !== "claude-code" && e !== "codex") || !this.d.accountExists?.(e, a)) throw new Error("that account does not exist");
      }
      // An empty string clears the choice for that engine.
      const next: Record<string, string> = { ...(this.store.get(id)?.accounts ?? {}) };
      for (const [e, a] of Object.entries(patch.accounts)) { if (a) next[e] = a; else delete next[e]; }
      patch = { ...patch, accounts: next as ChiefProfile["accounts"] };
    }
    if (patch.brain && patch.brain.engine !== "claude-code" && patch.brain.engine !== "api") throw new Error("a Manager runs on Claude Code or an API key");
    if (patch.mode !== undefined) {
      if (!isMode(patch.mode)) throw new Error("unknown mode");
      // Switching modes re-applies the mode's brain and limits; the person's soul and projects stay.
      const m = MODES[patch.mode];
      patch = { ...patch, brain: { ...m.brain }, max_parallel: m.max_parallel, daily_chats: m.daily_chats };
    }
    if (patch.avatar !== undefined && !(MASCOTS as readonly string[]).includes(patch.avatar)) throw new Error("unknown mascot");
    if (patch.project_ids) {
      const known = new Set(this.d.workspaces().map((w) => w.id));
      patch.project_ids = [...new Set(patch.project_ids)].filter((x) => known.has(x));
    }
    const p = this.store.update(id, patch);
    if (patch.name || patch.title !== undefined) this.d.chats.setChief(p.chat_id, { id, role: "home" }, p.title || p.name);
    if (patch.brain || patch.accounts) this.syncBrain(p);
    this.fillSlots(p.id);
    this.changed(id, true);
    return p;
  }

  /** `workers`: also delete the worker chats it started (their transcripts); otherwise they stay as ordinary chats in their projects. Files they changed are never touched. */
  remove(id: string, workers = false): boolean {
    const p = this.store.get(id);
    if (!p) return false;
    const mine = this.store.itemsOf(id).flatMap((i) => i.chats.map((c) => c.chat_id));
    for (const chatId of mine) this.stop(chatId);
    const r = this.running.get(p.chat_id);
    if (r) this.d.turns.interrupt(r);
    this.store.remove(id);
    this.d.chats.remove(p.chat_id);
    if (workers) for (const chatId of mine) this.d.turns.deleteChat(chatId);
    else for (const chatId of mine) this.d.chats.clearChief(chatId);
    this.d.broadcast("chat.changed", { chats: this.d.chats.list() });
    this.d.broadcast("chief.changed", { chief_id: id, removed: true, chiefs: this.store.list() });
    return true;
  }

  /** A worker chat was deleted by the person: it leaves its item; an item with nothing left is dropped from the board. */
  forgetChat(chatId: string): void {
    const item = this.store.itemOfChat(chatId);
    if (!item) return;
    item.chats = item.chats.filter((c) => c.chat_id !== chatId);
    this.running.delete(chatId);
    this.sendLater.delete(chatId);
    if (!item.chats.length && !item.pending?.length && !item.automation) item.state = "dropped";
    else if (item.state !== "dropped" && item.state !== "done") item.state = this.derived(item);
    this.store.touch(item);
    this.changed(item.chief_id);
  }

  /** A project was unlinked from Opscode: a Conductor that was only for it goes too (its worker chats are dropped with the project's chats). */
  projectRemoved(workspaceId: string): void {
    for (const p of this.store.list()) {
      if (p.mode && p.project_ids.length === 1 && p.project_ids[0] === workspaceId) this.remove(p.id, true);
      else if (p.mode && p.project_ids.includes(workspaceId)) this.update(p.id, { project_ids: p.project_ids.filter((x) => x !== workspaceId) });
    }
  }

  /** The chat's engine follows the Chief's brain setting. */
  private syncBrain(p: ChiefProfile): void {
    this.d.chats.setEngine(p.chat_id, { engine: p.brain.engine, ...(p.brain.model ? { model: p.brain.model } : {}), ...(p.brain.effort ? { effort: p.brain.effort } : {}) });
    this.pinAccount(p, p.chat_id, p.brain.engine);
  }

  /** The Chief's chosen account for this engine goes on the chat (a chat with a session on another account moves, starting fresh there). */
  private pinAccount(p: ChiefProfile, chatId: string, engine: string): void {
    const a = engine === "claude-code" || engine === "codex" ? p.accounts?.[engine] : undefined;
    if (a && (engine === "claude-code" || engine === "codex")) this.d.chats.moveAccount(chatId, engine, a);
  }

  view(id: string): { chief: ChiefProfile; items: Item[]; pipelines: Pipeline[]; queued_notes: number; running: boolean } {
    const p = this.store.get(id);
    if (!p) throw new Error("no such Manager");
    return { chief: { ...p }, items: this.store.itemsOf(id).filter((i) => i.state !== "dropped"), pipelines: this.store.pipelines(id).filter((x) => x.state !== "stopped"), queued_notes: this.inbox.get(id)?.notes.length ?? 0, running: this.running.has(p.chat_id) };
  }

  private changed(chiefId: string, profiles = false): void {
    try {
      this.d.broadcast("chief.changed", { chief_id: chiefId, ...this.view(chiefId), ...(profiles ? { chiefs: this.store.list() } : {}) });
    } catch { /* removed */ }
  }

  projectsOf(p: ChiefProfile): Workspace[] {
    const all = this.d.workspaces();
    return p.project_ids.length ? all.filter((w) => p.project_ids.includes(w.id)) : all;
  }

  // ---- notes and wake-ups ---------------------------------------------------------------------
  /** A note from the person. Runs now, or right after the Chief's current turn. */
  note(chiefId: string, text: string, attachments?: string[]): { turn_id?: string; queued: boolean } {
    const p = this.store.get(chiefId);
    if (!p) throw new Error("no such Manager");
    if (p.mode && !p.title) {
      const title = shortTitle(text);
      if (title) { this.store.update(chiefId, { title }); this.d.chats.setChief(p.chat_id, { id: chiefId, role: "home" }, title); this.d.broadcast("chat.changed", { chats: this.d.chats.list() }); this.changed(chiefId, true); }
    }
    const box = this.box(chiefId);
    box.notes.push(text);
    if (attachments?.length) box.attached.push(...attachments);
    // The person wrote: open questions wait a little longer (the Chief reads the note first), but do not freeze for good.
    const later = new Date(Date.now() + Math.max(1, p.ask_wait_minutes) * 60_000).toISOString();
    for (const i of this.store.itemsOf(chiefId)) if (i.ask?.go_ahead_at && i.ask.go_ahead_at < later) { i.ask.go_ahead_at = later; this.store.touch(i); }
    const turn = this.deliver(chiefId);
    this.changed(chiefId);
    return turn ? { turn_id: turn, queued: false } : { queued: true };
  }

  private box(chiefId: string): Inbox {
    let b = this.inbox.get(chiefId);
    if (!b) this.inbox.set(chiefId, (b = { notes: [], updates: [], attached: [] }));
    return b;
  }

  /** Adds a worker update and wakes the Chief soon (updates arriving together go in one turn). */
  private wake(chiefId: string, update: string): void {
    const box = this.box(chiefId);
    box.updates.push(update);
    if (box.timer) return;
    box.timer = setTimeout(() => { box.timer = undefined; this.deliver(chiefId); }, 1200);
    box.timer.unref?.();
  }

  /** Starts a Chief turn with everything waiting, unless one is running. Returns its turn id. */
  private deliver(chiefId: string): string | undefined {
    const p = this.store.get(chiefId);
    const box = this.inbox.get(chiefId);
    if (!p || !box || (box.notes.length === 0 && box.updates.length === 0)) return undefined;
    if (this.running.has(p.chat_id)) return undefined;
    const problem = this.d.engineProblem(p.brain.engine);
    if (problem) {
      // Keep the notes for later; tell the person once on the board.
      this.d.broadcast("chief.problem", { chief_id: chiefId, message: problem });
      return undefined;
    }
    const notes = box.notes.splice(0);
    const updates = box.updates.splice(0);
    const attachedRels = box.attached.splice(0);
    if (box.timer) { clearTimeout(box.timer); box.timer = undefined; }
    const board = boardText(this.store.itemsOf(chiefId), (id) => this.d.chats.get(id)?.title, (id) => this.d.workspaces().find((w) => w.id === id)?.name);
    const pipes = pipelineLines(this.store.pipelines(chiefId), (id) => (id ? this.store.item(id)?.ref : undefined));
    const engineText = [...notes.map((n) => `<note>${n}</note>`), ...updates, ...(pipes ? [pipes] : []), board].join("\n");
    const display = notes.length ? notes.join("\n\n") : updates.map((u) => /title="([^"]*)"/.exec(u)?.[1] ?? "").filter(Boolean).map((t) => `Update: ${t}`).join("\n") || "Update";
    const home = this.home(chiefId) as Workspace;
    // Attachments: the Conductor sees the pictures itself and gets absolute paths to hand to workers (chat_start attachments).
    let attachNote = "";
    if (attachedRels.length) {
      try {
        const got = resolveAttached(home.path, attachedRels);
        if (got.length) attachNote = `\n\n<attached>\nThe person attached these (pictures are shown to you). Give a worker the ones its task needs: put their paths in chat_start attachments.\n${got.map((a) => a.ref ? `- key or credentials file (stays where it is; give workers its path): ${a.abs}` : `- ${a.kind}: ${a.abs}${a.kind === "folder" ? `/ (${a.files ?? "?"} files)` : ""}`).join("\n")}\n</attached>`;
      } catch { /* the files vanished: carry on without them */ }
    }
    try {
      const r = this.d.turns.submit(home.id, p.chat_id, display, { engineText, event: notes.length === 0, ...(attachedRels.length ? { attachments: attachedRels, attachNote } : {}) });
      this.running.set(p.chat_id, r.turn_id);
      return r.turn_id;
    } catch (e) {
      box.notes.unshift(...notes);
      box.updates.unshift(...updates);
      box.attached.unshift(...attachedRels);
      this.d.log(`chief: could not start a turn: ${e instanceof Error ? e.message : String(e)}`);
      return undefined;
    }
  }

  /** What a worker is given: paths (absolute or project-relative) of pictures, files and folders. Ones the person attached in
   *  another project are copied into this worker's own project first, so the worker can open them. */
  private workerAttachments(proot: string, list: string[], homeDir?: string): { abs: string; kind: "image" | "file" | "folder"; ref?: boolean }[] {
    const out: { abs: string; kind: "image" | "file" | "folder"; ref?: boolean }[] = [];
    let realRoot: string;
    try { realRoot = realpathSync(proot); } catch { return out; }
    const attachDirs = [...this.d.workspaces().map((w) => w.path), ...(homeDir ? [homeDir] : [])].map((d) => { try { return join(realpathSync(d), ".opscode", "attachments"); } catch { return ""; } }).filter(Boolean);
    for (const x of list.slice(0, 12)) {
      let abs = x.startsWith("/") ? x : join(proot, x);
      try {
        abs = realpathSync(abs);
        // A key or credentials file stays where it is: the worker is told its path.
        if (isRef(abs)) { out.push({ abs, kind: "file", ref: true }); continue; }
        if (!abs.startsWith(realRoot + "/")) {
          // Only the person's own attachments cross projects.
          if (!attachDirs.some((d) => abs.startsWith(d + "/"))) continue;
          abs = join(realRoot, importPaths(proot, [abs])[0].path);
        }
        out.push({ abs, kind: statSync(abs).isDirectory() ? "folder" : isImagePath(abs) ? "image" : "file" });
      } catch { /* missing or refused: skipped */ }
    }
    return out;
  }

  /** The Library, for the Chief's library_search tool. */
  library(): import("../library").LibraryService | undefined { return this.d.library; }

  /** The prompt and tools for one turn of a Chief's own chat (TurnManager calls this). */
  brain(chat: ChatMeta, turnId: string): ChiefBrain | undefined {
    const p = this.store.byChat(chat.id);
    if (!p) return undefined;
    const projects = this.projectsOf(p);
    const autos: string[] = [];
    for (const w of projects) {
      let list: AutomationInfo[] = [];
      try { list = this.d.automations.list(w.id); } catch { /* none */ }
      for (const a of list.filter((x) => x.ok).slice(0, 8)) {
        const ins = Object.entries(a.inputs).map(([k, v]) => `${k}${v.required ? "*" : ""}`).join(", ");
        autos.push(`- ${w.name} (${w.id}): ${a.name} [${a.scope}]${a.description ? ` — ${clip(a.description, 140)}` : ""}${ins ? ` (inputs: ${ins})` : ""}`);
      }
    }
    const memory = projects.map((w) => this.d.memory.prompt(w.id)).find((m) => m) ?? this.d.memory.prompt("global");
    const tools = chiefTools(this, p);
    const token = randomBytes(24).toString("hex");
    this.tokens.set(token, { chiefId: p.id, turnId, tools });
    this.running.set(chat.id, turnId);
    const lim = p.mode ? this.limitsNow(p) : undefined;
    const limits = lim ? limitsLine(lim.claude, lim.codex) : "";
    return { system: systemPrompt(p, projects, autos.slice(0, 24).join("\n"), memory) + (limits ? `\n\n${limits}` : ""), tools, mcp: { url: this.d.mcpUrl(), token } };
  }

  /** Tools reachable with an MCP token (only while its turn runs). */
  toolsFor(token: string): Tool[] | undefined {
    return this.tokens.get(token)?.tools;
  }

  /** The person's own words in a Chief's chat (quotes must come from here). */
  personWords(p: ChiefProfile): string {
    const notes = this.inbox.get(p.id)?.notes ?? [];
    return [...this.d.turns.history(p.chat_id).filter((m) => m.role === "user" && !m.event).map((m) => m.text), ...notes].join("\n");
  }

  // ---- plan limits ----------------------------------------------------------------------------
  /** Both engines' bands right now (hysteresis kept between calls). Missing or stale data counts as normal and asks for a refresh. */
  limitsNow(p?: ChiefProfile): { claude: Lim; codex: Lim } {
    const all = this.d.limits?.all() ?? [];
    // A Chief set to a particular account is routed by that account's numbers.
    const of = (engine: "claude-code" | "codex"): EngineLimits | undefined => {
      const a = p?.accounts?.[engine];
      return (a ? this.d.limits?.forAccount?.(engine, a) : undefined) ?? (a ? undefined : all.find((l) => l.engine === engine));
    };
    const cu = usageOf(of("claude-code"));
    const xu = usageOf(of("codex"));
    if (this.d.limits && (!cu?.fresh || !xu?.fresh)) this.kickRefresh(false, p);
    this.bands = { claude: bandOf(cu, this.bands.claude), codex: bandOf(xu, this.bands.codex) };
    return { claude: { band: this.bands.claude, usage: cu }, codex: { band: this.bands.codex, usage: xu } };
  }

  /** Asks for fresh limits at most once a minute (the checks run no model and cost nothing). */
  private kickRefresh(force: boolean, chief?: ChiefProfile): void {
    if (!this.d.limits || Date.now() - this.lastKick < this.kickEvery) return;
    this.lastKick = Date.now();
    const extra = (["claude-code", "codex"] as const).flatMap((e) => { const a = chief?.accounts?.[e]; return a && this.d.limits?.refreshAccount ? [this.d.limits.refreshAccount(e, a, force)] : []; });
    Promise.all([this.d.limits.refresh(force), ...extra]).then(() => { for (const p of this.store.list()) this.fillSlots(p.id); }).catch((e) => this.d.log(`chief: limits refresh failed: ${String(e)}`));
  }

  // ---- worker chats ---------------------------------------------------------------------------
  /** Workers holding a slot. One that waits for the person's approval does not: it is idle until they answer, and in SHINOBI (one slot) it would block everything. */
  private runningWorkers(chiefId: string): number {
    return this.store.itemsOf(chiefId).reduce((n, i) => n + i.chats.filter((c) => c.state === "running").length, 0);
  }
  private opusToday(chiefId: string): number {
    const d = today();
    let n = 0;
    for (const i of this.store.itemsOf(chiefId)) for (const c of i.chats) if (c.started_at.slice(0, 10) === d && this.d.chats.get(c.chat_id)?.model?.includes("opus")) n++;
    return n;
  }

  private startedToday(chiefId: string): number {
    const d = today();
    return this.store.itemsOf(chiefId).reduce((n, i) => n + i.chats.filter((c) => c.started_at.slice(0, 10) === d).length, 0);
  }

  /** Starts chats for an item now, or parks them (waiting for a slot, or proposed for the person). */
  startChats(p: ChiefProfile, item: Item, specs: StartSpec[], propose: boolean): { state: string; chats: { chat_id: string; project_id: string; engine: string }[]; note?: string } {
    if (propose) {
      item.pending = [...(item.pending ?? []), ...specs];
      item.state = "proposed";
      this.store.touch(item);
      this.changed(p.id);
      return { state: "proposed", chats: [], note: "Proposed: the person starts it from the board." };
    }
    const started: { chat_id: string; project_id: string; engine: string }[] = [];
    const parked: StartSpec[] = [];
    let note: string | undefined;
    const errors: string[] = [];
    // A Conductor routes by plan limits: one reading for the whole batch, so a burst cannot flip mid-way.
    const lim = p.mode ? this.limitsNow(p) : undefined;
    let limitPark: Item["parked"] | undefined;
    for (const orig of specs) {
      let s = orig;
      if (lim) {
        // Pending specs are always the Conductor's originals; the routing decision is made fresh each time.
        const dec = route(orig, lim.claude, lim.codex);
        if (dec.action === "park") {
          parked.push(orig);
          limitPark = { reason: "limits", engine: dec.engine, ...(dec.until ? { until: dec.until } : {}) };
          note = dec.why;
          continue;
        }
        if (dec.rerouted_from) {
          s = { ...orig, engine: dec.engine, rerouted_from: dec.rerouted_from };
          if (dec.why) note = `${note ? `${note} ` : ""}${dec.why}`;
        }
      }
      if (this.startedToday(p.id) >= p.daily_chats) { parked.push(orig); note = `Today's limit of ${p.daily_chats} chats is reached; it waits until tomorrow or until the person raises the limit.`; continue; }
      if (this.runningWorkers(p.id) >= p.max_parallel) { parked.push(orig); note = `All ${p.max_parallel} slots are busy; it starts by itself when one frees.`; continue; }
      try {
        const { note: n, ...chat } = this.launch(p, item, s);
        started.push(chat);
        if (n) note = `${note ? `${note} ` : ""}${n}`;
      } catch (e) { errors.push(e instanceof Error ? e.message : String(e)); }
    }
    if (errors.length && started.length === 0 && parked.length === 0) {
      if (item.chats.length === 0 && item.state === "queued") item.detail = errors[0];
      this.store.touch(item);
      this.changed(p.id);
      throw new Error(errors[0]);
    }
    if (errors.length) note = `${note ? `${note} ` : ""}Some chats did not start: ${errors.join("; ")}`;
    if (parked.length) item.pending = [...(item.pending ?? []).filter((x) => !specs.includes(x)), ...parked];
    else if (item.pending) item.pending = item.pending.filter((x) => !specs.includes(x));
    if (item.pending?.length === 0) delete item.pending;
    // A plan-limit park is recorded on the item (and persisted) so the ticker and a restart honour it.
    if (limitPark) { item.parked = limitPark; item.detail = clip(note ?? "waits for a plan limit to reset", 240); }
    else if (item.parked?.reason === "limits" || !item.pending) delete item.parked;
    if (started.length) item.state = this.derived(item);
    else if (parked.length && item.state !== "running" && item.state !== "needs_you") item.state = "waiting";
    this.store.touch(item);
    this.changed(p.id);
    return { state: started.length ? "started" : limitPark ? "parked" : "waiting", chats: started, ...(note ? { note } : {}) };
  }

  private launch(p: ChiefProfile, item: Item, s: StartSpec): { chat_id: string; project_id: string; engine: string; note?: string } {
    const problem = this.d.engineProblem(s.engine);
    if (problem) throw new Error(problem);
    const access: Access = RANK[s.access] <= RANK[p.worker_access] ? s.access : p.worker_access;
    const chat = this.d.chats.create(s.project_id, MODE[access]);
    // In a mode, the mode's table decides the exact model and effort; otherwise the plain tier classes.
    // A pipeline stage's item carries its own mode (e.g. GODMODE for the plan inside a SHINOBI Conductor).
    const mode = p.mode ? MODES[item.mode ?? p.mode] : undefined;
    let m: { model?: string; effort?: string };
    let note: string | undefined;
    if (mode && s.engine === "claude-code") {
      const r = pickFor(mode, s.tier, s.role, this.opusToday(p.id), opusBlocked(this.d.limits?.all().find((l) => l.engine === "claude-code")), s.kind);
      m = { model: r.pick.model, effort: r.pick.effort };
      note = r.note;
    } else if (mode && s.engine === "codex") {
      const k = s.role === "review" || s.tier === "frontier" || s.tier === "opus" ? "frontier" : s.tier === "fast" ? "fast" : "base";
      const want = mode.codex_models[k];
      const have = this.d.codexModelIds?.() ?? [];
      m = { effort: mode.codex[k], ...(have.includes(want) ? { model: want } : {}) };
    } else m = resolveModel(s.engine, s.tier === "opus" ? "frontier" : s.kind === "qa" && s.engine === "claude-code" ? "base" : s.tier, undefined);
    this.d.chats.setEngine(chat.id, { engine: s.engine, ...(m.model ? { model: m.model } : {}), ...(m.effort ? { effort: m.effort } : {}) });
    this.pinAccount(p, chat.id, s.engine);
    this.d.chats.setChief(chat.id, { id: p.id, role: s.role, item_id: item.id }, s.role === "build" ? s.title : `${s.role === "review" ? "Review" : "Check"}: ${s.title}`);
    const ic: ItemChat = { chat_id: chat.id, workspace_id: s.project_id, role: s.role, engine: s.engine, state: "running", started_at: new Date().toISOString(), ...(s.tier ? { tier: s.tier } : {}), access };
    item.chats.push(ic);
    if (!item.project_ids.includes(s.project_id)) item.project_ids.push(s.project_id);
    if (s.kind) ic.kind = s.kind;
    if (s.rerouted_from) ic.rerouted_from = s.rerouted_from;
    try {
      // A Conductor's workers also get the matching skill, the working rules and a short project map (see skills.ts, pack.ts).
      const root = mode ? this.d.workspaces().find((w) => w.id === s.project_id)?.path : undefined;
      const skill = mode ? skillFor(s.role, s.kind) : "";
      const moved = s.rerouted_from ? "\n\n(Opscode moved this task to you because the other engine is near its plan limit. The instructions below are the same for you: do the task, then end with the report lines, including Check.)" : "";
      // Reference images: Codex gets them attached; every worker also gets their paths in the brief (Claude Code opens them itself).
      const proot = this.d.workspaces().find((w) => w.id === s.project_id)?.path;
      const given = proot ? this.workerAttachments(proot, s.images ?? [], this.home(p.id)?.path) : [];
      const images = given.filter((x) => x.kind === "image").map((x) => x.abs);
      const others = given.filter((x) => x.kind !== "image");
      const refs = (images.length ? `\n\nReference images (look at them): ${images.map((x) => x.slice(proot!.length + 1)).join(", ")}` : "") + (others.length ? `\n\nFiles and folders the person attached for this task (open what you need): ${others.map((x) => (x.ref ? x.abs : x.abs.slice(proot!.length + 1)) + (x.kind === "folder" ? "/" : "") + (x.ref ? " (key or credentials: left where it is; use it by this path, for example ssh -i; never print, copy or commit it)" : "")).join(", ")}` : "");
      const r = this.d.turns.submit(s.project_id, chat.id, s.brief, { engineText: s.brief + refs + moved + skill + (root ? workerExtras(root) : "") + crewContract(p.name), ...(images.length ? { images } : {}) });
      this.running.set(chat.id, r.turn_id);
    } catch (e) {
      ic.state = "failed";
      throw e;
    }
    return { chat_id: chat.id, project_id: s.project_id, engine: s.engine, ...(note ? { note } : {}) };
  }

  /** The person starts a proposed item from the board. */
  startProposed(itemId: string): Item {
    const item = this.store.item(itemId);
    if (!item) throw new Error("no such item");
    const p = this.store.get(item.chief_id) as ChiefProfile;
    if (item.state !== "proposed" || !item.pending?.length) throw new Error("this item has nothing waiting to start");
    item.state = "waiting";
    this.startChats(p, item, [...item.pending], false);
    return item;
  }

  /** Waiting items take free slots, oldest first. */
  private fillSlots(chiefId: string): void {
    const p = this.store.get(chiefId);
    if (!p) return;
    const now = Date.now();
    for (const item of this.store.itemsOf(chiefId).filter((i) => i.state === "waiting" && i.pending?.length).sort((a, b) => a.ref - b.ref)) {
      if (this.runningWorkers(chiefId) >= p.max_parallel || this.startedToday(chiefId) >= p.daily_chats) return;
      const pk = item.parked;
      // Not before its time: a limit park waits for the reset it recorded (this holds across a restart, when no limits are known yet); a failed start waits a little before retrying.
      if (pk?.until && Date.parse(pk.until) > now) continue;
      if (pk?.reason === "limits") {
        // Past the reset (or no reset known): look again only with a fresh reading; startChats re-parks if still full.
        const lim = this.limitsNow(p);
        const u = pk.engine === "codex" ? lim.codex.usage : lim.claude.usage;
        if (!u?.fresh) { this.kickRefresh(true); continue; }
      }
      try { this.startChats(p, item, [...(item.pending ?? [])], false); } catch (e) {
        // A start that fails keeps its work: retry three times, a couple of minutes apart, then mark it failed (the pending chats stay, so the person can start them again).
        const tries = (pk?.reason === "error" ? pk.tries ?? 0 : 0) + 1;
        item.detail = clip(e instanceof Error ? e.message : String(e), 240);
        if (tries >= 3) { item.state = "failed"; delete item.parked; }
        else item.parked = { reason: "error", tries, until: new Date(now + 120_000).toISOString() };
        this.store.touch(item);
        this.changed(chiefId);
      }
    }
  }

  /** A chat the Chief may message: one of its workers, or any chat in its projects. */
  chatFor(p: ChiefProfile, chatId: string): ChatMeta {
    const c = this.d.chats.get(chatId);
    if (!c || c.chief?.role === "home" || c.origin) throw new Error(`No chat ${chatId}.`);
    const mine = c.chief?.id === p.id;
    if (!mine && !this.projectsOf(p).some((w) => w.id === c.workspace_id)) throw new Error(`${chatId} is outside this Manager's projects.`);
    return c;
  }

  /** Sends a message to a worker: now if it is idle, else when its current turn ends. */
  send(p: ChiefProfile, chatId: string, text: string): { delivered: "now" | "after_current_turn" | "fresh_worker" | "waiting"; chat_id?: string; note?: string } {
    const c = this.chatFor(p, chatId);
    const msg = `[${p.name}] ${text}`;
    if (this.running.has(c.id)) {
      this.sendLater.set(c.id, [...(this.sendLater.get(c.id) ?? []), msg]);
      return { delivered: "after_current_turn" };
    }
    return this.deliverTo(p, c, msg);
  }

  /** Gives a message to an idle worker, or, in a mode, to a fresh worker when its chat has grown too large. */
  private deliverTo(p: ChiefProfile, c: ChatMeta, msg: string): { delivered: "now" | "fresh_worker" | "waiting"; chat_id?: string; note?: string } {
    const mode = p.mode ? MODES[p.mode] : undefined;
    // No context count reported: fall back to what the last request read and wrote.
    const tokens = c.usage?.context_tokens ?? (c.usage ? (c.usage.input_tokens ?? 0) + (c.usage.cached_tokens ?? 0) : 0);
    if (mode && tokens > mode.handoff_tokens) {
      const next = this.handOff(p, c, msg, tokens, mode.handoff_tokens);
      const why = `That chat had ${Math.round(tokens / 1000)}k tokens of history (over ${Math.round(mode.handoff_tokens / 1000)}k), so a fresh worker continues with its last report and your message.`;
      if (next?.chat_id) return { delivered: "fresh_worker", chat_id: next.chat_id, note: `${why} Use the new chat.` };
      if (next) return { delivered: "waiting", note: `${why} It waits: ${next.note ?? "no free slot yet"}` };
    }
    this.submitTo(c, msg);
    return { delivered: "now" };
  }

  /** Replaces a bloated worker by a fresh one of the same kind, starting from the old worker's last report. Goes through startChats, so slots, the daily cap and plan limits apply to it like to any start. */
  private handOff(p: ChiefProfile, old: ChatMeta, msg: string, tokens = 0, limit = 0): { chat_id?: string; note?: string } | null {
    const item = this.store.itemOfChat(old.id);
    const ic = item?.chats.find((x) => x.chat_id === old.id);
    if (!item || !ic) return null;
    const brief = [
      `Goal: ${item.title}`,
      "You are continuing work that another worker started. Its chat grew too large, so you start fresh. The project already has that worker's changes (see `git status` and `git diff --stat`).",
      "",
      `The previous worker's last report (status: ${ic.status ?? "unknown"}):`,
      ic.report ? clip(ic.report, 2000) : "(it left no report)",
      "",
      "What to do now:",
      msg,
    ].join("\n");
    try {
      // The router decides the engine again (a moved chore goes back to its original engine when there is room).
      const r = this.startChats(p, item, [{ project_id: ic.workspace_id, title: old.title.replace(/^(Review|Check): /, ""), brief, engine: ic.rerouted_from ?? ic.engine, role: ic.role, access: ic.access ?? p.worker_access, ...(ic.tier ? { tier: ic.tier } : {}), ...(ic.kind ? { kind: ic.kind } : {}) }], false);
      ic.state = "stopped";
      if (r.chats[0]) ic.handed_to = r.chats[0].chat_id;
      ic.handoff = { at: new Date().toISOString(), tokens, limit, ...(r.chats[0] ? {} : { waiting: true }) };
      item.state = this.derived(item);
      this.store.touch(item);
      this.changed(p.id);
      return r.chats[0] ? { chat_id: r.chats[0].chat_id } : { note: r.note };
    } catch (e) {
      this.d.log(`chief: hand-off failed, continuing in the same chat: ${String(e)}`);
      return null;
    }
  }

  private submitTo(c: ChatMeta, text: string): void {
    const r = this.d.turns.submit(c.workspace_id, c.id, text);
    this.running.set(c.id, r.turn_id);
    const item = this.store.itemOfChat(c.id);
    const ic = item?.chats.find((x) => x.chat_id === c.id);
    if (item && ic) {
      ic.state = "running";
      if (item.state !== "dropped") item.state = this.derived(item);
      this.store.touch(item);
      this.changed(item.chief_id);
    }
  }

  stop(chatId: string): boolean {
    const t = this.running.get(chatId);
    this.sendLater.delete(chatId);
    if (!t) return false;
    this.stoppedByChief.add(t);
    return this.d.turns.interrupt(t).interrupted;
  }

  digest(p: ChiefProfile, chatId: string): Record<string, unknown> {
    const c = this.chatFor(p, chatId);
    const hist = this.d.turns.history(c.id);
    const last = [...hist].reverse().find((m) => m.role === "assistant");
    const goal = hist.find((m) => m.role === "user")?.text ?? "";
    return { chat_id: c.id, title: c.title, running: this.running.has(c.id), goal: clip(goal, 800), latest_answer: clip(last?.text ?? "", 4000), ...(last?.error ? { error: last.error } : {}) };
  }

  search(p: ChiefProfile, query: string): Record<string, unknown>[] {
    const words = query.toLowerCase().split(/\W+/).filter((w) => w.length > 2);
    const scope = new Set(this.projectsOf(p).map((w) => w.id));
    const scored = this.d.chats.list().filter((c) => scope.has(c.workspace_id) && !c.origin && c.chief?.role !== "home").map((c) => {
      const hist = this.d.turns.history(c.id);
      const hay = `${c.title} ${hist.slice(0, 1).map((m) => m.text).join(" ")} ${hist.slice(-1).map((m) => m.text).join(" ")}`.toLowerCase();
      return { c, score: words.reduce((n, w) => n + (hay.includes(w) ? (c.title.toLowerCase().includes(w) ? 3 : 1) : 0), 0) };
    }).filter((x) => x.score > 0).sort((a, b) => b.score - a.score || b.c.updated_at.localeCompare(a.c.updated_at)).slice(0, 5);
    return scored.map(({ c }) => ({ chat_id: c.id, title: c.title, project: this.d.workspaces().find((w) => w.id === c.workspace_id)?.name, yours: c.chief?.id === p.id, updated_at: c.updated_at }));
  }

  remember(scope: string, text: string): void {
    this.d.memory.remember(scope, text);
  }

  // ---- automations ----------------------------------------------------------------------------
  runAutomation(p: ChiefProfile, o: { project_id: string; name: string; inputs: Record<string, string>; title?: string; item?: Item }): Item {
    if (!this.projectsOf(p).some((w) => w.id === o.project_id)) throw new Error("that project is not one of this Manager's projects");
    const a = this.d.automations.list(o.project_id).find((x) => x.name === o.name);
    if (!a) throw new Error(`no automation named ${o.name} in that project`);
    if (!a.ok) throw new Error(`${o.name} has problems in its file; fix it in Automations first`);
    if (this.runningWorkers(p.id) >= p.max_parallel) throw new Error(`all ${p.max_parallel} slots are busy; try again when a chat finishes`);
    const run = this.d.automations.start(o.project_id, a.scope, a.name, o.inputs);
    const item = o.item ?? this.store.addItem({ chief_id: p.id, title: clip(o.title ?? a.description ?? a.name, 100), state: "running", project_ids: [o.project_id] });
    item.automation = { workspace_id: o.project_id, name: a.name, scope: a.scope, run_id: run.id, status: run.status };
    item.state = "running";
    this.store.touch(item);
    this.changed(p.id);
    return item;
  }

  /** Automation runs report here (wired to the runner's broadcast). */
  onRun(run: { id: string; automation: string; status: string; error?: string; steps?: { name: string; status: string; summary?: string }[] }): void {
    const item = this.store.all().find((i) => i.automation?.run_id === run.id);
    if (!item?.automation || item.automation.status === run.status) return;
    item.automation.status = run.status;
    const last = [...(run.steps ?? [])].reverse().find((s) => s.summary)?.summary ?? "";
    if (run.status === "waiting") { item.state = "needs_you"; item.detail = `${run.automation} waits for your approval in Automations`; }
    else if (run.status === "running") { item.state = "running"; delete item.detail; }
    else {
      item.state = run.status === "succeeded" ? "review" : "failed";
      item.detail = run.status === "succeeded" ? clip(last || "finished", 200) : clip(run.error ?? run.status, 200);
      this.wake(item.chief_id, `<automation_update ref="[[${item.ref}]]" item_id="${item.id}" title="${attr(item.title)}" status="${run.status}">${clip(`${run.error ? `Error: ${run.error}. ` : ""}${last}`, 1500)}</automation_update>`);
    }
    this.store.touch(item);
    this.changed(item.chief_id);
  }

  // ---- following turns ------------------------------------------------------------------------
  /** Every turn event in Opscode passes through here. */
  observe(ev: TurnEvent): void {
    const chat = this.d.chats.get(ev.chat_id);
    if (!chat?.chief) return;
    const terminal = ev.type === "completed" || ev.type === "failed" || ev.type === "interrupted";
    if (ev.type === "started") this.running.set(chat.id, ev.turn_id);
    if (terminal && this.running.get(chat.id) === ev.turn_id) this.running.delete(chat.id);

    if (chat.chief.role === "home") {
      if (!terminal) return;
      for (const [tok, v] of this.tokens) if (v.turnId === ev.turn_id) this.tokens.delete(tok);
      // TurnManager frees the chat right after this event; deliver what waited then.
      setImmediate(() => { this.checkAsks(); this.deliver(chat.chief?.id as string); this.changed(chat.chief?.id as string); });
      return;
    }

    const item = this.store.itemOfChat(chat.id);
    const ic = item?.chats.find((c) => c.chat_id === chat.id);
    if (!item || !ic) return;
    const p = this.store.get(item.chief_id);
    if (!p) return;
    if (ev.type === "started") ic.state = "running";
    else if (ev.type === "approval_request") { ic.state = "needs_you"; item.detail = `waits for your approval: ${ev.tool ?? "a tool"}`; }
    else if (ev.type === "approval_resolved") { ic.state = "running"; if (item.detail?.startsWith("waits for your approval")) delete item.detail; }
    else if (ev.type === "completed") {
      const report = readReport(ev.text ?? "");
      ic.state = "idle";
      ic.report = report.text;
      ic.status = report.status ?? "done";
      if (ic.role === "build") {
        item.detail = report.status === "question" ? `asked: ${clip(report.question ?? report.text, 200)}` : report.status === "blocked" ? `blocked: ${clip(report.text, 200)}` : clip(report.text, 240);
      }
      const later = this.sendLater.get(chat.id);
      if (later?.length) {
        // The Chief's queued messages go first; it hears about this answer with the next one.
        this.sendLater.delete(chat.id);
        setImmediate(() => { try { this.deliverTo(p, this.d.chats.get(chat.id) ?? chat, later.join("\n\n")); } catch (e) { this.d.log(`chief: queued message failed: ${String(e)}`); } });
      } else if (p.mode && ic.role === "build" && ic.kind && ic.kind !== "chore" && !ic.nudged && ic.status !== "question" && ic.status !== "blocked" && (!report.check || (FILE_KINDS.includes(ic.kind) && !filesExist(report.check, this.d.workspaces().find((w) => w.id === ic.workspace_id)?.path)))) {
        // Finish check (modes only, once per chat): a build worker said done but nothing proves the work: no Check
        // line, or (for brand, art and asset jobs) none of the files it names exists. One reminder goes back to it.
        ic.nudged = true;
        const nudge = report.check
          ? `[${p.name}] Your Check line names files, but none of them exists in the project: ${clip(report.check, 300)}. Save every asset at the exact path the brief gives (copy it from where your image tool saved it), then report again with the Check line listing the real paths.`
          : `[${p.name}] Your report has no Check line, so nothing proves the work. Run the check that proves the goal itself — the stated requirement, not a proxy like "it compiles" or "the file exists": the repo's own tests near your change, or the reproduce command from the brief. Fix what fails. Then report again with the Check line (what you ran and the result). If nothing here can prove it, say why in the Check line.`;
        setImmediate(() => { try { this.deliverTo(p, this.d.chats.get(chat.id) ?? chat, nudge); } catch (e) { this.d.log(`chief: finish check failed: ${String(e)}`); } });
      } else {
        this.wake(p.id, `<chat_update ref="[[${item.ref}]]" item_id="${item.id}" chat_id="${chat.id}" title="${attr(chat.title)}" role="${ic.role}" engine="${ic.engine}" status="${ic.status}">${clip(report.text, 1500)}</chat_update>`);
      }
    } else if (ev.type === "failed") {
      ic.state = "failed";
      ic.report = clip(ev.error ?? "failed", 400);
      if (ic.role === "build") item.detail = clip(`failed: ${ev.error ?? ""}`, 240);
      this.wake(p.id, `<chat_update ref="[[${item.ref}]]" item_id="${item.id}" chat_id="${chat.id}" title="${attr(chat.title)}" role="${ic.role}" engine="${ic.engine}" status="failed">${clip(ev.error ?? "", 800)}</chat_update>`);
    } else if (ev.type === "interrupted") {
      ic.state = "stopped";
      if (!this.stoppedByChief.delete(ev.turn_id)) this.wake(p.id, `<chat_update ref="[[${item.ref}]]" item_id="${item.id}" chat_id="${chat.id}" title="${attr(chat.title)}" role="${ic.role}" status="stopped by the person"></chat_update>`);
    } else return;
    if (item.state !== "dropped" && item.state !== "done") item.state = this.derived(item);
    this.store.touch(item);
    this.changed(p.id);
    if (terminal) setImmediate(() => this.fillSlots(p.id));
  }

  /** An item's state from its chats (build chats decide; reviewers only add to detail). */
  derived(item: Item): Item["state"] {
    if (item.ask) return "needs_you";
    if (item.chats.some((c) => c.state === "needs_you")) return "needs_you";
    if (item.chats.some((c) => c.state === "running")) return "running";
    if (item.automation && (item.automation.status === "running" || item.automation.status === "waiting")) return item.automation.status === "waiting" ? "needs_you" : "running";
    if (item.pending?.length) return item.state === "proposed" ? "proposed" : "waiting";
    const build = [...item.chats].reverse().find((c) => c.role === "build");
    if (!build) return item.state === "running" ? "review" : item.state;
    if (build.state === "failed") return "failed";
    if (build.state === "stopped") return item.state === "running" ? "queued" : item.state;
    if (build.status === "blocked") return "needs_you";
    if (build.status === "question") return "running";
    if (build.status === "done") return "done";
    return "review";
  }

  // ---- asking the person ----------------------------------------------------------------------
  ask(p: ChiefProfile, o: { question: string; recommended: string; item?: Item; must_wait: boolean; chat_id?: string }): Record<string, unknown> {
    if (!o.item) return { asked: true, note: "No item: nothing goes ahead by itself. End your turn; the answer arrives as the next note." };
    const t = new Date();
    const wait = p.autonomy === 3 ? 0 : p.autonomy === 2 ? p.ask_wait_minutes : -1;
    o.item.ask = {
      question: clip(o.question, 400), recommended: clip(o.recommended, 400), must_wait: o.must_wait, asked_at: t.toISOString(),
      ...(o.chat_id ? { chat_id: o.chat_id } : {}),
      ...(!o.must_wait && wait >= 0 ? { go_ahead_at: new Date(t.getTime() + wait * 60_000).toISOString() } : {}),
    };
    o.item.state = "needs_you";
    this.store.touch(o.item);
    this.changed(p.id);
    return { asked: true, ...(o.item.ask.go_ahead_at ? { goes_ahead_at: o.item.ask.go_ahead_at } : { waits_for_the_person: true }) };
  }

  /** The person answered (or dismissed) a question on the board. */
  answer(itemId: string, text: string): { turn_id?: string; queued: boolean } {
    const item = this.store.item(itemId);
    if (!item?.ask) throw new Error("that item has no open question");
    const q = item.ask.question;
    delete item.ask;
    item.state = this.derived(item);
    this.store.touch(item);
    return this.note(item.chief_id, `About [[${item.ref}]] ("${q}"): ${text}`);
  }

  /** Unanswered questions whose wait is over go ahead with the Chief's recommendation. */
  checkAsks(at = Date.now()): void {
    for (const item of this.store.all()) {
      const a = item.ask;
      if (!a?.go_ahead_at || Date.parse(a.go_ahead_at) > at) continue;
      const mins = Math.max(0, Math.round((Date.parse(a.go_ahead_at) - Date.parse(a.asked_at)) / 60000));
      delete item.ask;
      item.state = this.derived(item);
      this.store.touch(item);
      this.wake(item.chief_id, `<no_answer ref="[[${item.ref}]]" item_id="${item.id}">You asked the person: ${a.question} ${mins ? `They have not answered in ${mins} minute${mins === 1 ? "" : "s"}` : "Your autonomy level lets you decide"}, so go ahead with your recommendation: ${a.recommended}.${a.chat_id ? ` It was chat ${a.chat_id}'s question: send the answer there with chat_send.` : ""} Then tell the person in one line what you went ahead with.</no_answer>`);
      this.changed(item.chief_id);
    }
  }

  // ---- board edits from the person ------------------------------------------------------------
  editItem(itemId: string, patch: { state?: "queued" | "done" | "dropped"; title?: string; pinned?: boolean }): Item {
    const item = this.store.item(itemId);
    if (!item) throw new Error("no such item");
    if (patch.title) item.title = clip(patch.title.trim(), 100);
    if (patch.pinned !== undefined) item.pinned = patch.pinned;
    if (patch.state) {
      if (patch.state === "dropped") for (const c of item.chats) this.stop(c.chat_id);
      item.state = patch.state;
      if (patch.state !== "queued") { delete item.pending; delete item.ask; }
    }
    this.store.touch(item);
    this.changed(item.chief_id);
    return item;
  }

  // ---- pipelines (end to end) -----------------------------------------------------------------
  /** A Conductor starts the end-to-end pipeline for a whole new project. The first stage starts at once. */
  startPipeline(p: ChiefProfile, o: { title: string; goal: string; project_ids: string[]; skip?: StageId[]; modes?: Partial<Record<StageId, ModeId>> }): { pipeline: Pipeline; text: string } {
    if (!p.mode) throw new Error("Pipelines run in a Conductor (a chat with a mode).");
    if (!o.project_ids.length) throw new Error("project_ids needs at least one project.");
    const stages = newStages(o.skip, o.modes);
    if (!stages.some((s) => s.state === "pending")) throw new Error("Every stage is skipped.");
    const t = new Date().toISOString();
    const pl = this.store.addPipeline({ id: newId("pl"), chief_id: p.id, title: clip(o.title.trim(), 80), goal: clip(o.goal, 2000), project_ids: [...new Set(o.project_ids)], folder: `docs/opscode/${slug(o.title)}`, stages, current: -1, state: "running", created_at: t, updated_at: t });
    const text = this.advance(pl, false) ?? "";
    return { pipeline: pl, text };
  }

  /** Moves to the next stage that is not skipped: makes its item and returns the stage text (or wakes the Conductor with it). */
  private advance(pl: Pipeline, wake = true): string | undefined {
    let i = pl.current + 1;
    while (i < pl.stages.length && pl.stages[i].state === "skipped") i++;
    pl.updated_at = new Date().toISOString();
    if (i >= pl.stages.length) {
      pl.current = pl.stages.length;
      pl.state = "done";
      this.store.saveBoard();
      this.changed(pl.chief_id);
      if (wake) this.wake(pl.chief_id, `<pipeline_done pipeline="${pl.id}">"${attr(pl.title)}" went through every stage. Tell the person in one line what was built and where ${pl.folder}/release.md is, if it exists.</pipeline_done>`);
      return undefined;
    }
    pl.current = i;
    pl.state = "running";
    const s = pl.stages[i];
    s.state = "running";
    const item = this.store.addItem({ chief_id: pl.chief_id, title: `${clip(pl.title, 60)} · ${stageTitle(s.id)}`, text: pl.goal, state: "queued", project_ids: [...pl.project_ids], mode: s.mode, pipeline: { id: pl.id, stage: s.id } });
    s.item_id = item.id;
    this.store.saveBoard();
    this.changed(pl.chief_id);
    const text = stageText(pl, s, item.ref);
    if (wake) this.wake(pl.chief_id, text);
    return text;
  }

  /** The Conductor says a stage's work is proven. Refused while its chats still run or wait to start. */
  stageDone(p: ChiefProfile, pipelineId: string, summary: string): Record<string, unknown> {
    const pl = this.store.pipeline(pipelineId);
    if (!pl || pl.chief_id !== p.id) throw new Error(`No pipeline ${pipelineId}.`);
    if (pl.state !== "running") throw new Error(pl.state === "gate" ? "This stage already waits for the person's approval." : `This pipeline is ${pl.state}.`);
    const s = pl.stages[pl.current];
    const item = s.item_id ? this.store.item(s.item_id) : undefined;
    if (!item || item.chats.length === 0) throw new Error(`Stage ${s.id} has no chats yet: start its work on [[${item?.ref ?? "?"}]] first.`);
    if (item.chats.some((c) => c.state === "running" || c.state === "needs_you") || item.pending?.length) throw new Error(`Stage ${s.id} still has chats running or waiting to start; call stage_done when they have reported.`);
    s.summary = clip(summary, 600);
    item.state = "done";
    item.detail = clip(summary, 240);
    this.store.touch(item);
    if (s.gate) {
      s.state = "gate";
      pl.state = "gate";
      pl.updated_at = new Date().toISOString();
      this.store.saveBoard();
      this.changed(p.id);
      this.d.broadcast("chief.pipeline_gate", { chief_id: p.id, pipeline_id: pl.id, stage: s.id, title: pl.title });
      return { stage: s.id, state: "waits_for_the_person", note: "The person approves this stage on the board before the next one starts. Tell them in one line what to look at. You cannot approve it." };
    }
    s.state = "done";
    const next = this.advance(pl, false);
    return { stage: s.id, state: "done", ...(next ? { next_stage: next } : { pipeline: "done" }) };
  }

  private pipelineOf(id: string): Pipeline {
    const pl = this.store.pipeline(id);
    if (!pl) throw new Error("no such pipeline");
    return pl;
  }

  /** Only the person opens a gate (an RPC from the board; the Conductor has no tool for it). */
  approveGate(pipelineId: string): Pipeline {
    const pl = this.pipelineOf(pipelineId);
    if (pl.state !== "gate") throw new Error("this pipeline is not waiting for an approval");
    const s = pl.stages[pl.current];
    s.state = "done";
    this.wake(pl.chief_id, `<pipeline_approved pipeline="${pl.id}" stage="${s.id}">The person approved ${stageTitle(s.id)}.</pipeline_approved>`);
    this.advance(pl);
    return pl;
  }

  /** The person sends a stage back with what to change: the stage runs again on the same item. */
  rejectGate(pipelineId: string, text: string): Pipeline {
    const pl = this.pipelineOf(pipelineId);
    if (pl.state !== "gate") throw new Error("this pipeline is not waiting for an approval");
    const s = pl.stages[pl.current];
    s.state = "running";
    pl.state = "running";
    pl.updated_at = new Date().toISOString();
    const item = s.item_id ? this.store.item(s.item_id) : undefined;
    if (item) { item.state = "queued"; item.detail = clip(`sent back: ${text}`, 240); this.store.touch(item); }
    this.store.saveBoard();
    this.changed(pl.chief_id);
    this.note(pl.chief_id, `About [[${item?.ref ?? "?"}]] (${stageTitle(s.id)} of "${pl.title}"), not approved yet: ${text}\n<pipeline_stage pipeline="${pl.id}" stage="${s.id}" item="[[${item?.ref ?? "?"}]]" sent_back="true">Change the stage's work as the person says (chat_send to its chat, or a new chat on the same item), then call stage_done again.</pipeline_stage>`);
    return pl;
  }

  /** The person changes a stage's mode (one that has not finished). */
  setStageMode(pipelineId: string, stage: StageId, mode: ModeId): Pipeline {
    const pl = this.pipelineOf(pipelineId);
    const s = pl.stages.find((x) => x.id === stage);
    if (!s) throw new Error("no such stage");
    if (s.state === "done" || s.state === "skipped") throw new Error("that stage is finished");
    s.mode = mode;
    const item = s.item_id ? this.store.item(s.item_id) : undefined;
    if (item) { item.mode = mode; this.store.touch(item); }
    pl.updated_at = new Date().toISOString();
    this.store.saveBoard();
    this.changed(pl.chief_id);
    return pl;
  }

  /** Images a pipeline produced, for the gallery at its gate: only files under its own folder in the first project, newest first, capped. */
  gallery(pipelineId: string): { folder: string; images: { path: string; data_url: string; bytes: number }[]; more: number } {
    const pl = this.pipelineOf(pipelineId);
    const root = this.d.workspaces().find((w) => w.id === pl.project_ids[0])?.path;
    if (!root) return { folder: pl.folder, images: [], more: 0 };
    let base: string;
    try { base = realpathSync(join(root, pl.folder)); } catch { return { folder: pl.folder, images: [], more: 0 }; }
    if (!base.startsWith(realpathSync(root) + "/")) return { folder: pl.folder, images: [], more: 0 };
    const TYPES: Record<string, string> = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif", svg: "image/svg+xml" };
    const found: { path: string; abs: string; mtime: number; bytes: number }[] = [];
    const walk = (dir: string, depth: number): void => {
      if (depth > 4 || found.length > 400) return;
      let names: string[] = [];
      try { names = readdirSync(dir); } catch { return; }
      for (const n of names) {
        if (n.startsWith(".")) continue;
        const abs = join(dir, n);
        let st;
        try { st = lstatSync(abs); } catch { continue; }
        if (st.isSymbolicLink()) continue;
        if (st.isDirectory()) walk(abs, depth + 1);
        else if (TYPES[n.split(".").pop()?.toLowerCase() ?? ""] && st.size <= 4 * 1024 * 1024) found.push({ path: abs.slice(root.length + 1), abs, mtime: st.mtimeMs, bytes: st.size });
      }
    };
    walk(base, 0);
    found.sort((a, b) => b.mtime - a.mtime);
    const images = found.slice(0, 24).map((f) => ({ path: f.path, bytes: f.bytes, data_url: `data:${TYPES[f.path.split(".").pop()!.toLowerCase()]};base64,${readFileSync(f.abs).toString("base64")}` }));
    return { folder: pl.folder, images, more: Math.max(0, found.length - images.length) };
  }

  /** One image a Chief's worker made, for the live card: only inside the worker's project or Codex's own generated_images folder. */
  workerImage(chatId: string, path: string): { path: string; data_url: string; bytes: number } {
    const c = this.d.chats.get(chatId);
    if (!c?.chief || c.chief.role === "home") throw new Error("not a worker chat");
    const root = this.d.workspaces().find((w) => w.id === c.workspace_id)?.path;
    const TYPES: Record<string, string> = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif" };
    const type = TYPES[path.split(".").pop()?.toLowerCase() ?? ""];
    if (!type) throw new Error("not an image");
    let real: string;
    try { real = realpathSync(path.startsWith("/") || !root ? path : join(root, path)); } catch { throw new Error("no such image"); }
    const allowed = [root ? realpathSync(root) : null, (() => { try { return realpathSync(join(homedir(), ".codex", "generated_images")); } catch { return null; } })()].filter((x): x is string => !!x);
    if (!allowed.some((a) => real.startsWith(a + "/"))) throw new Error("that image is outside the worker's project");
    const st = lstatSync(real);
    if (!st.isFile() || st.size > 8 * 1024 * 1024) throw new Error("too large to preview");
    return { path: real, bytes: st.size, data_url: `data:${type};base64,${readFileSync(real).toString("base64")}` };
  }

  stopPipeline(pipelineId: string): Pipeline {
    const pl = this.pipelineOf(pipelineId);
    if (pl.state === "done" || pl.state === "stopped") return pl;
    pl.state = "stopped";
    pl.updated_at = new Date().toISOString();
    const s = pl.stages[pl.current];
    const item = s?.item_id ? this.store.item(s.item_id) : undefined;
    if (item && item.state !== "done") this.editItem(item.id, { state: "dropped" });
    this.store.saveBoard();
    this.changed(pl.chief_id);
    return pl;
  }

  // ---- lifecycle ------------------------------------------------------------------------------
  startTicker(ms = 20_000): void {
    this.kickEvery = Math.min(60_000, ms * 3);
    // Stages cut off by a restart: their Conductors look at what is there and continue.
    for (const id of this.resumeStages) {
      const pl = this.store.pipeline(id);
      const s = pl?.stages[pl.current];
      const item = s?.item_id ? this.store.item(s.item_id) : undefined;
      if (pl && s && item && pl.state === "running") this.wake(pl.chief_id, stageText(pl, s, item.ref, true));
    }
    this.resumeStages.clear();
    this.timer = setInterval(() => { this.checkAsks(); for (const p of this.store.list()) this.fillSlots(p.id); }, ms);
    this.timer.unref?.();
  }
  stopTicker(): void { if (this.timer) clearInterval(this.timer); this.timer = null; }
}
