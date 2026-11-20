// What the notch shows, worked out from the runtime's own events (turn.event, chat.changed). Pure: no Electron, no
// timers, so scripts/test-phase56.mjs drives it directly. Main feeds it events and sends snapshot() to the notch page.

import type { ChatMeta, TurnEvent, Workspace } from "../shared/protocol";

export type NotchStatus = "working" | "needs" | "done" | "failed" | "idle";
export type NotchPose = "sleeping" | "working" | "needs" | "done" | "error";
export type NotchPulseKind = "needs" | "done" | "failed";

export interface NotchApproval {
  turn_id: string;
  call_id: string;
  tool: string;
  summary: string;
  detail?: string;
  choices?: { id: string; label: string; hint?: string }[];
  branch?: boolean;
  at: number;
}

export interface NotchSession {
  chat_id: string;
  workspace_id: string;
  title: string;
  project: string;
  engine: string;
  model?: string;
  status: NotchStatus;
  /** One line: what it does now (a tool) or the end of what it said. */
  line: string;
  /** The end of what it said in its current or last reply (the workers view shows it). */
  tail?: string;
  turn_id?: string;
  approvals: NotchApproval[];
  started_at?: number;
  ended_at?: number;
  /** Finished or failed while the person was not looking at it. */
  unseen: boolean;
  updated: number;
}

export interface NotchPulse {
  seq: number;
  kind: NotchPulseKind;
  chat_id: string;
}

export interface NotchFeed {
  sessions: NotchSession[];
  counts: { working: number; needs: number; unseen: number };
  pose: NotchPose;
  /** The latest thing that happened (the page plays its sound and glow once per seq). */
  pulse: NotchPulse | null;
  workspaces: { id: string; name: string }[];
  /** The project a quick message goes to when none is picked: the one worked in last. */
  workspace_id: string | null;
}

const MAX_SESSIONS = 8;
const RECENT_MS = 6 * 3600_000;
const LINE_MAX = 160;

