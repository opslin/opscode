// Chiefs and their boards: chiefs.json (profiles) and chief-board.json (items),
// both in the state dir, 0600.

import { randomBytes } from "node:crypto";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";
import type { ModeId } from "./modes";
import type { Pipeline, StageId } from "./pipeline";
import type { JobKind } from "./skills";

export type BrainEngine = "claude-code" | "api";
export type WorkerEngine = "claude-code" | "codex" | "api";
export type Tier = "fast" | "base" | "frontier" | "opus";
export type Access = "read" | "edit" | "full";

/** Opscode's own pixel mascots (assets/brand/mascots); a Chief wears one. */
export const MASCOTS = ["engineer", "hacker", "wizard", "robot", "fox", "cat", "penguin", "octopus", "raccoon", "frog", "axolotl", "crab", "panda", "capybara", "duck", "hedgehog"] as const;

export interface ChiefProfile {
  id: string;
  name: string;
  /** A Conductor's label in the sidebar: what the person first asked for. Empty until they write to it; `name` stays the mode's name. */
  title?: string;
  /** Mascot id from MASCOTS. */
  avatar?: string;
  /** Set on a project Conductor: GODMODE, WARLORD or SHINOBI (see modes.ts). Absent on a plain Chief. */
  mode?: ModeId;
  /** What the Chief itself runs on, and its model (claude: haiku/sonnet/opus or a full id). */
  brain: { engine: BrainEngine; model?: string; effort?: string };
  /** Standing instructions, with an optional "## Crew rules" part. */
  soul: string;
  autonomy: 1 | 2 | 3;
  updates: "results" | "milestones" | "everything";
  /** The most a worker chat may do: read-only, edit files, or full access. */
  worker_access: Access;
  /** Engine for workers when the Chief names none. */
  worker_engine: WorkerEngine;
  /** The account each engine's chats run on for this Chief (its own chat and its workers). Absent = the one new chats use. */
  accounts?: { "claude-code"?: string; codex?: string };
  /** Projects it covers; empty = all. */
  project_ids: string[];
  /** Worker chats running at once; more wait for a slot. */
  max_parallel: number;
  /** Worker chats it may start in one day. */
  daily_chats: number;
  /** Minutes before an unanswered question goes ahead with the Chief's recommendation (level 2). */
  ask_wait_minutes: number;
  /** Its own chat. */
  chat_id: string;
  created_at: string;
  updated_at: string;
}

export interface StartSpec {
  project_id: string;
  title: string;
  brief: string;
  engine: WorkerEngine;
  tier?: Tier;
  role: "build" | "review" | "check";
  access: Access;
  /** The job's shape: fix, feature or chore. Picks the short skill the worker gets. */
  kind?: JobKind;
  /** Reference images for the worker, as paths inside the project (a logo, earlier assets). Codex gets them attached. */
  images?: string[];
  /** The person asked for this engine: the limits router never moves it. */
  pin_engine?: true;
  /** Set by the limits router when it moved this spec off the engine the Conductor picked. */
  rerouted_from?: WorkerEngine;
}

export interface ItemChat {
  chat_id: string;
  workspace_id: string;
  role: "build" | "review" | "check";
  engine: WorkerEngine;
  state: "running" | "idle" | "needs_you" | "failed" | "stopped";
  report?: string;
  status?: string;
  started_at: string;
  /** How it was started, so a hand-off can start its replacement the same way. */
  tier?: Tier;
  access?: Access;
  kind?: JobKind;
  /** Set when the limits router moved this chat off the engine the Conductor picked. */
  rerouted_from?: WorkerEngine;
  /** Set when a fresh worker took over because this chat grew too large. */
  handed_to?: string;
  /** When and why it was handed off: the chat's size and the mode's limit; waiting when the fresh worker could not start yet. */
  handoff?: { at: string; tokens: number; limit: number; waiting?: true };
  /** Set once the finish-check reminder was sent, so it is sent at most once. */
  nudged?: true;
}

export interface Item {
  id: string;
  /** Short number shown as #n and written [[n]] by the Chief. */
  ref: number;
  chief_id: string;
  title: string;
  text?: string;
  state: "queued" | "proposed" | "waiting" | "running" | "needs_you" | "review" | "done" | "failed" | "dropped";
  project_ids: string[];
  chats: ItemChat[];
  detail?: string;
  /** Chats to start when the person says so (proposed) or a slot frees (waiting). */
  pending?: StartSpec[];
  /** Why waiting pending chats may not start yet, besides slots: a plan limit (until its reset) or a start that failed (retried a few times). Persisted, so a restart keeps it. */
  parked?: { reason: "limits" | "error"; engine?: WorkerEngine; until?: string; tries?: number };
  ask?: { question: string; recommended: string; must_wait: boolean; chat_id?: string; asked_at: string; go_ahead_at?: string };
  automation?: { workspace_id: string; name: string; scope: "project" | "me"; run_id: string; status: string };
  guess?: boolean;
  pinned?: boolean;
  /** Set on a pipeline stage's item: its workers run on this mode's models instead of the Conductor's. */
  mode?: ModeId;
  pipeline?: { id: string; stage: StageId };
  created_at: string;
  updated_at: string;
}

export const DEFAULT_SOUL = `# Soul

## Standing instructions
- Reuse components from our existing apps before writing new ones.
- Keep the person's words exactly as they wrote them in every brief.

## Crew rules
- Claude Code (claude-code) does logic: data, APIs, state, anything hard.
- Codex (codex) does UI screens, assets and small jobs.
- Reviews and plans use Claude Code at tier frontier; everything else tier base or fast.`;

