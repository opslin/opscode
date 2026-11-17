// Main-process side of the agent's browser. Main keeps one session to the
// runtime and registers as the device host; the runtime sends browser ops
// (devices.request) and main answers (devices.reply).
//
// The page is the project's Browser tab in the side panel (a <webview>); the
// renderer opens it and tells main its WebContents id. With no window, main
// uses a hidden window of its own. Main drives the page with the Chrome
// DevTools Protocol (webContents.debugger): real mouse/keyboard input, an
// isolated world for reading, console + network logs, JS dialogs.

import { BrowserWindow, webContents as allWebContents, type WebContents } from "electron";
import { GUEST_PARTITION } from "../shared/ipc";
import { PAGE_SCRIPT } from "./pageScript";
import { MainRpcClient } from "./rpcClient";
import type { Endpoint } from "./runtime";

type Args = Record<string, unknown>;
interface Result { text: string; image?: { media_type: string; data: string } }

export interface RendererBridge {
  /** Asks the renderer (the window's own frame); rejects if there is no window or no answer. */
  ask<T>(op: string, args: Args, timeoutMs?: number): Promise<T>;
  available(): boolean;
}

interface ConsoleEntry { level: string; text: string; where: string }
interface NetEntry { id: string; seq: number; method: string; url: string; type: string; status?: number; failed?: string }
interface Seen { url: string; byRef: Record<string, string>; text: string[] }
interface PageState {
  wc: WebContents;
  world?: number;
  console: ConsoleEntry[];
  net: Map<string, NetEntry>;
  dialog?: { type: string; message: string; defaultPrompt?: string };
  /** Counts every console entry / request ever recorded (the lists are capped), to find what is new. */
  consoleSeq: number;
  netSeq: number;
  /** Called when a JS dialog opens (input events and page reads stall until it is answered). */
  onDialog: Set<() => void>;
  /** The page as it was before the action that opened the dialog (to report what answering it changed). */
  beforeDialog?: Seen;
  scale: number; // screenshot pixels per CSS pixel
}

const LOG_MAX = 300;
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);

/** Keys the model can name, for Input.dispatchKeyEvent. */
const NAMED: Record<string, { key: string; code: string; keyCode: number; text?: string }> = {
  enter: { key: "Enter", code: "Enter", keyCode: 13, text: "\r" }, return: { key: "Enter", code: "Enter", keyCode: 13, text: "\r" },
  tab: { key: "Tab", code: "Tab", keyCode: 9 }, escape: { key: "Escape", code: "Escape", keyCode: 27 }, esc: { key: "Escape", code: "Escape", keyCode: 27 },
  backspace: { key: "Backspace", code: "Backspace", keyCode: 8 }, delete: { key: "Delete", code: "Delete", keyCode: 46 },
  arrowup: { key: "ArrowUp", code: "ArrowUp", keyCode: 38 }, arrowdown: { key: "ArrowDown", code: "ArrowDown", keyCode: 40 },
  arrowleft: { key: "ArrowLeft", code: "ArrowLeft", keyCode: 37 }, arrowright: { key: "ArrowRight", code: "ArrowRight", keyCode: 39 },
  up: { key: "ArrowUp", code: "ArrowUp", keyCode: 38 }, down: { key: "ArrowDown", code: "ArrowDown", keyCode: 40 },
  left: { key: "ArrowLeft", code: "ArrowLeft", keyCode: 37 }, right: { key: "ArrowRight", code: "ArrowRight", keyCode: 39 },
  home: { key: "Home", code: "Home", keyCode: 36 }, end: { key: "End", code: "End", keyCode: 35 },
  pageup: { key: "PageUp", code: "PageUp", keyCode: 33 }, pagedown: { key: "PageDown", code: "PageDown", keyCode: 34 },
  space: { key: " ", code: "Space", keyCode: 32, text: " " },
};
const MOD: Record<string, number> = { alt: 1, option: 1, ctrl: 2, control: 2, cmd: 4, meta: 4, command: 4, super: 4, shift: 8 };
/** Editing shortcuts need an explicit command on macOS (no native menu reaches the page). */
const COMMANDS: Record<string, string> = { a: "selectAll", c: "copy", v: "paste", x: "cut", z: "undo", y: "redo" };

export class BrowserHost {
  private client: MainRpcClient | undefined;
  private stopped = false;
  private readonly pages = new Map<number, PageState>(); // by WebContents id
  private readonly current = new Map<string, string>(); // workspace -> tab id the agent last used
  private readonly hidden = new Map<string, BrowserWindow>(); // "bg:<n>" -> hidden window (no app window)
  private hiddenSeq = 0;

  constructor(
    private readonly endpoint: () => Endpoint | null,
    private readonly renderer: RendererBridge,
    private readonly log: (line: string) => void,
  ) {}

