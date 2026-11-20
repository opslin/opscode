// Chat turns. A turn is one user message and the streamed assistant reply,
// broadcast to every session as `turn.event`:
//   started -> delta* -> completed | interrupted | failed
// One turn may run per workspace at a time.
//
// The Engine interface is the seam for Phase 5 (real agent + providers).
// EchoEngine is a deliberate STUB so the streaming contract can be built and
// tested now. Transcripts are in memory only for this phase.

import { createHash, randomUUID } from "node:crypto";
import { LIMITS, isAgentEngine, type AgentEngineId, type ApprovalChoice, type AskAnswer, type AskQuestion, type ChatMessage, type ChatMeta, type PermissionMode, type MessagePart, type RpcNotification, type TurnEvent, type TurnEventType, type Workspace } from "../shared/protocol";
import { fail } from "./rpc";
import type { Tool } from "./agent/tools";
import { attachedNote, resolveAttached } from "./attachments";
import { currentBranch, type BranchHost, type BranchRule } from "./engines/branchGuard";
import type { DeviceGrants } from "./devices/mcp";
import { devicesNote } from "./engines/claude";
import type { ChatStore } from "./chats";
import type { LedgerStore, LedgerView } from "./ledger";
import { buildPack, gitSummary, planHandoff, recentMessages, tokensOf, type HandoffPlan } from "./handoff";
import { isLimitError, lastModelOn, type AutoSwitch } from "./autoswitch";
import { isAuthError } from "./engines/accounts";
import { lowDiskCard } from "./disk";
import { answerMessage, answerText, checkAnswers, parseQuestionBlock, questionSummary, type AskResult } from "./ask";

/** Nobody watches a Manager's worker or an automation's step: a question there is answered at once. */
function defaultNoAsk(chat: ChatMeta | undefined): string | undefined {
  if (chat?.origin) return "Nobody can answer now: this chat is a step of an automation.";
  if (chat?.chief && chat.chief.role !== "home") return "Nobody can answer now: this chat is a Manager's worker. Put the open question in your report.";
  return undefined;
}

/** How often a running turn checks free disk space. */
const DISK_CHECK_MS = Number(process.env.OPSCODE_DISK_CHECK_MS) || 10 * 60_000;

export interface EngineInput {
  text: string;
  /** Absolute paths of reference images inside the project (engines that can see images attach them). */
  images?: string[];
  history: readonly ChatMessage[];
  signal: AbortSignal;
  /**
   * Set when this turn takes over from another engine (H3). `text` is the pack with the user's recent
   * words; `bare` is the same without them, for an engine that gets `messages` as real history (Codex).
   * The engine delivers it and calls host.handoffSent(); it then skips the old priorContext text.
   */
  handoff?: { kind: "full" | "update"; text: string; bare: string; messages: { role: "user" | "assistant"; text: string }[] };
}

/** What an engine can do besides streaming text: run tools and ask for approval. */
export interface TurnHost {
  /** Absolute, verified project root. */
  root: string;
  workspaceName: string;
  /** Notes to put in the system prompt ("" when none or memory is off). */
  memory: string;
  /** The chat's permission mode right now (it can change mid-turn). */
  mode(): PermissionMode;
  /** Auto mode only: the person said "decide yourself" (voice mode), so only high-risk steps ask (engines/safety.ts autoAsks). */
  trusted?(): boolean;
  /** Tools beyond the built-ins (MCP servers). */
  extraTools: Tool[];
  saveNote(title: string, body: string): void;
  /** Skills this chat can use, and their steps by name. */
  skills: { name: string; description: string }[];
  /** The same skills with their files, for Claude Code and Codex (they open a skill's file when a task matches). */
  skillFiles: { name: string; description: string; path: string }[];
  readSkill(name: string): string | undefined;
  /** Sub-agents this chat can hand tasks to, and one's definition by name. */
  agents: { name: string; description: string }[];
  getAgent(name: string): { name: string; access: "read" | "edit" | "full"; body: string } | undefined;
  toolStart(call: { call_id: string; tool: string; summary: string; detail?: string; choices?: ApprovalChoice[] }, needsApproval: boolean): void;
  /** For engines that ask after a tool card is already shown: marks it awaiting approval, then resolves with the decision. */
  askApproval(callId: string, card?: { summary: string; detail?: string; choices?: ApprovalChoice[] }): Promise<boolean>;
  /** The choice the person picked on the last card that offered choices (undefined: none offered). */
  choiceOf?(callId: string): string | undefined;
  /** The project's branch rule, for engines that guard branch creation (engines/branchGuard.ts). */
  branch?: BranchHost;
  /** Asks about creating a new git branch with the branch card; the answer may ask to remember it. */
  askBranch?(callId: string, info: { names: string[]; current: string }): Promise<{ allow: boolean; remember?: "allow" | "current" }>;
  /** The chat this turn belongs to (engine, model, effort, the engine's session). */
  chat: import("../shared/protocol").ChatMeta;
  /** The account this turn runs on (Claude Code / Codex): "default" is the Mac's own sign-in. */
  account?: string;
  /** Saves the engine's session id and token usage on the chat. */
  setEngineState(patch: { engine_session?: string; usage?: import("../shared/protocol").ChatUsage; connectors?: import("../shared/protocol").ChatConnector[] }): void;
  /** Resolves with the user's decision; false if denied or the turn is stopped. */
  approve(callId: string): Promise<boolean>;
  /** Turns the call's card into a question card and waits for the person's answer (skipped when nobody can answer or the turn stops). */
  askUser?(callId: string, questions: AskQuestion[], card?: { tool?: string; summary?: string }): Promise<AskResult>;
  /** Set for a Chief's own chat: its prompt and its only tools (MCP endpoint for Claude Code). */
  chief?: ChiefBrain;
  /** Device tools (browser) for engines that run outside the runtime (MCP over HTTP, this turn's token). */
  devices?: { url: string; token: string; note: string; describe(name: string, input: Record<string, unknown>): { summary: string; detail?: string } | undefined };
  toolEnd(callId: string, r: { output: string; is_error: boolean; denied?: boolean }): void;
  /** The engine's own plan changed (Codex turn/plan/updated, Claude TodoWrite): kept in the task ledger. */
  planUpdated?(steps: { step: string; status: unknown }[], explanation?: string): void;
  log?(line: string): void;
  /** The engine delivered input.handoff: how, and how many characters. */
  handoffSent?(via: "inject" | "message", chars: number): void;
}