/** A Conductor's soul: only the person's standing instructions. Its crew rules come from its mode. */
export const MODE_SOUL = `# Soul

## Standing instructions
- Reuse components from our existing apps before writing new ones.
- Keep the person's words exactly as they wrote them in every brief.`;

const now = (): string => new Date().toISOString();
export const newId = (prefix: string): string => `${prefix}_${randomBytes(5).toString("hex")}`;

export class ChiefStore {
  private readonly profilesFile: string;
  private readonly boardFile: string;
  private profiles: ChiefProfile[];
  private items: Item[];
  private pipes: Pipeline[];
  private nextRef: number;

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.profilesFile = join(stateDir, "chiefs.json");
    this.boardFile = join(stateDir, "chief-board.json");
    const p = readJson(this.profilesFile);
    this.profiles = Array.isArray(p) ? (p.filter((x) => isRecord(x) && typeof x.id === "string" && typeof x.chat_id === "string") as unknown as ChiefProfile[]) : [];
    const b = readJson(this.boardFile);
    const raw = isRecord(b) && Array.isArray(b.items) ? b.items : [];
    this.items = raw.filter((x) => isRecord(x) && typeof x.id === "string" && typeof x.chief_id === "string") as unknown as Item[];
    this.pipes = isRecord(b) && Array.isArray(b.pipelines) ? (b.pipelines.filter((x) => isRecord(x) && typeof x.id === "string" && Array.isArray(x.stages)) as unknown as Pipeline[]) : [];
    this.nextRef = isRecord(b) && typeof b.next_ref === "number" ? b.next_ref : this.items.reduce((n, i) => Math.max(n, i.ref + 1), 1);
  }

  private saveProfiles(): void { writeJsonAtomic(this.profilesFile, this.profiles); }
  saveBoard(): void { writeJsonAtomic(this.boardFile, { next_ref: this.nextRef, items: this.items, pipelines: this.pipes }); }

  list(): ChiefProfile[] { return this.profiles.map((p) => ({ ...p })); }
  get(id: string): ChiefProfile | undefined { return this.profiles.find((p) => p.id === id); }
  byChat(chatId: string): ChiefProfile | undefined { return this.profiles.find((p) => p.chat_id === chatId); }

  add(p: ChiefProfile): ChiefProfile {
    if (p.mode) { if (this.profiles.filter((x) => x.mode).length >= 40) throw new Error("at most 40 Conductors"); }
    else if (this.profiles.filter((x) => !x.mode).length >= 8) throw new Error("at most 8 Managers");
    this.profiles.push(p);
    this.saveProfiles();
    return { ...p };
  }
  update(id: string, patch: Partial<ChiefProfile>): ChiefProfile {
    const p = this.get(id);
    if (!p) throw new Error("no such Manager");
    Object.assign(p, patch, { id: p.id, chat_id: p.chat_id, created_at: p.created_at, updated_at: now() });
    this.saveProfiles();
    return { ...p };
  }
  remove(id: string): boolean {
    const i = this.profiles.findIndex((p) => p.id === id);
    if (i < 0) return false;
    this.profiles.splice(i, 1);
    this.items = this.items.filter((x) => x.chief_id !== id);
    this.pipes = this.pipes.filter((x) => x.chief_id !== id);
    this.saveProfiles();
    this.saveBoard();
    return true;
  }

  // ---- pipelines ----
  pipelines(chiefId?: string): Pipeline[] { return chiefId ? this.pipes.filter((x) => x.chief_id === chiefId) : this.pipes; }
  pipeline(id: string): Pipeline | undefined { return this.pipes.find((x) => x.id === id); }
  addPipeline(pl: Pipeline): Pipeline {
    if (this.pipes.filter((x) => x.chief_id === pl.chief_id && (x.state === "running" || x.state === "gate")).length >= 5) throw new Error("at most 5 live pipelines per Conductor; finish or stop one first");
    this.pipes.push(pl);
    this.saveBoard();
    return pl;
  }

  // ---- board ----
  itemsOf(chiefId: string): Item[] { return this.items.filter((i) => i.chief_id === chiefId); }
  item(id: string): Item | undefined { return this.items.find((i) => i.id === id); }
  byRef(chiefId: string, ref: number): Item | undefined { return this.items.find((i) => i.chief_id === chiefId && i.ref === ref); }
  itemOfChat(chatId: string): Item | undefined { return this.items.find((i) => i.chats.some((c) => c.chat_id === chatId)); }
  all(): Item[] { return this.items; }

  addItem(o: Omit<Item, "id" | "ref" | "created_at" | "updated_at" | "chats"> & { chats?: ItemChat[] }): Item {
    const live = this.items.filter((i) => i.chief_id === o.chief_id);
    // Keep the board bounded: forget the oldest finished items first.
    if (live.length >= 300) {
      const old = live.filter((i) => i.state === "done" || i.state === "dropped" || i.state === "failed").sort((a, b) => a.updated_at.localeCompare(b.updated_at))[0];
      if (!old) throw new Error("the board is full; drop some items first");
      this.items = this.items.filter((i) => i !== old);
    }
    const t = now();
    const item: Item = { ...o, chats: o.chats ?? [], id: newId("it"), ref: this.nextRef++, created_at: t, updated_at: t };
    this.items.push(item);
    this.saveBoard();
    return item;
  }
  touch(item: Item): void {
    item.updated_at = now();
    this.saveBoard();
  }
}
