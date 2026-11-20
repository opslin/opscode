// The notch: a clear, always-on-top panel on the screen's top edge that shows every chat's state with Opscode's own
// character (asleep, working, needs you, done, failed), pops open when something needs the person, and lets them answer
// approvals, jump to a chat, send a quick message or dictate one, from whatever app is in front (fullscreen too).
//
// It has its own runtime connection (MainRpcClient), so it keeps working while the main window is hidden or closed.
// Its page (notch.html) never gets the runtime endpoint: main sends it the feed and does what it asks, checked here.
//
// Pointer: the window lets every click through (setIgnoreMouseEvents(true, forward)) except over the drawn shape; the
// page says when the pointer is over it, and main watches the cursor so a fast exit never leaves it catching clicks.

import { app, BrowserWindow, globalShortcut, ipcMain, Menu, screen, systemPreferences, type IpcMainEvent } from "electron";
import { execFile } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { NOTCH } from "../shared/ipc";
import type { ChatMeta, TurnEvent, Workspace } from "../shared/protocol";
import { MainRpcClient } from "./rpcClient";
import type { Endpoint } from "./runtime";
import { Overlay } from "./overlay";
import { mobileApprovalRevision, mobileCanAllow } from "./mobileBridge";
import { MobilePairing } from "./mobilePairing";
import { MobileWorkspace } from "./mobileWorkspace";
import { NotchModel, hardwareNotchOf, notchAction, type NotchHardware } from "./notchState";

export { hardwareNotchOf, notchAction };

export const NOTCH_WIDTH = 640;
export const NOTCH_HEIGHT = 640;
const WATCH_MS = 150;
const SHORTCUT = "CommandOrControl+Shift+Space";
/** Start or stop talking with the voice agent from any app. */
const TALK_SHORTCUT = "Control+Alt+Space";

export interface OpenTarget { chat_id?: string; workspace_id?: string; draft?: string; newchat?: boolean }

interface ModelPick { engine?: string; model?: string; effort?: string }
interface NotchSettings { sounds: boolean; hiddenUntil: number; /** What new voice workers run on (empty: the default). */ workerPick?: ModelPick }

interface EngineRow { id: string; label: string; found: boolean; models: { id: string; label: string; efforts?: string[] }[] }
const EFFORT_LEVELS = ["low", "medium", "high", "xhigh", "max"];

const MEASURE = `ObjC.import("AppKit"); var s = $.NSScreen.screens.objectAtIndex(0); JSON.stringify({ width: s.frame.size.width, top: s.safeAreaInsets.top, left: s.auxiliaryTopLeftArea.size.width, right: s.auxiliaryTopRightArea.size.width })`;

function measureNotch(): Promise<NotchHardware | null | undefined> {
  if (process.platform !== "darwin") return Promise.resolve(null);
  return new Promise((resolve) => {
    execFile("/usr/bin/osascript", ["-l", "JavaScript", "-e", MEASURE], { timeout: 5000 }, (err, out) => resolve(err ? undefined : hardwareNotchOf(String(out))));
  });
}

export class Notch {
  private win: BrowserWindow | null = null;
  private client: MainRpcClient | null = null;
  private readonly model = new NotchModel();
  private hardware: NotchHardware | null | undefined;
  private watching: NodeJS.Timeout | undefined;
  private changing: NodeJS.Timeout | undefined;
  private sending: NodeJS.Timeout | undefined;
  private voiceSession: string | null = null;
  /** Dictation: voice.start was asked and has not answered yet; a stop pressed meanwhile waits here. */
  private voiceStarting = false;
  private voiceStopAfterStart: "stop" | "cancel" | null = null;
  /** Voice mode is starting: its first events (the model picks, a worker) arrive before its session id does. */
  private talkEarly: Record<string, unknown>[] | null = null;
  /** The voice-agent session the notch talks in (voice mode), or null. */
  private talkSession: string | null = null;
  /** The glow, the app frame and the workers' mini screens. */
  private overlay: Overlay | null = null;
  /** What the voice agent talks with and what new workers run on (the runtime's "picks" event). */
  private picks: { brain?: ModelPick; worker?: ModelPick & { default?: boolean } } = {};
  private stopped = false;
  private rendererChat: string | null = null;
  private focused = false;
  private settings: NotchSettings;
  private readonly settingsPath: string;
  private mobile?: MobilePairing;
  private mobileWorkspace?: MobileWorkspace;
  private mobileFeedReady = false;