export interface ChiefBrain {
  system: string;
  tools: Tool[];
  /** Where Claude Code reaches the same tools (MCP over HTTP, this turn's token). */
  mcp: { url: string; token: string };
}

export interface Engine {
  readonly id: string;
  /** Streams the reply through emit(); resolves when done or aborted. */
  run(input: EngineInput, emit: (delta: string) => void, host: TurnHost): Promise<void>;
}

const sleep = (ms: number, signal: AbortSignal): Promise<void> =>
  new Promise((resolve) => {
    const t = setTimeout(resolve, ms);
    signal.addEventListener("abort", () => {
      clearTimeout(t);
      resolve();
    }, { once: true });
  });

/** STUB engine: streams the user's text back, word by word. */
export class EchoEngine implements Engine {
  readonly id = "echo";
  constructor(private readonly delayMs = 15) {}
  async run({ text, signal }: EngineInput, emit: (delta: string) => void): Promise<void> {
    const reply = `Echo (no provider is set up — add one in Settings): ${text}`;
    for (const piece of reply.split(/(\s+)/)) {
      if (!piece) continue;
      await sleep(this.delayMs, signal);
      if (signal.aborted) return;
      emit(piece);
    }
  }
}

interface Running {
  turnId: string;
  controller: AbortController;
  /** Pending approval decisions by call id. */
  approvals: Map<string, (allowed: boolean, remember?: "allow" | "current") => void>;
  /** What the person asked to remember with a branch answer, by call id. */
  remembered: Map<string, "allow" | "current">;
  /** Which of a card's choices the person picked, by call id. */
  chosen: Map<string, string>;
  /** The choices each open card offered, by call id (only these ids are accepted). */
  offered: Map<string, ApprovalChoice[]>;
  /** Open question cards by call id. */
  questions: Map<string, { questions: AskQuestion[]; resolve: (r: AskResult) => void }>;
}

/** A question card shown after a turn ended (an agent that asked in its reply): its answer starts the next turn. */
interface LateCard { turnId: string; chatId: string; workspaceId: string; questions: AskQuestion[] }

export interface TurnDeps {
  /** Chosen per turn from the chat's engine, so a change applies to the next message. */
  engine(chat: ChatMeta): Engine;
  workspace(id: string): Workspace | undefined;
  chats: ChatStore;
  defaultMode(): PermissionMode;
  /** Memory notes for the prompt, and a way for the agent to save a draft. */
  memory?: { prompt(workspaceId: string): string; saveDraft(workspaceId: string, title: string, body: string): void };
  skills?: { catalog(workspaceId: string): { name: string; description: string }[]; read(workspaceId: string, name: string): string | undefined; files?(workspaceId: string): { name: string; description: string; path: string }[] };
  agents?: { catalog(workspaceId: string): { name: string; description: string }[]; get(workspaceId: string, name: string): { name: string; access: "read" | "edit" | "full"; body: string } | undefined };
  /** Extra tools (e.g. MCP, browser), resolved per turn for the built-in agent. */
  extraTools?: (scope: ToolScope) => Promise<Tool[]>;
  /** Device tools offered to outside engines (Claude Code, Codex) over MCP; none when no device is available. */
  devices?: { tools(scope: ToolScope): Tool[]; grants: DeviceGrants; url(): string };
  rootOf(w: Workspace): string;
  broadcast(n: RpcNotification): void;
  /** Sees every turn event (the Chief follows its workers this way). */
  observe?(ev: TurnEvent): void;
  /** A Chief's prompt and tools for a turn in its own chat; called once per turn. */
  chiefBrain?(chat: ChatMeta, turnId: string): ChiefBrain | undefined;
  /** Per-project branch rules (ask / stay on the current branch / allow new ones). */
  branches?: { get(workspaceId: string): BranchRule; set(workspaceId: string, rule: BranchRule): void };
  /** A chat's turn ended (any way): the place to remove skills it installed for that task. */
  turnEnded?(chatId: string): void;
  /** A chat was deleted. */
  chatDeleted?(chatId: string): void;
  /** Why nobody can answer a question card in this chat right now (a reason), or undefined when the person can. */
  noAsk?(chat: ChatMeta): string | undefined;
  /** The task ledger (what happened in each chat, kept by Opscode for hand-offs between engines). */
  ledger?: LedgerStore;
  /** H4: move a chat to the other engine when one runs out of its plan limit. */
  autoSwitch?: AutoSwitch;
  /** Which account a chat runs on (Claude Code / Codex), and what to do when a failure says "sign in again". */
  accounts?: { resolve(engine: AgentEngineId, chat: ChatMeta): string; touch(engine: AgentEngineId, id: string): void; authFailed(engine: AgentEngineId, id: string): void };
  log(line: string): void;
}

