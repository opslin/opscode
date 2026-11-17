// RPC method registry. Every method validates its params (unknown keys are
// rejected), and every method except runtime.hello requires a completed hello.

import { randomUUID } from "node:crypto";
import {
  PERMISSION_MODES,
  ErrorCode,
  LIMITS,
  MIN_CLIENT_REVISION,
  PROTOCOL_REVISION,
  type Hello,
  type RpcNotification,
  type Settings,
  type Workspace,
} from "../shared/protocol";
import { listDir, readFile, writeFile } from "./files";
import { BRANCH_RULES, type BranchRules } from "./engines/branchGuard";
import { importPaths, saveBlob, thumbnail, voiceNotePath, LIMITS as ATTACH_LIMITS } from "./attachments";
import { resolveExisting, rootOf } from "./paths";
import {
  isRecord as isRecordLike,
  bool,
  fail,
  id,
  int,
  list,
  method,
  num,
  object,
  oneOf,
  optional,
  RpcFailure,
  str,
  type AnyMethod,
  type Check,
} from "./rpc";
import { SettingsStore, validateSettingsPatch } from "./settings";
import type { TerminalManager } from "./terminals";
import { PROVIDER_IDS, type ProviderStore } from "./agent/providers";
import type { McpManager } from "./mcp";
import { DENIED_APP_NAMES, isDenied, type ComputerStore, type Driver } from "./computer";
import { execFile } from "node:child_process";
import type { MemoryStore } from "./memory";
import type { ChatStore } from "./chats";
import type { PluginStore } from "./plugins";
import type { SkillSet } from "./skillset";
import { ACCESS_LEVELS, AGENT_NAME, type AgentSet } from "./agentfiles";
import { SKILL_NAME } from "./skills";
import { alreadyHere, apply, scan as scanImports, type ImportItem } from "./importer";
import { MODES, MODE_IDS } from "./chief/modes";
import { STAGE_IDS } from "./chief/pipeline";
import { measureStart } from "./engines/startcost";
import { ActionStore, ACTION_ICONS, changes as gitChanges, envInfo, remoteCheck, localServers, readProjectActions, searchFiles, suggestActions } from "./project";
import { EFFORTS, type EngineStore } from "./engines/detect";
import type { CodexEngine } from "./engines/codex";
import { MCP_CATALOG, catalogSecrets } from "./mcpCatalog";
import type { ChiefManager } from "./chief/manager";
import type { AutomationRunner } from "./automations/runner";
import { TEMPLATES } from "./automations/templates";
import { NAME as AUTO_NAME } from "./automations/spec";
import type { TurnManager } from "./turns";
import type { WorkspaceStore } from "./workspaces";

export { RpcFailure };
export type { AnyMethod, CallContext } from "./rpc";

export interface MethodDeps {
  version: string;
  settings: SettingsStore;
  workspaces: WorkspaceStore;
  terminals: TerminalManager;
  turns: TurnManager;
  providers: ProviderStore;
  memory: MemoryStore;
  chats: ChatStore;
  plugins: PluginStore;
  skillset: SkillSet;
  branches: BranchRules;
  agents: AgentSet;
  actions: ActionStore;
  engines: { store: EngineStore; codex: CodexEngine; acp: Record<"antigravity" | "qoder", import("./engines/acp").AcpEngine>; refresher: import("./engines/refresh").EngineRefresher; limits?: import("./engines/limits").LimitsStore; accounts?: import("./engines/accounts").AccountStore };
  imageGen?: import("./imagegen").ImageGen;
  usage?: import("./usage").UsageService;
  library?: import("./library").LibraryService;
  automations(): AutomationRunner;
  chief(): ChiefManager;
  mcp: McpManager;
  computer: { store: ComputerStore; driver: Driver | undefined };
  devices(): import("./devices/bridge").DeviceBridge;
  voice: import("./voice").VoiceService;
  tts: import("./tts").TtsService;
  voiceAgent(): import("./voiceagent").VoiceAgentService;
  ios(): import("./devices/ios").IosSimulators | undefined;
  broadcast(notification: RpcNotification): void;
}

const relPath = str({ max: LIMITS.PATH_MAX_CHARS });
const cols = int(2, 500);
const rows = int(1, 300);
const settingsPatch: Check<Partial<Settings>> = (v) => validateSettingsPatch(v);

