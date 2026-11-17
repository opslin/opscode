// Shared app state with a tiny subscribe/notify.
import { words } from "./dom.js";

export const state = {
  client: null,
  bridge: window.opscode,
  settings: null,
  workspaces: [],
  active: null, // workspace id
  surface: "chat", // chat | files | terminal
  collapsed: readPref("sidebar-collapsed") === "1",
  conn: "connecting",
  hello: null,
  providers: [],
  engines: [], // coding-agent engines found on this computer (Claude Code, Codex)
  engineSettings: null,
  accounts: [], // Claude Code and Codex sign-ins: [{ id, engine, is_default, active, status: { signed_in, email, plan, org, method } }]
  login: null, // the open browser sign-in, if any
  limitsByAccount: [], // plan limits of every account that was read
  notes: [],
  chats: [], // every chat, newest first
  running: new Set(), // chat ids with a turn in progress
  chatSel: {}, // workspace id -> chat id | "new"
  mcp: [],
  computer: null, // computer-use status (see computer.status)
  agents: [], // sub-agents visible in the active project
  skills: [], // skills visible in the active project
  plugins: [],
  marketplaces: [],
  page: "app", // app | settings
  section: "general",
};

/** Callbacks the app registers so any module can navigate without importing app.js. */
export const nav = { openSettings: (_section) => {}, closeSettings: () => {} };

const subs = new Set();
export const subscribe = (fn) => (subs.add(fn), () => subs.delete(fn));
export const notify = () => subs.forEach((fn) => fn(state));

export function readPref(key) {
  try { return localStorage.getItem(`opscode:${key}`); } catch { return null; }
}
export function writePref(key, value) {
  try { localStorage.setItem(`opscode:${key}`, value); } catch { /* storage unavailable */ }
}

export const activeWorkspace = () => state.workspaces.find((w) => w.id === state.active) ?? null;

/** Transient message at the bottom of the window. */
export function toast(message, ms = 3200) {
  for (const old of document.querySelectorAll(".toast")) old.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.setAttribute("role", "status");
  el.textContent = words(message);
  document.body.append(el);
  setTimeout(() => el.remove(), ms);
}