  constructor(private readonly o: {
    url: string;
    preload: string;
    log: (line: string) => void;
    endpoint: () => Endpoint | null;
    openMain: (target: OpenTarget) => void;
  }) {
    this.settingsPath = join(app.getPath("userData"), "notch.json");
    this.settings = { sounds: true, hiddenUntil: 0 };
    try { this.settings = { ...this.settings, ...(JSON.parse(readFileSync(this.settingsPath, "utf8")) as Partial<NotchSettings>) }; } catch { /* first run */ }
  }

  start(): void {
    if (process.platform === "darwin") {
      try {
        const workspace = this.mobileWorkspace = new MobileWorkspace(() => this.client);
        this.mobile = new MobilePairing({
          log: this.o.log,
          workspace: (device, request) => workspace.request(device, request),
          onRevoked: (device) => workspace.disposeDevice(device),
          feed: () => this.mobileFeedReady ? this.model.snapshot() : null,
          decide: async ({ revision, ...decision }) => {
            const client = this.client;
            if (!client) throw new Error("Runtime unavailable");
            const request = this.model.approval(decision.turn_id, decision.call_id);
            if (!request || mobileApprovalRevision(request) !== revision) return false;
            if (decision.allow && (!mobileCanAllow(request) ||
              (request.choices?.length ? !request.choices.some((choice) => choice.id === decision.choice) : decision.choice !== undefined))) return false;
            return (await client.call<{ resolved: boolean }>("turn.approve", decision)).resolved;
          },
        });
      } catch { this.o.log("mobile: invalid relay configuration"); }
    }
    this.overlay = new Overlay({ url: this.o.url.replace(/notch\.html$/, "overlay.html"), preload: this.o.preload.replace(/notch\.js$/, "overlay.js"), log: this.o.log, open: (chatId) => { const c = this.model.chat(chatId); this.o.openMain(c ? { chat_id: c.id, workspace_id: c.workspace_id } : {}); } });
    this.overlay.start();
    const fromPage = (e: IpcMainEvent): boolean => !!this.win && !this.win.isDestroyed() && e.sender === this.win.webContents;
    ipcMain.on(NOTCH.READY, (e) => { if (fromPage(e)) this.push(true); });
    ipcMain.on(NOTCH.OVER, (e, on) => { if (fromPage(e)) this.over(on === true); });
    ipcMain.on(NOTCH.MENU, (e) => { if (fromPage(e)) this.menu(); });
    ipcMain.on(NOTCH.ACT, (e, raw) => { const a = fromPage(e) ? notchAction(raw) : null; if (a) void this.act(a); });
    const again = (): void => { clearTimeout(this.changing); this.changing = setTimeout(() => void this.settle(), 400); };
    screen.on("display-added", again);
    screen.on("display-removed", again);
    screen.on("display-metrics-changed", again);
    if (!globalShortcut.register(SHORTCUT, () => this.summon())) this.o.log(`notch: ${SHORTCUT} is taken by another app`);
    if (!globalShortcut.register(TALK_SHORTCUT, () => this.talkSummon())) this.o.log(`notch: ${TALK_SHORTCUT} is taken by another app`);
    this.win = this.create();
    void this.settle();
    void this.connect();
  }

  stop(): void {
    this.mobile?.stop();
    this.mobileWorkspace?.stop();
    this.overlay?.stop();
    this.stopped = true;
    globalShortcut.unregister(SHORTCUT);
    globalShortcut.unregister(TALK_SHORTCUT);
    if (this.talkSession) void this.client?.call("voiceagent.stop", { session: this.talkSession }).catch(() => {});
    clearInterval(this.watching);
    this.client?.close();
    if (this.win && !this.win.isDestroyed()) this.win.destroy();
    this.win = null;
  }

