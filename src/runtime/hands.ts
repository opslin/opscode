// Computer use through Accessibility (native/opscode-hands). Four parts:
//   Hands            runs the native helper (one JSON line per call; the element numbers of each chat in its own state file)
//   handsTools()     the computer_* tools the agents use: read an app as a numbered list, act by number, every action checked
//   instant          plain commands that need no AI at all ("open Chrome", "quit Slack", "go to github.com"): $0, instant
//   ReplayStore      a task that worked once, with only plain steps, replays next time with no AI; anything risky is never kept
//
// Asking (the person's decision, 2026-11-18): steps run without asking, EXCEPT risky ones — a button or menu item that buys,
// pays, sends, deletes, submits…, keys that quit/close/delete, and typing what looks like a card number or password. Apps on
// the denylist (terminals, password managers, system prompts, Opscode) and apps the person set to "never" are refused.
// Password fields are never typed into (the helper refuses too).

import { execFile } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import type { Tool } from "./agent/tools";
import { isDenied, type AppRef, type ComputerStore } from "./computer";

// ---- the helper ---------------------------------------------------------------------------------------------------------

export interface HandsResult {
  ok: boolean;
  error?: string;
  map?: string;
  changed?: boolean | null;
  note?: string;
  did?: string;
  field_has?: string;
  app?: string;
  pid?: number;
  count?: number;
  apps?: { name: string; bundle: string; pid: number; front: boolean; hidden: boolean }[];
  accessibility?: boolean;
  /** Screen Recording (the helper's quiet check). */
  screen?: boolean;
  skylight?: boolean;
}
interface StateNode { id: number; role: string; label: string; secret: boolean; disabled: boolean; risky: boolean }
interface State { pid: number; app: string; bundle: string; window: string; nodes: StateNode[] }

/** Where the helper is: OPSCODE_HANDS_BIN (tests), else dist/native/opscode-hands beside the runtime. */
export function handsBin(env: NodeJS.ProcessEnv = process.env): string | undefined {
  if (env.OPSCODE_HANDS_BIN) return env.OPSCODE_HANDS_BIN;
  if (process.platform !== "darwin") return undefined;
  // Installed: beside the app's own program (Contents/MacOS), signed as the app itself, so macOS applies the person's
  // Accessibility permission for Opscode to it. From source: dist/native.
  const inApp = join(__dirname, "..", "..", "..", "..", "MacOS", "opscode-hands");
  if (existsSync(inApp)) return inApp;
  const p = join(__dirname, "..", "native", "opscode-hands");
  return existsSync(p) ? p : undefined;
}

export class Hands {
  constructor(private readonly bin: string, private readonly dir: string) { ensurePrivateDir(dir); }

  private statePath(key: string): string { return join(this.dir, `${key.replace(/[^\w-]/g, "_").slice(0, 80) || "default"}.json`); }

  /** One call. Never throws: a failure comes back as { ok: false, error }. */
  run(key: string, args: string[], signal?: AbortSignal, timeoutMs = 25_000): Promise<HandsResult> {
    return new Promise((resolve) => {
      execFile(this.bin, ["--state", this.statePath(key), ...args], { timeout: timeoutMs, maxBuffer: 2_000_000, ...(signal ? { signal } : {}) }, (err, stdout) => {
        const line = String(stdout ?? "").trim().split("\n").pop() ?? "";
        try { return resolve(JSON.parse(line) as HandsResult); } catch { /* not JSON */ }
        resolve({ ok: false, error: err ? (err.name === "AbortError" ? "Stopped." : err.message) : "The computer helper gave no answer." });
      });
    });
  }

  /** The last look of this chat (labels and risk of each number), for deciding whether to ask. */
  state(key: string): State | undefined {
    try { return JSON.parse(readFileSync(this.statePath(key), "utf8")) as State; } catch { return undefined; }
  }

  check(): Promise<HandsResult> { return this.run("check", ["check"], undefined, 8000); }
  apps(): Promise<HandsResult> { return this.run("apps", ["apps"], undefined, 8000); }
}

// ---- risk -----------------------------------------------------------------------------------------------------------------

