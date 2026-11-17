// Creates the main window with a hardened webPreferences profile and locks
// down navigation, popups, and <webview> attachment. The webview tag is enabled
// now (reserved for the in-app browser pane in a later phase) but every guest is
// forced into the isolated guest partition with no preload and web security on.

import { existsSync } from "node:fs";
import { join } from "node:path";
import { BrowserWindow, shell } from "electron";
import { APP_URL, GUEST_PARTITION, isOwnFrame } from "../shared/ipc";

const isGuestUrl = (url: string): boolean => /^https?:\/\//i.test(url) || url === "about:blank";

/** The window / taskbar icon (the .ico beside the app on Windows, the PNG in the source tree otherwise). */
function windowIcon(): string | undefined {
  if (process.platform === "darwin") return undefined;
  const root = join(__dirname, "..", "..");
  for (const p of [join(root, "assets", "brand", "logo", "opscode.ico"), join(root, "assets", "brand", "logo", "opscode-app-icon-1024.png"), join(process.resourcesPath ?? "", "opscode.ico")]) if (p && existsSync(p)) return p;
  return undefined;
}

export function createMainWindow(preloadPath: string): BrowserWindow {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 720,
    minHeight: 480,
    show: false,
    title: "Opscode",
    backgroundColor: "#141514",
    titleBarStyle: process.platform === "darwin" ? "hiddenInset" : "default",
    // Windows / Linux: a normal window frame; the menu bar stays out of the way (Alt shows it).
    autoHideMenuBar: process.platform !== "darwin",
    ...(windowIcon() ? { icon: windowIcon() } : {}),
    webPreferences: {
      preload: preloadPath,
      sandbox: true,
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: true,
      spellcheck: false,
      // The smoke run drives a window nobody looks at; keep its timers on time.
      backgroundThrottling: !process.env.OPSCODE_SMOKE,
    },
  });

  // Never let a first-party frame navigate away from its own origin.
  win.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith(APP_URL)) event.preventDefault();
  });

  // Open external links in the OS browser; never spawn an in-app window.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//i.test(url)) void shell.openExternal(url);
    return { action: "deny" };
  });

  // Harden any <webview> before it attaches: isolated partition, no preload,
  // web security on, node off. (Mirrors the researched will-attach-webview gate.)
  win.webContents.on("will-attach-webview", (_event, webPreferences, params) => {
    delete webPreferences.preload;
    webPreferences.sandbox = true;
    webPreferences.contextIsolation = true;
    webPreferences.nodeIntegration = false;
    (webPreferences as { nodeIntegrationInSubFrames?: boolean }).nodeIntegrationInSubFrames = false;
    webPreferences.webSecurity = true;

    params.partition = GUEST_PARTITION;
    if (!isGuestUrl(params.src ?? "")) params.src = "about:blank";
  });

  // Guests (the in-app browser) stay on http(s) pages, and their popups open in
  // the same tab instead of a new app window.
  win.webContents.on("did-attach-webview", (_event, guest) => {
    guest.setWindowOpenHandler(({ url }) => {
      if (/^https?:\/\//i.test(url)) void guest.loadURL(url);
      return { action: "deny" };
    });
    guest.on("will-navigate", (event, url) => {
      if (!isGuestUrl(url)) event.preventDefault();
    });
    guest.on("will-redirect", (event, url) => {
      if (!isGuestUrl(url)) event.preventDefault();
    });
  });

  win.once("ready-to-show", () => win.show());
  void win.loadURL(APP_URL);
  return win;
}

/** Bring an existing window back to the front (page window.focus() can't). */
export function focusWindow(win: BrowserWindow | null): void {
  if (!win || win.isDestroyed()) return;
  if (win.isMinimized()) win.restore();
  win.show();
  win.focus();
}

export { isOwnFrame };