  pairAndroid(reportInWindow = true): Promise<void> | undefined { return this.mobile?.show(reportInWindow); }

  mobileStatus() { return this.mobile?.status() ?? null; }
  revokeMobileDevice(id: string): Promise<void> | undefined { return this.mobile?.revoke(id); }

  /** The main window says which chat it shows (null: none, or another page). */
  viewing(chatId: string | null): void {
    this.rendererChat = chatId;
    this.refreshViewing();
  }

  /** The main window gained or lost focus (or was hidden). */
  mainFocus(on: boolean): void {
    this.focused = on;
    this.refreshViewing();
  }

  /** Open with the message box ready (global shortcut). */
  summon(): void {
    if (!this.win || this.win.isDestroyed()) return;
    if (this.settings.hiddenUntil > Date.now()) { this.settings.hiddenUntil = 0; this.save(); void this.settle(); }
    this.win.setIgnoreMouseEvents(false);
    this.win.focus();
    this.win.webContents.send(NOTCH.SUMMON);
  }

  /** ⌃⌥Space: start talking (or stop, when already talking). */
  talkSummon(): void {
    if (!this.win || this.win.isDestroyed()) return;
    if (this.settings.hiddenUntil > Date.now()) { this.settings.hiddenUntil = 0; this.save(); void this.settle(); }
    this.win.setIgnoreMouseEvents(false);
    this.win.webContents.send(NOTCH.TALK_SUMMON);
  }

  /**
   * The model menu for voice mode (a native menu under the chip): every engine found on this Mac with its models, the API
   * key's model, and the effort. "brain" = what the voice agent talks with (saved as the voice setting); "worker" = what
   * new workers run on (kept in notch.json for next time).
   */
  private async modelMenu(c: MainRpcClient, which: "brain" | "worker", x?: number, y?: number): Promise<void> {
    const win = this.win;
    const session = this.talkSession;
    if (!win || win.isDestroyed() || !session) return;
    const [{ engines }, { providers }] = await Promise.all([
      c.call<{ engines: EngineRow[] }>("engines.list", {}),
      c.call<{ providers: { label: string; configured: boolean; active: boolean; model: string }[] }>("provider.list", {}),
    ]);
    const cur = (which === "brain" ? this.picks.brain : this.picks.worker) ?? {};
    const isDefault = which === "worker" && !!(this.picks.worker as { default?: boolean } | undefined)?.default;
    const apply = (p: ModelPick): void => {
      void (async () => {
        try {
          const r = await c.call<{ brain?: ModelPick; worker?: ModelPick }>("voiceagent.pick", { session, [which]: p });
          this.picks = { brain: r.brain, worker: r.worker };
          if (which === "brain") await c.call("settings.set", { patch: { voice_brain_engine: p.engine ?? "", voice_brain_model: p.model ?? "", voice_brain_effort: p.effort ?? "" } });
          else { this.settings.workerPick = p.engine || p.model || p.effort ? p : undefined; this.save(); }
        } catch (err) { this.toast(err instanceof Error ? err.message : String(err)); }
      })();
    };
    const items: Electron.MenuItemConstructorOptions[] = [{ label: which === "brain" ? "Opscode talks with" : "New workers run on", enabled: false }];
    if (which === "worker") items.push({ label: "Default (same as new chats)", type: "radio", checked: isDefault, click: () => apply({}) });
    for (const e of engines.filter((x) => x.found)) {
      const sub: Electron.MenuItemConstructorOptions[] = e.models.length
        ? e.models.slice(0, 16).map((m) => ({ label: m.label, type: "radio" as const, checked: !isDefault && cur.engine === e.id && cur.model === m.id, click: () => apply({ engine: e.id, model: m.id, ...(cur.effort && (!m.efforts || m.efforts.includes(cur.effort)) ? { effort: cur.effort } : {}) }) }))
        : [{ label: "Its own default model", type: "radio" as const, checked: !isDefault && cur.engine === e.id, click: () => apply({ engine: e.id }) }];
      items.push({ label: `${!isDefault && cur.engine === e.id ? "● " : ""}${e.label}`, submenu: sub });
    }
    const api = providers.find((p) => p.active && p.configured);
    if (api) items.push({ label: `API key · ${api.model}`, type: "radio", checked: !isDefault && cur.engine === "api", click: () => apply({ engine: "api" }) });
    if (!isDefault && cur.engine) {
      const model = engines.find((e) => e.id === cur.engine)?.models.find((m) => m.id === cur.model);
      const levels = model?.efforts?.length ? model.efforts.filter((l) => EFFORT_LEVELS.includes(l)) : EFFORT_LEVELS;
      items.push({ type: "separator" }, { label: "Effort", submenu: [
        { label: "Default", type: "radio", checked: !cur.effort, click: () => apply({ engine: cur.engine, ...(cur.model ? { model: cur.model } : {}) }) },
        ...levels.map((l) => ({ label: l[0].toUpperCase() + l.slice(1), type: "radio" as const, checked: cur.effort === l, click: () => apply({ engine: cur.engine, ...(cur.model ? { model: cur.model } : {}), effort: l }) })),
      ] });
    }
    if (which === "brain") items.push({ type: "separator" }, { label: "Switches from its next reply; it keeps the conversation.", enabled: false });
    else items.push({ type: "separator" }, { label: "Workers already running keep their model.", enabled: false });
    Menu.buildFromTemplate(items).popup({ window: win, ...(x !== undefined && y !== undefined ? { x, y } : {}) });
  }