export function buildMethods(deps: MethodDeps): Map<string, AnyMethod> {
  const m = new Map<string, AnyMethod>();
  const def = (name: string, a: AnyMethod): void => void m.set(name, a);

  const workspaceOr404 = (workspaceId: string): Workspace => {
    const w = deps.workspaces.get(workspaceId);
    if (!w) throw fail.notFound("no such workspace");
    return w;
  };
  const notesChanged = (): void => deps.broadcast({ method: "memory.changed", params: { notes: deps.memory.list() } });
  const guardNote = <T,>(fn: () => T): T => {
    try {
      return fn();
    } catch (e) {
      if (e instanceof RpcFailure) throw e;
      throw fail.invalid(e instanceof Error ? e.message : String(e));
    }
  };
  const changed = (): void =>
    deps.broadcast({ method: "workspace.changed", params: { workspaces: deps.workspaces.list() } });

  // ---- runtime --------------------------------------------------------------
  def(
    "runtime.hello",
    method(false, object({ client_revision: int(0, 1_000_000) }), (p, ctx): Hello => {
      if (p.client_revision < MIN_CLIENT_REVISION) {
        throw new RpcFailure(ErrorCode.CLIENT_TOO_OLD, "client is older than this runtime supports", {
          min_client_revision: MIN_CLIENT_REVISION,
        });
      }
      ctx.markHello();
      return {
        version: deps.version,
        protocol_revision: PROTOCOL_REVISION,
        min_client_revision: MIN_CLIENT_REVISION,
        capabilities: ["ping", "settings", "workspace", "fs", "term", "turn"],
        session_id: ctx.sessionId,
      };
    }),
  );
  def(
    "runtime.ping",
    method(true, object({ sent_at: optional(num) }), (p) => ({
      pong: true,
      at: Date.now(),
      echo: p.sent_at ?? null,
      id: randomUUID(),
    })),
  );

  // ---- settings -------------------------------------------------------------
  def("settings.get", method(true, object({}), () => ({ settings: deps.settings.get() })));
  def(
    "settings.set",
    method(true, object({ patch: settingsPatch }), (p) => {
      const settings = deps.settings.update(p.patch);
      deps.broadcast({ method: "settings.changed", params: { settings } });
      return { settings };
    }),
  );

  // ---- workspace ------------------------------------------------------------
  def("workspace.list", method(true, object({}), () => ({ workspaces: deps.workspaces.list() })));
  def(
    "workspace.add",
    method(true, object({ path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }) }), (p) => {
      const result = deps.workspaces.add(p.path);
      if (result.created) changed();
      return result;
    }),
  );
  def(
    "workspace.remove",
    method(true, object({ workspace_id: id }), (p) => {
      if (!deps.workspaces.remove(p.workspace_id)) throw fail.notFound("no such workspace");
      try { deps.chief().projectRemoved(p.workspace_id); } catch { /* no Conductors yet */ }
      deps.terminals.closeWorkspace(p.workspace_id);
      deps.turns.forget(p.workspace_id);
      if (deps.memory.forgetScope(p.workspace_id) > 0) notesChanged();
      deps.actions.forget(p.workspace_id);
      changed();
      return { removed: true };
    }),
  );

  // ---- fs (always relative to the workspace root) -------------------------
  def(
    "fs.list",
    method(true, object({ workspace_id: id, path: optional(relPath) }), (p) =>
      listDir(rootOf(workspaceOr404(p.workspace_id)), p.path ?? ""),
    ),
  );
  def(
    "fs.read",
    method(
      true,
      object({ workspace_id: id, path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }), max_bytes: optional(int(1, LIMITS.FS_IO_MAX_BYTES)) }),
      (p) => readFile(rootOf(workspaceOr404(p.workspace_id)), p.path, p.max_bytes),
    ),
  );
  def(
    "fs.write",
    method(
      true,
      object({
        workspace_id: id,
        path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }),
        // base64 of the byte cap is ~1.34x larger
        content: str({ max: Math.ceil((LIMITS.FS_IO_MAX_BYTES * 4) / 3) + 4, allowNul: true }),
        encoding: optional(oneOf("utf8", "base64")),
        create_dirs: optional(bool),
      }),
      (p) => {
        const root = rootOf(workspaceOr404(p.workspace_id));
        let bytes: Buffer;
        if (p.encoding === "base64") {
          if (!/^[A-Za-z0-9+/]*={0,2}$/.test(p.content) || p.content.length % 4 !== 0) {
            throw fail.invalid("content is not valid base64");
          }
          bytes = Buffer.from(p.content, "base64");
        } else {
          bytes = Buffer.from(p.content, "utf8");
        }
        return writeFile(root, p.path, bytes, p.create_dirs ?? false);
      },
    ),
  );

  // ---- terminals ------------------------------------------------------------
  def(
    "term.open",
    method(
      true,
      object({
        workspace_id: id,
        cols: optional(cols),
        rows: optional(rows),
        command: optional(str({ min: 1, max: 8192 })),
        cwd: optional(relPath),
      }),
      (p, ctx) => {
        const root = rootOf(workspaceOr404(p.workspace_id));
        const cwd = resolveExisting(root, p.cwd ?? "").abs;
        return deps.terminals.open({
          workspaceId: p.workspace_id,
          cwd,
          cols: p.cols ?? 80,
          rows: p.rows ?? 24,
          command: p.command,
          sessionId: ctx.sessionId,
        });
      },
    ),
  );
  def(
    "term.write",
    method(true, object({ terminal_id: id, data: str({ min: 1, max: LIMITS.TERM_WRITE_MAX_CHARS, allowNul: true }) }), (p) => {
      deps.terminals.write(p.terminal_id, p.data);
      return {};
    }),
  );
  def(
    "term.resize",
    method(true, object({ terminal_id: id, cols, rows }), (p) => deps.terminals.resize(p.terminal_id, p.cols, p.rows)),
  );
  def(
    "term.attach",
    method(true, object({ terminal_id: id }), (p, ctx) => deps.terminals.attach(p.terminal_id, ctx.sessionId)),
  );
  def(
    "term.detach",
    method(true, object({ terminal_id: id }), (p, ctx) => {
      deps.terminals.detach(p.terminal_id, ctx.sessionId);
      return {};
    }),
  );
  def(
    "term.close",
    method(true, object({ terminal_id: id }), (p) => {
      deps.terminals.close(p.terminal_id);
      return { closed: true };
    }),
  );
  def(
    "term.list",
    method(true, object({ workspace_id: optional(id) }), (p) => ({ terminals: deps.terminals.list(p.workspace_id) })),
  );

  // ---- turns ----------------------------------------------------------------
  def(
    "turn.submit",
    method(true, object({ workspace_id: id, chat_id: optional(id), text: str({ min: 1, max: LIMITS.TURN_TEXT_MAX_CHARS }), attachments: optional(list(str({ min: 1, max: 1024 }), ATTACH_LIMITS.PER_MESSAGE)) }), (p) => {
      workspaceOr404(p.workspace_id);
      if (!p.text.trim()) throw fail.invalid("text must not be blank");
      return deps.turns.submit(p.workspace_id, p.chat_id, p.text, p.attachments?.length ? { attachments: p.attachments } : {});
    }),
  );
  // A Conductor's own chat runs in a private home folder (id "chief:<id>"); attachments for it live there.
  const attachRootOf = (workspaceId: string): string => {
    const home = workspaceId.startsWith("chief:") ? deps.chief?.()?.homeWorkspace(workspaceId) : undefined;
    return rootOf(home ?? workspaceOr404(workspaceId));
  };
  // Attachments: photos, files and folders the person adds to a message. They are copied into the project
  // (.opscode/attachments) so every engine and Conductor worker opens them the same way.
  def(
    "attachment.add",
    method(true, object({ workspace_id: id, paths: optional(list(str({ min: 1, max: 4096 }), ATTACH_LIMITS.PER_MESSAGE)), name: optional(str({ min: 1, max: 200 })), data: optional(str({ min: 1, max: 1_900_000 })) }), (p) => {
      const root = attachRootOf(p.workspace_id);
      try {
        if (p.data !== undefined) return { items: [saveBlob(root, p.name ?? "pasted-image.png", Buffer.from(p.data, "base64"))] };
        if (!p.paths?.length) throw new Error("nothing to attach");
        return { items: importPaths(root, p.paths) };
      } catch (e) { throw fail.invalid(e instanceof Error ? e.message : String(e)); }
    }),
  );
  def(
    "attachment.thumb",
    method(true, object({ workspace_id: id, path: str({ min: 1, max: 1024 }) }), (p) => ({ data_url: thumbnail(attachRootOf(p.workspace_id), p.path) ?? null })),
  );
  def(
    "turn.approve",
    method(true, object({ turn_id: id, call_id: id, allow: bool, remember: optional(oneOf("allow", "current")) }), (p) => deps.turns.approve(p.turn_id, p.call_id, p.allow, p.remember)),
  );
  // The project's rule for new git branches: ask (default), stay on the current branch, or allow new ones.
  def("branch.rule", method(true, object({ workspace_id: id }), (p) => { workspaceOr404(p.workspace_id); return { rule: deps.branches.get(p.workspace_id) }; }));
  def("branch.rule.set", method(true, object({ workspace_id: id, rule: oneOf(...BRANCH_RULES) }), (p) => { workspaceOr404(p.workspace_id); deps.branches.set(p.workspace_id, p.rule); return { rule: p.rule }; }));
  def(
    "turn.interrupt",
    method(true, object({ turn_id: id }), (p) => deps.turns.interrupt(p.turn_id)),
  );
  // Voice input (Apple's on-device speech recognition). Events come as `voice.event` { session, ev, ... }.
  def("voice.status", method(true, object({}), () => deps.voice.status()));
  def("voice.locales", method(true, object({}), () => deps.voice.locales()));
  def(
    "voice.start",
    method(true, object({ workspace_id: optional(id), note: optional(bool) }), (p) => {
      const ws = p.workspace_id ? deps.workspaces.get(p.workspace_id) : undefined;
      // A voice note also keeps the recording, inside the project (git-ignored), to attach to the message.
      let record: string | undefined;
      if (p.note) {
        if (!ws) throw fail.invalid("a voice note needs a project");
        try { record = voiceNotePath(rootOf(ws)); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); }
      }
      // The project's name and its top-level names are words the recognizer should keep whole.
      const words = ws ? [ws.name, ...ws.name.split(/[^A-Za-z0-9]+/)].filter(Boolean) : [];
      try { return deps.voice.start({ locale: deps.settings.get().voice_locale, words, ...(record ? { record } : {}) }); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); }
    }),
  );
  def("voice.stop", method(true, object({ cancel: optional(bool) }), (p) => deps.voice.stop(p.cancel === true)));
  // Dictation where the window captures the microphone (Windows): 16 kHz Int16 chunks, base64 (100 ms = 4.3 kB).
  def("voice.audio", method(true, object({ session: id, pcm: str({ max: 65536 }) }), (p) => ({ ok: deps.voice.audio(p.session, p.pcm) })));
  // Voice mode: a front agent you talk to; it briefs the worker chat. Events come as `voiceagent.event` { session, ev, ... }.
  const pick = optional(object({ engine: optional(str({ min: 1, max: 40 })), model: optional(str({ min: 1, max: 120 })), effort: optional(str({ min: 1, max: 40 })), account_id: optional(str({ min: 1, max: 40 })) }));
  def("voiceagent.approve", method(true, object({ session: id, call_id: str({ min: 1, max: 200 }), allow: bool }), (p) => {
    try { return deps.voiceAgent().approve(p.session, p.call_id, p.allow); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); }
  }));
  def("voiceagent.status", method(true, object({}), () => deps.voiceAgent().status()));
  def(
    "voiceagent.start",
    method(true, object({ workspace_id: id, chat_id: optional(id), brain: pick, worker: optional(object({ engine: optional(str({ min: 1, max: 40 })), model: optional(str({ min: 1, max: 120 })), effort: optional(str({ min: 1, max: 40 })), account_id: optional(str({ min: 1, max: 40 })), mode: optional(oneOf(...PERMISSION_MODES)) })) }), async (p) => {
      workspaceOr404(p.workspace_id);
      try { return await deps.voiceAgent().start(p); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); }
    }),
  );
  // The microphone, ~10 chunks a second: 100 ms of 16 kHz Int16 is 3.2 kB (4.3 kB as base64); a 64 kB cap leaves room.
  def("voiceagent.audio", method(true, object({ session: id, pcm: str({ max: 65536 }) }), (p) => { deps.voiceAgent().audio(p.session, p.pcm); return { ok: true }; }));
  def("voiceagent.playback", method(true, object({ session: id, playing: bool }), (p) => { deps.voiceAgent().playback(p.session, p.playing); return { ok: true }; }));
  def("voiceagent.interrupt", method(true, object({ session: id }), (p) => { deps.voiceAgent().interrupt(p.session); return { ok: true }; }));
  def("voiceagent.attach", method(true, object({ session: id, paths: list(str({ min: 1, max: 4096 }), 50) }), (p) => { try { deps.voiceAgent().attach(p.session, p.paths); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); } return { ok: true }; }));
  def("voiceagent.say", method(true, object({ session: id, text: str({ min: 1, max: 4000 }) }), (p) => { try { deps.voiceAgent().say(p.session, p.text); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); } return { ok: true }; }));
  def("voiceagent.stop", method(true, object({ session: id }), (p) => deps.voiceAgent().stop(p.session)));
  // Read aloud (Pocket TTS on this Mac). Audio and install progress come as `tts.event`.
  def("tts.status", method(true, object({}), () => deps.tts.status()));
  def("tts.install", method(true, object({}), () => deps.tts.install()));
  def("tts.remove", method(true, object({}), () => deps.tts.remove()));
  def(
    "tts.speak",
    method(true, object({ text: str({ max: 200_000 }), voice: optional(str({ min: 1, max: 40 })) }), (p) => {
      try { return deps.tts.speak({ text: p.text, voice: p.voice ?? deps.settings.get().tts_voice }); } catch (e) { throw fail.conflict(e instanceof Error ? e.message : String(e)); }
    }),
  );
  def("tts.progress", method(true, object({ session: id, played: int(0, 100000) }), (p) => { deps.tts.progress(p.session, p.played); return { ok: true }; }));
  def("tts.stop", method(true, object({ session: optional(id) }), (p) => deps.tts.stop(p.session)));
  // What happened in a chat (files changed and read, commands and results, what was running at a stop),
  // kept by Opscode for hand-offs between engines. null when nothing has happened yet.
  def(
    "chat.ledger",
    method(true, object({ chat_id: id }), (p) => {
      if (!deps.chats.get(p.chat_id)) throw fail.notFound("no such chat");
      return { ledger: deps.turns.ledger(p.chat_id) ?? null };
    }),
  );
  // `chat_id` picks a chat; with only `workspace_id`, the project's most recent chat.
  def(
    "turn.history",
    method(true, object({ workspace_id: optional(id), chat_id: optional(id) }), (p) => {
      if (p.chat_id === undefined && p.workspace_id === undefined) throw fail.invalid("chat_id or workspace_id is required");
      let chat = p.chat_id !== undefined ? deps.chats.get(p.chat_id) : undefined;
      if (p.chat_id !== undefined) {
        if (!chat || (p.workspace_id !== undefined && chat.workspace_id !== p.workspace_id)) throw fail.notFound("no such chat");
      } else {
        workspaceOr404(p.workspace_id as string);
        chat = deps.chats.latest(p.workspace_id as string);
      }
      return { chat_id: chat?.id ?? null, messages: chat ? deps.turns.history(chat.id) : [] };
    }),
  );

  // ---- chats ----------------------------------------------------------------
  const mode = oneOf(...PERMISSION_MODES);
  const chatOr404 = (chatId: string) => {
    const c = deps.chats.get(chatId);
    if (!c) throw fail.notFound("no such chat");
    if (c.chief?.role === "home") throw fail.invalid("this is a Manager's chat; change it in the Manager's settings");
    return c;
  };
  const chatsChanged = (): void => deps.broadcast({ method: "chat.changed", params: { chats: deps.chats.list() } });
  def("chat.list", method(true, object({ workspace_id: optional(id) }), (p) => ({ chats: deps.chats.list(p.workspace_id), running: deps.turns.runningChats() })));
  const engineId = oneOf("api", "claude-code", "codex", "antigravity", "qoder");
  const effort = oneOf(...EFFORTS);
  def(
    "chat.create",
    method(true, object({ workspace_id: id, mode: optional(mode), engine: optional(engineId), model: optional(str({ min: 1, max: 120 })), effort: optional(effort), account_id: optional(str({ min: 1, max: 40 })) }), (p) => {
      workspaceOr404(p.workspace_id);
      let chat = guardNote(() => deps.chats.create(p.workspace_id, p.mode ?? deps.settings.get().default_mode));
      const d = deps.engines.store.settings();
      const engine = p.engine ?? d.default_engine;
      if (engine !== "api" || p.model || p.effort) chat = deps.chats.setEngine(chat.id, { engine, model: p.model ?? (p.engine ? undefined : d.default_model || undefined), effort: p.effort ?? (p.engine ? undefined : d.default_effort || undefined) }) ?? chat;
      // The account this chat starts on (otherwise the one new chats use, pinned on its first message).
      if (p.account_id && engine !== "api") {
        if (!deps.engines.accounts?.find(engine, p.account_id)) throw fail.invalid("that account does not exist");
        chat = deps.chats.pinAccount(chat.id, engine, p.account_id) ?? chat;
      }
      chatsChanged();
      return { chat };
    }),
  );
  def(
    "chat.set_engine",
    method(true, object({ chat_id: id, engine: engineId, model: optional(str({ min: 1, max: 120 })), effort: optional(effort) }), (p) => {
      chatOr404(p.chat_id);
      if (deps.turns.runningChats().includes(p.chat_id)) throw fail.conflict("wait for the current reply to finish");
      const chat = deps.chats.setEngine(p.chat_id, { engine: p.engine, model: p.model, effort: p.effort });
      chatsChanged();
      return { chat };
    }),
  );
  // Plan limits (5-hour and weekly) for Claude Code and Codex. Checking runs no model and costs nothing.
  def("limits.get", method(true, object({ refresh: optional(bool), all_accounts: optional(bool) }), async (p) => {
    const l = deps.engines.limits;
    if (!l) return { limits: [], by_account: [] };
    // `limits` is the account new chats use, one per engine; `by_account` has every account that was read.
    const more = p.all_accounts === true && (deps.engines.accounts?.records().length ?? 0) > 2;
    const list = p.refresh || more || l.all().length === 0 ? await l.refresh(p.refresh ?? false, more) : l.all();
    return { limits: list, by_account: l.everything() };
  }));
  // Image generation: which Codex accounts can make images now, and when the first one is back if none can.
  def("imagegen.status", method(true, object({ refresh: optional(bool) }), async (p) => {
    const g = deps.imageGen;
    if (!g) return { state: "unavailable", accounts: [], message: "Image generation is not available." };
    return p.refresh ? await g.statusFresh() : g.status();
  }));
  // Where tokens go: reads Claude Code and Codex session logs (read-only), cached per file.
  def("usage.report", method(true, object({ days: optional(int(1, 90)), refresh: optional(bool), wait: optional(bool), account_id: optional(str({ min: 1, max: 40 })) }), async (p) => {
    const u = deps.usage;
    if (!u) return { report: null, scanning: false };
    const stale = Date.now() - u.lastScan > 5 * 60_000;
    if (p.refresh || stale) { const run = u.scan(); if (p.wait || u.lastScan === 0) await run; }
    // `accounts` lists each account's headline when there is more than one; `account_id` narrows the report to one.
    const multi = (deps.engines.accounts?.records().length ?? 0) > 2;
    return { report: u.lastScan ? u.report(p.days ?? 30, Date.now(), p.account_id) : null, scanning: u.scanning, progress: u.progress, scanned_at: u.lastScan, ...(multi && u.lastScan ? { accounts: u.perAccount(p.days ?? 30) } : {}) };
  }));
  // Measures a worker's start-up size at each lean level: one tiny Haiku request per level, only when asked.
  def("engines.measure_start", method(true, object({ workspace_id: optional(id) }), async (p) => {
    const bin = deps.engines.store.claudePath();
    if (!bin) throw fail.invalid("Claude Code is not installed");
    const root = p.workspace_id ? rootFor(p.workspace_id) : undefined;
    const results = await measureStart(bin, root, deps.engines.store.settings().claude_lean);
    return { results, setting: deps.engines.store.settings().worker_start, model: "claude-haiku-5-5" };
  }));
  // The Library: the person's existing apps, indexed (read-only, no model tokens). Nothing is indexed until an app is added.
  const appIds: Check<string[]> = (v, key) => Array.isArray(v) && v.length <= 20 && v.every((x) => typeof x === "string" && x.length > 0 && x.length <= 128) ? { ok: true, value: v as string[] } : { ok: false, message: `${key} must be a list of app ids` };
  const lib = (): import("./library").LibraryService => { if (!deps.library) throw fail.invalid("the Library is not available"); return deps.library; };
  def("library.list", method(true, object({}), () => ({ apps: lib().list(), suggestions: lib().suggestions() })));
  def("library.add", method(true, object({ path: str({ min: 1, max: 1024 }), name: optional(str({ max: 60 })) }), (p) => ({ app: guard(() => lib().add(p.path, p.name)) })));
  def("library.remove", method(true, object({ app_id: id }), (p) => ({ removed: lib().remove(p.app_id) })));
  def("library.reindex", method(true, object({ app_id: id, wait: optional(bool) }), async (p) => {
    guard(() => lib().app(p.app_id));
    const run = lib().reindex(p.app_id);
    if (p.wait) await run;
    return { app: lib().app(p.app_id) };
  }));
  def("library.get", method(true, object({ app_id: id }), (p) => guard(() => lib().detail(p.app_id))));
  def("library.feature", method(true, object({ app_id: id, feature_id: str({ min: 1, max: 200 }) }), (p) => guard(() => lib().feature(p.app_id, p.feature_id))));
  def("library.search", method(true, object({ query: str({ min: 1, max: 300 }), app_ids: optional(appIds), limit: optional(int(1, 40)) }), (p) => ({ hits: guard(() => lib().search(p.query, p.app_ids, p.limit ?? 12)) })));
  def("library.context", method(true, object({ app_id: id, query: str({ min: 1, max: 300 }), max_files: optional(int(1, 60)) }), (p) => guard(() => lib().context(p.app_id, p.query, p.max_files ?? 15))));
  // The list answers at once from what the last run found (kept on disk) and is read again in the background; the windows hear
  // the result as `engines.changed`. `refresh: true` (the Check button) waits for everything to be asked again, all at once.
  def("engines.list", method(true, object({ refresh: optional(bool) }), async (p) => {
    const store = deps.engines.store;
    if (p.refresh) return { engines: await deps.engines.refresher.refresh(), settings: store.settings() };
    const known = store.cached();
    if (known) { deps.engines.refresher.revalidate(); return { engines: known, settings: store.settings() }; }
    // The very first time: the programs and versions now (quick), the models in the background.
    const first = await store.list(false);
    void deps.engines.refresher.refresh().catch(() => undefined);
    return { engines: first, settings: store.settings() };
  }));
  def(
    "engines.set",
    method(true, object({ claude_path: optional(str({ max: 1024 })), codex_path: optional(str({ max: 1024 })), antigravity_path: optional(str({ max: 1024 })), qoder_path: optional(str({ max: 1024 })), claude_lean: optional(bool), worker_start: optional(oneOf("standard", "lean", "leanest")), default_engine: optional(engineId), default_model: optional(str({ max: 120 })), default_effort: optional(oneOf("", ...EFFORTS)), auto_switch: optional(bool) }), async (p) => {
      const settings = guardNote(() => deps.engines.store.update(p));
      const engines = await deps.engines.store.list(true);
      deps.broadcast({ method: "engines.changed", params: { engines, settings } });
      return { engines, settings };
    }),
  );

  // ---- accounts (Claude Code and Codex sign-ins) -----------------------------------------------------------
  // Opscode runs the programs' own sign-in commands and shows the result; it never sees a password or token.
  const acct = (): import("./engines/accounts").AccountStore => { if (!deps.engines.accounts) throw fail.invalid("accounts are not available"); return deps.engines.accounts; };
  const authEngine = oneOf("claude-code", "codex", "antigravity", "qoder");
  const aguard = async <T,>(fn: () => Promise<T>): Promise<T> => {
    try { return await fn(); } catch (e) {
      if (e instanceof RpcFailure) throw e;
      throw fail.invalid(e instanceof Error ? e.message : String(e));
    }
  };
  const accountId = str({ min: 1, max: 40 });
  def("accounts.list", method(true, object({ refresh: optional(bool) }), async (p) => {
    const a = acct();
    return { accounts: await a.list(p.refresh ?? false), login: a.loginView() };
  }));
  def("accounts.login_start", method(true, object({ engine: authEngine, account_id: optional(accountId), new_account: optional(bool), method: optional(oneOf("claudeai", "console", "sso", "chatgpt", "google", "qoder")), email: optional(str({ min: 3, max: 254 })) }), async (p) => {
    const login = await aguard(() => acct().loginStart({ engine: p.engine, ...(p.account_id ? { accountId: p.account_id } : {}), ...(p.new_account ? { newAccount: true } : {}), ...(p.method ? { method: p.method } : {}), ...(p.email ? { email: p.email } : {}) }));
    return { login };
  }));
  def("accounts.login_cancel", method(true, object({ login_id: id }), (p) => { acct().loginCancel(p.login_id); return { login: acct().loginView() }; }));
  def("accounts.login_code", method(true, object({ login_id: id, code: str({ min: 6, max: 2000 }) }), (p) => {
    if (!/^[\w\-#.~%+=/:]+$/.test(p.code)) throw fail.invalid("that does not look like the code from the browser");
    guardNote(() => acct().loginCode(p.login_id, p.code));
    return { ok: true };
  }));
  def("accounts.logout", method(true, object({ engine: authEngine, account_id: accountId }), async (p) => {
    await aguard(() => acct().logout(p.engine, p.account_id));
    return { accounts: acct().views() };
  }));
  def("accounts.switch", method(true, object({ engine: authEngine, account_id: accountId }), async (p) => {
    await aguard(() => acct().switchTo(p.engine, p.account_id));
    return { accounts: acct().views() };
  }));
  // Moves one chat to another account on its engine (its old session lives in the old account, so it starts a fresh one with the conversation as context).
  def("chat.set_account", method(true, object({ chat_id: id, account_id: accountId }), async (p) => {
    const c = chatOr404(p.chat_id);
    if (!c.engine || c.engine === "api") throw fail.invalid("only chats on a coding agent have an account");
    if (deps.turns.runningChats().includes(p.chat_id)) throw fail.conflict("wait for the current reply to finish");
    const a = acct();
    if (!a.find(c.engine, p.account_id)) throw fail.invalid("that account does not exist");
    const s = await a.status(c.engine, p.account_id);
    if (!s.signed_in) throw fail.invalid("Sign in to that account first (Settings → Models & keys).");
    const chat = deps.chats.moveAccount(c.id, c.engine, p.account_id);
    chatsChanged();
    return { chat };
  }));
  def(
    "chat.rename",
    method(true, object({ chat_id: id, title: str({ max: 200 }) }), (p) => {
      const chat = deps.chats.rename(chatOr404(p.chat_id).id, p.title);
      chatsChanged();
      return { chat };
    }),
  );
  def(
    "chat.set_mode",
    method(true, object({ chat_id: id, mode }), (p) => {
      const chat = deps.chats.setMode(chatOr404(p.chat_id).id, p.mode);
      chatsChanged();
      return { chat };
    }),
  );
  def(
    "chat.delete",
    method(true, object({ chat_id: id }), (p) => {
      const c = chatOr404(p.chat_id); // a Manager's or Conductor's own chat is removed with chief.remove, not here
      deps.turns.deleteChat(p.chat_id);
      if (c.chief) chiefM().forgetChat(p.chat_id);
      return { deleted: true };
    }),
  );

  // ---- memory ---------------------------------------------------------------
  const noteScope = str({ min: 1, max: 128 });
  const noteState = oneOf("kept", "draft");
  def("memory.list", method(true, object({}), () => ({ notes: deps.memory.list() })));
  def(
    "memory.add",
    method(true, object({ body: str({ min: 1, max: 4000 }), title: optional(str({ max: 400 })), scope: noteScope, pinned: optional(bool) }), (p) => {
      if (p.scope !== "global") workspaceOr404(p.scope);
      const note = guardNote(() => deps.memory.add({ body: p.body, title: p.title, scope: p.scope, pinned: p.pinned }));
      notesChanged();
      return { note };
    }),
  );
  def(
    "memory.update",
    method(true, object({ id, body: optional(str({ min: 1, max: 4000 })), title: optional(str({ max: 400 })), scope: optional(noteScope), state: optional(noteState), pinned: optional(bool) }), (p) => {
      if (p.scope !== undefined && p.scope !== "global") workspaceOr404(p.scope);
      const { id: noteId, ...patch } = p;
      const note = guardNote(() => deps.memory.update(noteId, patch));
      if (!note) throw fail.notFound("no such note");
      notesChanged();
      return { note };
    }),
  );
  def(
    "memory.delete",
    method(true, object({ id }), (p) => {
      if (!deps.memory.remove(p.id)) throw fail.notFound("no such note");
      notesChanged();
      return { deleted: true };
    }),
  );

  // ---- MCP servers ----------------------------------------------------------
  def("mcp.list", method(true, object({}), () => ({ servers: deps.mcp.list() })));
  def(
    "mcp.add",
    method(true, object({ input: str({ min: 1, max: 2000 }), name: optional(str({ min: 1, max: 60 })) }), (p) => ({ server: guardNote(() => deps.mcp.add(p.input, p.name)) })),
  );
  def(
    "mcp.remove",
    method(true, object({ id }), (p) => {
      if (!guardNote(() => deps.mcp.remove(p.id))) throw fail.notFound("no such server");
      return { removed: true };
    }),
  );
  def(
    "mcp.set_enabled",
    method(true, object({ id, enabled: bool }), (p) => {
      if (!guardNote(() => deps.mcp.setEnabled(p.id, p.enabled))) throw fail.notFound("no such server");
      return { servers: deps.mcp.list() };
    }),
  );
  const strRecord: Check<Record<string, string>> = (v, key) =>
    isRecordLike(v) && Object.keys(v).length <= 16 && Object.values(v).every((x) => typeof x === "string" && x.length <= 4096)
      ? { ok: true, value: v as Record<string, string> }
      : { ok: false, message: `${key} must be an object of up to 16 text values` };
  def("mcp.catalog", method(true, object({}), () => {
    const have = new Set(deps.mcp.list().map((x) => x.catalog).filter(Boolean));
    return { catalog: MCP_CATALOG.map((e) => ({ id: e.id, name: e.name, description: e.description, mark: e.mark, transport: e.transport, target: e.transport === "stdio" ? [e.command, ...(e.args ?? [])].join(" ") : e.url, inputs: e.inputs.map(({ key, label, help }) => ({ key, label, help })), needs: e.needs ?? null, docs: e.docs, added: have.has(e.id) })) };
  }));
  def(
    "mcp.catalog.add",
    method(true, object({ id: str({ min: 1, max: 64 }), values: optional(strRecord) }), (p) => {
      const entry = MCP_CATALOG.find((e) => e.id === p.id);
      if (!entry) throw fail.notFound("no such catalog entry");
      if (deps.mcp.list().some((x) => x.catalog === entry.id)) throw fail.conflict(`${entry.name} is already added`);
      const keys = guardNote(() => catalogSecrets(entry, p.values ?? {}));
      const server = guardNote(() => deps.mcp.addServer({ name: entry.name, ...(entry.transport === "stdio" ? { command: entry.command, args: entry.args } : { url: entry.url }), enabled: true, catalog: entry.id, ...keys }));
      return { server };
    }),
  );
  def(
    "mcp.set_secrets",
    method(true, object({ id, values: strRecord }), (p) => {
      const server = deps.mcp.list().find((x) => x.id === p.id);
      if (!server) throw fail.notFound("no such server");
      const entry = server.catalog ? MCP_CATALOG.find((e) => e.id === server.catalog) : undefined;
      const patch = entry ? guardNote(() => catalogSecrets(entry, p.values)) : server.transport === "http" ? { headers: p.values } : { env: p.values };
      if (!guardNote(() => deps.mcp.setSecrets(p.id, patch))) throw fail.notFound("no such server");
      return { servers: deps.mcp.list() };
    }),
  );
  def(
    "mcp.refresh",
    method(true, object({ id }), async (p) => {
      if (!deps.mcp.has(p.id)) throw fail.notFound("no such server");
      await deps.mcp.connect(p.id);
      return { servers: deps.mcp.list() };
    }),
  );

  // ---- skills ----------------------------------------------------------------
  const skillName = str({ min: 1, max: 64 });
  const skillScope = oneOf("user", "project");
  const skillsChanged = (): void => deps.broadcast({ method: "skill.changed", params: {} });
  const projectOr404 = (wid: string | undefined): void => {
    if (wid !== undefined) workspaceOr404(wid);
  };
  def(
    "skill.list",
    method(true, object({ workspace_id: optional(id) }), (p) => {
      projectOr404(p.workspace_id);
      return { skills: deps.skillset.list(p.workspace_id) };
    }),
  );
  def(
    "skill.read",
    method(true, object({ name: skillName, workspace_id: optional(id) }), (p) => {
      projectOr404(p.workspace_id);
      const hit = deps.skillset.get(p.workspace_id, p.name);
      if (!hit) throw fail.notFound("no such skill");
      return { skill: hit.info, body: hit.body };
    }),
  );
  def(
    "skill.save",
    method(true, object({ scope: skillScope, workspace_id: optional(id), name: skillName, description: str({ max: 1000 }), body: str({ max: 40_000 }) }), (p) => {
      projectOr404(p.workspace_id);
      if (!SKILL_NAME.test(p.name)) throw fail.invalid("a skill name is lowercase letters, digits and dashes, like release-notes");
      guardNote(() => deps.skillset.save(p.scope, p.workspace_id, { name: p.name, description: p.description, body: p.body }));
      skillsChanged();
      return { skills: deps.skillset.list(p.workspace_id) };
    }),
  );
  def(
    "skill.delete",
    method(true, object({ scope: skillScope, workspace_id: optional(id), name: skillName }), (p) => {
      projectOr404(p.workspace_id);
      if (!guardNote(() => deps.skillset.remove(p.scope, p.workspace_id, p.name))) throw fail.notFound("no such skill");
      skillsChanged();
      return { deleted: true };
    }),
  );
  def(
    "skill.import",
    method(true, object({ path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }), scope: skillScope, workspace_id: optional(id) }), (p) => {
      projectOr404(p.workspace_id);
      if (p.scope === "project" && !p.workspace_id) throw fail.invalid("choose a project");
      const dest = p.scope === "user" ? deps.skillset.userDir : (guardNote(() => deps.skillset.projectDir(p.workspace_id as string, true)) as string);
      const names = guardNote(() => deps.plugins.importSkills(p.path, dest));
      skillsChanged();
      return { imported: names };
    }),
  );

  // ---- side panel: environment, changes, file search, servers, actions ---------------------
  const rootFor = (wid: string): string => rootOf(workspaceOr404(wid));
  def("workspace.env", method(true, object({ workspace_id: id }), async (p) => ({ env: await envInfo(rootFor(p.workspace_id)) })));
  def("workspace.remote_check", method(true, object({ workspace_id: id }), async (p) => remoteCheck(rootFor(p.workspace_id))));
  def("changes.diff", method(true, object({ workspace_id: id }), async (p) => gitChanges(rootFor(p.workspace_id))));
  def(
    "fs.search",
    method(true, object({ workspace_id: id, query: str({ max: 200 }), limit: optional(int(1, 50)) }), (p) => ({ results: searchFiles(rootFor(p.workspace_id), p.query, p.limit ?? 20) })),
  );
  def("workspace.servers", method(true, object({ workspace_id: id }), async (p) => ({ servers: await localServers(rootFor(p.workspace_id)) })));
  def(
    "workspace.servers.stop",
    method(true, object({ workspace_id: id, pid: int(2, 4_194_304), port: int(1, 65535) }), async (p) => {
      const listed = (await localServers(rootFor(p.workspace_id))).some((x) => x.pid === p.pid && x.port === p.port);
      if (!listed) throw fail.notFound("that server is not running in this project");
      try { process.kill(p.pid, "SIGTERM"); } catch (e) { throw fail.io(e instanceof Error ? e.message : String(e)); }
      return { stopped: true };
    }),
  );
  def(
    "actions.list",
    method(true, object({ workspace_id: id }), (p) => {
      const root = rootFor(p.workspace_id);
      let project: ReturnType<typeof readProjectActions> = [];
      let error: string | undefined;
      try { project = readProjectActions(root); } catch (e) { error = e instanceof Error ? e.message : String(e); }
      const list = [...project, ...deps.actions.list(p.workspace_id)];
      return { actions: list, suggestions: suggestActions(root, new Set(list.map((a) => a.command))), ...(error ? { error } : {}) };
    }),
  );
  const actionItem: Check<{ id?: string; name: string; command: string; icon?: string }> = (v) => {
    const r = object({ id: optional(str({ min: 1, max: 24 })), name: str({ max: 60 }), command: str({ min: 1, max: 2000 }), icon: optional(oneOf(...ACTION_ICONS)) })(v);
    return r.ok ? { ok: true, value: r.value as { id?: string; name: string; command: string; icon?: string } } : r;
  };
  def(
    "actions.save",
    method(true, object({ workspace_id: id, actions: (v: unknown) => {
      if (!Array.isArray(v) || v.length > 50) return { ok: false as const, message: "actions must be a list of at most 50" };
      const out: { id?: string; name: string; command: string; icon?: string }[] = [];
      for (const a of v) { const r = actionItem(a, "action"); if (!r.ok) return r; out.push(r.value); }
      return { ok: true as const, value: out };
    } }), (p) => {
      workspaceOr404(p.workspace_id);
      const saved = guardNote(() => deps.actions.set(p.workspace_id, p.actions));
      deps.broadcast({ method: "actions.changed", params: { workspace_id: p.workspace_id } });
      return { actions: saved };
    }),
  );

  // ---- automations ----------------------------------------------------------------------------
  const scope = oneOf("project", "me");
  const autoName = str({ min: 1, max: 40 });
  const auto = (): AutomationRunner => deps.automations();
  const inputsCheck: Check<Record<string, string>> = (v, key) =>
    isRecordLike(v) && Object.keys(v).length <= 20 && Object.values(v).every((x) => typeof x === "string" && x.length <= 20_000)
      ? { ok: true, value: v as Record<string, string> }
      : { ok: false, message: `${key} must be an object of text values` };
  def("automation.list", method(true, object({ workspace_id: id }), (p) => {
    workspaceOr404(p.workspace_id);
    return { automations: auto().list(p.workspace_id).map((f) => auto().describe(f)) };
  }));
  def("automation.get", method(true, object({ workspace_id: id, scope, name: autoName }), (p) => {
    workspaceOr404(p.workspace_id);
    const f = auto().get(p.workspace_id, p.scope, p.name);
    if (!f) throw fail.notFound("no such automation");
    return { automation: auto().describe(f), text: f.text };
  }));
  def("automation.file_write", method(true, object({ workspace_id: id, scope, name: autoName, text: str({ min: 1, max: 256 * 1024 }) }), (p) => {
    workspaceOr404(p.workspace_id);
    const diagnostics = guardNote(() => auto().write(p.workspace_id, p.scope, p.name, p.text));
    return { diagnostics };
  }));
  def("automation.delete", method(true, object({ workspace_id: id, scope, name: autoName }), (p) => {
    workspaceOr404(p.workspace_id);
    if (!auto().remove(p.workspace_id, p.scope, p.name)) throw fail.notFound("no such automation");
    return { deleted: true };
  }));
  def("automation.set_enabled", method(true, object({ workspace_id: id, scope, name: autoName, enabled: bool }), (p) => {
    workspaceOr404(p.workspace_id);
    guardNote(() => auto().setEnabled(p.workspace_id, p.scope, p.name, p.enabled));
    return { automation: auto().describe(auto().get(p.workspace_id, p.scope, p.name)!) };
  }));
  def("automation.run", method(true, object({ workspace_id: id, scope, name: autoName, inputs: optional(inputsCheck) }), (p) => {
    workspaceOr404(p.workspace_id);
    return { run: guardNote(() => auto().start(p.workspace_id, p.scope, p.name, p.inputs ?? {})) };
  }));
  def("automation.runs", method(true, object({ workspace_id: optional(id), name: optional(autoName) }), (p) => ({ runs: auto().listRuns(p.workspace_id, p.name).slice(0, 50) })));
  def("automation.run_get", method(true, object({ run_id: id }), (p) => {
    const run = auto().getRun(p.run_id);
    if (!run) throw fail.notFound("no such run");
    return { run };
  }));
  def("automation.run_cancel", method(true, object({ run_id: id }), (p) => ({ cancelled: auto().cancel(p.run_id) })));
  def("automation.approve", method(true, object({ run_id: id, step: autoName, decision: oneOf("approve", "reject") }), (p) => ({ run: guardNote(() => auto().approve(p.run_id, p.step, p.decision === "approve")) })));
  def("automation.templates", method(true, object({}), () => ({ templates: TEMPLATES.map(({ id: tid, title, summary, name, text }) => ({ id: tid, title, summary, name, text })) })));
  def("automation.from_template", method(true, object({ workspace_id: id, scope, template: str({ min: 1, max: 64 }), name: optional(autoName) }), (p) => {
    workspaceOr404(p.workspace_id);
    const t = TEMPLATES.find((x) => x.id === p.template);
    if (!t) throw fail.notFound("no such template");
    const name = p.name ?? t.name;
    if (auto().get(p.workspace_id, p.scope, name)) throw fail.conflict(`there is already an automation named ${name}`);
    const diagnostics = guardNote(() => auto().write(p.workspace_id, p.scope, name, t.text));
    return { name, diagnostics };
  }));
  def("automation.create", method(true, object({ workspace_id: id, scope, title: str({ min: 1, max: 120 }), prompt: str({ min: 1, max: 20_000 }), schedule: oneOf("manual", "weekdays", "daily", "hourly"), engine: optional(engineId), access: optional(oneOf("read", "edit", "full")) }), (p) => {
    workspaceOr404(p.workspace_id);
    let name = p.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 36) || "automation";
    if (!/^[a-z]/.test(name)) name = `a-${name}`.slice(0, 36);
    for (let n = 2; auto().get(p.workspace_id, p.scope, name); n++) name = `${name.replace(/-\d+$/, "")}-${n}`;
    if (!AUTO_NAME.test(name)) throw fail.invalid("choose a title with some letters");
    const on = p.schedule === "weekdays" ? `\non:\n  schedule: { at: "09:00", weekdays: [mon, tue, wed, thu, fri] }\n` : p.schedule === "daily" ? `\non:\n  schedule: { at: "09:00" }\n` : p.schedule === "hourly" ? `\non:\n  schedule: { every: 1h }\n` : "";
    const text = `version: 1\ndescription: ${JSON.stringify(p.title)}\n${on}\nbudget:\n  tokens: 500000\n\nsteps:\n  main:\n    prompt: ${JSON.stringify(p.prompt)}\n${p.engine ? `    engine: ${p.engine}\n` : ""}    access: ${p.access ?? "read"}\n`;
    const diagnostics = guardNote(() => auto().write(p.workspace_id, p.scope, name, text));
    return { name, diagnostics };
  }));

  // ---- import (from Claude Code, Codex, Cursor) -----------------------------------------
  const importDeps = {
    mcp: deps.mcp,
    skills: { has: (n: string) => deps.skillset.has(n), saveUser: (s: { name: string; description: string; body: string }) => deps.skillset.save("user", undefined, s) },
    memory: deps.memory,
  };
  const publicItem = (it: ImportItem): Record<string, unknown> => ({
    id: it.id,
    source: it.source,
    kind: it.kind,
    title: it.title,
    detail: it.detail,
    ...(it.warn ? { warn: it.warn } : {}),
    ...(it.blocked ? { blocked: it.blocked } : {}),
    exists: !it.blocked && alreadyHere(it, importDeps),
  });
  def(
    "import.scan",
    method(true, object({}), () => {
      const r = scanImports();
      return { sources: r.sources, items: r.items.map(publicItem) };
    }),
  );
  const idList: Check<string[]> = (v) =>
    Array.isArray(v) && v.length >= 1 && v.length <= 300 && v.every((x) => typeof x === "string" && x.length <= 300)
      ? { ok: true, value: v as string[] }
      : { ok: false, message: "ids must be 1-300 item ids" };
  def(
    "import.run",
    method(true, object({ ids: idList }), (p) => {
      const want = new Set(p.ids);
      const items = scanImports().items.filter((i) => want.has(i.id));
      const res = apply(items, importDeps);
      for (const id of p.ids) if (!items.some((i) => i.id === id)) res.skipped.push({ id, reason: "No longer found in the other app." });
      if (res.imported.length) {
        notesChanged();
        skillsChanged();
      }
      return { ...res, items: scanImports().items.map(publicItem) };
    }),
  );

  // ---- sub-agents (agent files) -----------------------------------------------------------
  const agentChanged = (): void => deps.broadcast({ method: "subagent.changed", params: {} });
  const access = oneOf(...ACCESS_LEVELS);
  def(
    "subagent.list",
    method(true, object({ workspace_id: optional(id) }), (p) => {
      projectOr404(p.workspace_id);
      return { agents: deps.agents.list(p.workspace_id) };
    }),
  );
  def(
    "subagent.read",
    method(true, object({ name: skillName, workspace_id: optional(id) }), (p) => {
      projectOr404(p.workspace_id);
      const hit = deps.agents.get(p.workspace_id, p.name);
      if (!hit) throw fail.notFound("no such agent");
      return { agent: hit.info, body: hit.def.body };
    }),
  );
  def(
    "subagent.save",
    method(true, object({ scope: skillScope, workspace_id: optional(id), name: skillName, description: str({ max: 1000 }), access, body: str({ max: 40_000 }) }), (p) => {
      projectOr404(p.workspace_id);
      if (!AGENT_NAME.test(p.name)) throw fail.invalid("an agent name is lowercase letters, digits and dashes, like code-reviewer");
      guardNote(() => deps.agents.save(p.scope, p.workspace_id, { name: p.name, description: p.description, access: p.access, body: p.body }));
      agentChanged();
      return { agents: deps.agents.list(p.workspace_id) };
    }),
  );
  def(
    "subagent.delete",
    method(true, object({ scope: skillScope, workspace_id: optional(id), name: skillName }), (p) => {
      projectOr404(p.workspace_id);
      if (!guardNote(() => deps.agents.remove(p.scope, p.workspace_id, p.name))) throw fail.notFound("no such agent");
      agentChanged();
      return { deleted: true };
    }),
  );

  // ---- plugins + marketplaces -------------------------------------------------------
  const pluginsChanged = (): void => {
    deps.mcp.setExternal(deps.plugins.mcpServers());
    deps.broadcast({ method: "plugin.changed", params: { plugins: deps.plugins.list(), marketplaces: deps.plugins.marketplaces() } });
    skillsChanged();
  };
  def("plugin.list", method(true, object({}), () => ({ plugins: deps.plugins.list(), marketplaces: deps.plugins.marketplaces() })));
  def("plugin.preview", method(true, object({ path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }) }), (p) => ({ preview: guardNote(() => deps.plugins.preview(p.path)) })));
  def(
    "plugin.install",
    method(true, object({ path: optional(str({ min: 1, max: LIMITS.PATH_MAX_CHARS })), marketplace_id: optional(id), plugin: optional(str({ min: 1, max: 80 })) }), (p) => {
      let path = p.path;
      if (path === undefined) {
        if (p.marketplace_id === undefined || p.plugin === undefined) throw fail.invalid("give a folder path, or a marketplace_id and plugin name");
        path = guardNote(() => deps.plugins.marketplacePluginPath(p.marketplace_id as string, p.plugin as string));
      }
      const plugin = guardNote(() => deps.plugins.install(path as string));
      pluginsChanged();
      return { plugin };
    }),
  );
  def(
    "plugin.set_enabled",
    method(true, object({ id, enabled: bool }), (p) => {
      if (!deps.plugins.setEnabled(p.id, p.enabled)) throw fail.notFound("no such plugin");
      pluginsChanged();
      return { plugins: deps.plugins.list() };
    }),
  );
  def(
    "plugin.uninstall",
    method(true, object({ id }), (p) => {
      if (!deps.plugins.uninstall(p.id)) throw fail.notFound("no such plugin");
      pluginsChanged();
      return { uninstalled: true };
    }),
  );
  def(
    "marketplace.add",
    method(true, object({ path: str({ min: 1, max: LIMITS.PATH_MAX_CHARS }) }), (p) => {
      const marketplace = guardNote(() => deps.plugins.addMarketplace(p.path));
      pluginsChanged();
      return { marketplace };
    }),
  );
  def(
    "marketplace.remove",
    method(true, object({ id }), (p) => {
      if (!deps.plugins.removeMarketplace(p.id)) throw fail.notFound("no such marketplace");
      pluginsChanged();
      return { removed: true };
    }),
  );

  // ---- providers ------------------------------------------------------------
  // Keys go in, never out: provider.list reports only a configured flag and the last 4 characters.
  const providerChanged = (): void => deps.broadcast({ method: "provider.changed", params: { providers: deps.providers.list() } });
  const providerId = oneOf(...PROVIDER_IDS);
  const guard = <T,>(fn: () => T): T => {
    try {
      return fn();
    } catch (e) {
      if (e instanceof RpcFailure) throw e;
      throw fail.invalid(e instanceof Error ? e.message : String(e));
    }
  };
  def("provider.list", method(true, object({}), () => ({ providers: deps.providers.list() })));
  def(
    "provider.set",
    method(
      true,
      object({ id: providerId, api_key: optional(str({ max: 512, allowNul: false })), base_url: optional(str({ max: 512 })), model: optional(str({ max: 200 })) }),
      (p) => {
        guard(() => deps.providers.set(p.id, { api_key: p.api_key, base_url: p.base_url, model: p.model }));
        providerChanged();
        return { providers: deps.providers.list() };
      },
    ),
  );
  def(
    "provider.select",
    method(true, object({ id: providerId }), (p) => {
      guard(() => deps.providers.setActive(p.id));
      providerChanged();
      return { providers: deps.providers.list() };
    }),
  );
  def(
    "provider.remove",
    method(true, object({ id: providerId }), (p) => {
      deps.providers.remove(p.id);
      providerChanged();
      return { providers: deps.providers.list() };
    }),
  );

  // ---- computer use ---------------------------------------------------------------
  const computerStatus = async (): Promise<unknown> => {
    const { store, driver } = deps.computer;
    return {
      supported: driver !== undefined,
      driver: driver?.kind ?? "none",
      enabled: store.enabled(),
      permissions: driver ? await driver.permissions() : { accessibility: null, screen_recording: null },
      rules: store.rules(),
      denied: DENIED_APP_NAMES,
    };
  };
  // ---- devices (main hosts the browser pages) ----------------------------------------------
  def("devices.host.register", method(true, object({ devices: optional(str({ min: 1, max: 40 })) }), (_p, ctx) => {
    deps.devices().register(ctx.sessionId);
    return { ok: true };
  }));
  def("devices.reply", method(true, (v: unknown) => {
    if (!isRecordLike(v) || typeof v.rid !== "string" || v.rid.length > 64) return { ok: false as const, message: "rid must be a string" };
    for (const k of Object.keys(v)) if (!["rid", "result", "error"].includes(k)) return { ok: false as const, message: `unknown param "${k}"` };
    if (v.error !== undefined && typeof v.error !== "string") return { ok: false as const, message: "error must be a string" };
    return { ok: true as const, value: { rid: v.rid, result: v.result, error: v.error === undefined ? undefined : String(v.error).slice(0, 4000) } };
  }, (p, ctx) => ({ ok: deps.devices().reply(ctx.sessionId, p.rid, p.result, p.error) })));
  def("devices.status", method(true, object({}), () => ({ browser: deps.devices().available(), ios: !!deps.ios() })));

  // ---- iOS Simulator panel (the user's own clicks; the agent uses the ios_simulator tool) ----
  const sims = () => { const s = deps.ios(); if (!s) throw fail.invalid("the iOS Simulator needs macOS with Xcode"); return s; };
  const simOf = async (udid: string | undefined, booted = true) => { try { return await sims().resolve(udid, booted); } catch (e) { throw fail.invalid(e instanceof Error ? e.message : String(e)); } };
  const coord = num;
  def("ios.list", method(true, object({}), async () => {
    const s = deps.ios();
    if (!s) return { available: false, devices: [], help: "The iOS Simulator needs macOS with Xcode." };
    try {
      const devices = await s.list();
      return { available: true, devices, ...(devices.length ? {} : { help: (await import("./devices/ios")).simctlHelp() }) };
    } catch (e) { return { available: false, devices: [], help: e instanceof Error ? e.message : String(e) }; }
  }));
  def("ios.screen", method(true, object({ udid: id }), async (p) => {
    const d = await simOf(p.udid);
    const s = await sims().screenshot(d);
    return { data_url: `data:${s.media_type};base64,${s.data}`, width: s.width, height: s.height, name: d.name };
  }));
  def("ios.boot", method(true, object({ udid: id }), async (p) => ({ text: await sims().boot(await simOf(p.udid, false)) })));
  def("ios.shutdown", method(true, object({ udid: id }), async (p) => ({ text: await sims().shutdown(await simOf(p.udid, false)) })));
  def("ios.tap", method(true, object({ udid: id, x: coord, y: coord }), async (p) => {
    const d = await simOf(p.udid);
    try { await sims().tap(d.udid, p.x, p.y); } catch (e) { throw fail.invalid(e instanceof Error ? e.message : String(e)); }
    return { ok: true };
  }));
  def("ios.button", method(true, object({ udid: id, name: oneOf("home", "lock", "side", "siri") }), async (p) => {
    const d = await simOf(p.udid);
    try { await sims().button(d.udid, p.name); } catch (e) { throw fail.invalid(e instanceof Error ? e.message : String(e)); }
    return { ok: true };
  }));

  const computerChanged = async (): Promise<void> => deps.broadcast({ method: "computer.changed", params: { status: await computerStatus() } });
  def("computer.status", method(true, object({}), async () => ({ status: await computerStatus() })));
  def(
    "computer.set_enabled",
    method(true, object({ enabled: bool }), async (p) => {
      if (p.enabled && !deps.computer.driver) throw fail.invalid("computer use is only available on macOS");
      deps.computer.store.setEnabled(p.enabled);
      await computerChanged();
      return { status: await computerStatus() };
    }),
  );
  def(
    "computer.rule.set",
    method(true, object({ name: str({ min: 1, max: 120 }), bundle_id: optional(str({ max: 200 })), rule: oneOf("always", "never") }), async (p) => {
      guardNote(() => deps.computer.store.setRule({ name: p.name, bundle_id: p.bundle_id ?? "" }, p.rule));
      await computerChanged();
      return { status: await computerStatus() };
    }),
  );
  def(
    "computer.rule.remove",
    method(true, object({ id: str({ min: 1, max: 200 }) }), async (p) => {
      if (!deps.computer.store.removeRule(p.id)) throw fail.notFound("no such rule");
      await computerChanged();
      return { status: await computerStatus() };
    }),
  );
  // Running apps, for the "add a rule" picker. Off-limits apps are flagged, not hidden.
  def(
    "computer.apps",
    method(true, object({}), async () => {
      const d = deps.computer.driver;
      if (!d) return { apps: [] };
      const apps = await d.runningApps().catch(() => []);
      return { apps: apps.map((a) => ({ ...a, denied: isDenied(a), rule: deps.computer.store.ruleFor(a) ?? null })) };
    }),
  );
  // Opens the macOS privacy pane where the user grants access. It never grants anything itself.
  const PANES: Record<string, string> = {
    accessibility: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    screen: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
  };
  def(
    "computer.preview",
    method(true, object({}), async () => {
      const d = deps.computer.driver;
      if (!d) throw fail.invalid("computer use is only available on macOS");
      if (!deps.computer.store.enabled()) throw fail.forbidden("computer use is turned off");
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), 15_000);
      try {
        const shot = await d.screenshot(ctl.signal);
        const front = await d.frontApp().catch(() => null);
        return { image: `data:image/jpeg;base64,${shot.jpeg.toString("base64")}`, width: shot.width, height: shot.height, front: front?.name ?? null };
      } catch (e) {
        throw fail.io(e instanceof Error ? e.message : String(e));
      } finally {
        clearTimeout(timer);
      }
    }),
  );
  def(
    "computer.open_settings",
    method(true, object({ pane: oneOf("accessibility", "screen") }), async (p) => {
      if (deps.computer.driver?.kind !== "macos") return { opened: false };
      await new Promise<void>((resolve) => execFile("/usr/bin/open", [PANES[p.pane] as string], () => resolve()));
      return { opened: true };
    }),
  );

  // ---- chief ----------------------------------------------------------------
  const chiefM = (): ChiefManager => deps.chief();
  const ids: Check<string[]> = (v, key) => Array.isArray(v) && v.length <= 100 && v.every((x) => typeof x === "string" && x.length > 0 && x.length <= 128) ? { ok: true, value: v as string[] } : { ok: false, message: `${key} must be a list of ids` };
  const brain: Check<{ engine: "claude-code" | "api"; model?: string; effort?: string }> = (v, key) => {
    if (!isRecordLike(v) || (v.engine !== "claude-code" && v.engine !== "api")) return { ok: false, message: `${key}.engine must be claude-code or api` };
    if (v.model !== undefined && (typeof v.model !== "string" || v.model.length > 120)) return { ok: false, message: `${key}.model must be a short string` };
    if (v.effort !== undefined && !(EFFORTS as readonly unknown[]).includes(v.effort)) return { ok: false, message: `${key}.effort must be one of ${EFFORTS.join(", ")}` };
    return { ok: true, value: { engine: v.engine, ...(typeof v.model === "string" && v.model ? { model: v.model } : {}), ...(typeof v.effort === "string" ? { effort: v.effort } : {}) } };
  };
  def("chief.list", method(true, object({}), () => ({ chiefs: chiefM().store.list() })));
  def("chief.get", method(true, object({ chief_id: id }), (p) => guard(() => chiefM().view(p.chief_id))));
  def("chief.modes", method(true, object({}), () => ({ modes: Object.values(MODES).map((m) => ({ id: m.id, name: m.name, tagline: m.tagline, max_parallel: m.max_parallel, opus_per_day: m.opus_per_day, ui_rounds: m.ui_rounds, tiers: m.tiers })) })));
  def("chief.create", method(true, object({ name: optional(str({ max: 40 })), brain: optional(brain), mode: optional(oneOf(...MODE_IDS)), project_id: optional(id) }), (p) => {
    const chief = guard(() => chiefM().create({ ...(p.name ? { name: p.name } : {}), ...(p.brain ? { brain: p.brain } : {}), ...(p.mode ? { mode: p.mode } : {}), ...(p.project_id ? { project_id: p.project_id } : {}) }));
    deps.broadcast({ method: "chat.changed", params: { chats: deps.chats.list() } });
    return { chief };
  }));
  def("chief.update", method(true, object({
    chief_id: id, mode: optional(oneOf(...MODE_IDS)), name: optional(str({ min: 1, max: 40 })), title: optional(str({ min: 1, max: 60 })), avatar: optional(str({ min: 1, max: 40 })), brain: optional(brain), soul: optional(str({ max: 20_000 })),
    autonomy: optional(int(1, 3)), updates: optional(oneOf("results", "milestones", "everything")), worker_access: optional(oneOf("read", "edit", "full")),
    worker_engine: optional(oneOf("claude-code", "codex", "api")), project_ids: optional(ids), max_parallel: optional(int(1, 8)), daily_chats: optional(int(1, 200)), ask_wait_minutes: optional(int(0, 1440)),
    // Which account each engine's chats run on for this Chief ("" = whichever new chats use).
    accounts: optional(object({ "claude-code": optional(str({ max: 40 })), codex: optional(str({ max: 40 })) })),
  }), (p) => {
    const { chief_id, ...patch } = p;
    if (chiefM().store.get(chief_id) && deps.turns.runningChats().includes(chiefM().store.get(chief_id)?.chat_id as string) && (patch.brain || patch.mode)) throw fail.conflict("wait for the Chief's current reply to finish");
    return { chief: guard(() => chiefM().update(chief_id, patch as Parameters<ChiefManager["update"]>[1])) };
  }));
  def("chief.remove", method(true, object({ chief_id: id, delete_workers: optional(bool) }), (p) => ({ removed: chiefM().remove(p.chief_id, p.delete_workers === true) })));
  def("chief.note", method(true, object({ chief_id: id, text: str({ min: 1, max: LIMITS.TURN_TEXT_MAX_CHARS }), attachments: optional(list(str({ min: 1, max: 1024 }), ATTACH_LIMITS.PER_MESSAGE)) }), (p) => {
    if (!p.text.trim()) throw fail.invalid("text must not be blank");
    return guard(() => chiefM().note(p.chief_id, p.text.trim(), p.attachments));
  }));
  def("chief.items.start", method(true, object({ item_id: id }), (p) => ({ item: guard(() => chiefM().startProposed(p.item_id)) })));
  def("chief.items.update", method(true, object({ item_id: id, state: optional(oneOf("queued", "done", "dropped")), title: optional(str({ min: 1, max: 100 })), pinned: optional(bool) }), (p) => {
    const { item_id, ...patch } = p;
    return { item: guard(() => chiefM().editItem(item_id, patch)) };
  }));
  // Pipelines: only the person approves a gate (the Conductor has no tool for it).
  def("chief.pipeline.approve", method(true, object({ pipeline_id: id }), (p) => ({ pipeline: guard(() => chiefM().approveGate(p.pipeline_id)) })));
  def("chief.pipeline.reject", method(true, object({ pipeline_id: id, text: str({ min: 1, max: 4000 }) }), (p) => ({ pipeline: guard(() => chiefM().rejectGate(p.pipeline_id, p.text.trim())) })));
  def("chief.pipeline.mode", method(true, object({ pipeline_id: id, stage: oneOf(...STAGE_IDS), mode: oneOf(...MODE_IDS) }), (p) => ({ pipeline: guard(() => chiefM().setStageMode(p.pipeline_id, p.stage, p.mode)) })));
  def("chief.pipeline.gallery", method(true, object({ pipeline_id: id }), (p) => guard(() => chiefM().gallery(p.pipeline_id))));
  def("chief.worker_image", method(true, object({ chat_id: id, path: str({ min: 1, max: 1024 }) }), (p) => guard(() => chiefM().workerImage(p.chat_id, p.path))));
  def("chief.pipeline.stop", method(true, object({ pipeline_id: id }), (p) => ({ pipeline: guard(() => chiefM().stopPipeline(p.pipeline_id)) })));
  def("chief.items.answer", method(true, object({ item_id: id, text: str({ min: 1, max: 4000 }) }), (p) => guard(() => chiefM().answer(p.item_id, p.text.trim()))));

  return m;
}
