// Voice mode: a front agent you talk to, and a worker it briefs.
//
//   window mic (echo-cancelled) -> voiceagent.audio -> helper (Apple on-device recognizer) -> utterance
//   utterance -> the front agent (a hidden chat, any Claude Code / API model, only its own tools) -> sentences -> Pocket TTS -> window
//   the front agent starts / checks / stops the worker (the visible chat) with tools and is told when the worker finishes
//
// One session at a time (one microphone). Plan: docs/voice-mode-plan.md.

import { randomBytes } from "node:crypto";
import type { ChatMeta, PermissionMode, RpcNotification, Settings, TurnEvent, Workspace } from "../../shared/protocol";
import type { Tool } from "../agent/tools";
import type { ChatStore } from "../chats";
import { listDir } from "../files";
import { SentenceStream } from "../tts/speakable";
import type { TtsService } from "../tts";
import type { ChiefBrain, TurnManager } from "../turns";
import type { VoiceService } from "../voice";
import { countWords, echoShare, isEcho } from "./echo";
import { voiceBrowserTools } from "./browser";
import { voicePrompt } from "./prompt";
import { voiceTools, type WorkerApi } from "./tools";

export type AgentState = "starting" | "listening" | "hearing" | "thinking" | "speaking";
/** What the voice agent can run on: every engine that can take it over MCP (the model you talk to; the worker has its own). */
export type BrainEngine = "api" | "claude-code" | "codex" | "antigravity" | "qoder";
export const BRAIN_ENGINES: readonly string[] = ["claude-code", "codex", "antigravity", "qoder", "api"];
export interface Pick { engine?: string; model?: string; effort?: string; account_id?: string }
export interface StartOpts { workspace_id: string; chat_id?: string; brain?: Pick; worker?: Pick & { mode?: PermissionMode } }

export interface VoiceAgentDeps {
  broadcast(n: RpcNotification): void;
  log(line: string): void;
  voice: VoiceService;
  tts: TtsService;
  turns: TurnManager;
  chats: ChatStore;
  workspace(id: string): Workspace | undefined;
  rootOf(w: Workspace): string;
  settings(): Settings;
  mcpUrl(): string;
  memory?(workspaceId: string): string;
  /** The engine a new chat starts on. */
  defaultEngine(): { engine: string; model?: string; effort?: string };
  /** Why an engine cannot run right now (not installed, not signed in), or undefined. */
  engineProblem(engine: string): string | undefined;
  /** The Browser panel's tools for this project (devices/browser.ts), or undefined when the window has no browser. */
  browser?(workspaceId: string, chatId: string): Tool[] | undefined;
}

interface Approval { call_id: string; tool: string; summary: string; detail?: string; /** The agent has told the person about it (a plain spoken yes/no may now answer it). */ asked?: boolean }