  private toTalk(e: Record<string, unknown>): void {
    if (this.win && !this.win.isDestroyed()) this.win.webContents.send(NOTCH.TALK, e);
  }

  private refreshViewing(): void {
    if (this.model.setViewing(this.focused ? this.rendererChat : null)) this.push();
  }

  // ---- runtime connection -----------------------------------------------------------------------------------------

  private async connect(): Promise<void> {
    while (!this.stopped) {
      const ep = this.o.endpoint();
      if (ep) {
        const c = new MainRpcClient(ep);
        try {
          await c.open();
          this.client = c;
          c.on<TurnEvent>("turn.event", (ev) => {
            this.mobile?.workspaceChanged();
            if (!this.model.event(ev)) return;
            this.push();
            if (ev.type === "approval_request") this.mobile?.notifyApproval();
          });
          c.on<{ chats: ChatMeta[] }>("chat.changed", ({ chats }) => { this.model.setChats(chats); this.push(); this.mobile?.workspaceChanged(); });
          c.on<{ workspaces: Workspace[] }>("workspace.changed", (p) => { if (Array.isArray(p?.workspaces)) { this.model.setWorkspaces(p.workspaces); this.push(); this.mobile?.workspaceChanged(); } });
          c.on("plugin.changed", () => this.mobile?.workspaceChanged());
          c.on<Record<string, unknown>>("voice.event", (v) => this.onVoice(v));
          // Voice mode: the agent's events and its voice (only the notch's own session).
          // Steps on the Mac (any chat, voice mode, the notch's own tasks): the glow and the app frame.
          c.on<Record<string, unknown>>("computer.act", (a) => {
            this.overlay?.act(a); this.toTalk({ kind: "computer", ...a });
            // One log line per step (what, where, whether it worked and why not): the way to see what really happened on this Mac.
            this.o.log(`computer: ${String(a.source ?? "?")} ${String(a.phase ?? "?")}${a.phase === "end" ? (a.ok === false ? " FAILED" : " ok") : ""} app=${String(a.app ?? "-")}${a.summary ? ` step="${String(a.summary).slice(0, 100)}"` : ""}${a.error ? ` error="${String(a.error).slice(0, 200)}"` : ""}`);
          });
          c.on<Record<string, unknown>>("voiceagent.event", (v) => {
            this.mobileWorkspace?.voiceEvent("agent", v);
            // "Show my workers" from voice mode (the notch's or the window's).
            if (v.ev === "show_workers") { this.overlay?.setFeed(this.model.snapshot()); this.overlay?.workers(v.on !== false); }
            if (!this.talkSession && this.talkEarly) { this.talkEarly.push(v); return; }
            if (!this.talkSession || v.session !== this.talkSession) return;
            if (v.ev === "ended") { this.talkSession = null; this.toTalk({ kind: "off", why: v.why ?? "ended" }); return; }
            if (v.ev === "picks") this.picks = { brain: v.brain as ModelPick, worker: v.worker as ModelPick };
            this.toTalk({ kind: "agent", ...v });
          });
          c.on<Record<string, unknown>>("tts.event", (v) => { this.mobileWorkspace?.voiceEvent("tts", v); if (this.talkSession) this.toTalk({ kind: "tts", ...v }); });
          const [{ workspaces }, { chats, running }] = await Promise.all([
            c.call<{ workspaces: Workspace[] }>("workspace.list"),
            c.call<{ chats: ChatMeta[]; running: string[] }>("chat.list"),
          ]);
          this.model.setWorkspaces(workspaces);
          this.model.setChats(chats, running);
          this.mobileFeedReady = true;
          this.mobile?.workspaceChanged();
          this.push();
          this.o.log("notch: connected to the runtime");
          void this.diagnoseAccess(c);
          await c.closed();
        } catch (err) {
          this.o.log(`notch: runtime connection failed: ${err instanceof Error ? err.message : String(err)}`);
        }
        if (this.client === c) this.client = null;
        this.mobileFeedReady = false;
        this.mobile?.publish();
        if (this.talkSession) { this.talkSession = null; this.toTalk({ kind: "off", why: "disconnected" }); }
        c.close();
      }
      await new Promise((r) => setTimeout(r, 1500));
    }
  }

