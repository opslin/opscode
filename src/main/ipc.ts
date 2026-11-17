// Registers IPC handlers. Every handler validates the sender frame with
// isOwnFrame(event.senderFrame?.url) before doing anything, so only pages
// served from opscode://app/ can reach these channels.

import { app, BrowserWindow, dialog, ipcMain, nativeTheme, webContents, type IpcMainEvent } from "electron";
import { CH, isOwnFrame, type RuntimeInfo, type ThemeSource } from "../shared/ipc";
import { focusWindow } from "./window";
import { fileAction } from "./fileLinks";

const own = (event: { senderFrame?: { url?: string } | null }): boolean =>
  isOwnFrame(event.senderFrame?.url);

export function registerIpc(getEndpoint: () => RuntimeInfo["endpoint"]): void {
  const runtimeInfo = (): RuntimeInfo => ({
    appName: app.getName(),
    appVersion: app.getVersion(),
    platform: process.platform,
    // The local runtime's ws URL + bearer token. Only first-party frames get it.
    endpoint: getEndpoint(),
  });

  // sendSync: renderer reads bootstrap info during preload evaluation.
  ipcMain.on(CH.RUNTIME, (event: IpcMainEvent) => {
    event.returnValue = own(event) ? runtimeInfo() : null;
  });

  // invoke: liveness/version round-trip.
  ipcMain.handle(CH.PING, (event, sentAt: unknown) => {
    if (!own(event)) return null;
    return { pong: true, at: Date.now(), echo: typeof sentAt === "number" ? sentAt : null };
  });

  // send: set native theme source (allow-listed values only).
  ipcMain.on(CH.THEME, (event, theme: unknown) => {
    if (!own(event)) return;
    if (theme === "system" || theme === "light" || theme === "dark") {
      nativeTheme.themeSource = theme as ThemeSource;
    }
  });

  // invoke: a live picture of a Browser tab (a <webview> inside the asking window only), for voice mode's mini screen.
  ipcMain.handle(CH.BROWSER_FRAME, async (event, wcId: unknown, width: unknown, rect: unknown) => {
    if (!own(event) || typeof wcId !== "number") return null;
    const wc = webContents.fromId(wcId);
    if (!wc || wc.isDestroyed() || wc.getType() !== "webview" || wc.hostWebContents !== event.sender) return null;
    const w = Math.max(160, Math.min(900, Number(width) || 560));
    const timeout = <T,>(p: Promise<T>): Promise<T | null> => Promise.race([p, new Promise<null>((r) => setTimeout(() => r(null), 1500))]);
    // A picture taken before the page was painted is all black: not a picture yet (the window keeps its placeholder).
    const blank = (img: Electron.NativeImage): boolean => { const px = img.resize({ width: 16, height: 10 }).toBitmap(); let sum = 0; for (let i = 0; i < px.length; i += 4) sum += px[i]! + px[i + 1]! + px[i + 2]!; return sum / (px.length / 4) / 3 < 2; };
    const jpeg = (img: Electron.NativeImage): string | null => { if (blank(img)) return null; const out = img.getSize().width > w ? img.resize({ width: w, quality: "good" }) : img; return `data:image/jpeg;base64,${out.toJPEG(72).toString("base64")}`; };
    const meta = { url: wc.getURL(), title: wc.getTitle() };
    try {
      // What the person sees: the part of this window where the Browser tab is drawn (the tab is on screen while the
      // agent browses, because the panel shows it).
      const r = rect as { x?: unknown; y?: unknown; width?: unknown; height?: unknown } | null;
      if (r && [r.x, r.y, r.width, r.height].every((n) => typeof n === "number" && Number.isFinite(n)) && (r.width as number) > 40 && (r.height as number) > 40) {
        const img = await timeout(event.sender.capturePage({ x: Math.round(r.x as number), y: Math.round(r.y as number), width: Math.round(r.width as number), height: Math.round(r.height as number) }));
        const j = img && !img.isEmpty() ? jpeg(img) : null;
        if (j) return { ...meta, image: j };
      }
      // Not on screen: let the page draw itself.
      const img = await timeout(wc.capturePage(undefined, { stayHidden: true, stayAwake: true }));
      if (!img || img.isEmpty()) return null;
      const j = jpeg(img);
      return j ? { ...meta, image: j } : null;
    } catch { return null; }
  });

  // invoke: native directory picker.
  ipcMain.handle(CH.PICK_FOLDER, async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (!own(event) || !win) return null;
    const picked = await dialog.showOpenDialog(win, {
      title: "Add a project",
      buttonLabel: "Add Project",
      properties: ["openDirectory"],
    });
    return picked.canceled ? null : picked.filePaths[0] ?? null;
  });

  // invoke: attach files, photos or a folder to a message (the runtime copies them into the project).
  ipcMain.handle(CH.PICK_ATTACH, async (event, kind: unknown) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (!own(event) || !win) return [];
    const folder = kind === "folder";
    const picked = await dialog.showOpenDialog(win, folder
      ? { title: "Add a folder", buttonLabel: "Add folder", properties: ["openDirectory"] }
      : { title: "Add files or photos", buttonLabel: "Add", properties: ["openFile", "multiSelections"] });
    return picked.canceled ? [] : picked.filePaths.slice(0, 12);
  });

  // invoke: open / reveal / look up a file the person clicked in a reply (main/fileLinks.ts).
  ipcMain.handle(CH.FILE_ACTION, async (event, op: unknown, path: unknown) => {
    if (!own(event)) return { ok: false, error: "not allowed" };
    return fileAction(op, path);
  });

  // send: close / show the sender window.
  ipcMain.on(CH.CLOSE_WINDOW, (event) => {
    if (own(event)) BrowserWindow.fromWebContents(event.sender)?.close();
  });
  ipcMain.on(CH.SHOW_WINDOW, (event) => {
    if (own(event)) focusWindow(BrowserWindow.fromWebContents(event.sender));
  });
}
