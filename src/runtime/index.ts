// Runtime entry. Started by main with a JSON bootstrap on fd 3 (never argv/env):
// reads it, opens the settings store, starts the session server on loopback,
// prints READY_LINE, and exits cleanly on SIGTERM or if its parent disappears.

import { homedir } from "node:os";
import { execFile } from "node:child_process";
import { createReadStream, existsSync } from "node:fs";
import { READY_LINE, type Bootstrap } from "../shared/protocol";
import { buildMethods } from "./methods";
import { startServer } from "./server";
import { SettingsStore } from "./settings";
import { TerminalManager } from "./terminals";
import { AgentEngine } from "./agent/agent";
import { ProviderStore } from "./agent/providers";
import { rootOf } from "./paths";
import { McpManager } from "./mcp";
import { ComputerStore, computerTools, makeDriver } from "./computer";
import { Hands, ReplayStore, handsBin, handsDir, handsTools, parseInstant, runInstant, runReplay, type Step } from "./hands";
import { MemoryStore } from "./memory";
import { ChatStore } from "./chats";
import { PluginStore } from "./plugins";
import { SkillSet } from "./skillset";
import { seedBuiltinSkills } from "./builtinSkills";
import { SkillFinder, skillFinderTools } from "./skillFinder";
import { BranchRules } from "./engines/branchGuard";
import { AgentSet } from "./agentfiles";
import { ActionStore } from "./project";
import { ENGINE_NAMES, EngineStore } from "./engines/detect";
import { AutomationRunner } from "./automations/runner";
import { changes as gitChanges } from "./project";
import { ClaudeCodeEngine } from "./engines/claude";
import { CodexEngine } from "./engines/codex";
import { AcpEngine } from "./engines/acp";
import { EngineRefresher } from "./engines/refresh";
import { LimitsStore } from "./engines/limits";
import { AccountStore } from "./engines/accounts";
import { UsageService } from "./usage";
import { LibraryService } from "./library";
import { LeadsService } from "./leads";
import type { Tool } from "./agent/tools";
import { EchoEngine, TurnManager } from "./turns";
import { ChiefManager } from "./chief/manager";
import { CHIEF_MCP_PATH, chiefMcpHandler } from "./chief/mcp";
import { DeviceBridge } from "./devices/bridge";
import { browserTools } from "./devices/browser";
import { IosSimulators, iosTool } from "./devices/ios";
import { askTool } from "./ask";
import { DEVICES_MCP_PATH, DeviceGrants, devicesMcpHandler } from "./devices/mcp";
import type { ToolScope } from "./turns";
import { WorkspaceStore } from "./workspaces";
import { LedgerStore } from "./ledger";
import { checkpointTool } from "./checkpoint";
import { ImageGen, imageTool } from "./imagegen";
import { AutoSwitch } from "./autoswitch";
import { VoiceService } from "./voice";
import { TtsService } from "./tts";
import { VoiceAgentService } from "./voiceagent";

process.title = "opscode-runtime";

const log = (line: string): void => {
  process.stdout.write(`[runtime] ${line}\n`);
};

function parseBootstrap(raw: unknown): Bootstrap {
  const b = raw as Partial<Bootstrap>;
  const ok =
    typeof b === "object" &&
    b !== null &&
    b.host === "127.0.0.1" &&
    Number.isInteger(b.port) &&
    (b.port as number) > 0 &&
    (b.port as number) < 65536 &&
    typeof b.token === "string" &&
    /^[0-9a-f]{64}$/.test(b.token) &&
    typeof b.stateDir === "string" &&
    b.stateDir.length > 0 &&
    typeof b.appVersion === "string" &&
    Number.isInteger(b.parentPid);
  if (!ok) throw new Error("invalid bootstrap envelope");
  return b as Bootstrap;
}

function readBootstrap(): Promise<Bootstrap> {
  return new Promise((resolve, reject) => {
    let text = "";
    const stream = createReadStream("", { fd: 3, encoding: "utf8" });
    stream.on("data", (chunk) => (text += chunk));
    stream.on("error", reject);
    stream.on("end", () => {
      try {
        resolve(parseBootstrap(JSON.parse(text)));
      } catch (err) {
        reject(err);
      }
    });
  });
}