/** Which chat a turn's tools act for. */
export interface ToolScope {
  workspaceId: string;
  chatId: string;
  mode(): PermissionMode;
}

export class TurnManager {
  private readonly running = new Map<string, Running>(); // by chat
  private readonly known = new Map<string, string>(); // turn -> chat
  /** Chats whose person said "decide yourself" (voice mode): in auto mode only high-risk steps ask. */
  private readonly trustedChats = new Set<string>();

  /** Voice mode's "allow it yourself": in auto mode, medium-risk steps of this chat stop asking. */
  setTrusted(chatId: string, on: boolean): void { if (on) this.trustedChats.add(chatId); else this.trustedChats.delete(chatId); }
  private readonly done = new Map<string, { status: string; text: string; error?: string }>();
  /** Question cards from ended turns, by call id. */
  private readonly late = new Map<string, LateCard>();
  private readonly waiters = new Map<string, ((r: { status: string; text: string; error?: string }) => void)[]>();

  /** Resolves when the turn ends: completed, failed or interrupted, with the reply text. */
  whenDone(turnId: string): Promise<{ status: string; text: string; error?: string }> {
    const d = this.done.get(turnId);
    if (d) return Promise.resolve(d);
    return new Promise((resolve) => this.waiters.set(turnId, [...(this.waiters.get(turnId) ?? []), resolve]));
  }

  constructor(private readonly deps: TurnDeps) {}

  /** Ledger updates never break a turn. */
  private led(f: (l: LedgerStore) => void): void {
    const l = this.deps.ledger;
    if (!l) return;
    try { f(l); } catch (e) { this.deps.log(`ledger: ${e instanceof Error ? e.message : String(e)}`); }
  }

  /** The chat's task ledger, or undefined when nothing has happened in it yet. */
  ledger(chatId: string): LedgerView | undefined {
    return this.deps.ledger?.get(chatId);
  }

  private chatsChanged(): void {
    this.deps.broadcast({ method: "chat.changed", params: { chats: this.deps.chats.list() } });
  }

