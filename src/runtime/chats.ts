// Chats: several conversations per project, each with its own permission mode.
// Metadata lives in chats.json; each transcript in chats/<id>.json (0600).
// A reply that was streaming when the runtime stopped loads as "interrupted".

import { randomUUID } from "node:crypto";
import { rmSync } from "node:fs";
import { join } from "node:path";
import { LIMITS, PERMISSION_MODES, isAgentEngine, type AgentEngineId, type ChatMessage, type ChatMeta, type PermissionMode } from "../shared/protocol";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { isRecord } from "./rpc";

const MAX_CHATS = 500;
const TITLE_MAX = 80;

export class ChatStore {
  private readonly metaFile: string;
  private readonly dir: string;
  private chats: ChatMeta[];
  private readonly messages = new Map<string, ChatMessage[]>();
  private readonly dirty = new Set<string>();
  private flushing = false;

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.dir = join(stateDir, "chats");
    ensurePrivateDir(this.dir);
    this.metaFile = join(stateDir, "chats.json");
    this.chats = this.loadMeta();
  }

  private loadMeta(): ChatMeta[] {
    const raw = readJson(this.metaFile);
    if (!Array.isArray(raw)) return [];
    return raw.filter(
      (c): c is ChatMeta =>
        isRecord(c) && typeof c.id === "string" && /^[0-9a-f-]{36}$/.test(c.id) && typeof c.workspace_id === "string" && typeof c.title === "string" &&
        (PERMISSION_MODES as readonly unknown[]).includes(c.mode) && typeof c.created_at === "string" && typeof c.updated_at === "string",
    );
  }
  private saveMeta(): void {
    writeJsonAtomic(this.metaFile, this.chats);
  }

  list(workspaceId?: string): ChatMeta[] {
    return this.chats
      .filter((c) => !c.voice && (workspaceId === undefined || c.workspace_id === workspaceId))
      .map((c) => ({ ...c }))
      .sort((a, b) => b.updated_at.localeCompare(a.updated_at));
  }

  get(id: string): ChatMeta | undefined {
    return this.chats.find((c) => c.id === id);
  }

  /** The project's most recently active chat. */
  latest(workspaceId: string): ChatMeta | undefined {
    return this.list(workspaceId)[0];
  }

  create(workspaceId: string, mode: PermissionMode): ChatMeta {
    if (this.chats.length >= MAX_CHATS) throw new Error(`at most ${MAX_CHATS} chats; delete some first`);
    const now = new Date().toISOString();
    const chat: ChatMeta = { id: randomUUID(), workspace_id: workspaceId, title: "", mode, created_at: now, updated_at: now };
    this.chats.push(chat);
    this.saveMeta();
    return { ...chat };
  }

  /** Marks a chat as a voice agent's hidden chat (not listed anywhere). */
  setVoice(id: string, voice: { session: string }): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.voice = voice;
    c.title = "Voice agent";
    this.saveMeta();
    return { ...c };
  }

  /** Ids of every voice agent chat (leftovers of a crash are swept at start). */
  voiceChatIds(): string[] { return this.chats.filter((c) => c.voice).map((c) => c.id); }

  rename(id: string, title: string): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.title = title.trim().slice(0, TITLE_MAX);
    this.saveMeta();
    return { ...c };
  }

  setMode(id: string, mode: PermissionMode): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.mode = mode;
    this.saveMeta();
    return { ...c };
  }

  /** Picks the engine/model/effort. A different engine starts its own context fresh. */
  setEngine(id: string, o: { engine: "api" | AgentEngineId; model?: string; effort?: string }): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    const old = c.engine ?? "api";
    if (old !== o.engine) {
      // Keep the old engine's session for when the chat comes back to it; resume the new engine's own, if any.
      const sessions = { ...(c.engine_sessions ?? {}) };
      if (c.engine_session && isAgentEngine(old)) sessions[old] = c.engine_session;
      const back = isAgentEngine(o.engine) ? sessions[o.engine] : undefined;
      if (back) c.engine_session = back; else delete c.engine_session;
      if (Object.keys(sessions).length) c.engine_sessions = sessions;
      delete c.usage;
    }
    c.engine = o.engine;
    if (o.model) c.model = o.model; else delete c.model;
    if (o.effort) c.effort = o.effort; else delete c.effort;
    this.saveMeta();
    return { ...c };
  }

  /** Pins the account an engine runs on in this chat. */
  pinAccount(id: string, engine: AgentEngineId, account: string): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.accounts = { ...(c.accounts ?? {}), [engine]: account };
    this.saveMeta();
    return { ...c };
  }

  /** Moves a chat to another account on its engine. Its old session lives in the old account's folder, so the new one starts fresh. */
  moveAccount(id: string, engine: AgentEngineId, account: string): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    if (c.accounts?.[engine] === account) return { ...c };
    c.accounts = { ...(c.accounts ?? {}), [engine]: account };
    if (c.engine_sessions?.[engine]) {
      const sessions = { ...c.engine_sessions };
      delete sessions[engine];
      if (Object.keys(sessions).length) c.engine_sessions = sessions; else delete c.engine_sessions;
    }
    if (c.engine === engine) delete c.engine_session;
    this.saveMeta();
    return { ...c };
  }

  /** An account was removed: chats pinned to it let go (and forget the session that lived there). Returns the chats that changed. */
  unpinAccount(engine: AgentEngineId, account: string): string[] {
    const hit: string[] = [];
    for (const c of this.chats) {
      if (c.accounts?.[engine] !== account) continue;
      const accounts = { ...c.accounts };
      delete accounts[engine];
      if (Object.keys(accounts).length) c.accounts = accounts; else delete c.accounts;
      if (c.engine_sessions?.[engine]) { const s = { ...c.engine_sessions }; delete s[engine]; if (Object.keys(s).length) c.engine_sessions = s; else delete c.engine_sessions; }
      if (c.engine === engine) delete c.engine_session;
      hit.push(c.id);
    }
    if (hit.length) this.saveMeta();
    return hit;
  }

  setOrigin(id: string, origin: { automation: string; run_id: string; step: string }): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.origin = origin;
    c.title = `${origin.automation} · ${origin.step}`.slice(0, 60);
    this.saveMeta();
    return { ...c };
  }

  /** Marks a chat as a Chief's own chat or one of its workers. */
  setChief(id: string, chief: NonNullable<ChatMeta["chief"]>, title?: string): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.chief = chief;
    if (title) c.title = title.replace(/\s+/g, " ").trim().slice(0, TITLE_MAX);
    this.saveMeta();
    return { ...c };
  }

  /** A worker chat that outlives its Conductor becomes an ordinary chat. */
  clearChief(id: string): void {
    const c = this.get(id);
    if (!c?.chief) return;
    delete c.chief;
    this.saveMeta();
  }

  /** What an engine reports after a turn: its session id and token usage. */
  setEngineState(id: string, patch: { engine_session?: string; usage?: import("../shared/protocol").ChatUsage; connectors?: import("../shared/protocol").ChatConnector[] }): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    if (patch.engine_session) {
      c.engine_session = patch.engine_session;
      if (isAgentEngine(c.engine)) c.engine_sessions = { ...(c.engine_sessions ?? {}), [c.engine]: patch.engine_session };
    }
    if (patch.usage) c.usage = patch.usage;
    if (patch.connectors) c.connectors = patch.connectors;
    this.saveMeta();
    return { ...c };
  }

  /** Bumps recency; names an unnamed chat after its first message. */
  touch(id: string, firstText?: string): ChatMeta | undefined {
    const c = this.get(id);
    if (!c) return undefined;
    c.updated_at = new Date().toISOString();
    if (!c.title && firstText) c.title = firstText.replace(/\s+/g, " ").trim().slice(0, 50);
    this.saveMeta();
    return { ...c };
  }

  remove(id: string): boolean {
    const i = this.chats.findIndex((c) => c.id === id);
    if (i < 0) return false;
    this.chats.splice(i, 1);
    this.messages.delete(id);
    this.dirty.delete(id);
    this.saveMeta();
    try {
      rmSync(join(this.dir, `${id}.json`), { force: true });
    } catch { /* ignore */ }
    return true;
  }

  removeWorkspace(workspaceId: string): string[] {
    const ids = this.chats.filter((c) => c.workspace_id === workspaceId).map((c) => c.id);
    for (const id of ids) this.remove(id);
    return ids;
  }

  /** The live (mutable) transcript; loaded from disk on first use. */
  transcript(id: string): ChatMessage[] {
    let m = this.messages.get(id);
    if (!m) {
      const raw = readJson(join(this.dir, `${id}.json`));
      m = [];
      if (Array.isArray(raw)) {
        for (const x of raw) {
          if (isRecord(x) && (x.role === "user" || x.role === "assistant") && typeof x.text === "string" && typeof x.turn_id === "string") {
            const msg = x as unknown as ChatMessage;
            if (msg.status === "streaming") msg.status = "interrupted";
            m.push(msg);
          }
        }
      }
      this.messages.set(id, m);
    }
    return m;
  }

  /** Writes the transcript soon (coalesced). */
  save(id: string): void {
    this.dirty.add(id);
    if (this.flushing) return;
    this.flushing = true;
    setTimeout(() => this.flush(), 150).unref();
  }

  flush(): void {
    this.flushing = false;
    for (const id of this.dirty) {
      const m = this.messages.get(id);
      if (m && this.get(id)) {
        const trimmed = m.length > LIMITS.TURN_HISTORY_MAX_MESSAGES ? m.slice(-LIMITS.TURN_HISTORY_MAX_MESSAGES) : m;
        writeJsonAtomic(join(this.dir, `${id}.json`), trimmed);
      }
    }
    this.dirty.clear();
  }
}