  /** Keeps a session to the runtime (reconnecting after a runtime restart). */
  start(): void {
    const loop = async (): Promise<void> => {
      while (!this.stopped) {
        const ep = this.endpoint();
        if (ep) {
          const c = new MainRpcClient(ep);
          try {
            await c.open();
            c.on<{ rid: string; device: string; op: string; args: Args }>("devices.request", (p) => void this.serve(c, p));
            await c.call("devices.host.register", {});
            this.client = c;
            await c.closed();
          } catch { /* runtime not up yet */ }
          this.client = undefined;
        }
        if (!this.stopped) await pause(800);
      }
    };
    void loop();
  }

  stop(): void {
    this.stopped = true;
    this.client?.close();
    for (const w of this.hidden.values()) if (!w.isDestroyed()) w.destroy();
  }

  private async serve(c: MainRpcClient, p: { rid: string; device: string; op: string; args: Args }): Promise<void> {
    let result: Result | undefined;
    let error: string | undefined;
    try {
      if (p.device !== "browser") throw new Error(`unknown device ${p.device}`);
      result = await this.run(p.op, p.args ?? {});
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
    await c.call("devices.reply", { rid: p.rid, ...(error !== undefined ? { error } : { result }) }, 20_000).catch((e) => this.log(`browser: reply failed: ${e instanceof Error ? e.message : String(e)}`));
  }

  // ---- pages -------------------------------------------------------------------------------

  /** The page the agent works in for a project (opens a Browser tab when there is none). */
  private async page(workspaceId: string, opts: { tab_id?: string; new?: boolean; url?: string } = {}): Promise<{ tab: string; st: PageState }> {
    const want = opts.tab_id ?? (opts.new ? undefined : this.current.get(workspaceId));
    let tab: string | undefined;
    let wc: WebContents | undefined;
    if (this.renderer.available() && !(want?.startsWith("bg:"))) {
      try {
        const r = await this.renderer.ask<{ tab_id: string; wc_id: number }>("ensure", { workspace_id: workspaceId, ...(want ? { tab_id: want } : {}), ...(opts.new ? { new: true } : {}), ...(opts.url ? { url: opts.url } : {}) }, 10_000);
        tab = r.tab_id;
        wc = allWebContents.fromId(r.wc_id) ?? undefined;
      } catch (e) {
        this.log(`browser: renderer could not open a tab (${e instanceof Error ? e.message : String(e)}); using a hidden window`);
      }
    }
    if (!wc) {
      // No window (or it did not answer): a hidden window of our own, same isolated partition.
      let key = want?.startsWith("bg:") && this.hidden.has(want) && !opts.new ? want : [...this.hidden.keys()].find((k) => k.startsWith(`bg:${workspaceId}:`));
      if (!key || opts.new) {
        key = `bg:${workspaceId}:${++this.hiddenSeq}`;
        const w = new BrowserWindow({ show: false, width: 1280, height: 800, webPreferences: { partition: GUEST_PARTITION, sandbox: true, contextIsolation: true, nodeIntegration: false, backgroundThrottling: false } });
        w.webContents.setWindowOpenHandler(({ url }) => { if (/^https?:\/\//i.test(url)) void w.webContents.loadURL(url); return { action: "deny" }; });
        w.webContents.on("will-navigate", (ev, url) => { if (!/^https?:|^about:blank/i.test(url)) ev.preventDefault(); });
        const k = key;
        w.on("closed", () => this.hidden.delete(k));
        this.hidden.set(key, w);
      }
      tab = key;
      wc = this.hidden.get(key)!.webContents;
    }
    this.current.set(workspaceId, tab!);
    return { tab: tab!, st: this.attach(wc) };
  }

  private attach(wc: WebContents): PageState {
    const have = this.pages.get(wc.id);
    if (have && wc.debugger.isAttached()) return have;
    try {
      if (!wc.debugger.isAttached()) wc.debugger.attach("1.3");
    } catch (e) {
      throw new Error(`Could not take control of the page (${e instanceof Error ? e.message : String(e)}). If DevTools is open on that tab, close it and try again.`);
    }
    const st: PageState = { wc, console: [], net: new Map(), scale: 1, consoleSeq: 0, netSeq: 0, onDialog: new Set() };
    this.pages.set(wc.id, st);
    const d = wc.debugger;
    d.on("message", (_e, method, params: Record<string, any>) => {
      switch (method) {
        case "Runtime.consoleAPICalled": {
          // Electron's own dev-time warning in every page is noise for the agent.
          if (typeof params.args?.[0]?.value === "string" && params.args[0].value.includes("Electron Security Warning")) break;
          const text = (params.args ?? []).map((a: Record<string, any>) => (a.value !== undefined ? (typeof a.value === "string" ? a.value : JSON.stringify(a.value)) : a.description ?? a.type)).join(" ");
          const f = params.stackTrace?.callFrames?.[0];
          this.push(st.console, { level: params.type === "warning" ? "warn" : String(params.type), text: clip(text, 2000), where: f ? `${f.url}:${f.lineNumber + 1}` : "" });
          break;
        }
        case "Runtime.exceptionThrown": {
          const x = params.exceptionDetails ?? {};
          this.push(st.console, { level: "error", text: clip(String(x.exception?.description ?? x.text ?? "exception"), 2000), where: x.url ? `${x.url}:${(x.lineNumber ?? 0) + 1}` : "" });
          break;
        }
        case "Log.entryAdded":
          this.push(st.console, { level: String(params.entry?.level ?? "info"), text: clip(String(params.entry?.text ?? ""), 2000), where: params.entry?.url ?? "" });
          break;
        case "Network.requestWillBeSent":
          st.net.set(params.requestId, { id: params.requestId, seq: ++st.netSeq, method: params.request?.method ?? "GET", url: clip(String(params.request?.url ?? ""), 500), type: String(params.type ?? "") });
          if (st.net.size > LOG_MAX) st.net.delete(st.net.keys().next().value as string);
          break;
        case "Network.responseReceived": {
          const n = st.net.get(params.requestId);
          if (n) n.status = params.response?.status;
          break;
        }
        case "Network.loadingFailed": {
          const n = st.net.get(params.requestId);
          if (n) n.failed = params.canceled ? "canceled" : String(params.errorText ?? "failed");
          break;
        }
        case "Page.javascriptDialogOpening":
          st.dialog = { type: params.type, message: clip(String(params.message ?? ""), 500), ...(params.defaultPrompt ? { defaultPrompt: params.defaultPrompt } : {}) };
          for (const f of st.onDialog) f();
          break;
        case "Page.javascriptDialogClosed":
          st.dialog = undefined;
          break;
        case "Runtime.executionContextsCleared":
          st.world = undefined;
          break;
      }
    });
    d.on("detach", () => this.pages.delete(wc.id));
    wc.once("destroyed", () => this.pages.delete(wc.id));
    void Promise.all(["Runtime.enable", "Log.enable", "Network.enable", "Page.enable"].map((m) => d.sendCommand(m).catch(() => {})));
    // The page behaves as if focused even when the user is typing elsewhere (typing and focus events still land).
    void d.sendCommand("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
    return st;
  }

  private push(list: ConsoleEntry[], e: ConsoleEntry): void {
    const st = [...this.pages.values()].find((p) => p.console === list);
    if (st) st.consoleSeq++;
    list.push(e);
    if (list.length > LOG_MAX) list.splice(0, list.length - LOG_MAX);
  }

  private cdp<T = any>(st: PageState, method: string, params: Args = {}): Promise<T> {
    return st.wc.debugger.sendCommand(method, params) as Promise<T>;
  }

  /** An input event. If it opens a JS dialog (alert/confirm/prompt), the page stops until the dialog is
   *  answered, and so does this command: return as soon as the dialog shows up instead of hanging. */
  private input(st: PageState, method: string, params: Args): Promise<void> {
    if (st.dialog) return Promise.resolve();
    return new Promise<void>((resolve, reject) => {
      const done = (): void => { st.onDialog.delete(done); clearTimeout(timer); resolve(); };
      const timer = setTimeout(() => { st.onDialog.delete(done); reject(new Error("The page did not take the input within 15s (is it frozen?).")); }, 15_000);
      st.onDialog.add(done);
      this.cdp(st, method, params).then(done, (e: unknown) => { st.onDialog.delete(done); clearTimeout(timer); reject(e instanceof Error ? e : new Error(String(e))); });
    });
  }

  /** Runs one of the page script's functions in our isolated world. */
  private async ops<T>(st: PageState, call: string): Promise<T> {
    if (st.dialog) throw new Error(`A ${st.dialog.type} dialog is open (${JSON.stringify(st.dialog.message)}), and the page is paused until it is answered: use browser_act action "dialog" (accept true/false${st.dialog.type === "prompt" ? ", text" : ""}).`);
    for (let attempt = 0; attempt < 2; attempt++) {
      if (st.world === undefined) {
        const tree = await this.cdp<{ frameTree: { frame: { id: string } } }>(st, "Page.getFrameTree");
        const w = await this.cdp<{ executionContextId: number }>(st, "Page.createIsolatedWorld", { frameId: tree.frameTree.frame.id, worldName: "opscode-agent" });
        st.world = w.executionContextId;
      }
      try {
        const r = await this.cdp<{ result: { value?: T }; exceptionDetails?: { exception?: { description?: string }; text?: string } }>(st, "Runtime.evaluate", { expression: `${PAGE_SCRIPT};\n${call}`, contextId: st.world, returnByValue: true, awaitPromise: true });
        if (r.exceptionDetails) {
          const msg = String(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text ?? "script error").split("\n")[0].replace(/^Error: /, "");
          throw new Error(msg);
        }
        return r.result.value as T;
      } catch (e) {
        const m = e instanceof Error ? e.message : String(e);
        if (attempt === 0 && /context|Cannot find|destroyed/i.test(m)) { st.world = undefined; continue; }
        throw e;
      }
    }
    throw new Error("the page kept changing; try again");
  }

  private async settle(st: PageState, ms = 350): Promise<void> {
    await pause(ms);
    for (let end = Date.now() + 8000; st.wc.isLoading() && Date.now() < end; ) await pause(100);
  }

  /** Console errors/warnings and failed or 4xx/5xx requests recorded since the marks. */
  private problemsSince(st: PageState, consoleMark: number, netMark: number): string {
    const newConsole = st.console.slice(Math.max(0, st.console.length - (st.consoleSeq - consoleMark))).filter((c) => c.level === "error" || c.level === "warn");
    const badNet = [...st.net.values()].filter((n) => n.seq > netMark && (n.failed && n.failed !== "canceled" || (n.status ?? 0) >= 400));
    const lines = [
      ...newConsole.slice(-5).map((c) => `console ${c.level}: ${clip(c.text.split("\n")[0], 200)}${c.where ? ` (${clip(c.where, 80)})` : ""}`),
      ...badNet.slice(-5).map((n) => `request ${n.method} ${clip(n.url, 120)} -> ${n.failed ?? n.status}`),
    ];
    return lines.length ? `\nProblems seen: \n${lines.map((l) => `- ${l}`).join("\n")}` : "";
  }

  private async seen(st: PageState): Promise<Seen | undefined> {
    try { return await this.ops<Seen>(st, "__ops.state()"); } catch { return undefined; }
  }

  /** What an action changed on the page, in a few lines (so the agent rarely needs to read it again). */
  private changes(before: Seen | undefined, after: Seen | undefined, skipRef?: string): string {
    if (!before || !after || before.url !== after.url) return "";
    const appeared: string[] = [];
    const changed: string[] = [];
    for (const [ref, line] of Object.entries(after.byRef)) {
      if (!(ref in before.byRef)) appeared.push(line);
      else if (before.byRef[ref] !== line && ref !== skipRef) changed.push(line);
    }
    const gone = Object.keys(before.byRef).filter((r) => !(r in after.byRef)).map((r) => before.byRef[r]);
    const had = new Set(before.text);
    const newText = after.text.filter((t) => !had.has(t) && !appeared.some((a) => a.includes(clip(t, 60)))).slice(0, 8);
    const out: string[] = [];
    if (appeared.length) out.push(`Appeared:\n${appeared.slice(0, 15).map((l) => `  ${l}`).join("\n")}${appeared.length > 15 ? `\n  … ${appeared.length - 15} more (browser_read to see all)` : ""}`);
    if (changed.length) out.push(`Changed:\n${changed.slice(0, 8).map((l) => `  ${l}`).join("\n")}`);
    if (gone.length) out.push(`Gone: ${gone.slice(0, 6).map((l) => l.replace(/^- /, "").replace(/ \(.*\)$/, "")).join("; ")}${gone.length > 6 ? ` and ${gone.length - 6} more` : ""}`);
    if (newText.length) out.push(`New text: ${newText.map((t) => JSON.stringify(clip(t, 120))).join(", ")}`);
    return out.length ? `\n${out.join("\n")}` : "\nNothing visible changed.";
  }

  private dialogNote(st: PageState): string {
    return st.dialog ? `\nA ${st.dialog.type} dialog is open: ${JSON.stringify(st.dialog.message)}. Answer it with browser_act action "dialog" (accept true/false${st.dialog.type === "prompt" ? ", text" : ""}).` : "";
  }

  private async activity(workspaceId: string, tab: string, label: string): Promise<void> {
    if (this.renderer.available() && !tab.startsWith("bg:")) await this.renderer.ask("activity", { workspace_id: workspaceId, tab_id: tab, label }, 2000).catch(() => {});
  }

  // ---- ops ---------------------------------------------------------------------------------

  async run(op: string, a: Args): Promise<Result> {
    const ws = String(a.workspace_id ?? "");
    if (!ws) throw new Error("no project");
    switch (op) {
      case "navigate": return this.navigate(ws, String(a.url ?? ""), a.new_tab === true);
      case "read": {
        const { st } = await this.page(ws);
        const budget = Math.min(Number(a.max_chars) || 12_000, 24_000);
        if (a.mode === "text") return { text: (await this.ops<string>(st, `__ops.text(${budget})`)) + this.dialogNote(st) };
        return { text: (await this.ops<string>(st, `__ops.tree(${JSON.stringify(a.mode === "all" ? "all" : "interactive")}, ${JSON.stringify(typeof a.ref_id === "string" ? a.ref_id : "")}, ${budget})`)) + this.dialogNote(st) };
      }
      case "find": {
        const { st } = await this.page(ws);
        return { text: await this.ops<string>(st, `__ops.find(${JSON.stringify(String(a.query ?? ""))})`) };
      }
      case "act": return this.act(ws, a);
      case "screenshot": return this.screenshot(ws, typeof a.ref === "string" ? a.ref : undefined);
      case "logs": return this.logs(ws, a);
      case "eval": return this.evaluate(ws, String(a.code ?? ""));
      case "tabs": return this.tabs(ws, a);
      default: throw new Error(`unknown browser op ${op}`);
    }
  }

  private async navigate(ws: string, url: string, newTab: boolean): Promise<Result> {
    const isNav = ["back", "forward", "reload"].includes(url);
    const { tab, st } = await this.page(ws, newTab ? { new: true } : {});
    const wc = st.wc;
    const marks = [st.consoleSeq, st.netSeq] as const;
    void this.activity(ws, tab, isNav ? url : "opening a page");
    let failed: string | undefined;
    const onFail = (_e: unknown, code: number, desc: string, _u: string, main: boolean): void => { if (main && code !== -3) failed = `${desc || "load failed"} (${code})`; };
    wc.on("did-fail-load", onFail);
    try {
      if (url === "back") { if (!wc.navigationHistory.canGoBack()) return { text: "There is no page to go back to." }; wc.navigationHistory.goBack(); }
      else if (url === "forward") { if (!wc.navigationHistory.canGoForward()) return { text: "There is no page to go forward to." }; wc.navigationHistory.goForward(); }
      else if (url === "reload") wc.reload();
      else await wc.loadURL(url).catch(() => {}); // aborted/failed loads are reported below
      await this.settle(st, 150);
    } finally {
      wc.off("did-fail-load", onFail);
    }
    st.world = undefined;
    if (failed) return { text: `Could not load ${url}: ${failed}. Is the server running?` };
    // The interactive outline comes with the page, so opening it is one call, not two.
    const outline = await this.ops<string>(st, `__ops.tree("interactive", "", 6000)`).catch(() => "");
    return { text: `Loaded ${JSON.stringify(wc.getTitle())} (tab ${tab}).\n${outline.replace(/^Page: .*\n/, "")}${this.problemsSince(st, marks[0], marks[1])}${this.dialogNote(st)}` };
  }

  private async mouse(st: PageState, x: number, y: number, kind: "click" | "double_click" | "right_click" | "hover"): Promise<void> {
    await this.input(st, "Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "none" });
    if (kind === "hover") return;
    const button = kind === "right_click" ? "right" : "left";
    const clicks = kind === "double_click" ? 2 : 1;
    for (let n = 1; n <= clicks && !st.dialog; n++) {
      await this.input(st, "Input.dispatchMouseEvent", { type: "mousePressed", x, y, button, buttons: button === "left" ? 1 : 2, clickCount: n });
      await this.input(st, "Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button, buttons: 0, clickCount: n });
    }
  }

  private async keys(st: PageState, combo: string): Promise<void> {
    for (const chord of combo.trim().split(/\s+/).filter(Boolean)) {
      const parts = chord.split("+").filter(Boolean);
      const last = parts.pop() ?? "";
      let modifiers = 0;
      for (const m of parts) {
        const bit = MOD[m.toLowerCase()];
        if (bit === undefined) throw new Error(`Unknown modifier "${m}" in "${chord}". Use cmd, ctrl, alt, shift.`);
        modifiers |= bit;
      }
      const named = NAMED[last.toLowerCase()];
      let ev: { key: string; code: string; keyCode: number; text?: string };
      if (named) ev = named;
      else if (/^f([1-9]|1[0-2])$/i.test(last)) { const n = Number(last.slice(1)); ev = { key: `F${n}`, code: `F${n}`, keyCode: 111 + n }; }
      else if ([...last].length === 1) {
        const ch = (modifiers & 8) && /[a-z]/.test(last) ? last.toUpperCase() : last;
        const up = last.toUpperCase();
        ev = { key: ch, code: /[a-z]/i.test(last) ? `Key${up}` : /\d/.test(last) ? `Digit${last}` : "", keyCode: up.charCodeAt(0), text: ch };
      } else throw new Error(`Unknown key "${last}".`);
      const shortcut = (modifiers & (2 | 4)) !== 0;
      const command = shortcut && (modifiers & (process.platform === "darwin" ? 4 : 2)) ? COMMANDS[last.toLowerCase()] : undefined;
      const text = shortcut ? undefined : ev.text;
      if (st.dialog) return;
      await this.input(st, "Input.dispatchKeyEvent", { type: text ? "keyDown" : "rawKeyDown", key: ev.key, code: ev.code, windowsVirtualKeyCode: ev.keyCode, modifiers, ...(text ? { text, unmodifiedText: text } : {}), ...(command ? { commands: [command === "redo" && (modifiers & 8) ? "redo" : command] } : {}) });
      await this.input(st, "Input.dispatchKeyEvent", { type: "keyUp", key: ev.key, code: ev.code, windowsVirtualKeyCode: ev.keyCode, modifiers });
    }
  }

  /** Where to act: a ref's centre (scrolled into view), or a point in the last screenshot. */
  private async target(st: PageState, a: Args): Promise<{ x: number; y: number; label: string; covered: string } | undefined> {
    if (typeof a.ref === "string") return this.ops(st, `__ops.point(${JSON.stringify(a.ref)})`);
    if (typeof a.x === "number" && typeof a.y === "number") return { x: a.x / st.scale, y: a.y / st.scale, label: `the point ${a.x},${a.y}`, covered: "" };
    return undefined;
  }

  private async act(ws: string, a: Args): Promise<Result> {
    const { tab, st } = await this.page(ws);
    const action = String(a.action);
    const before = st.wc.getURL();
    const marks = [st.consoleSeq, st.netSeq] as const;
    const watch = !["wait", "dialog", "scroll", "scroll_to", "hover"].includes(action);
    const seenBefore = watch ? await this.seen(st) : undefined;
    void this.activity(ws, tab, action.replace("_", " "));
    let done = "";
    switch (action) {
      case "click": case "double_click": case "right_click": case "hover": {
        const t = await this.target(st, a);
        if (!t) throw new Error(`${action} needs ref, or x and y.`);
        await this.mouse(st, t.x, t.y, action);
        done = `${action === "hover" ? "Hovered" : action === "click" ? "Clicked" : action === "double_click" ? "Double-clicked" : "Right-clicked"} ${t.label}${t.covered ? ` (something else was on top of it there: ${t.covered})` : ""}.`;
        break;
      }
      case "type": {
        const text = String(a.text ?? "");
        if (typeof a.ref === "string") { const t = await this.target(st, a); if (t) await this.mouse(st, t.x, t.y, "click"); }
        if (text) await this.input(st, "Input.insertText", { text });
        if (a.submit === true) await this.keys(st, "Enter");
        done = `Typed ${JSON.stringify(clip(text, 60))}${a.submit === true ? " and pressed Enter" : ""}.`;
        break;
      }
      case "fill": {
        if (typeof a.ref !== "string") throw new Error("fill needs ref.");
        const r = await this.ops<{ done: boolean; text?: string; error?: string; label?: string }>(st, `__ops.fill(${JSON.stringify(a.ref)}, ${JSON.stringify(a.value ?? "")})`);
        if (r.error) throw new Error(r.error);
        if (r.done) { done = `${r.text}.`; break; }
        // A real click gives the field focus the way a person would, then select its text and type over it.
        const t = await this.target(st, { ref: a.ref });
        if (t) await this.mouse(st, t.x, t.y, "click");
        await this.ops(st, `__ops.fill(${JSON.stringify(a.ref)}, ${JSON.stringify(a.value ?? "")})`);
        const value = String(a.value ?? "");
        if (value) await this.input(st, "Input.insertText", { text: value });
        else await this.keys(st, "Delete");
        done = `Set ${r.label} to ${JSON.stringify(clip(value, 60))}.`;
        break;
      }
      case "key": {
        const k = String(a.keys ?? a.text ?? "");
        if (!k) throw new Error("key needs keys, e.g. \"Enter\" or \"cmd+a\".");
        await this.keys(st, k);
        done = `Pressed ${k}.`;
        break;
      }
      case "scroll": {
        const t = (await this.target(st, a)) ?? { x: 0, y: 0, label: "", covered: "" };
        const x = t.label ? t.x : (await this.ops<number>(st, "innerWidth")) / 2;
        const y = t.label ? t.y : (await this.ops<number>(st, "innerHeight")) / 2;
        const n = Math.min(Math.max(Number(a.amount) || 3, 1), 30) * 120;
        const dir = String(a.direction ?? "down");
        await this.input(st, "Input.dispatchMouseEvent", { type: "mouseWheel", x, y, deltaX: dir === "left" ? -n : dir === "right" ? n : 0, deltaY: dir === "up" ? -n : dir === "down" ? n : 0 });
        done = `Scrolled ${dir}.`;
        break;
      }
      case "scroll_to": {
        if (typeof a.ref !== "string") throw new Error("scroll_to needs ref.");
        done = `Scrolled to ${await this.ops<string>(st, `__ops.scrollTo(${JSON.stringify(a.ref)})`)}.`;
        break;
      }
      case "dialog": {
        if (!st.dialog) return { text: "No dialog is open." };
        const was = st.dialog;
        await this.cdp(st, "Page.handleJavaScriptDialog", { accept: a.accept !== false, ...(typeof a.text === "string" ? { promptText: a.text } : {}) });
        st.dialog = undefined;
        done = `${a.accept !== false ? "Accepted" : "Dismissed"} the ${was.type} ${JSON.stringify(was.message)}.`;
        await this.settle(st, 500);
        const prior = st.beforeDialog;
        st.beforeDialog = undefined;
        return { text: done + (prior ? this.changes(prior, await this.seen(st)) : "") + this.problemsSince(st, marks[0], marks[1]) + this.dialogNote(st) };
      }
      case "wait": {
        if (typeof a.text === "string" && a.text) {
          const end = Date.now() + Math.min(Math.max(Number(a.seconds) || 10, 1), 30) * 1000;
          while (Date.now() < end) {
            if (await this.ops<boolean>(st, `__ops.hasText(${JSON.stringify(a.text)})`).catch(() => false)) return { text: `${JSON.stringify(a.text)} is on the page.` };
            await pause(250);
          }
          return { text: `${JSON.stringify(a.text)} did not appear.` };
        }
        await pause(Math.min(Math.max(Number(a.seconds) || 1, 0), 10) * 1000);
        return { text: "Waited." };
      }
      default: throw new Error(`unknown action ${action}`);
    }
    await this.settle(st);
    const after = st.wc.getURL();
    if (after !== before) st.world = undefined;
    let changes = "";
    if (after !== before) {
      const outline = await this.ops<string>(st, `__ops.tree("interactive", "", 6000)`).catch(() => "");
      changes = ` The page is now ${JSON.stringify(st.wc.getTitle())}.\n${outline.replace(/^Page: .*\n/, "")}`;
    } else if (st.dialog) st.beforeDialog = seenBefore;
    else if (watch) changes = this.changes(seenBefore, await this.seen(st), action === "fill" || action === "type" ? String(a.ref ?? "") : undefined);
    return { text: done + changes + this.problemsSince(st, marks[0], marks[1]) + this.dialogNote(st) };
  }

  private async screenshot(ws: string, ref: string | undefined): Promise<Result> {
    const { st } = await this.page(ws);
    const css = await this.ops<{ w: number; h: number }>(st, "({ w: innerWidth, h: innerHeight })");
    let rect: Electron.Rectangle | undefined;
    if (ref) {
      const r = await this.ops<{ x: number; y: number; w: number; h: number }>(st, `__ops.rect(${JSON.stringify(ref)})`);
      if (r.w < 1 || r.h < 1) throw new Error(`${ref} has no size on screen.`);
      rect = { x: Math.round(r.x), y: Math.round(r.y), width: Math.max(1, Math.round(r.w)), height: Math.max(1, Math.round(r.h)) };
      await pause(120);
    }
    const img = await Promise.race([
      st.wc.capturePage(rect, { stayHidden: true, stayAwake: true }),
      pause(4000).then(() => null),
    ]);
    if (!img || img.isEmpty()) {
      return { text: "No picture: the Browser tab is not on screen (the user is looking at another project, or the side panel is closed). Read the page with browser_read instead, or ask the user to show the Browser tab." };
    }
    // Downscale to CSS pixels, at most 1280 wide, so the picture is cheap and its pixels are click points.
    const size = img.getSize();
    const cssW = rect ? rect.width : css.w;
    const target = Math.min(cssW, 1280);
    const out = size.width > target ? img.resize({ width: target, quality: "good" }) : img;
    if (!ref) st.scale = out.getSize().width / css.w;
    const jpeg = out.toJPEG(75);
    return {
      text: `Screenshot ${out.getSize().width}x${out.getSize().height}${ref ? ` of ${ref}` : ""} — ${st.wc.getURL()}${ref ? "" : `. browser_act x,y use this picture's pixels.`}${this.dialogNote(st)}`,
      image: { media_type: "image/jpeg", data: jpeg.toString("base64") },
    };
  }

  private async logs(ws: string, a: Args): Promise<Result> {
    const { st } = await this.page(ws);
    const pat = String(a.pattern ?? "").toLowerCase();
    const limit = Math.min(Math.max(Number(a.limit) || 50, 1), 200);
    if (a.kind !== "network" && a.kind !== "console") {
      const c = await this.logs(ws, { ...a, kind: "console" });
      const n = await this.logs(ws, { ...a, kind: "network" });
      return { text: `Console:\n${c.text}\n\nNetwork:\n${n.text}` };
    }
    if (a.kind === "network") {
      const rows = [...st.net.values()].filter((n) => (!a.only_errors || n.failed || (n.status ?? 0) >= 400) && (!pat || n.url.toLowerCase().includes(pat))).slice(-limit);
      return { text: rows.length ? rows.map((n) => `${n.method} ${n.status ?? (n.failed ? "✗" : "…")} ${n.url}${n.type ? ` [${n.type}]` : ""}${n.failed ? ` (${n.failed})` : ""}`).join("\n") : "No matching requests (requests are recorded from when the agent first used this tab)." };
    }
    const rows = st.console.filter((c) => (!a.only_errors || c.level === "error") && (!pat || c.text.toLowerCase().includes(pat))).slice(-limit);
    return { text: rows.length ? rows.map((c) => `[${c.level}] ${c.text}${c.where ? `  (${c.where})` : ""}`).join("\n") : "No matching console messages (they are recorded from when the agent first used this tab)." };
  }

  private async evaluate(ws: string, code: string): Promise<Result> {
    const { st } = await this.page(ws);
    const run = async (expression: string) => this.cdp<{ result: { value?: unknown; type: string; description?: string }; exceptionDetails?: { exception?: { description?: string }; text?: string } }>(st, "Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true, userGesture: true, timeout: 10_000 });
    let r = await run(`(async () => { return (${code}\n); })()`);
    if (r.exceptionDetails && /SyntaxError/.test(String(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text))) r = await run(`(async () => { ${code}\n })()`);
    if (r.exceptionDetails) throw new Error(clip(String(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text ?? "error"), 2000));
    const v = r.result.value;
    const text = v === undefined ? (r.result.type === "undefined" ? "undefined" : String(r.result.description ?? r.result.type)) : typeof v === "string" ? v : JSON.stringify(v, null, 2);
    return { text: clip(text ?? "undefined", 16_000) };
  }

  private async tabs(ws: string, a: Args): Promise<Result> {
    const action = String(a.action ?? "list");
    if (action === "new") {
      const { tab } = await this.page(ws, { new: true });
      if (typeof a.url === "string") return this.navigate(ws, a.url, false).then((r) => ({ text: `New tab ${tab}. ${r.text}` }));
      return { text: `New tab ${tab}.` };
    }
    if (action === "resize") {
      const { st } = await this.page(ws);
      const p = String(a.preset ?? "");
      if (p === "desktop" || (!p && !a.width)) {
        await this.cdp(st, "Emulation.clearDeviceMetricsOverride");
        await this.cdp(st, "Emulation.setTouchEmulationEnabled", { enabled: false });
        return { text: "Back to the tab's own size." };
      }
      const [w, h] = p === "mobile" ? [375, 812] : p === "tablet" ? [768, 1024] : [Math.round(Number(a.width)), Math.round(Number(a.height) || 800)];
      if (!(w >= 200 && w <= 3840 && h >= 200 && h <= 3840)) throw new Error("width and height must be 200 to 3840.");
      const mobile = p === "mobile" || p === "tablet";
      await this.cdp(st, "Emulation.setDeviceMetricsOverride", { width: w, height: h, deviceScaleFactor: 0, mobile });
      await this.cdp(st, "Emulation.setTouchEmulationEnabled", { enabled: mobile, maxTouchPoints: mobile ? 5 : 1 });
      return { text: `The page now renders at ${w}x${h}${mobile ? " as a touch device" : ""}.` };
    }
    // list / select / close go through the panel (hidden windows are listed here too).
    const own = [...this.hidden.entries()].filter(([k]) => k.startsWith(`bg:${ws}:`)).map(([k, w]) => ({ tab_id: k, url: w.webContents.getURL(), title: w.webContents.getTitle(), active: this.current.get(ws) === k }));
    let panel: { tab_id: string; url: string; title: string; active: boolean }[] = [];
    if (this.renderer.available()) {
      if (action === "select" || action === "close") {
        if (typeof a.tab_id !== "string") throw new Error(`${action} needs tab_id.`);
        if (a.tab_id.startsWith("bg:")) {
          if (action === "close") this.hidden.get(a.tab_id)?.destroy();
          else if (this.hidden.has(a.tab_id)) this.current.set(ws, a.tab_id);
        } else await this.renderer.ask(action, { workspace_id: ws, tab_id: a.tab_id }, 5000);
        if (action === "select") this.current.set(ws, a.tab_id);
        if (action === "close" && this.current.get(ws) === a.tab_id) this.current.delete(ws);
      }
      panel = await this.renderer.ask<typeof panel>("list", { workspace_id: ws }, 5000).catch(() => []);
      for (const t of panel) t.active = this.current.get(ws) === t.tab_id;
    }
    const all = [...panel, ...own];
    return { text: all.length ? all.map((t) => `${t.active ? "* " : "  "}${t.tab_id}  ${JSON.stringify(t.title || "")}  ${t.url || "(blank)"}`).join("\n") : "No browser tabs yet. Open one with browser_navigate." };
  }
}