  /**
   * Starts a turn. Without chat_id it continues the project's most recent chat
   * (creating one if there is none).
   */
  submit(workspaceId: string, chatId: string | undefined, text: string, opts: { engineText?: string; event?: boolean; images?: string[]; attachments?: string[]; attachNote?: string; limitFrom?: string; requestId?: string } = {}): { turn_id: string; chat_id: string; engine: string } {
    const workspace = this.deps.workspace(workspaceId);
    if (!workspace) throw fail.notFound("no such workspace");
    let chat: ChatMeta | undefined;
    if (chatId !== undefined) {
      chat = this.deps.chats.get(chatId);
      if (!chat || chat.workspace_id !== workspaceId) throw fail.notFound("no such chat");
    } else {
      chat = this.deps.chats.latest(workspaceId) ?? this.deps.chats.create(workspaceId, this.deps.defaultMode());
    }
    const requestHash = opts.requestId ? createHash("sha256").update(JSON.stringify([text, opts.attachments ?? []])).digest("hex") : undefined;
    if (opts.requestId) {
      const prior = this.deps.chats.transcript(chat.id).find((message) => message.role === "user" && message.request_id === opts.requestId);
      if (prior) {
        if (prior.request_hash !== requestHash) throw fail.conflict("This request was already used for a different message.");
        return { turn_id: prior.turn_id, chat_id: chat.id, engine: chat.engine ?? "api" };
      }
    }
    if (this.running.has(chat.id)) throw fail.conflict("a turn is already running in this chat");
    const root = this.deps.rootOf(workspace); // throws if the folder vanished or was swapped
    // H4: the chat's engine is already at its plan limit: this turn starts on the other engine.
    let limitFrom = opts.limitFrom;
    if (!opts.event && !limitFrom) {
      try {
        const to = this.deps.autoSwitch?.beforeTurn(chat);
        if (to && chat.engine) {
          limitFrom = chat.engine;
          chat = this.switchEngine(chat, to);
        }
      } catch (e) { this.deps.log(`auto-switch check failed: ${String(e)}`); }
    }
    // The account this chat runs on is pinned on its first message with an engine and kept: later switches of the
    // active account apply to new chats only.
    const eng = chat.engine;
    if (this.deps.accounts && isAgentEngine(eng)) {
      try {
        const acct = this.deps.accounts.resolve(eng, chat);
        if (chat.accounts?.[eng] !== acct) chat = this.deps.chats.pinAccount(chat.id, eng, acct) ?? chat;
        this.deps.accounts.touch(eng, acct);
      } catch (e) { this.deps.log(`account pin failed: ${String(e)}`); }
    }
    const engine = this.deps.engine(chat);

    const turnId = randomUUID();
    const controller = new AbortController();
    const attached = opts.attachments?.length ? resolveAttached(root, opts.attachments) : [];
    const transcript = this.deps.chats.transcript(chat.id);
    const history = transcript.slice();
    transcript.push({ role: "user", text, turn_id: turnId, status: "complete", ...(opts.requestId ? { request_id: opts.requestId, request_hash: requestHash } : {}), ...(opts.event ? { event: true } : {}), ...(attached.length ? { attachments: attached.map((a) => ({ path: a.path, name: a.name, kind: a.kind, ...(a.files !== undefined ? { files: a.files } : {}), ...(a.ref ? { ref: true } : {}) })) } : {}) });
    const reply: ChatMessage = { role: "assistant", text: "", turn_id: turnId, status: "streaming", parts: [] };
    transcript.push(reply);
    if (transcript.length > LIMITS.TURN_HISTORY_MAX_MESSAGES) {
      transcript.splice(0, transcript.length - LIMITS.TURN_HISTORY_MAX_MESSAGES);
    }
    this.deps.chats.touch(chat.id, opts.event ? undefined : text);
    this.deps.chats.save(chat.id);
    const started = chat;
    // A hand-off: the chat's last turn was by another engine (decided before this turn is recorded).
    let handoff: HandoffPlan | null = null;
    try { handoff = this.deps.ledger ? planHandoff(this.deps.ledger.get(chat.id), engine.id, !!chat.engine_session) : null; } catch (e) { this.deps.log(`hand-off check failed: ${String(e)}`); }
    this.led((l) => l.turnStart(started.id, { turn_id: turnId, engine: engine.id, ...(started.model ? { model: started.model } : {}), ...(started.effort ? { effort: started.effort } : {}), text, root, ...(opts.event ? { event: true } : {}) }));
    this.chatsChanged();

    const running: Running = { turnId, controller, approvals: new Map(), remembered: new Map(), chosen: new Map(), offered: new Map(), questions: new Map() };
    // Stopping a turn denies anything still waiting for approval, and closes open questions.
    controller.signal.addEventListener("abort", () => {
      for (const resolve of running.approvals.values()) resolve(false);
      running.approvals.clear();
      for (const q of running.questions.values()) q.resolve({ skipped: true, reason: "The turn was stopped." });
      running.questions.clear();
    }, { once: true });
    // A new message answers a question card left open by the last turn (the agent asked in its reply).
    for (const [id, late] of this.late) if (late.chatId === chat.id) this.late.delete(id);
    this.running.set(chat.id, running);
    this.known.set(turnId, chat.id);
    const chatIdFinal = chat.id;
    // Start after this call's response is sent, so clients learn the turn_id first.
    const engineText = (opts.engineText ?? text) + (attached.length ? (opts.attachNote ?? attachedNote(attached)) : "");
    const images = [...new Set([...(opts.images ?? []).filter((x) => x.startsWith(root + "/")), ...attached.filter((a) => a.kind === "image").map((a) => a.abs)])].slice(0, 12);
    setImmediate(() => void this.run({ engine, workspace, chatId: chatIdFinal, root, running, turnId, text: engineText, history, reply, images, handoff, event: !!opts.event, ...(limitFrom ? { limitFrom } : {}) }));
    return { turn_id: turnId, chat_id: chat.id, engine: engine.id };
  }

  /** The user's decision on a tool call that asked for approval. */
  approve(turnId: string, callId: string, allow: boolean, remember?: "allow" | "current", choice?: string): { resolved: boolean } {
    const chatId = this.known.get(turnId);
    if (chatId === undefined) throw fail.notFound("no such turn");
    const r = this.running.get(chatId);
    const resolve = r?.turnId === turnId ? r.approvals.get(callId) : undefined;
    if (!r || !resolve) return { resolved: false };
    const offered = r.offered.get(callId);
    if (allow && offered?.length) {
      // Only a choice the card offered counts. An answer with none picked takes the narrowest one (a task-only install).
      const pick = choice !== undefined ? offered.find((c) => c.id === choice) : (offered.find((c) => c.id === "temp") ?? offered[0]);
      if (!pick) throw fail.invalid(`this card offers: ${offered.map((c) => c.id).join(", ")}`);
      r.chosen.set(callId, pick.id);
    }
    r.offered.delete(callId);
    r.approvals.delete(callId);
    resolve(allow, remember);
    return { resolved: true };
  }