  /** One log line at start: which program is allowed to use Accessibility, and what each way of asking says (for support). */
  private async diagnoseAccess(c: MainRpcClient): Promise<void> {
    if (process.platform !== "darwin") return;
    try {
      const mine = systemPreferences.isTrustedAccessibilityClient(false);
      const bin = join(process.resourcesPath, "..", "MacOS", "opscode-hands");
      const direct = existsSync(bin) ? await new Promise<string>((resolve) => execFile(bin, ["check"], { timeout: 6000 }, (_e, out) => { try { resolve(String((JSON.parse(String(out).trim()) as { accessibility?: boolean }).accessibility)); } catch { resolve("no answer"); } })) : "no helper in the app";
      const d = await c.call<{ helper: string | null; hands: { ok?: boolean; accessibility?: boolean; screen?: boolean } | null; jxa: boolean | null }>("computer.diagnose", {});
      this.o.log(`accessibility: opscode=${mine} helper(direct)=${direct} helper(runtime)=${d.hands?.accessibility ?? "n/a"} osascript=${d.jxa ?? "n/a"} helperPath=${d.helper ?? "none"}; screen recording: opscode=${systemPreferences.getMediaAccessStatus("screen")} helper(runtime)=${d.hands?.screen ?? "n/a"}`);
    } catch (e) { this.o.log(`accessibility: could not check (${e instanceof Error ? e.message : String(e)})`); }
  }

  // ---- actions ------------------------------------------------------------------------------------------------------

