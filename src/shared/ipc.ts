// Shared constants for the main <-> renderer boundary.
// Kept in one place so main and preload agree on channel names and the origin.

/** Custom privileged scheme the renderer is served from. */
export const APP_SCHEME = "opscode";
export const APP_HOST = "app";
/** Canonical origin of first-party renderer frames. */
export const APP_URL = `${APP_SCHEME}://${APP_HOST}/`;

/** Partition used later by the in-app <webview> browser pane (isolated from the app). */
export const GUEST_PARTITION = "persist:opscode-guest";

/**
 * A frame is "our own" only when it was served from APP_URL. Every IPC handler
 * checks this so guest pages (http/https webviews) and any embedded content
 * cannot reach privileged channels. (Reimplemented from the pattern observed in
 * the researched app, not copied.)
 */
export const isOwnFrame = (url: string | undefined): boolean =>
  typeof url === "string" && url.startsWith(APP_URL);

/** IPC channels. One namespace prefix, like the researched app's `caveman:`. */
export const CH = {
  /** sendSync: renderer asks for bootstrap info at load. */
  RUNTIME: "opscode:runtime",
  /** invoke: round-trip liveness/version check. */
  PING: "opscode:ping",
  /** send: set the native theme source. */
  THEME: "opscode:theme",
  /** invoke: native folder picker; returns a path or null. */
  PICK_FOLDER: "opscode:pick-folder",
  /** invoke: native picker for files/photos or a folder to attach; returns absolute paths. */
  PICK_ATTACH: "opscode:pick-attach",
  /** invoke: a file link in a reply: { op: "info" | "open" | "reveal", path }. */
  FILE_ACTION: "opscode:file-action",
  /** send: close the sender's window. */
  CLOSE_WINDOW: "opscode:close-window",
  /** send: bring the window to the front. */
  SHOW_WINDOW: "opscode:show-window",
  /** main -> renderer: an agent browser op on the side panel ({ rid, op, args }). */
  BROWSER: "opscode:browser",
  /** send: renderer -> main, the answer ({ rid, result } | { rid, error }). */
  BROWSER_REPLY: "opscode:browser-reply",
  /** send: renderer -> main, it is listening for BROWSER requests. */
  BROWSER_READY: "opscode:browser-ready",
  /** invoke: a small live picture of one of this window's Browser tabs (voice mode's mini screen). */
  BROWSER_FRAME: "opscode:browser-frame",
} as const;

export type ThemeSource = "system" | "light" | "dark";

/** Shape returned by RUNTIME and exposed on the bridge. */
export interface RuntimeInfo {
  appName: string;
  appVersion: string;
  platform: NodeJS.Platform;
  /** The local runtime's session endpoint (ws URL + bearer token), or null if unavailable. */
  endpoint: { url: string; token: string } | null;
}