const RISK_WORDS = /\b(buy|purchase|pay|payment|order|place order|checkout|check out|bid|subscribe|delete|remove|erase|trash|send|submit|post|publish|transfer|withdraw|donate|sign out|log out|uninstall|format|reset|confirm purchase)\b/i;
export const risky = (s: string): boolean => RISK_WORDS.test(s);
/** cmd+q, cmd+w, cmd+delete, cmd+opt+esc. */
export function riskyKey(combo: string): boolean {
  const c = combo.toLowerCase().replace(/\s+/g, "");
  return /(cmd|command|⌘)\+.*(q|w|delete|backspace|forwarddelete)$/.test(c) || /(cmd|command).*(alt|option|opt).*(esc|escape)$/.test(c);
}
/** Text that looks like a card number or a password: the person types those themselves, or says yes first. */
export function sensitiveText(t: string): boolean {
  const digits = t.replace(/[\s-]/g, "");
  return /\b\d{13,19}\b/.test(digits) || /\b(password|passcode|pin|cvv|cvc)\b\s*[:=]/i.test(t);
}

// ---- tools ----------------------------------------------------------------------------------------------------------------

export interface Step { verb: "open" | "quit" | "activate" | "key" | "menu" | "press" | "type"; app?: string; args: string[] }

export interface HandsToolOpts {
  /** The chat (or voice session) whose element numbers these tools use. */
  key: string;
  /** Every step that ran and was confirmed, for learning a replay at the end of the task. */
  onStep?(step: Step, ok: boolean): void;
  /** A step is starting (its one-line summary and the app, when known), for live step lines (the notch, voice mode). */
  onAct?(summary: string, at?: { app?: string; pid?: number }): void;
  /** A step finished: the app it worked in (for the frame drawn around that app's window). */
  onTarget?(at: { app?: string; pid?: number; ok: boolean; error?: string }): void;
}

const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);
const appRef = (name: string, bundle = ""): AppRef => ({ name, bundle_id: bundle });