  private async act(a: Record<string, unknown>): Promise<void> {
    const c = this.client;
    try {
      switch (a.type) {
        case "open": {
          const chat = a.chat_id ? this.model.chat(a.chat_id as string) : undefined;
          this.o.openMain(chat ? { chat_id: chat.id, workspace_id: chat.workspace_id } : {});
          if (chat && this.model.seen(chat.id)) this.push();
          return;
        }
        case "newchat": this.o.openMain({ newchat: true, ...(a.workspace_id ? { workspace_id: a.workspace_id as string } : {}) }); return;
        case "seen": if (a.all) this.model.seenAll(); else this.model.seen(a.chat_id as string); this.push(); return;
        case "sounds": this.settings.sounds = a.on === true; this.save(); this.push(); return;
        case "workers": this.overlay?.setFeed(this.model.snapshot()); this.overlay?.workers(typeof a.on === "boolean" ? a.on : !this.overlay.showingWorkers); return;
        case "focus":
          if (!this.win || this.win.isDestroyed()) return;
          if (a.on) this.win.focus(); else this.win.blur();
          return;
      }
      if (!c) throw new Error("Opscode's runtime is not connected yet.");
      switch (a.type) {
        case "approve": {
          // Never answer blind: only an approval the notch is showing, still waiting.
          if (!this.model.approval(a.turn_id as string, a.call_id as string)) throw new Error("That request was already answered.");
          await c.call("turn.approve", { turn_id: a.turn_id, call_id: a.call_id, allow: a.allow, ...(a.choice ? { choice: a.choice } : {}), ...(a.remember ? { remember: a.remember } : {}) });
          return;
        }
        case "stop": await c.call("turn.interrupt", { turn_id: a.turn_id }); return;
        case "mac": {
          // "On my Mac": a plain command or a learned task is done now; anything else becomes a chat that does it (shown in the notch).
          const r = await c.call<{ done: boolean; ok?: boolean; say?: string; chat_id?: string }>("computer.task", { text: a.text }, 30_000);
          this.toast(r.done ? r.say ?? "Done." : "On it. Watch the steps here.");
          return;
        }
        case "send": {
          let chatId = a.chat_id as string | undefined;
          let wid = chatId ? this.model.chat(chatId)?.workspace_id : (a.workspace_id as string | undefined) ?? this.model.snapshot().workspace_id ?? undefined;
          if (!wid) throw new Error("Add a project in Opscode first.");
          if (!chatId) {
            const { chat } = await c.call<{ chat: ChatMeta }>("chat.create", { workspace_id: wid });
            chatId = chat.id;
            wid = chat.workspace_id;
          }
          await c.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: (a.text as string).trim() });
          return;
        }
        case "talk": {
          if (a.op === "start") {
            if (this.talkSession) return;
            const wp = this.settings.workerPick;
            this.talkEarly = [];
            let r: { session: string; chat_id: string | null; picks?: { brain?: ModelPick; worker?: ModelPick } };
            r = await c.call("voiceagent.start", wp && (wp.engine || wp.model || wp.effort) ? { worker: wp } : {}, 30_000);
            const early = (this.talkEarly ?? []).filter((v) => v.session === r.session);
            this.talkEarly = null;
            this.talkSession = r.session;
            this.toTalk({ kind: "on", session: r.session });
            if (r.picks) { this.picks = { brain: r.picks.brain, worker: r.picks.worker }; this.toTalk({ kind: "agent", ev: "picks", session: r.session, ...r.picks }); }
            // What it said while starting (a worker it picked up), in order, after "on".
            for (const v of early) if (v.ev !== "picks") this.toTalk({ kind: "agent", ...v });
          } else if (this.talkSession) {
            await c.call(a.op === "stop" ? "voiceagent.stop" : "voiceagent.interrupt", { session: this.talkSession });
            if (a.op === "stop") { this.talkSession = null; this.toTalk({ kind: "off", why: "stopped" }); }
          }
          return;
        }
        case "talk_audio": if (this.talkSession) void c.call("voiceagent.audio", { session: this.talkSession, pcm: a.pcm }).catch(() => {}); return;
        case "talk_playback": if (this.talkSession) void c.call("voiceagent.playback", { session: this.talkSession, playing: a.playing }).catch(() => {}); return;
        case "talk_progress": if (this.talkSession) void c.call("tts.progress", { session: a.tts, played: a.played }).catch(() => {}); return;
        case "talk_approve": if (this.talkSession) await c.call("voiceagent.approve", { session: this.talkSession, call_id: a.call_id, allow: a.allow }); return;
        case "talk_pick": if (this.talkSession) await this.modelMenu(c, a.which as "brain" | "worker", a.x as number | undefined, a.y as number | undefined); return;
        case "talk_say": if (this.talkSession) await c.call("voiceagent.say", { session: this.talkSession, text: a.text }); return;
        case "voice_audio": if (this.voiceSession) void c.call("voice.audio", { session: this.voiceSession, pcm: a.pcm }).catch(() => {}); return;
        case "voice": {
          if (a.op === "start") {
            if (this.voiceSession || this.voiceStarting) return;
            this.voiceStarting = true;
            this.voiceStopAfterStart = null;
            try {
              const status = await c.call<{ capture: string }>("voice.status", {});
              const { session } = await c.call<{ session: string }>("voice.start", {});
              this.voiceSession = session;
              if (status.capture === "window" && !this.voiceStopAfterStart) this.toVoice({ ev: "capture" });
            } finally { this.voiceStarting = false; }
            // The person already pressed stop while it was starting: stop now.
            const later = this.voiceStopAfterStart;
            this.voiceStopAfterStart = null;
            if (later) await c.call("voice.stop", { cancel: later === "cancel" });
          } else {
            if (this.voiceStarting) { this.voiceStopAfterStart = a.op === "cancel" ? "cancel" : "stop"; return; }
            if (!this.voiceSession) { this.toVoice({ ev: "cancelled" }); return; }
            await c.call("voice.stop", { cancel: a.op === "cancel" });
          }
          return;
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.o.log(`notch: ${String(a.type)} failed: ${msg}`);
      if (a.type === "voice") { this.voiceSession = null; this.toVoice({ ev: "error", message: msg }); }
      if (a.type === "talk" && a.op === "start") { this.talkEarly = null; this.toTalk({ kind: "off", why: "error", message: msg }); }
      this.toast(msg);
    }
  }

