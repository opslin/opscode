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
  /** send: main window -> main, the chat on screen ({ chat_id } or null). The notch counts it as seen. */
  NOTCH_VIEWING: "opscode:notch-viewing",
  /** main -> main window: open a chat or a new chat because the notch asked ({ chat_id?, workspace_id?, draft? }). */
  NOTCH_OPEN: "opscode:notch-open",
  MOBILE_DEVICES: "opscode:mobile-devices",
} as const;

/**
 * The notch's own window (notch.html). Its page gets no runtime endpoint or token: main tells it what to show and
 * does what it asks. Each channel is checked against the notch window's own webContents.
 */
export const NOTCH = {
  /** send: page -> main, it listens now. */
  READY: "opscode:notch:ready",
  /** main -> page: the feed (sessions, pose, pulse) plus the screen's notch size. */
  STATE: "opscode:notch:state",
  /** send: page -> main, an action ({ type, ... }; validated in main/notch.ts). */
  ACT: "opscode:notch:act",
  /** send: page -> main, the pointer is over the drawn shape (true) or off it (false). */
  OVER: "opscode:notch:over",
  /** main -> page: the pointer left the window in one move. */
  AWAY: "opscode:notch:away",
  /** send: page -> main, the right-click menu. */
  MENU: "opscode:notch:menu",
  /** main -> page: open with the message box focused (the global shortcut). */
  SUMMON: "opscode:notch:summon",
  /** main -> page: a voice dictation event ({ ev, text?, full?, rms?, message? }). */
  VOICE: "opscode:notch:voice",
  /** main -> page: voice mode (talking with the voice agent): its events and the voice audio ({ kind: "agent" | "tts" | "on" | "off", ... }). */
  TALK: "opscode:notch:talk",
  /** main -> page: start talking (the voice-mode shortcut). */
  TALK_SUMMON: "opscode:notch:talk-summon",
  /** main -> page: a short message to show (an error from an action). */
  TOAST: "opscode:notch:toast",
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

/** The overlay (overlay.html): the glow around the screen and the frame around the app while Opscode uses the Mac, and the workers' mini screens. */
export const OVERLAY = {
  /** send: page -> main, it listens now. */
  READY: "opscode:overlay:ready",
  /** main -> page: what to draw ({ working, summary, app, rect, gallery, feed }). */
  STATE: "opscode:overlay:state",
  /** send: page -> main ({ type: "close" } | { type: "open", chat_id }). */
  ACT: "opscode:overlay:act",
} as const;