export function handsTools(hands: Hands, store: ComputerStore, o: HandsToolOpts): Tool[] {
  const out = (r: HandsResult, extra = ""): { output: string; is_error: boolean } => {
    if (!r.ok) return { output: r.error ?? "It did not work.", is_error: true };
    const parts = [r.did ? `Done: ${r.did}.` : "", r.note ?? "", r.field_has !== undefined ? `The field now has: "${r.field_has}"` : "", extra, r.map ? `\n${r.map}` : ""].filter(Boolean);
    return { output: parts.join(" ").trim() || "Done.", is_error: false };
  };
  /** Refuses the denylist and the person's "never" apps; returns the app the step is in. */
  const allowedApp = (name: string, bundle = ""): string | undefined => {
    const a = appRef(name, bundle);
    if (isDenied(a)) return `${name} is never controlled (terminals, password managers, system prompts and Opscode itself are off limits).`;
    if (store.ruleFor(a) === "never") return `The person has blocked ${name}.`;
    return undefined;
  };
  const target = (): State | undefined => hands.state(o.key);
  const node = (id: unknown): StateNode | undefined => target()?.nodes.find((n) => n.id === Number(id));

  const tool = (name: string, description: string, properties: Record<string, unknown>, required: string[],
    describe: (i: Record<string, unknown>) => string,
    gate: (i: Record<string, unknown>) => { rule: "auto" | "ask" | "deny"; reason?: string; detail?: string },
    run: (i: Record<string, unknown>, signal: AbortSignal) => Promise<{ output: string; is_error: boolean }>): Tool => ({
    def: { name, description, schema: { type: "object", properties, required } },
    kind: "computer",
    describe: (i) => ({ summary: describe(i) }),
    async gate(i) {
      const g = gate(i);
      return { rule: g.rule, summary: describe(i), ...(g.detail ? { detail: g.detail } : {}), ...(g.reason ? { reason: g.reason } : {}), app: target()?.bundle || target()?.app || "computer" };
    },
    async run(i, ctx) {
      const t0 = target();
      o.onAct?.(describe(i), { ...(t0?.app ? { app: t0.app } : name === "computer_open" ? { app: str(i.target, 120) } : {}), ...(t0?.pid ? { pid: t0.pid } : {}) });
      let r: { output: string; is_error: boolean };
      try { r = await run(i, ctx.signal); } catch (e) { r = { output: e instanceof Error ? e.message : String(e), is_error: true }; }
      const t1 = target();
      o.onTarget?.({ ...(name === "computer_open" ? { app: str(i.target, 120) } : t1?.app ? { app: t1.app } : {}), ...(name !== "computer_open" && t1?.pid ? { pid: t1.pid } : {}), ok: !r.is_error, ...(r.is_error ? { error: clip(r.output.replace(/\s+/g, " "), 200) } : {}) });
      return r;
    },
  });
  const step = (s: Step, r: HandsResult): void => { o.onStep?.(s, r.ok && r.changed !== false); };
  const str = (v: unknown, max: number): string => (typeof v === "string" ? v.trim().slice(0, max) : "");

  return [
    tool("computer_see",
      "Read an app as a numbered list of its buttons, fields, menus and visible text (no screenshot: fast and exact). Leave app out for the app in front. Use the numbers with the other computer_* tools. Look again after anything big changes.",
      { app: { type: "string", description: "App name (e.g. \"Google Chrome\"), or empty for the app in front." } }, [],
      (i) => `Look at ${str(i.app, 60) || "the app in front"}`,
      (i) => { const a = str(i.app, 60); const why = a ? allowedApp(a) : undefined; return why ? { rule: "deny", reason: why } : { rule: "auto" }; },
      async (i, signal) => {
        const r = await hands.run(o.key, ["see", ...(str(i.app, 60) ? [str(i.app, 60)] : [])], signal);
        if (r.ok && r.app) { const why = allowedApp(r.app, target()?.bundle ?? ""); if (why) return { output: why, is_error: true }; }
        return out(r);
      }),
    tool("computer_click",
      "Click element [id] from your last computer_see. how: \"right\" for its context menu, \"double\" to double-click. The result says whether the window changed and gives the new list.",
      { id: { type: "number" }, how: { type: "string", enum: ["click", "right", "double"] } }, ["id"],
      (i) => { const n = node(i.id); return `Click ${n ? `"${clip(n.label, 50)}"` : `[${i.id}]`}${target()?.app ? ` in ${target()!.app}` : ""}`; },
      (i) => {
        const t = target(); const n = node(i.id);
        if (!t) return { rule: "deny", reason: "Look at the app first (computer_see)." };
        const why = allowedApp(t.app, t.bundle); if (why) return { rule: "deny", reason: why };
        if (n && (n.risky || risky(n.label))) return { rule: "ask", detail: `"${n.label}" in ${t.app} looks like it buys, sends, deletes or submits something.` };
        return { rule: "auto" };
      },
      async (i, signal) => {
        const n = node(i.id); const t = target();
        const how = i.how === "right" || i.how === "double" ? String(i.how) : "";
        const r = await hands.run(o.key, ["click", String(Number(i.id)), ...(how ? [how] : [])], signal);
        if (n && t && !how && n.label) step({ verb: "press", app: t.app, args: [n.label, n.role] }, r);
        return out(r);
      }),
    tool("computer_type",
      "Type into field [id] from your last computer_see (replaces its text; append true adds to it). Never passwords: the person types those.",
      { id: { type: "number" }, text: { type: "string" }, append: { type: "boolean" } }, ["id", "text"],
      (i) => { const n = node(i.id); return `Type "${clip(str(i.text, 2000), 40)}" into ${n ? `"${clip(n.label, 40)}"` : `[${i.id}]`}`; },
      (i) => {
        const t = target(); const n = node(i.id);
        if (!t) return { rule: "deny", reason: "Look at the app first (computer_see)." };
        const why = allowedApp(t.app, t.bundle); if (why) return { rule: "deny", reason: why };
        if (n?.secret) return { rule: "deny", reason: "That is a password field. Ask the person to type it." };
        if (sensitiveText(str(i.text, 2000))) return { rule: "ask", detail: "This looks like a card number or a password." };
        return { rule: "auto" };
      },
      async (i, signal) => {
        const text = str(i.text, 2000);
        if (!text) return { output: "Nothing to type.", is_error: true };
        const n = node(i.id); const t = target();
        const r = await hands.run(o.key, [i.append === true ? "append" : "type", String(Number(i.id)), text], signal);
        if (n && t && n.label) step({ verb: "type", app: t.app, args: [n.label, text] }, r);
        return out(r);
      }),
    tool("computer_key",
      "Press a key or shortcut in an app: \"return\", \"tab\", \"escape\", \"cmd+t\", \"cmd+shift+n\". app: which app (empty = the one you last looked at).",
      { combo: { type: "string" }, app: { type: "string" } }, ["combo"],
      (i) => `Press ${str(i.combo, 40)}${str(i.app, 60) ? ` in ${str(i.app, 60)}` : target()?.app ? ` in ${target()!.app}` : ""}`,
      (i) => {
        const a = str(i.app, 60) || target()?.app || "";
        const why = a ? allowedApp(a, str(i.app, 60) ? "" : target()?.bundle ?? "") : undefined; if (why) return { rule: "deny", reason: why };
        return riskyKey(str(i.combo, 40)) ? { rule: "ask", detail: `${str(i.combo, 40)} quits, closes or deletes.` } : { rule: "auto" };
      },
      async (i, signal) => {
        const app = str(i.app, 60) || (target() ? String(target()!.pid) : "");
        const r = await hands.run(o.key, ["key", str(i.combo, 40), ...(app ? [app] : [])], signal);
        step({ verb: "key", app: str(i.app, 60) || target()?.app, args: [str(i.combo, 40)] }, { ...r, changed: r.ok ? true : r.changed });
        return out(r);
      }),
    tool("computer_scroll",
      "Scroll the app you last looked at: lines > 0 down, < 0 up. id: scroll at that element (0 = the window).",
      { id: { type: "number" }, lines: { type: "number" } }, ["lines"],
      (i) => `Scroll ${Number(i.lines) > 0 ? "down" : "up"}${target()?.app ? ` in ${target()!.app}` : ""}`,
      () => { const t = target(); if (!t) return { rule: "deny", reason: "Look at the app first (computer_see)." }; const why = allowedApp(t.app, t.bundle); return why ? { rule: "deny", reason: why } : { rule: "auto" }; },
      async (i, signal) => out(await hands.run(o.key, ["scroll", String(Number(i.id) || 0), String(Math.max(-50, Math.min(50, Math.round(Number(i.lines) || 3))))], signal))),
    tool("computer_menu",
      "Choose a menu bar item by its path, e.g. \"File > New Window\" or \"View > Zoom In\". app: which app (empty = the one in front).",
      { path: { type: "string" }, app: { type: "string" } }, ["path"],
      (i) => `Menu ${str(i.path, 80)}${str(i.app, 60) ? ` in ${str(i.app, 60)}` : ""}`,
      (i) => {
        const a = str(i.app, 60); const why = a ? allowedApp(a) : undefined; if (why) return { rule: "deny", reason: why };
        return risky(str(i.path, 80)) ? { rule: "ask", detail: `"${str(i.path, 80)}" looks like it sends, deletes or buys something.` } : { rule: "auto" };
      },
      async (i, signal) => {
        const r = await hands.run(o.key, ["menu", str(i.path, 120), ...(str(i.app, 60) ? [str(i.app, 60)] : [])], signal);
        if (!r.ok && /^RISKY:/.test(r.error ?? "")) return { output: "That menu item is risky; it needs the person's yes first.", is_error: true };
        step({ verb: "menu", app: str(i.app, 60) || undefined, args: [str(i.path, 120)] }, r);
        return out(r);
      }),
    tool("computer_open",
      "Open an app by name (\"Google Chrome\", \"Notes\") or a web address (https://…). Then computer_see it.",
      { target: { type: "string" } }, ["target"],
      (i) => `Open ${str(i.target, 80)}`,
      (i) => { const t = str(i.target, 200); if (/^https?:\/\//i.test(t)) return { rule: "auto" }; const why = allowedApp(t); return why && !/^(terminal|system settings)$/i.test(t) ? { rule: "deny", reason: why } : { rule: "auto" }; },
      async (i, signal) => {
        const t = str(i.target, 300);
        const r = await hands.run(o.key, ["open", t], signal, 15_000);
        step({ verb: "open", args: [t] }, { ...r, changed: r.ok ? true : false });
        return out(r);
      }),
    tool("computer_apps",
      "Which apps are running and which one is in front.",
      {}, [], () => "List the running apps", () => ({ rule: "auto" }),
      async () => {
        const r = await hands.apps();
        if (!r.ok) return out(r);
        return { output: (r.apps ?? []).map((a) => `${a.name}${a.front ? " (in front)" : ""}${a.hidden ? " (hidden)" : ""}`).join("\n") || "No apps.", is_error: false };
      }),
  ];
}

// ---- instant commands (no AI) ---------------------------------------------------------------------------------------------

export type Instant = { kind: "open"; target: string; say: string } | { kind: "quit" | "activate"; target: string; say: string };

const SITES: Record<string, string> = {
  youtube: "https://www.youtube.com", gmail: "https://mail.google.com", github: "https://github.com", google: "https://www.google.com",
  "google drive": "https://drive.google.com", drive: "https://drive.google.com", "google docs": "https://docs.google.com", calendar: "https://calendar.google.com",
  "google calendar": "https://calendar.google.com", twitter: "https://x.com", x: "https://x.com", linkedin: "https://www.linkedin.com", reddit: "https://www.reddit.com",
  whatsapp: "https://web.whatsapp.com", "whatsapp web": "https://web.whatsapp.com", chatgpt: "https://chatgpt.com", claude: "https://claude.ai", figma: "https://www.figma.com",
  vercel: "https://vercel.com", netflix: "https://www.netflix.com", amazon: "https://www.amazon.in", stackoverflow: "https://stackoverflow.com", "stack overflow": "https://stackoverflow.com",
};
const APP_ALIASES: Record<string, string> = { chrome: "Google Chrome", "google chrome": "Google Chrome", vscode: "Visual Studio Code", "vs code": "Visual Studio Code", code: "Visual Studio Code", settings: "System Settings", "system settings": "System Settings", mail: "Mail", notes: "Notes", music: "Music", spotify: "Spotify", slack: "Slack", safari: "Safari", finder: "Finder", calendar: "Calendar", messages: "Messages", xcode: "Xcode", docker: "Docker", "app store": "App Store", whatsapp: "WhatsApp", telegram: "Telegram", discord: "Discord", zoom: "zoom.us", photos: "Photos", preview: "Preview", terminal: "Terminal", iterm: "iTerm" };
const titleCase = (s: string): string => s.replace(/\b\w/g, (c) => c.toUpperCase());

/**
 * A plain command that needs no AI: "open chrome", "launch spotify", "quit slack", "switch to notes", "go to github.com",
 * "open youtube". Anything longer or vaguer ("open the file I was editing", "open chrome and search…") is not instant.
 */
export function parseInstant(text: string): Instant | null {
  // Speech adds filler ("You... open Chrome.", "uh, hey Opscode, open Chrome please"): drop it around the command.
  let t = text.toLowerCase().replace(/…|\.{2,}/g, " ").replace(/[,;:!?]+/g, " ").replace(/\.+\s*$/, "").replace(/\s+/g, " ").trim();
  const FILLER = /^(you|uh+|um+|hmm+|ah+|so|and|okay|ok|hey|hi|yo|opscode|ops code|please|can you|could you|would you|will you|just|now|then|alright|all right|right|well)\b\.?\s*/;
  for (let i = 0; i < 6 && FILLER.test(t); i++) t = t.replace(FILLER, "");
  t = t.replace(/ (please|for me|now|right now|quickly)$/, "").trim();
  if (!t || t.split(/\s+/).length > 6) return null;
  let m = /^(?:go to|open|visit|browse to) ((?:https?:\/\/)?[a-z0-9-]+(?:\.[a-z0-9-]+)+(?:\/\S*)?)$/.exec(t);
  if (m) { const url = /^https?:\/\//.test(m[1]) ? m[1] : `https://${m[1]}`; return { kind: "open", target: url, say: `Opening ${m[1].replace(/^https?:\/\//, "")}.` }; }
  m = /^(?:open|launch|fire up) (?:the )?(?:app )?([a-z0-9 .&+-]{2,40}?)(?: app)?$/.exec(t);
  if (m) {
    const name = m[1].trim();
    if (/\b(and|then|with|in|to|on|for|my|the|that|this|file|folder|tab|page|project|projects|workers?|chats?)\b/.test(name)) return null;
    if (SITES[name]) return { kind: "open", target: SITES[name], say: `Opening ${titleCase(name)}.` };
    const app = APP_ALIASES[name] ?? titleCase(name);
    return { kind: "open", target: app, say: `Opening ${app}.` };
  }
  m = /^(?:quit|close|exit|kill) (?:the )?(?:app )?([a-z0-9 .&+-]{2,40}?)(?: app)?$/.exec(t);
  if (m && !/\b(tab|window|file|this|that|it|all)\b/.test(m[1])) { const app = APP_ALIASES[m[1].trim()] ?? titleCase(m[1].trim()); return { kind: "quit", target: app, say: `Quitting ${app}.` }; }
  m = /^(?:switch to|go to|focus) (?:the )?(?:app )?([a-z0-9 .&+-]{2,40}?)(?: app)?$/.exec(t);
  if (m && !/\b(tab|window|file|page|line|top|bottom|my|workers?|projects?|chats?)\b/.test(m[1])) { const app = APP_ALIASES[m[1].trim()] ?? titleCase(m[1].trim()); return { kind: "activate", target: app, say: `Switching to ${app}.` }; }
  return null;
}

/** Runs an instant command. Denied apps are never quit or switched to; opening one is fine (it is the person's own ask). */
export async function runInstant(hands: Hands, store: ComputerStore, cmd: Instant): Promise<{ ok: boolean; say: string }> {
  if (cmd.kind !== "open" && (isDenied(appRef(cmd.target)) || store.ruleFor(appRef(cmd.target)) === "never")) return { ok: false, say: `I can't control ${cmd.target}.` };
  const r = await hands.run("instant", [cmd.kind, cmd.target], undefined, 15_000);
  if (r.ok) return { ok: true, say: cmd.say.replace(/^Opening/, "Opened").replace(/^Quitting/, "Quit").replace(/^Switching to/, "Switched to") };
  return { ok: false, say: r.error ?? `I couldn't ${cmd.kind} ${cmd.target}.` };
}

// ---- learned replays -------------------------------------------------------------------------------------------------------

export interface Replay { phrase: string; steps: Step[]; uses: number; learned: string; last?: string }

/** The words of a request as a key: lower case, no punctuation, no politeness. */
export function phraseKey(text: string): string {
  return text.toLowerCase().replace(/[^\p{L}\p{N} ]+/gu, " ").replace(/\b(please|can you|could you|hey|okay|ok|for me|now|just)\b/g, " ").replace(/\s+/g, " ").trim();
}

/** Words that point at "this moment" (the screen now, what was just said): such a request is never replayed. */
const DEICTIC = /\b(this|that|these|those|it|here|there|selected|current|same|again|previous|last one)\b/;

export class ReplayStore {
  private readonly file: string;
  private items: Replay[] = [];
  constructor(dir: string) {
    ensurePrivateDir(dir);
    this.file = join(dir, "replays.json");
    const raw = readJson(this.file) as { items?: unknown } | undefined;
    if (raw && Array.isArray(raw.items)) this.items = (raw.items as Replay[]).filter((r) => typeof r?.phrase === "string" && Array.isArray(r.steps)).slice(0, 500);
  }
  private save(): void { writeJsonAtomic(this.file, { items: this.items }); }
  list(): Replay[] { return this.items.map((r) => ({ ...r, steps: r.steps.map((s) => ({ ...s, args: [...s.args] })) })); }
  find(text: string): Replay | undefined { const k = phraseKey(text); return k ? this.items.find((r) => r.phrase === k) : undefined; }

  /**
   * Keeps a task's steps if every one ran, was confirmed, and is plain: nothing risky, no secrets, no "this/that" request.
   * Returns whether it was kept.
   */
  learn(text: string, steps: { step: Step; ok: boolean }[]): boolean {
    const k = phraseKey(text);
    if (!k || k.split(" ").length > 20 || DEICTIC.test(k) || !steps.length || steps.length > 25) return false;
    if (!steps.every((s) => s.ok)) return false;
    for (const { step: s } of steps) {
      if (s.verb === "quit") return false;
      if (s.verb === "key" && riskyKey(s.args[0] ?? "")) return false;
      if ((s.verb === "press" || s.verb === "menu") && risky(s.args.join(" "))) return false;
      if (s.verb === "type" && sensitiveText(s.args[1] ?? "")) return false;
    }
    const now = new Date().toISOString();
    const old = this.items.findIndex((r) => r.phrase === k);
    const item: Replay = { phrase: k, steps: steps.map((s) => s.step), uses: old >= 0 ? this.items[old].uses : 0, learned: now };
    if (old >= 0) this.items[old] = item; else this.items.unshift(item);
    this.items = this.items.slice(0, 500);
    this.save();
    return true;
  }
  forget(phrase: string): boolean {
    const k = phraseKey(phrase);
    const n = this.items.length;
    this.items = this.items.filter((r) => r.phrase !== k);
    if (this.items.length !== n) { this.save(); return true; }
    return false;
  }
  used(phrase: string): void { const r = this.items.find((x) => x.phrase === phrase); if (r) { r.uses++; r.last = new Date().toISOString(); this.save(); } }
}

/**
 * Plays a learned task with no AI. Stops at the first step that fails or changes nothing (the app has changed since): the
 * caller then lets the AI do it, and the AI's new steps replace the old ones.
 */
export async function runReplay(hands: Hands, store: ComputerStore, r: Replay, onAct?: (s: string) => void): Promise<{ ok: boolean; done: number; error?: string }> {
  let done = 0;
  for (const s of r.steps) {
    if (s.app && (isDenied(appRef(s.app)) || store.ruleFor(appRef(s.app)) === "never")) return { ok: false, done, error: `${s.app} is not allowed now.` };
    let args: string[];
    switch (s.verb) {
      case "open": args = ["open", s.args[0] ?? ""]; break;
      case "activate": args = ["activate", s.args[0] ?? ""]; break;
      case "key": args = ["key", s.args[0] ?? "", ...(s.app ? [s.app] : [])]; break;
      case "menu": args = ["menu", s.args[0] ?? "", ...(s.app ? [s.app] : [])]; break;
      case "press": args = ["press-label", s.args[0] ?? "", s.args[1] ?? "", ...(s.app ? [s.app] : [])]; break;
      case "type": {
        // Find the field again by its name, then type.
        const look = await hands.run("replay", ["see", ...(s.app ? [s.app] : [])]);
        const m = look.ok ? new RegExp(`\\[(\\d+)\\] [a-z -]+ "${(s.args[0] ?? "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`).exec(look.map ?? "") : null;
        if (!m) return { ok: false, done, error: `The field "${s.args[0]}" is not there now.` };
        args = ["type", m[1], s.args[1] ?? ""];
        break;
      }
      default: return { ok: false, done, error: "unknown step" };
    }
    onAct?.(`${s.verb} ${s.args[0] ?? ""}`.trim());
    const res = await hands.run("replay", args, undefined, 15_000);
    if (!res.ok) return { ok: false, done, error: res.error };
    if (res.changed === false && s.verb !== "key") return { ok: false, done, error: "Nothing changed; the app may have changed since this was learned." };
    done++;
  }
  return { ok: true, done };
}

/** Where the helper keeps each chat's numbers (inside the state folder). */
export function handsDir(stateDir: string): string { const d = join(stateDir, "hands"); mkdirSync(d, { recursive: true }); return d; }