  /**
   * The person's answer to a question card: answers per question, or skip. A card from a turn that already ended
   * (the agent asked in its reply) is answered by sending the answer as the chat's next message.
   */
  answer(turnId: string, callId: string, answers: AskAnswer[] | undefined, skip: boolean): { resolved: boolean; turn_id?: string; text?: string } {
    const chatId = this.known.get(turnId);
    if (chatId === undefined) throw fail.notFound("no such turn");
    const r = this.running.get(chatId);
    const open = r?.turnId === turnId ? r.questions.get(callId) : undefined;
    const late = open ? undefined : this.late.get(callId);
    const questions = open?.questions ?? (late?.turnId === turnId ? late.questions : undefined);
    if (!questions) return { resolved: false };
    if (!skip) {
      if (!answers?.length) throw fail.invalid("give answers, or skip");
      const bad = checkAnswers(questions, answers);
      if (bad) throw fail.invalid(bad);
    }
    const result: AskResult = skip ? { skipped: true, reason: "The user skipped the question." } : { answers: answers ?? [] };
    if (open && r) {
      r.questions.delete(callId);
      open.resolve(result);
      return { resolved: true };
    }
    if (!late) return { resolved: false };
    this.late.delete(callId);
    this.markAnswered(late.chatId, callId, result);
    if (this.running.has(late.chatId)) throw fail.conflict("a turn is already running in this chat");
    const text = answerMessage(questions, result);
    const next = this.submit(late.workspaceId, late.chatId, text);
    return { resolved: true, turn_id: next.turn_id, text };
  }

  /** Records an answer on the card in the chat's transcript (for a card from an ended turn). */
  private markAnswered(chatId: string, callId: string, result: AskResult): void {
    for (const m of this.deps.chats.transcript(chatId)) {
      const p = m.parts?.find((x): x is Extract<MessagePart, { kind: "tool" }> => x.kind === "tool" && x.call_id === callId);
      if (!p) continue;
      p.status = "done";
      if ("skipped" in result) p.skipped = true; else p.answers = result.answers;
      p.output = "skipped" in result ? "Skipped" : result.answers.map(answerText).join("; ");
      this.deps.chats.save(chatId);
      return;
    }
  }

  /** Stops a running turn. False if it had already finished. */
  interrupt(turnId: string): { interrupted: boolean } {
    const chatId = this.known.get(turnId);
    if (chatId === undefined) throw fail.notFound("no such turn");
    const r = this.running.get(chatId);
    if (!r || r.turnId !== turnId) return { interrupted: false };
    r.controller.abort();
    return { interrupted: true };
  }

  /** Chat ids with a turn in progress. */
  runningChats(): string[] {
    return [...this.running.keys()];
  }

  history(chatId: string): ChatMessage[] {
    return this.deps.chats.transcript(chatId).map((m) => ({ ...m, ...(m.parts ? { parts: m.parts.map((p) => ({ ...p })) } : {}) }));
  }

  /** Stops the chat's turn (if any) and deletes it. */
  deleteChat(chatId: string): boolean {
    this.running.get(chatId)?.controller.abort();
    const ok = this.deps.chats.remove(chatId);
    if (ok) { this.led((l) => l.remove(chatId)); this.chatsChanged(); try { this.deps.chatDeleted?.(chatId); } catch (e) { this.deps.log(`chat delete hook failed: ${String(e)}`); } }
    return ok;
  }

  /** Workspace removed: stop its turns and drop its chats. */
  forget(workspaceId: string): void {
    for (const c of this.deps.chats.list(workspaceId)) this.running.get(c.id)?.controller.abort();
    this.deps.chats.removeWorkspace(workspaceId);
    this.chatsChanged();
  }

  abortAll(): void {
    for (const r of this.running.values()) r.controller.abort();
    this.deps.chats.flush();
  }