/** A short, plain spoken yes or no ("okay, do it", "yes go ahead", "no, don't"); anything else is left to the agent. */
export function spokenAnswer(text: string): "yes" | "no" | null {
  const t = text.toLowerCase().replace(/[^a-z' ]+/g, " ").replace(/\s+/g, " ").trim();
  if (!t || t.split(" ").length > 9) return null;
  if (/\b(but|wait|first|what|why|how|which|before|instead|later|maybe|not sure)\b/.test(t)) return null;
  if (/^(no|nope|nah|don't|do not|dont|stop|deny|denied|refuse|reject|cancel|not now|never)\b/.test(t)) return "no";
  if (/\b(no|don't|dont|not)\b/.test(t)) return null;
  if (/^(yes|yeah|yep|yup|ok|okay|sure|go ahead|go for it|do it|approve|approved|allow|allowed|confirm|confirmed|fine|alright|all right|right now do|please do|proceed)\b/.test(t)) return "yes";
  return null;
}
interface Worker {
  /** w1, w2, … in the order they were started. */
  id: string;
  chatId: string;
  title: string;
  turnId?: string;
  status: "none" | "running" | "complete" | "failed" | "interrupted";
  startedAt?: number;
  endedAt?: number;
  current?: string;
  recent: string[];
  pending: Approval[];
  text: string;
  error?: string;
  /** Turns the front agent stopped itself (it already knows; no news). */
  stoppedByAgent: Set<string>;
  /** Messages for the worker that wait for its turn to end (work_tell). */
  later: string[];
}

interface Sess {
  id: string;
  workspaceId: string;
  workspaceName: string;
  root: string;
  brainChat: string;
  /** What the hidden agent chat runs on (a fresh one is made from it every few turns). */
  brainPick: { engine: BrainEngine; model?: string; effort?: string; account_id?: string };
  brainTurns: number;
  /** The conversation in short (what the person said, what the agent said): carried into a fresh agent chat. */
  convo: { who: "person" | "you"; text: string }[];
  /** What the agent has said in the current turn. */
  saidNow: string;
  /** The chat the window shows (voice mode was opened in it); the first worker runs there if it is empty. */
  viewChat: string | null;
  workerPick: NonNullable<StartOpts["worker"]>;
  state: AgentState;
  hearing: boolean;
  brainTurn: string | null;
  ignoreTurn: string | null;
  pumping: boolean;
  ended: boolean;
  queue: { kind: "heard" | "note"; text: string }[];
  buf: SentenceStream;
  /** The latest voice session (kept after it ends so a cut-off can say what was planned). */
  ttsId: string | null;
  /** True while that session still takes sentences (the reply is being written). */
  ttsOpen: boolean;
  playing: boolean;
  lastAudioEnd: number;
  spoken: { text: string; at: number }[];
  cutOff?: { said: string; partial: string; unsaid: string };
  files: string[];
  filesToBrain: Set<string>;
  filesToWorker: Set<string>;
  workers: Worker[];
  tokens: Set<string>;
  tools: Tool[];
}

const SPOKEN_KEEP = 8;
/** The agent's hidden chat is replaced by a fresh one (with a recap) after this many turns, so each turn stays small. */
export const BRAIN_ROTATE = 6;
const CONVO_KEEP = 12;
/** Workers that may run at the same time. */
export const MAX_RUNNING = 4;
const ECHO_WINDOW_MS = 1500;
const BOOST_WHILE_SPEAKING = 2.4;
const clip = (t: string, n: number): string => (t.length > n ? `${t.slice(0, n)}…` : t);
const tail = (t: string, n: number): string => (t.length > n ? `…${t.slice(-n)}` : t);

/** "40 seconds", "2 minutes", "1 hour 5 minutes". */
export function span(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 90) return `${s} second${s === 1 ? "" : "s"}`;
  const m = Math.round(s / 60);
  if (m < 90) return `${m} minute${m === 1 ? "" : "s"}`;
  const h = Math.floor(m / 60);
  return `${h} hour${h === 1 ? "" : "s"}${m % 60 ? ` ${m % 60} minutes` : ""}`;
}

export class VoiceAgentService {
  private s: Sess | null = null;
  private readonly tokens = new Map<string, Tool[]>();

  constructor(private readonly d: VoiceAgentDeps) {
    // A crash can leave hidden chats behind; they are never listed, so nothing else would remove them.
    for (const id of d.chats.voiceChatIds()) { try { d.turns.deleteChat(id); } catch { /* gone */ } }
  }

  // ---- status / session --------------------------------------------------------------------------------------------------------

  async status(): Promise<{ helper: boolean; available: boolean; mic: string; voice_installed: boolean; running: string | null }> {
    const v = await this.d.voice.status();
    return { helper: v.helper, available: v.available, mic: v.mic, voice_installed: this.d.tts.status().installed, running: this.s?.id ?? null };
  }

  private emit(s: Sess, ev: string, extra: Record<string, unknown> = {}): void {
    this.d.broadcast({ method: "voiceagent.event", params: { session: s.id, ev, ...extra } });
  }

  private setState(s: Sess, state: AgentState): void {
    if (s.state === state || s.ended) return;
    s.state = state;
    this.emit(s, "state", { state });
  }

  async start(o: StartOpts): Promise<{ session: string; chat_id: string | null }> {
    if (this.s) throw new Error("Voice mode is already running.");
    const d = this.d;
    const ws = d.workspace(o.workspace_id);
    if (!ws) throw new Error("No such project.");
    const root = d.rootOf(ws);
    const v = await d.voice.status();
    if (!v.helper || !v.available) throw new Error(v.helper ? "Voice mode needs macOS 26 (Apple's on-device speech recognition)." : "Voice mode is not available in this build.");
    if (!d.tts.status().installed) throw new Error("The voice is not installed yet. Install it first (Settings → General → Voice).");

    // What the front agent runs on: the pick from the window, else the saved setting, else the chat default.
    const set = d.settings();
    const def = d.defaultEngine();
    const engine = o.brain?.engine || set.voice_brain_engine || def.engine;
    const model = o.brain?.model || set.voice_brain_model || (engine === def.engine ? def.model : undefined);
    const effort = o.brain?.effort || set.voice_brain_effort || (engine === def.engine ? def.effort : undefined);
    if (!BRAIN_ENGINES.includes(engine)) throw new Error("Pick a model for the voice agent in the Voice button.");
    const problem = d.engineProblem(engine);
    if (problem) throw new Error(problem);

    let viewChat: string | null = null;
    if (o.chat_id) {
      const c = d.chats.get(o.chat_id);
      if (!c || c.workspace_id !== ws.id || c.voice || c.chief || c.origin) throw new Error("That chat cannot be used for voice mode.");
      viewChat = c.id;
    }

    // Names the recogniser should keep whole: the project and what is in its top folder.
    const words = [ws.name];
    try { for (const e of listDir(root, "").entries.slice(0, 40)) words.push(e.name.replace(/\.[a-z0-9]+$/i, "")); } catch { /* unreadable */ }
    let s!: Sess;
    const { session: id } = d.voice.converse({ locale: set.voice_locale, words, endMs: set.voice_end_ms }, (e) => { if (s) this.onHelper(s, e); });
    const brainPick = { engine: engine as BrainEngine, ...(model ? { model } : {}), ...(effort ? { effort } : {}), ...(o.brain?.account_id ? { account_id: o.brain.account_id } : {}) };
    let chat: ChatMeta;
    try {
      chat = this.makeBrainChat(ws.id, id, brainPick);
    } catch (e) {
      d.voice.stop(true);
      throw e;
    }
    s = {
      id, workspaceId: ws.id, workspaceName: ws.name, root, brainChat: chat.id, brainPick, brainTurns: 0, convo: [], saidNow: "", viewChat, workerPick: o.worker ?? {},
      state: "starting", hearing: false, brainTurn: null, ignoreTurn: null, pumping: false, ended: false, queue: [], buf: new SentenceStream(),
      ttsId: null, ttsOpen: false, playing: false, lastAudioEnd: 0, spoken: [], files: [], filesToBrain: new Set(), filesToWorker: new Set(),
      workers: [], tokens: new Set(), tools: [],
    };
    s.tools = [...voiceTools(this.api(s)), ...voiceBrowserTools(d.browser?.(ws.id, chat.id) ?? [], (tool, what) => this.emit(s, "act", { kind: "browse", tool, what }))];
    this.s = s;
    // Opened in a chat that already has work: that chat is worker w1 (the agent can add to it or ask about it).
    if (viewChat) {
      const l = d.turns.ledger(viewChat);
      const lastTurn = l?.turns.at(-1);
      const running = d.turns.runningChats().includes(viewChat);
      if (running || lastTurn) {
        const w = this.addWorker(s, viewChat, d.chats.get(viewChat)?.title || "This chat");
        if (running) Object.assign(w, { status: "running", startedAt: Date.now() });
        else if (lastTurn) Object.assign(w, { status: lastTurn.status === "running" ? "interrupted" : lastTurn.status, endedAt: Date.parse(lastTurn.ended_at ?? l!.updated_at), text: l!.last_reply ?? "" });
      }
    }
    for (const w of s.workers) this.emit(s, "worker", this.workerInfo(s, w));
    return { session: id, chat_id: viewChat };
  }

  /** A hidden chat for the agent, on the engine and account the person picked. */
  private makeBrainChat(workspaceId: string, session: string, p: Sess["brainPick"]): ChatMeta {
    const d = this.d;
    let chat = d.chats.create(workspaceId, "read");
    chat = d.chats.setEngine(chat.id, { engine: p.engine, ...(p.model ? { model: p.model } : {}), ...(p.effort ? { effort: p.effort } : {}) }) ?? chat;
    if (p.account_id && p.engine !== "api") chat = d.chats.pinAccount(chat.id, p.engine, p.account_id) ?? chat;
    d.chats.setVoice(chat.id, { session });
    return chat;
  }

  /** The window's microphone, 16 kHz mono Int16, base64. */
  audio(session: string, pcm: string): void {
    const s = this.s;
    if (s && s.id === session && !s.ended) this.d.voice.audio(s.id, pcm);
  }

  attach(session: string, paths: string[]): void {
    const s = this.require(session);
    for (const p of paths) if (!s.files.includes(p)) { s.files.push(p); s.filesToBrain.add(p); s.filesToWorker.add(p); }
    this.emit(s, "attached", { paths: s.files });
  }

  /** Typed words instead of speech (the keyboard fallback, and what tests use). */
  say(session: string, text: string): void {
    const s = this.require(session);
    const t = text.trim();
    if (!t) return;
    this.interrupt(session);
    this.heard(s, t);
  }

  /** The agent is answering: thinking, or its voice is being made or played. */
  private busyTalking(s: Sess): boolean { return !!(s.playing || s.ttsOpen || s.brainTurn); }

  /** Recognised words that are the person, not the agent's own voice coming back: enough of them, and mostly not its words. */
  private realWords(s: Sess, text: string, min: number): boolean {
    const audible = s.playing || s.ttsOpen || Date.now() - s.lastAudioEnd < ECHO_WINDOW_MS;
    return countWords(text) >= min && !(audible && echoShare(text, s.spoken.map((x) => x.text)) >= 0.6);
  }

  /** The window started or finished playing the agent's voice. */
  playback(session: string, playing: boolean): void {
    const s = this.s;
    if (!s || s.id !== session || s.ended) return;
    s.playing = playing;
    this.d.voice.vad(s.id, playing ? BOOST_WHILE_SPEAKING : 1);
    if (playing) { this.setState(s, "speaking"); return; }
    s.lastAudioEnd = Date.now();
    if (!s.brainTurn && !s.pumping && !s.ttsOpen) { this.setState(s, s.hearing ? "hearing" : "listening"); this.wake(s); }
  }

  /** Cut the agent off now (the person spoke over it, or tapped). */
  interrupt(session: string): void {
    const s = this.s;
    if (!s || s.id !== session || s.ended) return;
    this.bargeIn(s);
  }

  stop(session: string): { stopped: boolean } {
    const s = this.s;
    if (!s || s.id !== session) return { stopped: false };
    this.end(s, "stopped");
    return { stopped: true };
  }

  close(): void { if (this.s) this.end(this.s, "shutdown"); }

  private require(session: string): Sess {
    const s = this.s;
    if (!s || s.id !== session || s.ended) throw new Error("Voice mode is not running.");
    return s;
  }

  private end(s: Sess, why: string): void {
    if (s.ended) return;
    s.ended = true;
    this.s = null;
    try { this.d.voice.stop(true); } catch { /* not listening */ }
    if (s.ttsId) { try { this.d.tts.stop(s.ttsId); } catch { /* gone */ } }
    if (s.brainTurn) { try { this.d.turns.interrupt(s.brainTurn); } catch { /* gone */ } }
    for (const t of s.tokens) this.tokens.delete(t);
    // The hidden chat is only the agent's memory of this talk; the worker chat (if any) stays.
    setTimeout(() => { try { this.d.turns.deleteChat(s.brainChat); } catch { /* gone */ } }, 300).unref?.();
    this.emit(s, "ended", { why, chat_id: s.viewChat ?? s.workers[0]?.chatId ?? null });
  }

  // ---- the helper (microphone side) ---------------------------------------------------------------------------------------------

  private onHelper(s: Sess, e: Record<string, unknown>): void {
    if (s.ended) return;
    const ev = String(e.ev ?? "");
    switch (ev) {
      case "ready": break;
      case "asset": this.emit(s, "asset", { progress: e.progress }); break;
      case "started": this.setState(s, "listening"); this.emit(s, "ready", { locale: e.locale, engine: e.engine }); break;
      case "speech":
        s.hearing = true;
        // A sound is not yet a person: the agent's own voice coming back through the speakers starts "speech" too.
        // It is cut off only once real words are recognised (partial below, or the utterance).
        if (!this.busyTalking(s)) this.setState(s, "hearing");
        break;
      case "partial": {
        const text = String(e.text ?? "");
        this.emit(s, "partial", { text });
        if (this.busyTalking(s) && this.realWords(s, text, 2)) { this.bargeIn(s); this.setState(s, "hearing"); }
        break;
      }
      case "noise":
        s.hearing = false;
        this.setState(s, s.brainTurn ? "thinking" : s.playing ? "speaking" : "listening");
        this.wake(s);
        break;
      case "utterance": {
        s.hearing = false;
        const text = String(e.text ?? "").trim();
        if (!text) { this.setState(s, "listening"); this.wake(s); break; }
        // The agent's own words coming back through the speakers: not the person.
        const audible = s.playing || Date.now() - s.lastAudioEnd < ECHO_WINDOW_MS;
        if (audible && isEcho(text, s.spoken.map((x) => x.text))) { this.emit(s, "ignored", { text, why: "echo" }); this.setState(s, s.playing ? "speaking" : "listening"); this.wake(s); break; }
        if (this.busyTalking(s)) this.bargeIn(s);
        if (this.answerByVoice(s, text)) break;
        this.heard(s, text);
        break;
      }
      case "done": case "cancelled": if (!s.ended) this.end(s, ev); break;
      case "error": {
        const code = String(e.code ?? "");
        this.emit(s, "error", { code, message: String(e.message ?? "The microphone helper failed.") });
        if (["mic_denied", "locale", "asset", "audio", "unavailable", "helper_exit"].includes(code)) this.end(s, code);
        break;
      }
    }
  }

  // ---- approvals answered by voice ---------------------------------------------------------------------------------------------

  /** The one approval the agent has asked the person about, if exactly one is open. */
  private askedApproval(s: Sess): { w: Worker; p: Approval } | undefined {
    const open = s.workers.flatMap((w) => w.pending.filter((p) => p.asked).map((p) => ({ w, p })));
    return open.length === 1 ? open[0] : undefined;
  }

  /** A plain spoken yes/no to the approval the agent just asked about: answered at once, the agent only confirms. */
  private answerByVoice(s: Sess, text: string): boolean {
    const a = this.askedApproval(s);
    const said = a ? spokenAnswer(text) : null;
    if (!a || !said) return false;
    this.emit(s, "heard", { text });
    this.remember(s, "person", text);
    this.resolveApproval(s, a.w, a.p, said === "yes", `The person said "${clip(text, 120)}"`);
    return true;
  }

  /** Answers a worker's approval (spoken yes/no, or the box's Allow/Deny) and tells the agent so it confirms in a few words. */
  private resolveApproval(s: Sess, w: Worker, p: Approval, allow: boolean, why: string): void {
    if (!w.turnId) return;
    this.emit(s, "act", { kind: "visit", worker: w.id });
    let done = false;
    try { done = this.d.turns.approve(w.turnId, p.call_id, allow).resolved; } catch { /* the turn ended */ }
    w.pending = w.pending.filter((x) => x.call_id !== p.call_id);
    this.emit(s, "worker", this.workerInfo(s, w));
    this.emit(s, "approval", { worker: w.id, call_id: p.call_id, allow });
    s.queue.push({ kind: "heard", text: `<approval_answered worker="${w.id}" title="${w.title}">${why}. ${done ? (allow ? "It was approved" : "It was refused") : "It had already been answered"}: ${clip(p.summary, 200)}. Confirm in a few words (for example "Done, it's going ahead."). Do not call work_approve.</approval_answered>` });
    this.setState(s, "thinking");
    void this.pump(s);
  }

  /** The Allow / Deny buttons on a worker's box. */
  approve(session: string, callId: string, allow: boolean): { ok: boolean } {
    const s = this.require(session);
    for (const w of s.workers) {
      const p = w.pending.find((x) => x.call_id === callId);
      if (p) { this.resolveApproval(s, w, p, allow, `The person pressed ${allow ? "Allow" : "Deny"} on the worker's box`); return { ok: true }; }
    }
    return { ok: false };
  }

  // ---- the front agent ----------------------------------------------------------------------------------------------------------

  private heard(s: Sess, text: string): void {
    this.emit(s, "heard", { text });
    s.queue.push({ kind: "heard", text });
    this.setState(s, "thinking");
    void this.pump(s);
  }

  /** Something other than speech happened (the worker has news): the agent speaks up unless the person is talking. */
  private wake(s: Sess): void {
    if (s.queue.length && !s.hearing && !s.pumping && !s.ended) void this.pump(s);
  }

  private async pump(s: Sess): Promise<void> {
    if (s.pumping || s.ended) return;
    s.pumping = true;
    try {
      while (s.queue.length && !s.ended) {
        if (s.hearing) break; // never talk over the person; their utterance (or the quiet) wakes this again
        // Do not start while the previous reply is still audible, unless the person spoke (they already cut it off).
        // News (no new words from the person) waits until the previous reply has been heard, so it is not talked over.
        if (!s.queue.some((i) => i.kind === "heard")) await this.quiet(s);
        if (s.ended || s.hearing) continue;
        const items = s.queue.splice(0);
        await this.runBrain(s, items);
      }
    } finally {
      s.pumping = false;
    }
    if (!s.ended && !s.brainTurn && !s.playing && !s.ttsOpen) this.setState(s, s.hearing ? "hearing" : "listening");
  }

  /** Resolves when the agent's voice is not playing (at most 25 s). */
  private async quiet(s: Sess): Promise<void> {
    for (const end = Date.now() + 25_000; (s.playing || s.ttsOpen || (s.ttsId !== null && this.d.tts.busy(s.ttsId))) && Date.now() < end && !s.ended && !s.hearing; ) await new Promise((r) => setTimeout(r, 60));
  }

  private async runBrain(s: Sess, items: Sess["queue"]): Promise<void> {
    const heard = items.filter((i) => i.kind === "heard").map((i) => i.text);
    const notes = items.filter((i) => i.kind === "note").map((i) => i.text);
    // Keep each turn small: after a few turns the agent continues in a fresh chat that starts with a short recap,
    // instead of re-reading the whole conversation every time.
    let recap = "";
    if (s.brainTurns >= BRAIN_ROTATE) {
      try {
        const old = s.brainChat;
        s.brainChat = this.makeBrainChat(s.workspaceId, s.id, s.brainPick).id;
        s.brainTurns = 0;
        setTimeout(() => { try { this.d.turns.deleteChat(old); } catch { /* gone */ } }, 300).unref?.();
        recap = this.recap(s);
      } catch (e) { this.d.log(`voice: fresh agent chat failed: ${e instanceof Error ? e.message : String(e)}`); }
    }
    const parts: string[] = [...(recap ? [recap] : []), this.workerLine(s), ...notes];
    if (s.cutOff) {
      const c = s.cutOff;
      parts.push(`<cut_off>You were interrupted.${c.said ? ` You had said: "${clip(c.said, 400)}".` : ""}${c.partial ? ` You were partway through: "${clip(c.partial, 300)}".` : ""}${c.unsaid ? ` You had not yet said: "${clip(c.unsaid, 400)}".` : ""}</cut_off>`);
      s.cutOff = undefined;
    }
    const newFiles = [...s.filesToBrain];
    if (newFiles.length) parts.push(`<attached>${newFiles.join(", ")}</attached>`);
    if (heard.length) parts.push(`<heard>${heard.join(" ")}</heard>`);
    if (heard.length) this.remember(s, "person", heard.join(" "));
    s.filesToBrain.clear();
    s.saidNow = "";
    s.buf = new SentenceStream();

    let turnId: string;
    try {
      const r = this.d.turns.submit(s.workspaceId, s.brainChat, parts.join("\n"), { event: heard.length === 0, ...(newFiles.length ? { attachments: newFiles } : {}) });
      turnId = r.turn_id;
    } catch (e) {
      this.emit(s, "error", { code: "brain", message: e instanceof Error ? e.message : String(e) });
      return;
    }
    s.brainTurn = turnId;
    s.brainTurns++;
    this.setState(s, "thinking");
    const res = await this.d.turns.whenDone(turnId);
    if (s.brainTurn === turnId) s.brainTurn = null;
    this.emit(s, "act", { kind: "home" });
    if (s.ended) return;
    if (s.ignoreTurn === turnId) { s.ignoreTurn = null; if (s.saidNow.trim()) this.remember(s, "you", `${s.saidNow.trim()} (cut off)`); return; } // cut off by the person: nothing more to say from it
    const rest = s.buf.flush();
    if (rest.length) this.sayNow(s, rest);
    if (s.saidNow.trim()) this.remember(s, "you", s.saidNow.trim());
    // The agent has now told the person about these approvals: a plain spoken yes/no can answer them.
    const told = notes.join("\n");
    if (s.saidNow.trim()) for (const w of s.workers) for (const p of w.pending) if (told.includes(p.call_id)) p.asked = true;
    this.closeVoice(s);
    if (res.status === "failed") {
      this.emit(s, "error", { code: "brain", message: res.error ?? "The voice agent's model failed." });
      this.sayNow(s, ["Sorry, I couldn't reach my model just now. Try again in a moment."]);
      this.closeVoice(s);
    }
    if (!s.playing && !s.ttsOpen) this.setState(s, s.hearing ? "hearing" : "listening");
  }

  private remember(s: Sess, who: "person" | "you", text: string): void {
    s.convo.push({ who, text: clip(text, 600) });
    if (s.convo.length > CONVO_KEEP) s.convo.splice(0, s.convo.length - CONVO_KEEP);
  }

  /** What a fresh agent chat needs to carry on: the conversation in short and the workers (the <workers> line follows). */
  private recap(s: Sess): string {
    const lines = s.convo.map((c) => `${c.who === "person" ? "Person" : "You"}: ${clip(c.text, 300)}`);
    let text = lines.join("\n");
    if (text.length > 3000) text = `…${text.slice(-3000)}`;
    const briefs = s.workers.map((w) => `${w.id} "${w.title}"`).join(", ");
    return `<recap>This is a continuing voice conversation; earlier turns were summarised to keep things fast. Carry on naturally; do not mention the recap.\n${text || "(nothing said yet)"}${briefs ? `\nWorkers so far: ${briefs}.` : ""}</recap>`;
  }

  /** The reply is complete: the voice session ends after its last sentence. */
  private closeVoice(s: Sess): void {
    if (s.ttsId && s.ttsOpen) this.d.tts.finish(s.ttsId);
    s.ttsOpen = false;
  }

  /** Feeds sentences to the voice; the first one opens a live voice session (and the window starts playing). */
  private sayNow(s: Sess, sentences: string[]): void {
    if (s.ended || !sentences.length) return;
    try {
      if (!s.ttsId || !s.ttsOpen) {
        const r = this.d.tts.speakLive({ voice: this.d.settings().voice_tts_voice || this.d.settings().tts_voice });
        s.ttsId = r.session;
        s.ttsOpen = true;
        this.d.voice.vad(s.id, BOOST_WHILE_SPEAKING);
        this.emit(s, "say_start", { tts: r.session });
      }
      this.d.tts.feed(s.ttsId, sentences);
    } catch (e) {
      this.emit(s, "error", { code: "tts", message: e instanceof Error ? e.message : String(e) });
      return;
    }
    const now = Date.now();
    for (const t of sentences) s.spoken.push({ text: t, at: now });
    if (s.spoken.length > SPOKEN_KEEP) s.spoken.splice(0, s.spoken.length - SPOKEN_KEEP);
    s.saidNow += ` ${sentences.join(" ")}`;
    this.emit(s, "say", { text: sentences.join(" ") });
    this.setState(s, "speaking");
  }

  private bargeIn(s: Sess): void {
    const snap = s.ttsId ? this.d.tts.snapshot(s.ttsId) : undefined;
    if (s.ttsId) { this.d.tts.stop(s.ttsId); s.ttsId = null; }
    s.ttsOpen = false;
    if (snap && snap.sentences.length) {
      const k = Math.max(0, Math.min(snap.played, snap.sentences.length));
      s.cutOff = { said: snap.sentences.slice(0, Math.max(0, k - 1)).join(" "), partial: k > 0 ? snap.sentences[k - 1] : "", unsaid: snap.sentences.slice(k).join(" ") };
    }
    if (s.brainTurn) { s.ignoreTurn = s.brainTurn; try { this.d.turns.interrupt(s.brainTurn); } catch { /* ended */ } }
    s.buf = new SentenceStream();
    if (s.playing) { s.playing = false; s.lastAudioEnd = Date.now(); }
    this.d.voice.vad(s.id, 1);
    this.emit(s, "stop_audio");
  }

  // ---- the front agent's brain (called by TurnManager for its hidden chat) ------------------------------------------------------

  /** Prompt, tools and where Claude Code reaches them, for one turn of the agent's own chat. */
  brain(chat: ChatMeta, _turnId: string): ChiefBrain | undefined {
    const s = this.s;
    if (!s || !chat.voice || chat.id !== s.brainChat) return undefined;
    const token = randomBytes(24).toString("hex");
    this.tokens.set(token, s.tools);
    s.tokens.add(token);
    const system = voicePrompt({ project: s.workspaceName, today: new Date().toDateString(), memory: this.d.memory?.(s.workspaceId) ?? "", browser: s.tools.some((t) => t.def.name === "browser_search") });
    return { system, tools: s.tools, mcp: { url: this.d.mcpUrl(), token } };
  }

  /** Tools reachable with an MCP token. */
  toolsFor(token: string): Tool[] | undefined { return this.tokens.get(token); }

  // ---- turn events ---------------------------------------------------------------------------------------------------------------

  /** Every turn event in the runtime passes through here. */
  observe(ev: TurnEvent): void {
    const s = this.s;
    if (!s || s.ended) return;
    if (ev.chat_id === s.brainChat) this.onBrainEvent(s, ev);
    else { const w = s.workers.find((x) => x.chatId === ev.chat_id); if (w) this.onWorkerEvent(s, w, ev); }
  }

  private onBrainEvent(s: Sess, ev: TurnEvent): void {
    if (ev.turn_id === s.ignoreTurn) return;
    if (ev.type === "delta" && ev.text) {
      const sentences = s.buf.push(ev.text);
      if (sentences.length) this.sayNow(s, sentences);
    } else if (ev.type === "tool_start") {
      this.emit(s, "tool", { tool: ev.tool, summary: ev.summary });
    }
  }

  private onWorkerEvent(s: Sess, w: Worker, ev: TurnEvent): void {
    switch (ev.type) {
      case "started":
        Object.assign(w, { turnId: ev.turn_id, status: "running", startedAt: Date.now(), endedAt: undefined, current: undefined, recent: [], pending: [], text: "", error: undefined });
        this.emit(s, "worker", this.workerInfo(s, w));
        break;
      case "delta": w.text += ev.text ?? ""; if (w.text.length > 20_000) w.text = w.text.slice(-12_000); break;
      case "tool_start":
        w.current = ev.summary ?? ev.tool ?? "working";
        w.recent.push(w.current);
        if (w.recent.length > 8) w.recent.shift();
        this.emit(s, "worker", this.workerInfo(s, w));
        break;
      case "tool_end": w.current = undefined; break;
      case "approval_request": {
        // The summary comes with the card; fall back to the tool name.
        const summary = ev.summary ?? w.current ?? ev.tool ?? "a tool";
        w.pending = [...w.pending.filter((p) => p.call_id !== ev.call_id), { call_id: String(ev.call_id ?? ""), tool: String(ev.tool ?? ""), summary, ...(ev.detail ? { detail: ev.detail } : {}) }];
        this.emit(s, "worker", this.workerInfo(s, w));
        this.news(s, `<worker_update worker="${w.id}" title="${w.title}" status="waiting_for_approval">The worker wants to: ${clip(summary, 300)}${ev.detail ? `\nDetails: ${clip(ev.detail, 400)}` : ""}\ncall_id: ${ev.call_id}\nTell the person in one sentence and ask yes or no. Do not approve until they say so.</worker_update>`);
        break;
      }
      case "approval_resolved": w.pending = w.pending.filter((p) => p.call_id !== ev.call_id); this.emit(s, "worker", this.workerInfo(s, w)); break;
      case "completed": case "failed": case "interrupted": {
        w.status = ev.type === "completed" ? "complete" : ev.type;
        w.endedAt = Date.now();
        w.current = undefined;
        w.pending = [];
        if (ev.error) w.error = ev.error;
        this.emit(s, "worker", this.workerInfo(s, w));
        const mine = !!ev.turn_id && w.stoppedByAgent.delete(ev.turn_id);
        // Messages queued with work_tell go to the worker now.
        if (w.later.length && ev.type !== "failed") {
          const msg = w.later.splice(0).join("\n\n");
          setImmediate(() => { try { this.sendToWorker(s, w, msg); } catch (e) { this.d.log(`voice: queued message failed: ${e instanceof Error ? e.message : String(e)}`); } });
          break;
        }
        if (mine) break;
        const files = this.filesChanged(w);
        const took = w.startedAt ? span(Date.now() - w.startedAt) : "a while";
        const open = this.openErrors(w);
        const others = s.workers.filter((x) => x !== w && x.status === "running").length;
        this.news(s, `<worker_update worker="${w.id}" title="${w.title}" status="${w.status}" took="${took}">\n${ev.type === "completed" ? "The worker's own report (its last words):" : `The worker ${ev.type === "failed" ? "failed" : "was stopped"}${w.error ? `: ${clip(w.error, 300)}` : ""}. Its last words:`}\n${tail(w.text.trim(), 1800) || "(it said nothing)"}${files.length ? `\nFiles changed: ${files.join(", ")}` : ""}${open.length ? `\nCommands that still fail: ${open.join("; ")}` : ""}\nTell the person the result in one to three sentences${s.workers.length > 1 ? `, naming the work ("${w.title}")` : ""}. Do not claim anything was verified that the worker did not say it verified.${others ? ` ${others} other worker${others === 1 ? " is" : "s are"} still running.` : ""}\n</worker_update>`);
        break;
      }
    }
  }

  /** News for the agent: it speaks up as soon as the person is not talking. */
  private news(s: Sess, text: string): void {
    s.queue.push({ kind: "note", text });
    this.wake(s);
  }

  // ---- the workers (each its own visible chat) ----------------------------------------------------------------------------------

  private filesChanged(w: Worker): string[] {
    const l = this.d.turns.ledger(w.chatId);
    return (l?.files_changed ?? []).slice(-12).map((f) => f.path.split("/").pop() ?? f.path);
  }
  private openErrors(w: Worker): string[] {
    const l = this.d.turns.ledger(w.chatId);
    return (l?.open_errors ?? []).slice(0, 3).map((c) => `${clip(c.cmd, 80)} (exit ${c.exit ?? "?"})`);
  }

  private workerInfo(s: Sess, w: Worker): Record<string, unknown> {
    const ask = w.pending[0];
    const meta = this.d.chats.get(w.chatId);
    return { engine: meta?.engine ?? "api", ...(meta?.model ? { model: meta.model } : {}), id: w.id, title: w.title, status: w.status, started_at: w.startedAt, ended_at: w.endedAt, current: w.current, files: this.filesChanged(w).length, waiting: w.pending.length, chat_id: w.chatId, view: w.chatId === s.viewChat, ...(ask ? { ask: { call_id: ask.call_id, summary: clip(ask.summary, 160), ...(ask.detail ? { detail: clip(ask.detail, 240) } : {}) } } : {}) };
  }

  private addWorker(s: Sess, chatId: string, title: string): Worker {
    const w: Worker = { id: `w${s.workers.length + 1}`, chatId, title: clip(title.trim() || "Work", 60), status: "none", recent: [], pending: [], text: "", stoppedByAgent: new Set(), later: [] };
    s.workers.push(w);
    return w;
  }

  /** The worker a tool means: the one named, else the latest. */
  private pickWorker(s: Sess, id: string | undefined): Worker {
    if (!s.workers.length) throw new Error("There is no worker yet. Use work_start with a full brief.");
    if (!id) return s.workers[s.workers.length - 1];
    const w = s.workers.find((x) => x.id === id.trim().toLowerCase());
    if (!w) throw new Error(`No worker ${id}. Workers: ${s.workers.map((x) => `${x.id} "${x.title}"`).join(", ")}.`);
    return w;
  }

  private stateOf(w: Worker): string {
    if (w.pending.length) return `waiting for the person's approval: ${w.pending.map((p) => `${clip(p.summary, 120)} (call_id ${p.call_id})`).join("; ")}`;
    if (w.status === "running") return [`running for ${span(Date.now() - (w.startedAt ?? Date.now()))}`, w.current ? `now: ${clip(w.current, 100)}` : "thinking"].join(" · ");
    if (w.status === "none") return "not started";
    return `${w.status === "complete" ? "finished" : w.status} ${w.endedAt ? `${span(Date.now() - w.endedAt)} ago` : ""}`.trim();
  }

  /** One line the agent sees with everything the person says. */
  private workerLine(s: Sess): string {
    if (!s.workers.length) return `<workers>none yet. Nothing has been handed over.</workers>`;
    const shown = s.workers.filter((w, i) => w.status === "running" || w.pending.length || i >= s.workers.length - 4);
    return `<workers>${shown.map((w) => { const f = this.filesChanged(w).length; return `${w.id} "${w.title}": ${this.stateOf(w)}${f ? ` · ${f} file${f === 1 ? "" : "s"} changed` : ""}`; }).join(" | ")}</workers>`;
  }

  /** The full picture of one worker for work_status. */
  private statusReport(w: Worker): string {
    const l = this.d.turns.ledger(w.chatId);
    const lines: string[] = [`${w.id} "${w.title}"`, `state: ${this.stateOf(w)}`];
    if (w.recent.length) lines.push(`recent steps: ${w.recent.slice(-6).join(" → ")}`);
    const files = (l?.files_changed ?? []).map((f) => f.path);
    if (files.length) lines.push(`files changed (${files.length}): ${files.slice(-15).join(", ")}`);
    if (l?.plan?.steps.length) lines.push(`plan: ${l.plan.steps.map((p) => `[${p.status}] ${clip(p.step, 90)}`).join("; ")}`);
    const bad = l?.open_errors ?? [];
    if (bad.length) lines.push(`commands still failing: ${bad.slice(0, 3).map((c) => `${clip(c.cmd, 80)} (exit ${c.exit ?? "?"}): ${clip(c.tail.trim().split("\n").slice(-3).join(" / "), 200)}`).join(" | ")}`);
    for (const p of w.pending) lines.push(`needs approval (call_id ${p.call_id}): ${p.summary}${p.detail ? ` — ${clip(p.detail, 300)}` : ""}`);
    if (w.error) lines.push(`error: ${clip(w.error, 300)}`);
    const text = w.text.trim() || l?.last_reply || "";
    if (text) lines.push(`its last words: ${tail(text, 1500)}`);
    return lines.join("\n");
  }

  /** A fresh chat for new work: the window's chat if nothing has run in it yet, else a new one (no old history to pay for). */
  private newWorkerChat(s: Sess): string {
    const d = this.d;
    const v = s.viewChat;
    if (v && !s.workers.some((w) => w.chatId === v) && !d.turns.ledger(v)?.turns.length && !d.turns.runningChats().includes(v)) return v;
    const def = d.defaultEngine();
    const p = s.workerPick;
    const engine = (p.engine || def.engine) as "api" | "claude-code" | "codex" | "antigravity" | "qoder";
    let chat = d.chats.create(s.workspaceId, p.mode ?? d.settings().default_mode);
    const model = p.model || (p.engine ? undefined : def.model);
    const effort = p.effort || (p.engine ? undefined : def.effort);
    if (engine !== "api" || model || effort) chat = d.chats.setEngine(chat.id, { engine, ...(model ? { model } : {}), ...(effort ? { effort } : {}) }) ?? chat;
    if (p.account_id && engine !== "api") chat = d.chats.pinAccount(chat.id, engine, p.account_id) ?? chat;
    // The list first: the window can only show a chat it knows.
    d.broadcast({ method: "chat.changed", params: { chats: d.chats.list() } });
    if (!s.viewChat) { s.viewChat = chat.id; this.emit(s, "bind", { chat_id: chat.id }); }
    return chat.id;
  }

  private sendToWorker(s: Sess, w: Worker, text: string): string {
    const files = [...s.filesToWorker];
    const fresh = !this.d.chats.get(w.chatId)?.title;
    const r = this.d.turns.submit(s.workspaceId, w.chatId, text, files.length ? { attachments: files } : {});
    s.filesToWorker.clear();
    // The first message names a chat after its first words; the agent's own short title is better.
    if (fresh) { this.d.chats.rename(w.chatId, w.title); this.d.broadcast({ method: "chat.changed", params: { chats: this.d.chats.list() } }); }
    Object.assign(w, { turnId: r.turn_id, status: "running", startedAt: Date.now(), endedAt: undefined, current: undefined, recent: [], pending: [], text: "", error: undefined });
    this.emit(s, "worker", this.workerInfo(s, w));
    return r.turn_id;
  }

  private running(w: Worker): boolean { return this.d.turns.runningChats().includes(w.chatId); }

  /** The tools' view of the session. */
  private api(s: Sess): WorkerApi {
    return {
      root: s.root,
      workStart: (brief, title) => {
        const busy = s.workers.filter((w) => this.running(w));
        if (busy.length >= MAX_RUNNING) throw new Error(`${busy.length} workers are already running (${busy.map((w) => `${w.id} "${w.title}"`).join(", ")}). Wait for one to finish, add to one with work_tell, or stop one.`);
        const w = this.addWorker(s, this.newWorkerChat(s), title || brief.split("\n")[0].replace(/^Goal:\s*/i, ""));
        this.emit(s, "act", { kind: "start", worker: w.id });
        this.sendToWorker(s, w, brief);
        return `Started ${w.id} ("${w.title}") in its own chat. It will report when it finishes; you will be told.${busy.length ? ` ${busy.length} other worker${busy.length === 1 ? " is" : "s are"} still running.` : ""}`;
      },
      workTell: async (id, message, interrupt) => {
        const w = this.pickWorker(s, id);
        this.emit(s, "act", { kind: "visit", worker: w.id });
        if (!this.running(w)) { this.sendToWorker(s, w, message); return `Sent to ${w.id}. It is on it.`; }
        if (!interrupt) { w.later.push(message); return `${w.id} is busy; your message reaches it as soon as its current turn ends.`; }
        const t = w.turnId;
        if (t) { w.stoppedByAgent.add(t); this.d.turns.interrupt(t); await this.d.turns.whenDone(t); }
        this.sendToWorker(s, w, message);
        return `Stopped what ${w.id} was doing and sent the new direction.`;
      },
      workStatus: (id) => {
        if (!s.workers.length) return "No worker has been started. Nothing has been handed over.";
        if (id) { const w = this.pickWorker(s, id); this.emit(s, "act", { kind: "visit", worker: w.id }); return this.statusReport(w); }
        const show = s.workers.filter((w) => w.status === "running" || w.pending.length).concat(s.workers.slice(-2)).filter((w, i, a) => a.indexOf(w) === i);
        for (const w of show) this.emit(s, "act", { kind: "visit", worker: w.id });
        return show.map((w) => this.statusReport(w)).join("\n\n");
      },
      workStop: (id) => {
        const w = this.pickWorker(s, id);
        if (!this.running(w) || !w.turnId) return `${w.id} is not running.`;
        this.emit(s, "act", { kind: "visit", worker: w.id });
        w.stoppedByAgent.add(w.turnId);
        w.later = [];
        this.d.turns.interrupt(w.turnId);
        return `Stopped ${w.id}.`;
      },
      workApprove: (callId, allow) => {
        const w = s.workers.find((x) => x.pending.some((p) => p.call_id === callId));
        if (!w || !w.turnId) throw new Error("No worker is waiting on that approval.");
        this.emit(s, "act", { kind: "visit", worker: w.id });
        const r = this.d.turns.approve(w.turnId, callId, allow);
        return r.resolved ? (allow ? "Approved." : "Refused.") : "That approval had already been answered.";
      },
      peeked: (path) => this.emit(s, "act", { kind: "peek", path }),
      browsed: (tool) => this.emit(s, "act", { kind: "browse", tool }),
    };
  }
}
