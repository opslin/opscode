// The overlay: one clear, click-through window over the whole main screen, just under the notch. It shows the person that
// Opscode is using their Mac:
//   - a glow of red / ember pixels running around the screen's rounded edge while steps run (fades ~2.5 s after the last)
//   - a pixel frame around the window of the app being used (it follows the window: opscode-hands bounds, every 0.4 s)
//   - "show my workers": mini screens of every chat at work in the middle of the screen (the only time it takes clicks)
// Its page (overlay.html) gets no runtime endpoint: main sends it what to draw.

import { BrowserWindow, ipcMain, screen, type IpcMainEvent } from "electron";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { OVERLAY } from "../shared/ipc";

const HOLD_MS = 2500;
const TRACK_MS = 400;

export interface OverlayAct { source?: string; phase?: string; summary?: string; app?: string; pid?: number; ok?: boolean; chat_id?: string }

export class Overlay {
  private win: BrowserWindow | null = null;
  private ready = false;
  private working = false;
  private hold: NodeJS.Timeout | undefined;
  private track: NodeJS.Timeout | undefined;
  private target: { app?: string; pid?: number } = {};
  private rect: { x: number; y: number; w: number; h: number } | null = null;
  private summary = "";
  private gallery = false;
  private feed: unknown = null;
  private readonly bin: string | undefined;

  constructor(private readonly o: { url: string; preload: string; log: (l: string) => void; open: (chatId: string) => void }) {
    const inApp = join(__dirname, "..", "..", "..", "..", "MacOS", "opscode-hands");
    const b = join(__dirname, "..", "native", "opscode-hands");
    this.bin = process.env.OPSCODE_HANDS_BIN || (existsSync(inApp) ? inApp : existsSync(b) ? b : undefined);
  }

  start(): void {
    const mine = (e: IpcMainEvent): boolean => !!this.win && !this.win.isDestroyed() && e.sender === this.win.webContents;
    ipcMain.on(OVERLAY.READY, (e) => { if (mine(e)) { this.ready = true; this.send(); } });
    ipcMain.on(OVERLAY.ACT, (e, a: unknown) => {
      if (!mine(e) || typeof a !== "object" || a === null) return;
      const x = a as Record<string, unknown>;
      if (x.type === "close") this.workers(false);
      else if (x.type === "open" && typeof x.chat_id === "string" && x.chat_id.length <= 200) { this.workers(false); this.o.open(x.chat_id); }
    });
    screen.on("display-metrics-changed", () => this.place());
    screen.on("display-added", () => this.place());
    screen.on("display-removed", () => this.place());
  }

  stop(): void {
    clearTimeout(this.hold); clearInterval(this.track);
    if (this.win && !this.win.isDestroyed()) this.win.destroy();
    this.win = null;
  }

  /** A step on the Mac started or ended. */
  act(a: OverlayAct): void {
    if (a.phase === "start") {
      this.working = true;
      if (a.summary) this.summary = a.summary.slice(0, 120);
      if (a.pid || a.app) this.setTarget({ ...(a.app ? { app: a.app } : {}), ...(a.pid ? { pid: a.pid } : {}) });
      clearTimeout(this.hold);
      this.hold = setTimeout(() => this.idle(), 20_000);   // a step that never reports its end still fades
    } else {
      if (a.pid || a.app) this.setTarget({ ...(a.app ? { app: a.app } : {}), ...(a.pid ? { pid: a.pid } : {}) });
      clearTimeout(this.hold);
      this.hold = setTimeout(() => this.idle(), HOLD_MS);
    }
    this.ensure();
    this.send();
  }

  /** Mini screens of every chat at work ("show my workers"); the feed is the notch's. */
  workers(on: boolean): void {
    this.gallery = on;
    this.ensure();
    const win = this.win;
    if (win && !win.isDestroyed()) {
      win.setIgnoreMouseEvents(!on);
      if (on) { win.setFocusable(true); win.focus(); } else win.setFocusable(false);
    }
    this.send();
  }

  get showingWorkers(): boolean { return this.gallery; }

  setFeed(feed: unknown): void { this.feed = feed; if (this.gallery) this.send(); }

  private idle(): void {
    this.working = false;
    this.summary = "";
    clearInterval(this.track); this.track = undefined;
    this.send();
  }

  private setTarget(t: { app?: string; pid?: number }): void {
    const same = (t.pid && t.pid === this.target.pid) || (!t.pid && t.app && t.app === this.target.app);
    if (!same) this.rect = null;
    this.target = t;
    this.follow();
    if (!this.track) this.track = setInterval(() => this.follow(), TRACK_MS);
  }

  /** Where the target app's window is now (no permission needed: the window list). */
  private follow(): void {
    const who = this.target.pid ? String(this.target.pid) : this.target.app;
    if (!this.bin || !who || !this.working) return;
    execFile(this.bin, ["bounds", who], { timeout: 3000 }, (_e, out) => {
      try {
        const r = JSON.parse(String(out).trim()) as { ok: boolean; x: number; y: number; w: number; h: number };
        const d = screen.getPrimaryDisplay().bounds;
        const next = r.ok ? { x: r.x - d.x, y: r.y - d.y, w: r.w, h: r.h } : null;
        if (JSON.stringify(next) !== JSON.stringify(this.rect)) { this.rect = next; this.send(); }
      } catch { /* not JSON */ }
    });
  }

  private send(): void {
    const win = this.win;
    if (!win || win.isDestroyed() || !this.ready) return;
    win.webContents.send(OVERLAY.STATE, { working: this.working, summary: this.summary, app: this.target.app ?? "", rect: this.working ? this.rect : null, gallery: this.gallery, feed: this.gallery ? this.feed : null });
    if (!this.working && !this.gallery) setTimeout(() => { if (!this.working && !this.gallery && this.win && !this.win.isDestroyed()) this.win.hide(); }, 900);
    else if (!win.isVisible()) win.showInactive();
  }

  private place(): void {
    const win = this.win;
    if (!win || win.isDestroyed()) return;
    win.setBounds(screen.getPrimaryDisplay().bounds);
  }

  private ensure(): void {
    if (this.win && !this.win.isDestroyed()) return;
    const d = screen.getPrimaryDisplay().bounds;
    const win = new BrowserWindow({
      ...d, show: false, frame: false, transparent: true, hasShadow: false, resizable: false, movable: false, minimizable: false, maximizable: false,
      fullscreenable: false, skipTaskbar: true, focusable: false, alwaysOnTop: true, enableLargerThanScreen: true,
      ...(process.platform === "darwin" ? { type: "panel" } : {}),
      title: "Opscode Overlay",
      webPreferences: { preload: this.o.preload, contextIsolation: true, nodeIntegration: false, sandbox: true, backgroundThrottling: false, spellcheck: false },
    });
    // Above apps (and full-screen ones), under the notch.
    win.setAlwaysOnTop(true, "status");
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true, skipTransformProcessType: true });
    win.setIgnoreMouseEvents(true);
    win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
    win.webContents.on("will-navigate", (e) => e.preventDefault());
    win.on("closed", () => { if (this.win === win) { this.win = null; this.ready = false; } });
    this.ready = false;
    void win.loadURL(this.o.url);
    this.win = win;
  }
}