  private async run(o: {
    engine: Engine;
    workspace: Workspace;
    chatId: string;
    root: string;
    running: Running;
    turnId: string;
    text: string;
    history: ChatMessage[];
    reply: ChatMessage;
    images?: string[];
    handoff?: HandoffPlan | null;
    event?: boolean;
    /** H4: this turn runs here because that engine ran out of its limit. */
    limitFrom?: string;
  }): Promise<void> {
    const { engine, workspace, chatId, root, running, turnId, text, history, reply, images } = o;
    const signal = running.controller.signal;
    const parts = (reply.parts ??= []);
    let seq = 0;
    const emit = (type: TurnEventType, extra: Partial<TurnEvent> = {}): void => {
      const params: TurnEvent = { turn_id: turnId, chat_id: chatId, workspace_id: workspace.id, seq: seq++, type, ...extra };
      this.deps.broadcast({ method: "turn.event", params });
      try { this.deps.observe?.(params); } catch (e) { this.deps.log(`turn observer failed: ${e instanceof Error ? e.message : String(e)}`); }
    };
    const toolPart = (callId: string): Extract<MessagePart, { kind: "tool" }> | undefined =>
      parts.find((p): p is Extract<MessagePart, { kind: "tool" }> => p.kind === "tool" && p.call_id === callId);
    const clip = (s: string): string => (s.length > 8000 ? `${s.slice(0, 8000)}\n… (output shortened)` : s);

    const meta = this.deps.chats.get(chatId);
    const chief = meta?.chief?.role === "home" || meta?.voice ? this.deps.chiefBrain?.(meta, turnId) : undefined;
    const scope: ToolScope = { workspaceId: workspace.id, chatId, mode: () => this.deps.chats.get(chatId)?.mode ?? "supervised" };
    let extraTools: Tool[] = [];
    // A Chief has only its own tools, so it starts no MCP servers.
    if (!chief) {
      try {
        extraTools = (await this.deps.extraTools?.(scope)) ?? [];
      } catch (e) {
        this.deps.log(`extra tools unavailable: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
    const host: TurnHost = {
      root,
      workspaceName: workspace.name,
      mode: () => this.deps.chats.get(chatId)?.mode ?? "supervised",
      trusted: () => this.trustedChats.has(chatId),
      memory: this.deps.memory?.prompt(workspace.id) ?? "",
      extraTools,
      skills: this.deps.skills?.catalog(workspace.id) ?? [],
      skillFiles: this.deps.skills?.files?.(workspace.id) ?? [],
      readSkill: (name) => this.deps.skills?.read(workspace.id, name),
      agents: this.deps.agents?.catalog(workspace.id) ?? [],
      getAgent: (name) => this.deps.agents?.get(workspace.id, name),
      saveNote: (title, body) => {
        if (!this.deps.memory) throw new Error("memory is not available");
        this.deps.memory.saveDraft(workspace.id, title, body);
      },
      toolStart: (c, needsApproval) => {
        this.led((l) => l.toolStart(chatId, c));
        const choices = needsApproval && c.choices?.length ? c.choices : undefined;
        if (choices) running.offered.set(c.call_id, choices);
        parts.push({ kind: "tool", call_id: c.call_id, tool: c.tool, summary: c.summary, ...(c.detail ? { detail: c.detail } : {}), ...(choices ? { choices } : {}), status: needsApproval ? "awaiting_approval" : "running" });
        emit("tool_start", { call_id: c.call_id, tool: c.tool, summary: c.summary, ...(c.detail ? { detail: c.detail } : {}) });
        if (needsApproval) emit("approval_request", { call_id: c.call_id, tool: c.tool, summary: c.summary, detail: c.detail, ...(choices ? { choices } : {}) });
      },
      chat: { ...(this.deps.chats.get(chatId) as ChatMeta) },
      ...(this.deps.accounts && isAgentEngine(engine.id) ? { account: this.deps.accounts.resolve(engine.id, this.deps.chats.get(chatId) as ChatMeta) } : {}),
      ...(chief ? { chief } : {}),
      setEngineState: (patch) => {
        this.deps.chats.setEngineState(chatId, patch);
        this.chatsChanged();
      },
      askApproval: (callId, card) => {
        const part = toolPart(callId);
        if (part) {
          part.status = "awaiting_approval";
          // The engine's card was made from the call's arguments; the tool may know more by now (what it is, where from).
          if (card) { part.summary = card.summary; if (card.detail) part.detail = card.detail; if (card.choices?.length) part.choices = card.choices; }
        }
        if (card?.choices?.length) running.offered.set(callId, card.choices);
        emit("approval_request", { call_id: callId, tool: part?.tool ?? "tool",
          summary: card?.summary ?? part?.summary, detail: card?.detail ?? part?.detail,
          choices: card?.choices ?? part?.choices });
        return host.approve(callId);
      },
      choiceOf: (callId) => running.chosen.get(callId),
      askUser: async (callId, questions, card) => {
        const nobody = this.deps.noAsk?.(this.deps.chats.get(chatId) ?? (host.chat as ChatMeta)) ?? defaultNoAsk(this.deps.chats.get(chatId));
        let part = toolPart(callId);
        if (!part) {
          host.toolStart({ call_id: callId, tool: card?.tool ?? "ask_user", summary: card?.summary ?? questionSummary(questions) }, false);
          part = toolPart(callId);
        }
        if (nobody || signal.aborted) {
          const reason = signal.aborted ? "The turn was stopped." : nobody!;
          if (part) { part.questions = questions; part.skipped = true; }
          return { skipped: true, reason };
        }
        if (part) { part.status = "awaiting_answer"; part.questions = questions; part.summary = card?.summary ?? questionSummary(questions); }
        this.deps.chats.save(chatId);
        emit("question", { call_id: callId, tool: part?.tool ?? "ask_user", summary: part?.summary ?? questionSummary(questions), questions });
        const result = await new Promise<AskResult>((resolve) => running.questions.set(callId, { questions, resolve }));
        if (part) {
          part.status = "running";
          if ("skipped" in result) part.skipped = true; else part.answers = result.answers;
        }
        this.deps.chats.save(chatId);
        emit("question_answered", { call_id: callId, ...("skipped" in result ? { skipped: true } : { answers: result.answers }) });
        return result;
      },
      branch: {
        policy: () => this.deps.branches?.get(workspace.id) ?? "ask",
        current: () => currentBranch(root),
        remember: (rule) => { try { this.deps.branches?.set(workspace.id, rule); } catch (e) { this.deps.log(`could not save the branch rule: ${String(e)}`); } },
      },
      askBranch: async (callId, info) => {
        const part = toolPart(callId);
        if (part) {
          part.status = "awaiting_approval";
          part.summary = `Create branch ${info.names.join(", ")}`;
          part.branch = info;
        }
        emit("approval_request", { call_id: callId, tool: part?.tool ?? "tool", summary: `Create branch ${info.names.join(", ")}`, branch: info });
        const allow = await host.approve(callId);
        const remember = running.remembered.get(callId);
        running.remembered.delete(callId);
        return { allow, ...(remember ? { remember } : {}) };
      },
      approve: (callId) =>
        new Promise<boolean>((resolve) => {
          if (signal.aborted) return resolve(false);
          running.approvals.set(callId, (allowed, remember) => {
            if (remember) running.remembered.set(callId, remember);
            const part = toolPart(callId);
            if (part) part.status = allowed ? "running" : "denied";
            emit("approval_resolved", { call_id: callId, approved: allowed });
            resolve(allowed);
          });
        }),
      log: (line) => this.deps.log(line),
      handoffSent: (via, chars) => {
        if (!o.handoff) return;
        const info = { kind: o.handoff.kind, from: o.handoff.from, to: o.handoff.to, tokens: Math.ceil(chars / 4), via, ...(o.limitFrom ? { reason: "limit" as const } : {}) };
        reply.handoff = info;
        emit("handoff", { handoff: info });
      },
      planUpdated: (steps, explanation) => this.led((l) => l.setPlan(chatId, steps, explanation)),
      toolEnd: (callId, r) => {
        this.led((l) => l.toolEnd(chatId, callId, r));
        const part = toolPart(callId);
        const output = clip(r.output);
        if (part) {
          part.status = r.denied ? "denied" : r.is_error ? "error" : "done";
          part.output = output;
        }
        this.deps.chats.save(chatId);
        emit("tool_end", { call_id: callId, output, is_error: r.is_error, ...(r.denied ? { approved: false } : {}) });
      },
    };

    // Outside engines reach the device tools over MCP with a token that lives for this turn only.
    let deviceToken: string | undefined;
    const devTools = !chief && this.deps.devices ? this.deps.devices.tools(scope) : [];
    if (devTools.length && this.deps.devices) {
      const claimed = new Set<string>();
      deviceToken = this.deps.devices.grants.issue(devTools, {
        root,
        mode: scope.mode,
        claimCall: (name) => {
          for (let i = parts.length - 1; i >= 0; i--) {
            const p = parts[i];
            if (p.kind !== "tool" || p.status !== "running" || claimed.has(p.call_id)) continue;
            if (p.tool === name || p.tool.endsWith(`__${name}`) || (p.tool === "mcp" && p.summary.endsWith(` · ${name}`))) {
              claimed.add(p.call_id);
              return p.call_id;
            }
          }
          return undefined;
        },
        toolStart: host.toolStart,
        toolEnd: host.toolEnd,
        approve: host.approve,
        askApproval: host.askApproval,
        choiceOf: host.choiceOf,
        ...(host.askUser ? { askUser: host.askUser } : {}),
      });
      host.devices = { url: this.deps.devices.url(), token: deviceToken, note: devicesNote(devTools.map((t) => t.def.name)), describe: (name, input) => devTools.find((t) => t.def.name === name)?.describe(input) };
    }

    // The hand-off pack, from the ledger as it was before this turn (the user's new message is the turn itself).
    let handoffInput: EngineInput["handoff"];
    if (o.handoff && this.deps.ledger) {
      try {
        const l = this.deps.ledger.get(chatId);
        if (l) {
          if (!o.event) l.user_messages = l.user_messages.slice(0, -1);
          const git = await gitSummary(root);
          handoffInput = {
            kind: o.handoff.kind,
            text: buildPack(l, chatId, o.handoff, { git, withMessages: true }),
            bare: buildPack(l, chatId, o.handoff, { git, withMessages: false }),
            messages: o.handoff.kind === "full" ? recentMessages(history) : [],
          };
          this.deps.log(`hand-off ${o.handoff.kind} ${o.handoff.from} -> ${o.handoff.to}: ~${tokensOf(handoffInput.text)} tokens`);
        }
      } catch (e) { this.deps.log(`hand-off pack failed, using plain history: ${String(e)}`); }
    }

    emit("started", { engine: engine.id });
    // Moved for a limit with nothing to hand over (a new chat): still say why it runs here.
    if (o.limitFrom && !handoffInput) {
      const info = { kind: "full" as const, from: o.limitFrom, to: engine.id, tokens: 0, via: "message" as const, reason: "limit" as const };
      reply.handoff = info;
      emit("handoff", { handoff: info });
    }
    // A nearly full disk breaks builds and saving: say so once per turn, at the start and while it runs.
    let diskWarned = false;
    const checkDisk = (): void => {
      if (diskWarned || signal.aborted) return;
      const card = lowDiskCard(root);
      if (!card) return;
      diskWarned = true;
      const id = `disk-${turnId}`;
      host.toolStart({ call_id: id, tool: "disk_space", summary: card.summary, detail: card.detail }, false);
      host.toolEnd(id, { output: card.detail, is_error: true });
    };
    checkDisk();
    const diskTimer = setInterval(checkDisk, DISK_CHECK_MS);
    diskTimer.unref();
    try {
      await engine.run({ text, history, signal, ...(images?.length ? { images } : {}), ...(handoffInput ? { handoff: handoffInput } : {}) }, (delta) => {
        reply.text += delta;
        const last = parts[parts.length - 1];
        if (last?.kind === "text") last.text += delta;
        else parts.push({ kind: "text", text: delta });
        emit("delta", { text: delta });
      }, host);
      if (signal.aborted) {
        reply.status = "interrupted";
        emit("interrupted");
      } else {
        reply.status = "complete";
        emit("completed", { text: reply.text });
      }
    } catch (e) {
      reply.status = signal.aborted ? "interrupted" : "failed";
      if (signal.aborted) emit("interrupted");
      else {
        let message = e instanceof Error ? e.message : String(e);
        this.deps.log(`turn ${turnId} failed: ${message}`);
        // "Not logged in" and the like: say where to fix it, and have the account list re-read who is signed in.
        const eid = engine.id;
        if (this.deps.accounts && isAgentEngine(eid) && isAuthError(message) && !isLimitError(message)) {
          message = `${message}\n\nSign in again: Settings → Models & keys.`;
          try { this.deps.accounts.authFailed(eid, this.deps.accounts.resolve(eid, this.deps.chats.get(chatId) as ChatMeta)); } catch { /* best effort */ }
        }
        reply.error = message;
        emit("failed", { error: message });
      }
    } finally {
      clearInterval(diskTimer);
      if (deviceToken) this.deps.devices?.grants.revoke(deviceToken);
      this.led((l) => l.turnEnd(chatId, { turn_id: turnId, status: reply.status ?? "failed", reply: reply.text, ...(reply.error ? { error: reply.error } : {}) }));
      try { this.deps.turnEnded?.(chatId); } catch (e) { this.deps.log(`turn end hook failed: ${String(e)}`); }
      // Anything still shown as running/awaiting did not finish.
      for (const p of parts) {
        if (p.kind !== "tool") continue;
        if (p.status === "awaiting_answer") { p.status = "done"; p.skipped = true; }
        else if (p.status === "running" || p.status === "awaiting_approval") p.status = "error";
      }
      const r = this.running.get(chatId);
      if (r?.turnId === turnId) this.running.delete(chatId);
      // The agent asked in its reply (a "Questions:" block, the backup for agents without ask_user): show the same card;
      // its answer is sent as the next message.
      try {
        const asked = parts.some((p) => p.kind === "tool" && !!p.questions);
        const meta = this.deps.chats.get(chatId);
        const qs = reply.status === "complete" && !asked && meta && !(this.deps.noAsk?.(meta) ?? defaultNoAsk(meta)) ? parseQuestionBlock(reply.text) : [];
        if (qs.length) {
          const callId = `ask-${turnId}`;
          const summary = questionSummary(qs);
          parts.push({ kind: "tool", call_id: callId, tool: "ask_user", summary, status: "awaiting_answer", questions: qs });
          this.late.set(callId, { turnId, chatId, workspaceId: workspace.id, questions: qs });
          if (this.late.size > 100) this.late.delete(this.late.keys().next().value as string);
          emit("question", { call_id: callId, tool: "ask_user", summary, questions: qs });
        }
      } catch (e) { this.deps.log(`question block failed: ${String(e)}`); }
      const result = { status: reply.status, text: reply.text, ...(reply.error ? { error: reply.error } : {}) };
      this.done.set(turnId, result);
      if (this.done.size > 200) this.done.delete(this.done.keys().next().value as string);
      for (const w of this.waiters.get(turnId) ?? []) w(result);
      this.waiters.delete(turnId);
      this.deps.chats.touch(chatId);
      this.deps.chats.save(chatId);
      this.chatsChanged();
      // H4: the turn failed on a plan limit: move the chat to the other engine and carry on there.
      if (reply.status === "failed") {
        try {
          const meta = this.deps.chats.get(chatId);
          const to = this.deps.autoSwitch?.afterFailure(meta, reply.error, !!o.limitFrom && !!o.event);
          if (to && meta?.engine) {
            const from = meta.engine;
            this.switchEngine(meta, to);
            this.deps.log(`auto-switch: ${from} hit its limit in chat ${chatId}; continuing on ${to}`);
            setImmediate(() => {
              try { this.submit(workspace.id, chatId, "Continue the task from where it stopped.", { event: true, limitFrom: from }); }
              catch (e) { this.deps.log(`auto-switch continue failed: ${String(e)}`); }
            });
          }
        } catch (e) { this.deps.log(`auto-switch failed: ${String(e)}`); }
      }
    }
  }

  /** Moves a chat to another engine (keeping the model it last used there) and tells the clients. */
  private switchEngine(chat: ChatMeta, to: "claude-code" | "codex"): ChatMeta {
    const model = lastModelOn(this.deps.ledger?.get(chat.id), to);
    const next = this.deps.chats.setEngine(chat.id, { engine: to, ...(model ? { model } : {}) }) ?? chat;
    this.chatsChanged();
    return next;
  }
}