async function main(): Promise<void> {
  const boot = await readBootstrap();
  const settings = new SettingsStore(boot.stateDir); // creates the 0700 state dir
  const workspaces = new WorkspaceStore(boot.stateDir);
  const providers = new ProviderStore(boot.stateDir);
  const memory = new MemoryStore(boot.stateDir);
  const chats = new ChatStore(boot.stateDir);
  // What happened in each chat, for hand-offs between engines (docs/cross-engine-handoff-plan.md).
  const ledger = new LedgerStore(boot.stateDir, log);
  // Local voice input: Whisper Large-v3 Turbo Q5.
  const voice = new VoiceService((n) => broadcastRef(n), log, boot.stateDir);
  // Read aloud: Kitten TTS in a worker process, started on first use (src/runtime/tts).
  const tts = new TtsService(boot.stateDir, (n) => broadcastRef(n), log);
  try { const gone = ledger.sweep(new Set(chats.list().map((c) => c.id))); if (gone) log(`ledger: removed ${gone} of deleted chats`); } catch (e) { log(`ledger sweep failed: ${String(e)}`); }
  const plugins = new PluginStore(boot.stateDir);
  const computer = { store: new ComputerStore(boot.stateDir), driver: makeDriver() };
  // Computer use through Accessibility (native opscode-hands): read apps as numbered lists, act by number, only risky steps ask.
  const hb = handsBin();
  const hands = hb ? new Hands(hb, handsDir(boot.stateDir)) : undefined;
  const replays = new ReplayStore(handsDir(boot.stateDir));
  // Whether the helper can read apps (the Accessibility permission), checked at most every 20 s.
  let axKnown: { ok: boolean; at: number } | undefined;
  // Every step on the Mac is announced (computer.act) so the windows can show it: the glow around the screen, the frame
  // around the app being used, the live line in the notch.
  let broadcastAct: (params: Record<string, unknown>) => void = () => {};
  const computerAct = (source: Record<string, unknown>) => ({
    onAct: (summary: string, at?: { app?: string; pid?: number }) => broadcastAct({ ...source, phase: "start", summary, ...(at?.app ? { app: at.app } : {}), ...(at?.pid ? { pid: at.pid } : {}) }),
    onTarget: (at: { app?: string; pid?: number; ok: boolean; error?: string }) => broadcastAct({ ...source, phase: "end", ok: at.ok, ...(at.error ? { error: at.error } : {}), ...(at.app ? { app: at.app } : {}), ...(at.pid ? { pid: at.pid } : {}) }),
  });
  // Steps of the chats started as "do this on my Mac" (computer.task), kept to learn the task when it worked.
  const chatSteps = new Map<string, { step: Step; ok: boolean }[]>();
  /**
   * The person pressed Allow…: ask macOS for Accessibility. An entry left by an older build (a different signature) shows as ON in
   * System Settings but macOS no longer applies it; when Accessibility is not working, Opscode's own entry is removed first so the
   * prompt creates a fresh one that matches this build, then the Accessibility page is opened to turn it on.
   */
  const askAccess = async (pane: "accessibility" | "screen" = "accessibility"): Promise<boolean> => {
    if (!hands) return false;
    const real = process.platform === "darwin" && process.env.OPSCODE_COMPUTER_DRIVER !== "mock";
    if (pane === "screen") {
      // Same repair for Screen Recording: an entry from an older build shows as ON but is not applied.
      if ((await hands.check()).screen === true) return true;
      if (real) await new Promise<void>((resolve) => execFile("/usr/bin/tccutil", ["reset", "ScreenCapture", "com.opscode.app"], () => resolve()));
      const s = await hands.run("check", ["ask-screen"], undefined, 8000);
      const got = s.ok && s.screen === true;
      if (!got && real) await new Promise<void>((resolve) => execFile("/usr/bin/open", ["x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"], () => resolve()));
      return got;
    }
    if (await handsReady(true)) return true;
    if (real) await new Promise<void>((resolve) => execFile("/usr/bin/tccutil", ["reset", "Accessibility", "com.opscode.app"], () => resolve()));
    const r = await hands.run("check", ["ask-access"], undefined, 8000);
    const ok = r.ok && r.accessibility === true;
    axKnown = { ok, at: Date.now() };
    if (!ok && real) await new Promise<void>((resolve) => execFile("/usr/bin/open", ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"], () => resolve()));
    return ok;
  };
  const handsReady = async (force = false): Promise<boolean> => {
    if (!hands) return false;
    if (!force && axKnown && Date.now() - axKnown.at < 20_000) return axKnown.ok;
    const r = await hands.check();
    axKnown = { ok: r.ok && r.accessibility === true, at: Date.now() };
    return axKnown.ok;
  };
  const skillset = new SkillSet(boot.stateDir, plugins, (wid) => workspaces.get(wid));
  // Opscode's small built-in skills (fix-bug, check-on-screen, server-change), added once when missing.
  try { seedBuiltinSkills(skillset.userDir); } catch (e) { log(`built-in skills not written: ${String(e)}`); }
  const branchRules = new BranchRules(boot.stateDir);
  const skillFinder = new SkillFinder(boot.stateDir, skillset.userDir, log, undefined, undefined, { projectSkillsDir: (wid, create) => skillset.projectDir(wid, create), changed: () => broadcastRef({ method: "skill.changed", params: {} }) });
  try { skillFinder.startSweeping(); } catch (e) { log(`skill finder sweep failed: ${String(e)}`); }
  const engines = new EngineStore(boot.stateDir);
  // Who is signed in to Claude Code and Codex, and the extra accounts (each in its own private folder).
  const accounts: AccountStore = new AccountStore({
    stateDir: boot.stateDir, engines, log,
    notify: (method, params) => broadcastRef({ method, params }),
    busy: (engine, id): number => (turns?.runningChats() ?? []).filter((cid) => { const c = chats.get(cid); return c?.engine === engine && accounts.resolve(engine, c) === id; }).length,
    removed: (engine, id) => {
      const hit = chats.unpinAccount(engine, id);
      if (engine === "claude-code" || engine === "codex") limits.drop(engine, id);
      if (hit.length) broadcastRef({ method: "chat.changed", params: { chats: chats.list() } });
    },
  });
  const claudeEngine = new ClaudeCodeEngine(engines, accounts);
  const codexEngine = new CodexEngine(engines, accounts);
  const acpEngines = { antigravity: new AcpEngine("antigravity", engines, accounts), qoder: new AcpEngine("qoder", engines, accounts) };
  const engineRefresher = new EngineRefresher(engines, { codex: codexEngine, antigravity: acpEngines.antigravity, qoder: acpEngines.qoder }, (list, settings) => broadcastRef({ method: "engines.changed", params: { engines: list, settings } }), log);
  const limits = new LimitsStore(engines, accounts, (all, byAccount) => broadcastRef({ method: "limits.changed", params: { limits: all, by_account: byAccount } }));
  // The image rule: every engine's image requests go to Codex's image generator, hopping to the next Codex account when one is used up.
  const imageGen = new ImageGen({
    codexPath: () => engines.codexPath(),
    accounts: () => accounts.records("codex").map((a, i) => ({ id: a.id, position: i + 1, active: accounts.active("codex") === a.id, env: accounts.env("codex", a.id) })),
    limitsFor: (id) => limits.forAccount("codex", id),
    refreshLimits: (id, force) => limits.refreshAccount("codex", id, force),
    changed: (status) => broadcastRef({ method: "imagegen.changed", params: status }),
    log,
  });
  claudeEngine.onLimits = (info, account) => limits.fromClaudeEvent(info, account);
  codexEngine.onLimits = (p, account) => limits.fromCodexUpdate(p, account);
  const usage = new UsageService(boot.stateDir, (method, params) => broadcastRef({ method, params }), () => {
    // Which of the logged sessions are Opscode chats: the engine's session id is stored on the chat.
    const m = new Map<string, { chat_id: string; title: string; workspace_id: string; mode?: string }>();
    for (const c of chats.list()) {
      for (const s of Object.values(c.engine_sessions ?? {})) if (s && s !== c.engine_session) m.set(s, { chat_id: c.id, title: c.title, workspace_id: c.workspace_id });
      if (!c.engine_session) continue;
      // A worker or the Conductor's own chat belongs to a Chief; if that Chief has a mode, the chat is in it.
      const mode = c.chief ? chief?.store.get(c.chief.id)?.mode : undefined;
      m.set(c.engine_session, { chat_id: c.id, title: c.title, workspace_id: c.workspace_id, ...(mode ? { mode } : {}) });
    }
    return m;
  }, () => accounts.homes());
  const library = new LibraryService(boot.stateDir, (method, params) => broadcastRef({ method, params }));
  const leads = new LeadsService(boot.stateDir);
  const agentSet = new AgentSet(boot.stateDir, (wid) => workspaces.get(wid));
  let broadcastRef: (n: { method: string; params?: unknown }) => void = () => {};
  const mcp = new McpManager(boot.stateDir, boot.stateDir, () => broadcastRef({ method: "mcp.changed", params: { servers: mcp.list() } }), (id, ok, error) => broadcastRef({ method: "mcp.oauth.done", params: { id, ok, ...(error ? { error } : {}) } }), (line) => log(line));
  const echo = new EchoEngine();
  const agent = new AgentEngine(() => {
    const c = providers.active();
    if (!c) throw new Error("no provider is configured");
    return c;
  });
  let terminals: TerminalManager | undefined;
  let turns: TurnManager | undefined;
  let automations: AutomationRunner | undefined;
  let chief: ChiefManager | undefined;
  let voiceAgent: VoiceAgentService | undefined;
  let devicesRef: DeviceBridge | undefined;
  let simsRef: IosSimulators | undefined;

  const server = await startServer(
    boot,
    (hub) => {
      terminals = new TerminalManager({ notify: hub.notify, log });
      broadcastRef = hub.broadcast;
      mcp.setExternal(plugins.mcpServers());
      const devices = new DeviceBridge(hub.notify);
      const deviceGrants = new DeviceGrants();
      devicesRef = devices;
      hub.onHttp(DEVICES_MCP_PATH, devicesMcpHandler(deviceGrants, boot.appVersion));
      hub.onSessionClosed((sessionId) => devices.sessionClosed(sessionId));
      const sims = IosSimulators.create(log);
      simsRef = sims;
      sims?.hasDevices(); // learn early whether any simulator exists
      if (sims) sims.onActivity = (udid, label) => hub.broadcast({ method: "ios.activity", params: { udid, label } });
      // The base tools every chat gets (browser, simulators, skills, checkpoints, images).
      const baseTools = (scope: ToolScope): Tool[] => [...(devices.available() ? browserTools(devices, scope) : []), ...(sims?.hasDevices() ? [iosTool(sims, scope)] : []), ...skillFinderTools(skillFinder, scope), checkpointTool(ledger, scope), imageTool(imageGen), askTool()];
      // The person's own MCP servers (Firecrawl, TinyFish, GitHub, ...) as Opscode tools: one definition for every model. Approvals follow the
      // chat's permission mode, the same for the built-in agent (any provider) and for Claude Code and Codex.
      const userMcpTools = (short: boolean): Tool[] => mcp.agentTools(short).map(({ name, server, tool }) => ({
        def: { name, description: `(MCP) ${tool.description}`.slice(0, 1000), schema: tool.inputSchema },
        kind: "mcp",
        describe: (i) => ({ summary: name.replace(/^mcp__/, "").replace("__", " · "), detail: JSON.stringify(i, null, 2).slice(0, 2000) }),
        run: async (i, { signal }) => {
          const r = await mcp.call(server, tool.name, i, signal);
          return { output: r.text, is_error: r.is_error };
        },
      }) as Tool);
      // Claude Code and Codex reach the base tools and the MCP servers through Opscode's own MCP endpoint. (Every turn awaits mcpTools first,
      // which connects the servers, so they are ready by the time this list is read; nothing is started at launch.)
      const deviceTools = (scope: ToolScope): Tool[] => [...baseTools(scope), ...userMcpTools(true)];
      const mcpTools = async (scope: ToolScope): Promise<Tool[]> => {
        await mcp.ensureReady();
        // Fresh per turn: the tools remember the size of their last screenshot.
        // With the Accessibility helper: the numbered-list tools (only risky steps ask) plus a screenshot for questions about how
        // something looks. Without it: the older screenshot-and-position tools (each action asks).
        let own: Tool[] = [];
        if (computer.store.enabled()) {
          if (hands && await handsReady()) {
            const shot = computer.driver ? computerTools(computer.driver, computer.store).filter((t) => t.def.name === "computer_screenshot") : [];
            own = [...handsTools(hands, computer.store, { key: scope.chatId, ...computerAct({ source: "chat", chat_id: scope.chatId }), onStep: (step, ok) => chatSteps.get(scope.chatId)?.push({ step, ok }) }), ...shot];
          } else if (computer.driver) own = computerTools(computer.driver, computer.store);
        }
        return [...own, ...baseTools(scope), ...userMcpTools(false)];
      };
      const memoryOn = (): boolean => settings.get().memory_enabled;
      turns = new TurnManager({ ledger, noAsk: (c) => (voiceAgent?.isWorkerChat(c.id) ? "Nobody can answer now: the person is talking with the voice agent, which reads your reply. Put the open question at the end of your reply." : undefined), accounts: { resolve: (e, c) => accounts.resolve(e, c), touch: (e, id) => accounts.touch(e, id), authFailed: (e, id) => void accounts.invalidate(e, id) }, autoSwitch: new AutoSwitch({ enabled: () => engines.settings().auto_switch, installed: (e) => !!(e === "claude-code" ? engines.claudePath() : engines.codexPath()), limits: () => limits.all(), limitsFor: (e, id) => limits.forAccount(e, id ?? "default"), accountOf: (e, c) => accounts.resolve(e, c) }), branches: branchRules, turnEnded: (chatId) => { skillFinder.touch(chatId); }, chatDeleted: (chatId) => { skillFinder.chatGone(chatId); }, agents: { catalog: (wid) => agentSet.list(wid).map((x) => ({ name: x.name, description: x.description })), get: (wid, name) => { const a = agentSet.get(wid, name); return a ? { name: a.def.name, access: a.def.access, body: a.def.body } : undefined; } }, skills: { catalog: (wid) => skillset.list(wid).map((x) => ({ name: x.name, description: x.description })), read: (wid, name) => skillset.get(wid, name)?.body, files: (wid) => skillset.files(wid) }, chats, defaultMode: () => settings.get().default_mode, extraTools: mcpTools, devices: { tools: deviceTools, grants: deviceGrants, url: () => `http://127.0.0.1:${boot.port}${DEVICES_MCP_PATH}` }, memory: {
        prompt: (wid) => (memoryOn() ? memory.promptFor(wid) : ""),
        saveDraft: (wid, title, body) => {
          if (!memoryOn()) throw new Error("memory is turned off in Settings");
          memory.add({ scope: wid, title, body, state: "draft" });
          hub.broadcast({ method: "memory.changed", params: { notes: memory.list() } });
        },
      }, engine: (chat) => (chat.engine === "claude-code" ? claudeEngine : chat.engine === "codex" ? codexEngine : chat.engine === "antigravity" || chat.engine === "qoder" ? acpEngines[chat.engine] : providers.active() || chat.chief?.role === "home" || chat.voice ? agent : echo), workspace: (id) => workspaces.get(id) ?? chief?.homeWorkspace(id), rootOf, broadcast: hub.broadcast, log,
        observe: (ev) => { chief?.observe(ev); voiceAgent?.observe(ev); }, chiefBrain: (chat, turnId) => voiceAgent?.brain(chat, turnId) ?? chief?.brain(chat, turnId) });
      const t = terminals;
      const tm = turns;
      // Voice mode: a front agent you talk to that briefs the worker chat (src/runtime/voiceagent, docs/voice-mode-plan.md).
      broadcastAct = (params) => hub.broadcast({ method: "computer.act", params });
      voiceAgent = new VoiceAgentService({
        broadcast: hub.broadcast, log, voice, tts, turns: tm, chats,
        // The person's Mac for voice mode: the same tools, instant commands and learned tasks as chats.
        ...(hands ? { computer: {
          ready: async () => computer.store.enabled() && await handsReady(),
          status: async () => ({ on: computer.store.enabled(), accessibility: await handsReady() }),
          setup: async () => {
            computer.store.setEnabled(true);
            hub.broadcast({ method: "computer.changed", params: {} });
            axKnown = undefined;
            if (await handsReady()) return "Computer use is on and Accessibility is already allowed. It works from the next voice session (say End, then start again).";
            // macOS's own prompt adds Opscode to the Accessibility list (the person only flips the switch).
            if (await askAccess()) return "Computer use is on and Accessibility is allowed. It works from the next voice session (say End, then start again).";
            return "Computer use is on. System Settings → Accessibility is open: the person must turn on Opscode there themselves, then start voice mode again.";
          },
          tools: (o) => handsTools(hands, computer.store, { key: o.key, onStep: o.onStep, onAct: (summary, at) => { o.onAct(summary); computerAct({ source: "voice" }).onAct(summary, at); }, onTarget: computerAct({ source: "voice" }).onTarget }),
          instant: async (text) => {
            const cmd = parseInstant(text);
            if (!cmd) return null;
            // Opening, quitting or switching apps is the person's own command: it needs neither the Computer use switch nor
            // Accessibility (only clicking and typing inside apps do).
            broadcastAct({ source: "voice", phase: "start", summary: cmd.say, app: cmd.target });
            const r = await runInstant(hands, computer.store, cmd);
            broadcastAct({ source: "voice", phase: "end", ok: r.ok, app: cmd.target });
            return r;
          },
          replay: async (text, onAct) => {
            const r = replays.find(text);
            if (!r || !computer.store.enabled() || !(await handsReady())) return null;
            const res = await runReplay(hands, computer.store, r, (what) => { onAct(what); broadcastAct({ source: "voice", phase: "start", summary: what }); });
            broadcastAct({ source: "voice", phase: "end", ok: res.ok });
            if (!res.ok) return { ok: false, say: "" };
            replays.used(r.phrase);
            return { ok: true, say: "Done." };
          },
          learn: (text, steps) => replays.learn(text, steps as { step: Step; ok: boolean }[]),
        } } : {}),
        workspace: (id) => workspaces.get(id), rootOf, settings: () => settings.get(),
        // Voice mode works across every project, and can add a folder as a new one after the person says yes.
        workspaces: () => workspaces.list(),
        addWorkspace: (path) => {
          const r = workspaces.add(path);
          if (r.created) hub.broadcast({ method: "workspace.changed", params: { workspaces: workspaces.list() } });
          return r.workspace;
        },
        engines: () => engines.cached(),
        apiModel: () => providers.active()?.model,
        // Tests point the folder tools at a temporary home folder.
        home: () => process.env.OPSCODE_VOICE_HOME || homedir(),
        mcpUrl: () => `http://127.0.0.1:${boot.port}${CHIEF_MCP_PATH}`,
        memory: (wid) => (memoryOn() ? memory.promptFor(wid) : ""),
        defaultEngine: () => { const e = engines.settings(); return { engine: e.default_engine, ...(e.default_model ? { model: e.default_model } : {}), ...(e.default_effort ? { effort: e.default_effort } : {}) }; },
        engineProblem: (e) => e === "api" ? (providers.active() ? undefined : "No API key is set up (Settings → Models & keys).") : (() => { const p = engines.pathOf(e as "claude-code" | "codex" | "antigravity" | "qoder"); return !!p && existsSync(p); })() ? undefined : `${ENGINE_NAMES[e as "claude-code" | "codex" | "antigravity" | "qoder"] ?? e} is not installed on this Mac.`,
        // The voice agent opens and reads pages itself; "full" here only switches off the worker's approval cards, which a
        // hidden chat could not show. voiceagent/browser.ts adds its own rule for sites outside this computer.
        browser: (workspaceId, chatId) => (devices.available() ? browserTools(devices, { workspaceId, chatId, mode: () => "full" }) : undefined),
      });
      automations = new AutomationRunner({
        stateDir: boot.stateDir,
        workspace: (id) => workspaces.get(id),
        workspaces: () => workspaces.list(),
        rootOf,
        chats,
        turns: { submit: (w, c, text) => tm.submit(w, c, text), whenDone: (id) => tm.whenDone(id), interrupt: (id) => { try { return tm.interrupt(id); } catch { return null; } } },
        agent: (wid, name) => { const a = agentSet.get(wid, name); return a ? { access: a.def.access, body: a.def.body, ...(a.def.engine ? { engine: a.def.engine } : {}), ...(a.def.model ? { model: a.def.model } : {}), ...(a.def.decides ? { decides: a.def.decides } : {}) } : undefined; },
        // Automations and Conductor workers run on Claude Code, Codex or an API key; a default of Antigravity or Qoder is for chats only.
        defaultEngine: () => { const e = engines.settings().default_engine; return e === "antigravity" || e === "qoder" ? "claude-code" : e; },
        diff: async (root) => (await gitChanges(root)).diff,
        broadcast: (method, params) => {
          hub.broadcast({ method, params });
          if (method === "automation.run_updated") chief?.onRun((params as { run: Parameters<ChiefManager["onRun"]>[0] }).run);
        },
        log,
      });
      automations.startScheduler();
      const runner = automations;
      chief = new ChiefManager({
        stateDir: boot.stateDir,
        library,
        chats,
        turns: tm,
        workspaces: () => workspaces.list(),
        engineProblem: (e) =>
          e === "claude-code" ? (engines.claudePath() ? undefined : "Claude Code is not installed (no `claude` program found).")
          : e === "codex" ? (engines.codexPath() ? undefined : "Codex is not installed (no `codex` program found).")
          : providers.active() ? undefined : "No API key is set up (Settings → Models & keys).",
        defaultWorkerEngine: () => { const e = engines.settings().default_engine; return e === "antigravity" || e === "qoder" ? "claude-code" : e; },
        memory: {
          prompt: (wid) => (memoryOn() ? memory.promptFor(wid) : ""),
          remember: (scope, text) => {
            if (!memoryOn()) throw new Error("memory is turned off in Settings");
            memory.add({ scope, body: text, state: "kept" });
            hub.broadcast({ method: "memory.changed", params: { notes: memory.list() } });
          },
        },
        automations: {
          list: (wid) => runner.list(wid).map((f) => ({ name: f.name, scope: f.scope, description: f.automation?.description ?? "", inputs: f.automation?.inputs ?? {}, ok: !!f.automation })),
          start: (wid, scope, name, inputs) => runner.start(wid, scope, name, inputs),
        },
        mcpUrl: () => `http://127.0.0.1:${boot.port}${CHIEF_MCP_PATH}`,
        broadcast: (method, params) => hub.broadcast({ method, params }),
        log,
        limits,
        accountExists: (e, id) => !!accounts.find(e, id),
        codexModelIds: () => engines.codexModelIds(),
      });
      const cm = chief;
      // Learn this Codex's model ids once (a short app-server, no model run), so a mode's Codex pick applies from the first worker.
      // Right after start the agents are read again in the background (the windows already have the last answer from disk).
      engineRefresher.revalidate(0);
      cm.startTicker(Number(process.env.OPSCODE_CHIEF_TICK_MS) || undefined);
      hub.onHttp(CHIEF_MCP_PATH, chiefMcpHandler((token) => cm.toolsFor(token) ?? voiceAgent?.toolsFor(token), boot.appVersion));
      hub.onSessionClosed((sessionId) => t.sessionClosed(sessionId));
      return buildMethods({ branches: branchRules, version: boot.appVersion, settings, workspaces, terminals: t, turns, providers, memory, chats, plugins, skillset, agents: agentSet, actions: new ActionStore(boot.stateDir), engines: { store: engines, codex: codexEngine, acp: acpEngines, refresher: engineRefresher, limits, accounts }, imageGen, usage, library, leads, automations: () => automations as AutomationRunner, chief: () => chief as ChiefManager, mcp, computer, hands: { hands, replays, ready: handsReady, askAccess, known: (ok: boolean) => { axKnown = { ok, at: Date.now() }; }, steps: chatSteps, act: (p: Record<string, unknown>) => broadcastAct(p) }, voice, tts, voiceAgent: () => voiceAgent as VoiceAgentService, devices: () => devicesRef as DeviceBridge, ios: () => simsRef, broadcast: hub.broadcast });
    },
    log,
  );

  let stopping = false;
  const stop = async (why: string): Promise<void> => {
    if (stopping) return;
    stopping = true;
    log(`stopping (${why})`);
    automations?.stopScheduler();
    chief?.stopTicker();
    turns?.abortAll();
    ledger.flush();
    mcp.closeAll();
    voiceAgent?.close();
    voice.close();
    tts.close();
    simsRef?.closeAll();
    terminals?.closeAll(); // kill PTY children before we go
    await server.close();
    process.exit(0);
  };
  process.on("SIGTERM", () => void stop("SIGTERM"));
  process.on("SIGINT", () => void stop("SIGINT"));

  // Exit if the app that started us is gone, so the runtime never outlives it.
  setInterval(() => {
    try {
      process.kill(boot.parentPid, 0);
    } catch {
      void stop("parent exited");
    }
  }, 2000).unref();

  process.stdout.write(`${READY_LINE} ${server.port}\n`);
  log(`listening on ws://${boot.host}:${server.port}/session/v1`);
}

main().catch((err) => {
  process.stderr.write(`[runtime] fatal: ${err instanceof Error ? err.message : String(err)}\n`);
  process.exit(1);
});
