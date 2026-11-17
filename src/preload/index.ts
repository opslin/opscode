// Preload: runs in an isolated, sandboxed world and exposes a small, explicit
// API on window.opscode via contextBridge. The renderer never gets raw ipcRenderer
// or Node — only these typed functions.
//
// NOTE: a sandboxed preload can only require("electron") and a few built-ins —
// never local files. It is therefore bundled into one file by esbuild
// (npm run build:preload), which inlines ../shared/ipc.

import { contextBridge, ipcRenderer, webUtils } from "electron";
import { CH, type RuntimeInfo, type ThemeSource } from "../shared/ipc";

// Read bootstrap info synchronously at load, like the researched preload.
const runtime: RuntimeInfo | null = ipcRenderer.sendSync(CH.RUNTIME);

const api = {
  /** Bootstrap info captured at preload time (null if the sender wasn't trusted). */
  runtime,

  /** Round-trip to main; resolves with the echoed timestamp. */
  ping: (): Promise<{ pong: boolean; at: number; echo: number | null } | null> =>
    ipcRenderer.invoke(CH.PING, Date.now()),

  /** Set the OS/native theme source. */
  setTheme: (theme: ThemeSource): void => ipcRenderer.send(CH.THEME, theme),

  /** Native folder picker; resolves to an absolute path or null. */
  pickFolder: (): Promise<string | null> => ipcRenderer.invoke(CH.PICK_FOLDER),

  /** Native picker for attachments: "files" (files and photos) or "folder"; resolves to absolute paths. */
  pickAttachments: (kind: "files" | "folder"): Promise<string[]> => ipcRenderer.invoke(CH.PICK_ATTACH, kind),

  /** A file link in a reply: "info" (exists, folder, runnable), "open" (default app; programs only shown in Finder) or "reveal" (Finder). */
  fileAction: (op: "info" | "open" | "reveal", path: string): Promise<{ ok: boolean; exists: boolean; dir: boolean; runnable: boolean; path: string; revealed?: boolean; error?: string }> => ipcRenderer.invoke(CH.FILE_ACTION, op, path),

  /** The path of a file the person dropped on the window ("" if it has none, like a pasted picture). */
  pathForFile: (file: File): string => { try { return webUtils.getPathForFile(file); } catch { return ""; } },

  /** Window controls. */
  closeWindow: (): void => ipcRenderer.send(CH.CLOSE_WINDOW),
  showWindow: (): void => ipcRenderer.send(CH.SHOW_WINDOW),

  /** Electron/Chromium/Node versions, for the About/diagnostics view. */
  versions: { ...process.versions },
} as const;

export type OpscodeBridge = typeof api;

// The agent's browser: main asks the side panel to open/list/select Browser tabs and gets back
// the tab's WebContents id (main drives the page itself). Only these three channels are exposed.
(api as Record<string, unknown>).browserHost = {
  onRequest(cb: (msg: { rid: string; op: string; args: Record<string, unknown> }) => void): void {
    ipcRenderer.on(CH.BROWSER, (_e, msg) => cb(msg));
    ipcRenderer.send(CH.BROWSER_READY);
  },
  reply(msg: { rid: string; result?: unknown; error?: string }): void {
    ipcRenderer.send(CH.BROWSER_REPLY, msg);
  },
  /** A JPEG data URL (at most `width` px wide) of a Browser tab's page, or null when it cannot be seen. */
  frame(wcId: number, width: number, rect: { x: number; y: number; width: number; height: number } | null): Promise<{ url: string; title: string; image: string } | null> {
    return ipcRenderer.invoke(CH.BROWSER_FRAME, wcId, width, rect);
  },
};

contextBridge.exposeInMainWorld("opscode", api);