  private onVoice(v: Record<string, unknown>): void {
    if (!this.voiceSession || v.session !== this.voiceSession) return;
    const ev = String(v.ev ?? "");
    if (ev === "done" || ev === "cancelled" || ev === "error") this.voiceSession = null;
    this.toVoice({ ev, ...(typeof v.text === "string" ? { text: v.text } : {}), ...(typeof v.full === "string" ? { full: v.full } : {}), ...(typeof v.rms === "number" ? { rms: v.rms } : {}), ...(typeof v.message === "string" ? { message: v.message } : {}) });
  }

  private toVoice(e: Record<string, unknown>): void {
    if (this.win && !this.win.isDestroyed()) this.win.webContents.send(NOTCH.VOICE, e);
  }

  private toast(text: string): void {
    if (this.win && !this.win.isDestroyed()) this.win.webContents.send(NOTCH.TOAST, text.slice(0, 200));
  }

  // ---- window -------------------------------------------------------------------------------------------------------

  /** Sends the feed (coalesced: many stream deltas in a row become one send per frame-ish). */
  private push(now = false): void {
    if (now) { clearTimeout(this.sending); this.sending = undefined; this.send(); return; }
    if (this.sending) return;
    this.sending = setTimeout(() => { this.sending = undefined; this.send(); }, 50);
  }

  private send(): void {
    this.mobile?.publish();
    const win = this.win;
    if (!win || win.isDestroyed() || this.hardware === undefined) return;
    const d = screen.getPrimaryDisplay();
    const feed = this.model.snapshot();
    this.overlay?.setFeed(feed);
    win.webContents.send(NOTCH.STATE, {
      feed,
      hardware: this.hardware,
      bar: Math.max(0, d.workArea.y - d.bounds.y),
      sounds: this.settings.sounds,
      shortcut: process.platform === "darwin" ? "⌘⇧Space" : "Ctrl+Shift+Space",
      talkShortcut: process.platform === "darwin" ? "⌃⌥Space" : "Ctrl+Alt+Space",
      platform: process.platform,
    });
  }

  private over(on: boolean): void {
    const win = this.win;
    if (!win || win.isDestroyed()) return;
    win.setIgnoreMouseEvents(!on, { forward: true });
    clearInterval(this.watching);
    if (!on) return;
    this.watching = setInterval(() => {
      if (!this.win || this.win.isDestroyed()) return clearInterval(this.watching);
      const p = screen.getCursorScreenPoint();
      const b = this.win.getBounds();
      if (p.x >= b.x && p.x < b.x + b.width && p.y >= b.y && p.y < b.y + b.height) return;
      clearInterval(this.watching);
      this.win.setIgnoreMouseEvents(true, { forward: true });
      this.win.webContents.send(NOTCH.AWAY);
    }, WATCH_MS);
  }