/** One clean line: no markdown marks, no line breaks, at most LINE_MAX characters (the end kept for streaming text). */
export function oneLine(text: string, keep: "start" | "end" = "start"): string {
  const s = text.replace(/```[\s\S]*?```/g, " ").replace(/[`*_#>]+/g, "").replace(/\s+/g, " ").trim();
  if (s.length <= LINE_MAX) return s;
  return keep === "end" ? `…${s.slice(-(LINE_MAX - 1)).trimStart()}` : `${s.slice(0, LINE_MAX - 1).trimEnd()}…`;
}

export class NotchModel {
  private readonly sessions = new Map<string, NotchSession>();
  private readonly chats = new Map<string, ChatMeta>();
  private readonly projects = new Map<string, string>();
  private tails = new Map<string, string>();
  private pulse: NotchPulse | null = null;
  private seq = 0;
  /** The chat on screen in a focused main window, or null. */
  private viewing: string | null = null;

  setWorkspaces(list: Workspace[]): void {
    this.projects.clear();
    for (const w of list) this.projects.set(w.id, w.name);
    for (const s of this.sessions.values()) s.project = this.projects.get(s.workspace_id) ?? s.project;
  }

  /** The chat list changed (titles, new or deleted chats); `running` says which chats have a turn going. */
  setChats(list: ChatMeta[], running?: string[], now = Date.now()): void {
    this.chats.clear();
    for (const c of list) if (!c.voice) this.chats.set(c.id, c);
    for (const id of [...this.sessions.keys()]) if (!this.chats.has(id)) this.sessions.delete(id);
    for (const c of this.chats.values()) {
      const s = this.sessions.get(c.id);
      if (s) { s.title = c.title || "New chat"; s.engine = c.engine ?? "api"; s.model = c.model; continue; }
      const updated = Date.parse(c.updated_at) || 0;
      const isRunning = running?.includes(c.id) ?? false;
      if (!isRunning && now - updated > RECENT_MS) continue;
      this.sessions.set(c.id, this.blank(c, isRunning ? "working" : "idle", updated));
    }
    if (running) {
      const active = new Set(running);
      for (const [id, s] of this.sessions) {
        if (active.has(id)) {
          if (s.status === "idle") s.status = "working";
        } else if (s.status === "working" || s.status === "needs") {
          s.status = "idle";
          s.turn_id = undefined;
          s.approvals = [];
          s.line = "";
        }
      }
    }
  }

  /** A main-window chat is on screen and the window has focus (null when it lost focus): that chat counts as seen. */
  setViewing(chatId: string | null): boolean {
    this.viewing = chatId;
    return chatId ? this.seen(chatId) : false;
  }

  seen(chatId: string): boolean {
    const s = this.sessions.get(chatId);
    if (!s || !s.unseen) return false;
    s.unseen = false;
    if (s.status === "done" || s.status === "failed") s.status = "idle";
    return true;
  }

  /** Clears every finished card (the person dismissed them all). */
  seenAll(): void {
    for (const s of this.sessions.values()) if (s.unseen) this.seen(s.chat_id);
  }

  /** Applies one turn event; returns true when the feed changed. */
  event(ev: TurnEvent, now = Date.now()): boolean {
    const meta = this.chats.get(ev.chat_id);
    if (!meta && !this.sessions.has(ev.chat_id)) {
      // A chat the list has not reached yet (its first message): show it with a placeholder name until it does.
      if (ev.type !== "started") return false;
    }
    let s = this.sessions.get(ev.chat_id);
    if (!s) {
      s = this.blank(meta ?? ({ id: ev.chat_id, workspace_id: ev.workspace_id, title: "New chat" } as ChatMeta), "idle", now);
      this.sessions.set(ev.chat_id, s);
    }
    s.updated = now;
    switch (ev.type) {
      case "started":
        s.status = "working";
        s.turn_id = ev.turn_id;
        s.started_at = now;
        s.ended_at = undefined;
        s.unseen = false;
        s.approvals = [];
        s.line = "Thinking…";
        this.tails.set(ev.chat_id, "");
        if (ev.engine) s.engine = ev.engine;
        return true;
      case "delta": {
        const tail = ((this.tails.get(ev.chat_id) ?? "") + (ev.text ?? "")).slice(-600);
        this.tails.set(ev.chat_id, tail);
        const line = oneLine(tail, "end");
        s.tail = tail.slice(-500);
        if (!line || line === s.line) return false;
        s.line = line;
        return true;
      }
      case "tool_start":
        s.line = oneLine(ev.summary ? `${toolVerb(ev.tool)} ${ev.summary}` : toolVerb(ev.tool));
        this.tails.set(ev.chat_id, "");
        return true;
      case "tool_end":
        return false;
      case "approval_request": {
        if (!ev.call_id) return false;
        s.approvals = s.approvals.filter((a) => a.call_id !== ev.call_id);
        s.approvals.push({
          turn_id: ev.turn_id, call_id: ev.call_id, tool: ev.tool ?? "tool", summary: oneLine(ev.summary ?? ""),
          ...(ev.detail ? { detail: ev.detail.slice(0, 1200) } : {}),
          ...(ev.choices?.length ? { choices: ev.choices.slice(0, 4) } : {}),
          ...(ev.branch ? { branch: true } : {}),
          at: now,
        });
        s.status = "needs";
        this.bump("needs", ev.chat_id);
        return true;
      }
      case "approval_resolved":
        s.approvals = s.approvals.filter((a) => a.call_id !== ev.call_id);
        if (s.status === "needs" && s.approvals.length === 0) s.status = "working";
        return true;
      // A question card waits for the person (answered in the chat window): the notch shows the chat as needing you.
      case "question":
        s.status = "needs";
        this.bump("needs", ev.chat_id);
        return true;
      case "question_answered":
        if (s.status === "needs" && s.approvals.length === 0) s.status = "working";
        return true;
      case "completed":
      case "failed":
      case "interrupted": {
        s.approvals = [];
        s.ended_at = now;
        s.turn_id = undefined;
        if (ev.type === "interrupted") { s.status = "idle"; s.line = "Stopped"; return true; }
        const failed = ev.type === "failed";
        const tail = this.tails.get(ev.chat_id) ?? "";
        s.line = failed ? oneLine(ev.error ?? "Something went wrong") : oneLine(tail || ev.text || "Done", "end") || "Done";
        if (this.viewing === ev.chat_id) { s.status = "idle"; s.unseen = false; return true; }
        s.status = failed ? "failed" : "done";
        s.unseen = true;
        this.bump(failed ? "failed" : "done", ev.chat_id);
        return true;
      }
      default:
        return false;
    }
  }

  snapshot(): NotchFeed {
    const rank: Record<NotchStatus, number> = { needs: 0, working: 1, failed: 2, done: 3, idle: 4 };
    const all = [...this.sessions.values()].filter((s) => this.chats.has(s.chat_id) || s.status !== "idle");
    all.sort((a, b) => rank[a.status] - rank[b.status] || b.updated - a.updated);
    const counts = {
      working: all.filter((s) => s.status === "working").length,
      needs: all.filter((s) => s.status === "needs").length,
      unseen: all.filter((s) => s.unseen).length,
    };
    const pose: NotchPose = counts.needs ? "needs"
      : this.pulse?.kind === "failed" && all.some((s) => s.status === "failed" && s.unseen) && !counts.working ? "error"
      : counts.working ? "working"
      : counts.unseen ? "done"
      : "sleeping";
    const last = [...this.chats.values()].sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at))[0];
    return {
      sessions: all.slice(0, MAX_SESSIONS).map((s) => ({ ...s, approvals: s.approvals.map((a) => ({ ...a })) })),
      counts,
      pose,
      pulse: this.pulse,
      workspaces: [...this.projects].map(([id, name]) => ({ id, name })),
      workspace_id: last?.workspace_id && this.projects.has(last.workspace_id) ? last.workspace_id : ([...this.projects.keys()][0] ?? null),
    };
  }

  /** The approval with this id, still waiting (used before answering it from the notch). */
  approval(turnId: string, callId: string): NotchApproval | undefined {
    for (const s of this.sessions.values()) for (const a of s.approvals) if (a.turn_id === turnId && a.call_id === callId) return a;
    return undefined;
  }

  chat(chatId: string): ChatMeta | undefined {
    return this.chats.get(chatId);
  }

  private bump(kind: NotchPulseKind, chatId: string): void {
    this.pulse = { seq: ++this.seq, kind, chat_id: chatId };
  }

  private blank(c: ChatMeta, status: NotchStatus, updated: number): NotchSession {
    return {
      chat_id: c.id, workspace_id: c.workspace_id, title: c.title || "New chat", project: this.projects.get(c.workspace_id) ?? "",
      engine: c.engine ?? "api", ...(c.model ? { model: c.model } : {}), status, line: status === "working" ? "Working…" : "", approvals: [], unseen: false, updated,
    };
  }
}

/** A tool's name as a short verb for the one-line ticker. */
export function toolVerb(tool?: string): string {
  const t = (tool ?? "").toLowerCase();
  if (/read|view|open|cat/.test(t)) return "Reading";
  if (/write|edit|patch|create|apply/.test(t)) return "Editing";
  if (/run|bash|command|shell|exec|terminal/.test(t)) return "Running";
  if (/search|grep|glob|find|list/.test(t)) return "Searching";
  if (/web|fetch|browse|browser/.test(t)) return "Browsing";
  if (/task|agent/.test(t)) return "Delegating";
  return tool ? tool.replace(/_/g, " ") : "Working";
}

export interface NotchHardware { width: number; height: number }


/** The camera notch of the menu-bar screen, from AppKit's safe area (null: this screen has none). */
export function hardwareNotchOf(printed: string): NotchHardware | null {
  try {
    const { width, top, left, right } = JSON.parse(printed) as Record<string, unknown>;
    if (![width, top, left, right].every((n) => typeof n === "number")) return null;
    const across = Math.round((width as number) - (left as number) - (right as number));
    return (top as number) > 0 && (left as number) > 0 && (right as number) > 0 && across > 0 && across < (width as number) / 2 ? { width: across, height: Math.round(top as number) } : null;
  } catch { return null; }
}


const str = (v: unknown, max = 200): v is string => typeof v === "string" && v.length > 0 && v.length <= max;

/** Checks an action from the notch page; null drops it. */
export function notchAction(raw: unknown): Record<string, unknown> | null {
  if (typeof raw !== "object" || raw === null) return null;
  const a = raw as Record<string, unknown>;
  switch (a.type) {
    case "open": return { type: "open", ...(str(a.chat_id) ? { chat_id: a.chat_id } : {}) };
    case "newchat": return { type: "newchat", ...(str(a.workspace_id) ? { workspace_id: a.workspace_id } : {}) };
    case "approve":
      if (!str(a.turn_id) || !str(a.call_id) || typeof a.allow !== "boolean") return null;
      return { type: "approve", turn_id: a.turn_id, call_id: a.call_id, allow: a.allow, ...(str(a.choice, 32) ? { choice: a.choice } : {}), ...(a.remember === "allow" ? { remember: "allow" } : {}) };
    case "send":
      if (!str(a.text, 20_000) || !a.text.trim()) return null;
      return { type: "send", text: a.text, ...(str(a.chat_id) ? { chat_id: a.chat_id } : {}), ...(str(a.workspace_id) ? { workspace_id: a.workspace_id } : {}) };
    case "stop": return str(a.turn_id) ? { type: "stop", turn_id: a.turn_id } : null;
    case "seen": return str(a.chat_id) ? { type: "seen", chat_id: a.chat_id } : a.all === true ? { type: "seen", all: true } : null;
    case "voice": return a.op === "start" || a.op === "stop" || a.op === "cancel" ? { type: "voice", op: a.op } : null;
    case "focus": return { type: "focus", on: a.on === true };
    case "sounds": return { type: "sounds", on: a.on === true };
    case "workers": return { type: "workers", ...(typeof a.on === "boolean" ? { on: a.on } : {}) };
    case "mac": return str(a.text, 4000) && a.text.trim() ? { type: "mac", text: a.text.trim() } : null;
    // Voice mode in the notch (talking with the voice agent).
    case "talk": return a.op === "start" || a.op === "stop" || a.op === "interrupt" ? { type: "talk", op: a.op } : null;
    case "voice_audio":
    case "talk_audio": return typeof a.pcm === "string" && a.pcm.length > 0 && a.pcm.length <= 65536 && /^[A-Za-z0-9+/=]+$/.test(a.pcm) ? { type: a.type, pcm: a.pcm } : null;
    case "talk_playback": return { type: "talk_playback", playing: a.playing === true };
    case "talk_progress": return str(a.tts) && Number.isInteger(a.played) && (a.played as number) >= 0 && (a.played as number) <= 100000 ? { type: "talk_progress", tts: a.tts, played: a.played } : null;
    case "talk_approve": return str(a.call_id) && typeof a.allow === "boolean" ? { type: "talk_approve", call_id: a.call_id, allow: a.allow } : null;
    case "talk_pick": {
      if (a.which !== "brain" && a.which !== "worker") return null;
      const at = (v: unknown): number | undefined => (typeof v === "number" && Number.isFinite(v) && v >= 0 && v <= 4000 ? Math.round(v) : undefined);
      return { type: "talk_pick", which: a.which, ...(at(a.x) !== undefined ? { x: at(a.x) } : {}), ...(at(a.y) !== undefined ? { y: at(a.y) } : {}) };
    }
    case "talk_say": return str(a.text, 4000) && a.text.trim() ? { type: "talk_say", text: a.text.trim() } : null;
    default: return null;
  }
}