  private menu(): void {
    if (!this.win) return;
    Menu.buildFromTemplate([
      { label: "Open Opscode", click: () => this.o.openMain({}) },
      { label: "New Chat", accelerator: SHORTCUT, click: () => this.summon() },
      { label: this.talkSession ? "Stop Talking" : "Talk to Opscode", accelerator: TALK_SHORTCUT, click: () => this.talkSummon() },
      ...(this.mobile ? [{ label: "Pair Android…", click: () => this.pairAndroid() }] : []),
      { type: "separator" },
      { label: "Sounds", type: "checkbox", checked: this.settings.sounds, click: (i) => { this.settings.sounds = i.checked; this.save(); this.push(); } },
      { label: "Hide the Notch for an Hour", click: () => { this.settings.hiddenUntil = Date.now() + 3600_000; this.save(); void this.settle(); setTimeout(() => void this.settle(), 3600_000 + 1000).unref(); } },
      { type: "separator" },
      { label: "Quit Opscode", click: () => app.quit() },
    ]).popup({ window: this.win });
  }

  private save(): void {
    try { writeFileSync(this.settingsPath, JSON.stringify(this.settings), { mode: 0o600 }); } catch { /* read-only profile */ }
  }

  /** Measures the screen's notch, then puts the window against the menu-bar screen's top edge (or away while hidden). */
  private async settle(): Promise<void> {
    const measured = await measureNotch();
    const d = screen.getPrimaryDisplay();
    this.hardware = measured === undefined ? (d.internal && d.workArea.y - d.bounds.y >= 30 ? { width: 185, height: d.workArea.y - d.bounds.y } : null) : measured;
    const win = this.win;
    if (!win || win.isDestroyed()) return;
    if (this.settings.hiddenUntil > Date.now()) { win.hide(); return; }
    win.setBounds({ x: d.bounds.x + Math.round((d.bounds.width - NOTCH_WIDTH) / 2), y: d.bounds.y, width: NOTCH_WIDTH, height: NOTCH_HEIGHT });
    this.push(true);
    if (!win.isVisible()) win.showInactive();
    this.o.log(`notch: placed (${this.hardware ? `notch ${this.hardware.width}x${this.hardware.height}` : "no notch on this screen"})`);
  }

  private create(): BrowserWindow {
    const win = new BrowserWindow({
      width: NOTCH_WIDTH,
      height: NOTCH_HEIGHT,
      show: false,
      frame: false,
      transparent: true,
      hasShadow: false,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      skipTaskbar: true,
      alwaysOnTop: true,
      enableLargerThanScreen: true,
      // macOS: a non-activating panel. It floats over every app (fullscreen ones too) and can take typing without
      // bringing the main window forward.
      ...(process.platform === "darwin" ? { type: "panel" } : {}),
      title: "Opscode Notch",
      webPreferences: {
        preload: this.o.preload,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
        backgroundThrottling: false,
        spellcheck: false,
        // ⌘+ in the main window must not zoom a shape drawn to the point against the camera notch.
        zoomFactor: 1,
      },
    });
    win.setAlwaysOnTop(true, "main-menu", 3);
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true, skipTransformProcessType: true });
    win.setIgnoreMouseEvents(true, { forward: true });
    win.webContents.setVisualZoomLevelLimits(1, 1).catch(() => {});
    win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
    win.webContents.on("will-navigate", (e) => e.preventDefault());
    let crashes = 0;
    win.webContents.on("render-process-gone", (_e, d) => {
      if (d.reason === "clean-exit" || win.isDestroyed()) return;
      this.o.log(`notch: page gone (${d.reason})`);
      if (++crashes <= 3) setTimeout(() => { if (!win.isDestroyed()) win.webContents.reload(); }, 500);
    });
    win.on("closed", () => { if (this.win === win) this.win = null; clearInterval(this.watching); });
    void win.loadURL(this.o.url);
    return win;
  }
}
