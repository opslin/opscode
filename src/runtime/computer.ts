// Computer use: lets the agent look at the screen and drive other apps.
//
// Safety model (all enforced here, not in the UI):
//  - Off by default; the user turns it on in Settings.
//  - Hidden entirely in read-only chats.
//  - Every action names the app that is in front RIGHT NOW. Apps on the denylist
//    (terminals, password managers, system auth prompts, this app) are refused
//    and cannot be allowed. Apps with a "never" rule are refused.
//  - Unless the front app has an "always" rule, each action asks the user first,
//    in every permission mode (even Full access).
//  - After approval the front app is checked again; if it changed, nothing runs.
//
// The macOS driver uses only system tools (screencapture, sips, osascript/JXA),
// so there is nothing to install; it needs the Screen Recording and Accessibility
// permissions for the app that launched it.

import { execFile } from "node:child_process";
import { appendFileSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import type { Tool, ToolCtx } from "./agent/tools";

// ---- types ---------------------------------------------------------------------------

export interface AppRef {
  name: string;
  bundle_id: string;
}
export type AppRule = "always" | "never";
export interface ComputerRule {
  id: string; // bundle id when known, else the lower-cased name
  name: string;
  bundle_id: string;
  rule: AppRule;
}
export interface Permissions {
  accessibility: boolean | null; // null = cannot tell
  screen_recording: boolean | null;
}
export interface Shot {
  jpeg: Buffer;
  width: number; // pixels of the image the model sees
  height: number;
}

/** Everything the agent can do to the computer. One implementation per platform. */
export interface Driver {
  readonly kind: "macos" | "mock";
  permissions(): Promise<Permissions>;
  frontApp(): Promise<AppRef>;
  runningApps(): Promise<AppRef[]>;
  screenshot(signal: AbortSignal): Promise<Shot>;
  /** Points → used with the last screenshot's scale by the caller. */
  click(x: number, y: number, o: { button: "left" | "right"; count: 1 | 2 }, signal: AbortSignal): Promise<void>;
  drag(x1: number, y1: number, x2: number, y2: number, signal: AbortSignal): Promise<void>;
  scroll(x: number, y: number, dx: number, dy: number, signal: AbortSignal): Promise<void>;
  type(text: string, signal: AbortSignal): Promise<void>;
  key(combo: string, signal: AbortSignal): Promise<void>;
  openApp(name: string, signal: AbortSignal): Promise<void>;
  /** Screen size in points (what click coordinates are measured in). */
  screenSize(): Promise<{ w: number; h: number }>;
}

// ---- denylist ------------------------------------------------------------------------

const DENY_NAMES = new Set([
  "terminal", "iterm", "iterm2", "warp", "ghostty", "alacritty", "kitty", "hyper", "wezterm",
  "1password", "1password 7", "bitwarden", "lastpass", "dashlane", "keepassxc", "keychain access", "passwords",
  "system settings", "system preferences", "securityagent", "loginwindow", "coreservicesuiagent",
  "opscode", "electron", "claude", "claude code",
]);
const DENY_BUNDLES = [
  "com.apple.terminal", "com.googlecode.iterm2", "dev.warp.", "com.mitchellh.ghostty", "io.alacritty", "net.kovidgoyal.kitty",
  "com.1password.", "com.agilebits.", "com.bitwarden.", "com.lastpass.", "com.dashlane.", "org.keepassxc.",
  "com.apple.keychainaccess", "com.apple.passwords", "com.apple.systempreferences", "com.apple.securityagent", "com.apple.loginwindow",
  "com.anthropic.", "com.opscode.", "com.github.electron",
];
export const DENIED_APP_NAMES = ["Terminals (Terminal, iTerm, Warp, Ghostty…)", "Password managers (1Password, Bitwarden, Keychain, Passwords…)", "System Settings and macOS sign-in prompts", "Opscode itself and Claude apps"];

export function isDenied(app: AppRef): boolean {
  const n = app.name.trim().toLowerCase();
  const b = app.bundle_id.trim().toLowerCase();
  return DENY_NAMES.has(n) || (b !== "" && DENY_BUNDLES.some((p) => b === p || (p.endsWith(".") && b.startsWith(p))));
}

const ruleId = (a: AppRef): string => (a.bundle_id || a.name).trim().toLowerCase();

// ---- store: on/off switch + per-app rules ------------------------------------------

export class ComputerStore {
  private readonly file: string;
  private data: { enabled: boolean; rules: ComputerRule[] } = { enabled: false, rules: [] };

  constructor(dir: string) {
    ensurePrivateDir(dir);
    this.file = join(dir, "computer.json");
    const raw = readJson(this.file) as { enabled?: unknown; rules?: unknown } | undefined;
    if (raw && typeof raw === "object") {
      this.data.enabled = raw.enabled === true;
      if (Array.isArray(raw.rules)) {
        for (const r of raw.rules.slice(0, 200)) {
          const x = r as Partial<ComputerRule>;
          if (typeof x?.id === "string" && typeof x.name === "string" && (x.rule === "always" || x.rule === "never")) this.data.rules.push({ id: x.id.slice(0, 200), name: x.name.slice(0, 120), bundle_id: typeof x.bundle_id === "string" ? x.bundle_id.slice(0, 200) : "", rule: x.rule });
        }
      }
    }
  }
  private save(): void {
    writeJsonAtomic(this.file, this.data);
  }
  enabled(): boolean {
    return this.data.enabled;
  }
  setEnabled(on: boolean): void {
    this.data.enabled = on;
    this.save();
  }
  rules(): ComputerRule[] {
    return this.data.rules.map((r) => ({ ...r }));
  }
  ruleFor(app: AppRef): AppRule | undefined {
    const id = ruleId(app);
    const nm = app.name.trim().toLowerCase();
    return this.data.rules.find((r) => r.id === id || r.id === nm)?.rule;
  }
  setRule(app: AppRef, rule: AppRule): void {
    if (isDenied(app)) throw new Error(`${app.name} can never be controlled, so it cannot be allowed`);
    if (!app.name.trim() || app.name.length > 120) throw new Error("app name must be 1-120 characters");
    const id = ruleId(app);
    const cur = this.data.rules.find((r) => r.id === id);
    if (cur) cur.rule = rule;
    else {
      if (this.data.rules.length >= 200) throw new Error("too many app rules (200)");
      this.data.rules.push({ id, name: app.name.trim(), bundle_id: app.bundle_id.trim(), rule });
    }
    this.save();
  }
  removeRule(id: string): boolean {
    const n = this.data.rules.length;
    this.data.rules = this.data.rules.filter((r) => r.id !== id);
    if (this.data.rules.length === n) return false;
    this.save();
    return true;
  }
}

// ---- macOS driver --------------------------------------------------------------------

const KEYCODES: Record<string, number> = {
  return: 36, enter: 36, tab: 48, space: 49, delete: 51, backspace: 51, escape: 53, esc: 53, forwarddelete: 117,
  left: 123, right: 124, down: 125, up: 126, home: 115, end: 119, pageup: 116, pagedown: 121,
};
const MODS: Record<string, string> = { cmd: "command down", command: "command down", ctrl: "control down", control: "control down", alt: "option down", option: "option down", opt: "option down", shift: "shift down" };

/** "cmd+shift+t" → {mods, key} or throws. Only letters, digits, a few symbols and named keys. */
export function parseCombo(raw: string): { mods: string[]; named?: number; char?: string } {
  const parts = raw.trim().toLowerCase().split("+").map((s) => s.trim());
  if (parts.length === 0 || parts.length > 5 || parts.some((p) => p === "")) throw new Error(`bad key combination "${raw}"`);
  const last = parts[parts.length - 1] as string;
  const mods: string[] = [];
  for (const p of parts.slice(0, -1)) {
    const m = MODS[p];
    if (!m) throw new Error(`unknown modifier "${p}" (use cmd, ctrl, alt, shift)`);
    if (!mods.includes(m)) mods.push(m);
  }
  if (last in KEYCODES) return { mods, named: KEYCODES[last] as number };
  if (/^[a-z0-9\-=,./;'`[\]\\]$/.test(last)) return { mods, char: last };
  throw new Error(`unknown key "${last}"`);
}

const SAFE_ENV = (): Record<string, string> => {
  const env: Record<string, string> = {};
  for (const k of ["PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR"]) if (process.env[k] !== undefined) env[k] = process.env[k] as string;
  return env;
};

function run(cmd: string, args: string[], signal: AbortSignal, timeout = 15_000): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = execFile(cmd, args, { env: SAFE_ENV(), timeout, maxBuffer: 4 * 1024 * 1024, signal }, (err, stdout, stderr) => {
      if (err) reject(new Error(((stderr || String(err.message)) as string).trim().slice(0, 300) || `${cmd} failed`));
      else resolve(String(stdout).trim());
    });
    child.stdin?.end();
  });
}

const jxa = (script: string, signal: AbortSignal): Promise<string> => run("/usr/bin/osascript", ["-l", "JavaScript", "-e", script], signal);
const NEVER = new AbortController().signal;
const lit = (v: unknown): string => JSON.stringify(v);

export class MacDriver implements Driver {
  readonly kind = "macos" as const;
  private shotScale = 1;

  async permissions(): Promise<Permissions> {
    try {
      // Screen Recording cannot be checked without prompting (JXA does not expose the preflight call),
      // so it is reported as unknown; a missing grant shows up on the first screenshot.
      const out = await jxa("ObjC.import('ApplicationServices');JSON.stringify({a:!!$.AXIsProcessTrusted()})", NEVER);
      return { accessibility: (JSON.parse(out) as { a: boolean }).a, screen_recording: null };
    } catch {
      return { accessibility: null, screen_recording: null };
    }
  }
  async frontApp(): Promise<AppRef> {
    const out = await jxa("ObjC.import('AppKit');const a=$.NSWorkspace.sharedWorkspace.frontmostApplication;JSON.stringify({name:String(ObjC.unwrap(a.localizedName)||''),bundle_id:String(ObjC.unwrap(a.bundleIdentifier)||'')})", NEVER);
    const j = JSON.parse(out) as AppRef;
    return { name: j.name, bundle_id: j.bundle_id };
  }
  async runningApps(): Promise<AppRef[]> {
    const out = await jxa("ObjC.import('AppKit');const L=ObjC.unwrap($.NSWorkspace.sharedWorkspace.runningApplications);JSON.stringify(L.filter(a=>Number(ObjC.unwrap(a.activationPolicy))===0).map(a=>({name:String(ObjC.unwrap(a.localizedName)||''),bundle_id:String(ObjC.unwrap(a.bundleIdentifier)||'')})))", NEVER);
    return (JSON.parse(out) as AppRef[]).filter((a) => a.name);
  }
  async screenSize(): Promise<{ w: number; h: number }> {
    const out = await jxa("ObjC.import('AppKit');const f=$.NSScreen.mainScreen.frame;JSON.stringify({w:f.size.width,h:f.size.height})", NEVER);
    return JSON.parse(out) as { w: number; h: number };
  }
  async screenshot(signal: AbortSignal): Promise<Shot> {
    const dir = mkdtempSync(join(tmpdir(), "opscode-shot-"));
    try {
      const raw = join(dir, "raw.png");
      const out = join(dir, "shot.jpg");
      await run("/usr/sbin/screencapture", ["-x", "-m", "-t", "png", raw], signal, 20_000);
      await run("/usr/bin/sips", ["-Z", "1280", "-s", "format", "jpeg", "-s", "formatOptions", "60", raw, "--out", out], signal, 20_000);
      const info = await run("/usr/bin/sips", ["-g", "pixelWidth", "-g", "pixelHeight", out], signal);
      const w = Number(/pixelWidth:\s*(\d+)/.exec(info)?.[1]);
      const h = Number(/pixelHeight:\s*(\d+)/.exec(info)?.[1]);
      if (!w || !h) throw new Error("could not read the screenshot size");
      const pts = await this.screenSize();
      this.shotScale = pts.w / w;
      return { jpeg: readFileSync(out), width: w, height: h };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
  /** Model coordinates (screenshot pixels) → screen points. */
  private pt(v: number): number {
    return Math.round(v * this.shotScale);
  }
  async click(x: number, y: number, o: { button: "left" | "right"; count: 1 | 2 }, signal: AbortSignal): Promise<void> {
    const [dn, up, btn] = o.button === "left" ? ["kCGEventLeftMouseDown", "kCGEventLeftMouseUp", "kCGMouseButtonLeft"] : ["kCGEventRightMouseDown", "kCGEventRightMouseUp", "kCGMouseButtonRight"];
    await jxa(
      `ObjC.import('CoreGraphics');const P=$.CGPointMake(${this.pt(x)},${this.pt(y)});
const post=(t,n)=>{const e=$.CGEventCreateMouseEvent($(),t,P,$.${btn});$.CGEventSetIntegerValueField(e,$.kCGMouseEventClickState,n);$.CGEventPost($.kCGHIDEventTap,e)};
post($.kCGEventMouseMoved,0);delay(0.05);
for(let i=1;i<=${o.count};i++){post($.${dn},i);delay(0.03);post($.${up},i);delay(0.05)}`,
      signal,
    );
  }
  async drag(x1: number, y1: number, x2: number, y2: number, signal: AbortSignal): Promise<void> {
    await jxa(
      `ObjC.import('CoreGraphics');
const ev=(t,x,y)=>{const e=$.CGEventCreateMouseEvent($(),t,$.CGPointMake(x,y),$.kCGMouseButtonLeft);$.CGEventPost($.kCGHIDEventTap,e)};
const x1=${this.pt(x1)},y1=${this.pt(y1)},x2=${this.pt(x2)},y2=${this.pt(y2)};
ev($.kCGEventMouseMoved,x1,y1);delay(0.05);ev($.kCGEventLeftMouseDown,x1,y1);delay(0.05);
for(let i=1;i<=10;i++){ev($.kCGEventLeftMouseDragged,x1+(x2-x1)*i/10,y1+(y2-y1)*i/10);delay(0.02)}
ev($.kCGEventLeftMouseUp,x2,y2)`,
      signal,
    );
  }
  async scroll(x: number, y: number, dx: number, dy: number, signal: AbortSignal): Promise<void> {
    await jxa(
      `ObjC.import('CoreGraphics');
const m=$.CGEventCreateMouseEvent($(),$.kCGEventMouseMoved,$.CGPointMake(${this.pt(x)},${this.pt(y)}),$.kCGMouseButtonLeft);$.CGEventPost($.kCGHIDEventTap,m);delay(0.05);
const e=$.CGEventCreateScrollWheelEvent2($(),$.kCGScrollEventUnitLine,2,${-Math.round(dy)},${-Math.round(dx)},0);$.CGEventPost($.kCGHIDEventTap,e)`,
      signal,
    );
  }
  async type(text: string, signal: AbortSignal): Promise<void> {
    for (let i = 0; i < text.length; i += 200) {
      await jxa(`Application('System Events').keystroke(${lit(text.slice(i, i + 200))})`, signal);
    }
  }
  async key(combo: string, signal: AbortSignal): Promise<void> {
    const k = parseCombo(combo);
    const using = k.mods.length ? `,{using:${lit(k.mods)}}` : "";
    const call = k.named !== undefined ? `keyCode(${k.named}${using})` : `keystroke(${lit(k.char)}${using})`;
    await jxa(`Application('System Events').${call}`, signal);
  }
  async openApp(name: string, signal: AbortSignal): Promise<void> {
    await run("/usr/bin/open", ["-a", name], signal);
  }
}

// ---- mock driver (tests only; chosen by OPSCODE_COMPUTER_DRIVER=mock) -------------------

// A 4x4 JPEG would do; a tiny valid PNG is enough for the model-side plumbing.
const MOCK_IMAGE = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGP8z8Dwn4GBgYGJAQoAHhgCAh6X4CYAAAAASUVORK5CYII=", "base64");

export class MockDriver implements Driver {
  readonly kind = "mock" as const;
  constructor(private readonly logFile: string, private readonly frontFile: string) {}
  private log(o: Record<string, unknown>): void {
    appendFileSync(this.logFile, `${JSON.stringify(o)}\n`);
  }
  async permissions(): Promise<Permissions> {
    return { accessibility: true, screen_recording: true };
  }
  async frontApp(): Promise<AppRef> {
    try {
      const [name = "Notes", bundle_id = ""] = readFileSync(this.frontFile, "utf8").trim().split("|");
      return { name, bundle_id };
    } catch {
      return { name: "Notes", bundle_id: "com.apple.Notes" };
    }
  }
  async runningApps(): Promise<AppRef[]> {
    return [{ name: "Notes", bundle_id: "com.apple.Notes" }, { name: "Safari", bundle_id: "com.apple.Safari" }, { name: "Terminal", bundle_id: "com.apple.Terminal" }];
  }
  async screenSize(): Promise<{ w: number; h: number }> {
    return { w: 1280, h: 800 };
  }
  async screenshot(): Promise<Shot> {
    this.log({ a: "screenshot" });
    return { jpeg: MOCK_IMAGE, width: 1280, height: 800 };
  }
  async click(x: number, y: number, o: { button: string; count: number }): Promise<void> {
    this.log({ a: "click", x, y, ...o });
  }
  async drag(x1: number, y1: number, x2: number, y2: number): Promise<void> {
    this.log({ a: "drag", x1, y1, x2, y2 });
  }
  async scroll(x: number, y: number, dx: number, dy: number): Promise<void> {
    this.log({ a: "scroll", x, y, dx, dy });
  }
  async type(text: string): Promise<void> {
    this.log({ a: "type", text });
  }
  async key(combo: string): Promise<void> {
    parseCombo(combo);
    this.log({ a: "key", combo });
  }
  async openApp(name: string): Promise<void> {
    this.log({ a: "open", name });
  }
}

export function makeDriver(env: NodeJS.ProcessEnv = process.env): Driver | undefined {
  if (env.OPSCODE_COMPUTER_DRIVER === "mock" && env.OPSCODE_COMPUTER_MOCK_LOG && env.OPSCODE_COMPUTER_MOCK_FRONT) {
    return new MockDriver(env.OPSCODE_COMPUTER_MOCK_LOG, env.OPSCODE_COMPUTER_MOCK_FRONT);
  }
  return process.platform === "darwin" ? new MacDriver() : undefined;
}

// ---- agent tools ---------------------------------------------------------------------

const APP_NAME = /^[\p{L}\p{N} .&+()_-]{1,64}$/u;
const num = (v: unknown, name: string): number => {
  if (typeof v !== "number" || !Number.isFinite(v)) throw new Error(`${name} must be a number`);
  return v;
};
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);

export function computerTools(driver: Driver, store: ComputerStore): Tool[] {
  // The size of the last screenshot, so clicks can be bounds-checked. Per turn.
  let shot: { w: number; h: number } | undefined;
  const need = (): { w: number; h: number } => {
    if (!shot) throw new Error("Take a screenshot first, so coordinates match what you see.");
    return shot;
  };
  const inBounds = (x: number, y: number): void => {
    const s = need();
    if (x < 0 || y < 0 || x >= s.w || y >= s.h) throw new Error(`(${Math.round(x)}, ${Math.round(y)}) is outside the ${s.w}x${s.h} screenshot`);
  };

  /** Decide for the app in front right now. */
  const gateFront = async (what: string): Promise<{ rule: "auto" | "ask" | "deny"; summary: string; reason?: string; app?: string }> => {
    let front: AppRef;
    try {
      front = await driver.frontApp();
    } catch (e) {
      return { rule: "deny", summary: what, reason: `Could not tell which app is in front: ${e instanceof Error ? e.message : String(e)}` };
    }
    const label = front.name || "an unknown app";
    const summary = `${what} — in ${label}`;
    if (!front.name) return { rule: "deny", summary, reason: "Could not tell which app is in front." };
    if (isDenied(front)) return { rule: "deny", summary, app: front.bundle_id || front.name, reason: `${front.name} is never controlled (terminals, password managers, system prompts and this app are off limits). Ask the user to switch to another app.` };
    const rule = store.ruleFor(front);
    if (rule === "never") return { rule: "deny", summary, app: front.bundle_id || front.name, reason: `The user has blocked ${front.name}.` };
    return { rule: rule === "always" ? "auto" : "ask", summary, app: front.bundle_id || front.name };
  };
  /** Re-check just before acting: the user may have taken a while to approve. */
  const stillFront = async (ctx: ToolCtx): Promise<void> => {
    const want = ctx.approvedApp;
    if (want === undefined) throw new Error("internal: action ran without a gate");
    const g = await gateFront("");
    if (g.rule === "deny") throw new Error(g.reason ?? "Not allowed.");
    if (g.app !== want) throw new Error("The app in front changed after you asked. Take a new screenshot and try again.");
  };

  const mk = (
    name: string,
    description: string,
    properties: Record<string, unknown>,
    required: string[],
    what: (i: Record<string, unknown>) => { text: string; detail?: string },
    act: (i: Record<string, unknown>, signal: AbortSignal) => Promise<{ output: string; image?: Shot }>,
  ): Tool => ({
    def: { name, description, schema: { type: "object", properties, required } },
    kind: "computer",
    describe: (i) => {
      const w = what(i);
      return { summary: w.text, ...(w.detail ? { detail: w.detail } : {}) };
    },
    async gate(i) {
      const w = what(i);
      const g = await gateFront(w.text);
      return { ...g, ...(w.detail ? { detail: w.detail } : {}) };
    },
    async run(i, ctx) {
      await stillFront(ctx);
      const r = await act(i, ctx.signal);
      return { output: r.output, is_error: false, ...(r.image ? { image: { media_type: "image/jpeg", data: r.image.jpeg.toString("base64") } } : {}) };
    },
  });

  const xy = { x: { type: "number", description: "X in screenshot pixels" }, y: { type: "number", description: "Y in screenshot pixels" } };

  return [
    mk("computer_screenshot", "Take a screenshot of the main display. Coordinates for every other computer_* tool are pixels in this image. Take one before acting and after each action to check what happened.", {}, [], () => ({ text: "Take a screenshot" }), async (_i, signal) => {
      const s = await driver.screenshot(signal);
      shot = { w: s.width, h: s.height };
      return { output: `Screenshot ${s.width}x${s.height}. Coordinates are pixels in this image, origin at top-left.`, image: s };
    }),
    mk("computer_click", "Click at a point in the last screenshot. Set double for a double-click, or button \"right\" for a context menu.", { ...xy, button: { type: "string", enum: ["left", "right"] }, double: { type: "boolean" } }, ["x", "y"],
      (i) => ({ text: `${i.double === true ? "Double-click" : i.button === "right" ? "Right-click" : "Click"} (${Math.round(Number(i.x))}, ${Math.round(Number(i.y))})` }),
      async (i, signal) => {
        const x = num(i.x, "x");
        const y = num(i.y, "y");
        inBounds(x, y);
        await driver.click(x, y, { button: i.button === "right" ? "right" : "left", count: i.double === true ? 2 : 1 }, signal);
        return { output: `Clicked (${Math.round(x)}, ${Math.round(y)}). Take a screenshot to see the result.` };
      }),
    mk("computer_drag", "Press at one point, drag to another, and release.", { from_x: { type: "number" }, from_y: { type: "number" }, to_x: { type: "number" }, to_y: { type: "number" } }, ["from_x", "from_y", "to_x", "to_y"],
      (i) => ({ text: `Drag (${Math.round(Number(i.from_x))}, ${Math.round(Number(i.from_y))}) → (${Math.round(Number(i.to_x))}, ${Math.round(Number(i.to_y))})` }),
      async (i, signal) => {
        const [a, b, c, d] = [num(i.from_x, "from_x"), num(i.from_y, "from_y"), num(i.to_x, "to_x"), num(i.to_y, "to_y")];
        inBounds(a, b);
        inBounds(c, d);
        await driver.drag(a, b, c, d, signal);
        return { output: "Dragged. Take a screenshot to see the result." };
      }),
    mk("computer_scroll", "Scroll at a point. dy > 0 scrolls down, dy < 0 up; dx > 0 scrolls right. Units are lines (about 3 per mouse-wheel notch).", { ...xy, dy: { type: "number" }, dx: { type: "number" } }, ["x", "y"],
      (i) => ({ text: `Scroll ${Math.round(Number(i.dy ?? 0))} lines at (${Math.round(Number(i.x))}, ${Math.round(Number(i.y))})` }),
      async (i, signal) => {
        const x = num(i.x, "x");
        const y = num(i.y, "y");
        inBounds(x, y);
        const dy = Math.max(-50, Math.min(50, num(i.dy ?? 0, "dy")));
        const dx = Math.max(-50, Math.min(50, num(i.dx ?? 0, "dx")));
        await driver.scroll(x, y, dx, dy, signal);
        return { output: "Scrolled. Take a screenshot to see the result." };
      }),
    mk("computer_type", "Type text into the focused field (up to 2000 characters). Click the field first. Never type passwords or secrets.", { text: { type: "string" } }, ["text"],
      (i) => ({ text: `Type “${clip(String(i.text ?? "").replace(/\n/g, "↵"), 60)}”`, detail: clip(String(i.text ?? ""), 2000) }),
      async (i, signal) => {
        if (typeof i.text !== "string" || i.text.length === 0) throw new Error("text must be a non-empty string");
        if (i.text.length > 2000) throw new Error("text is longer than 2000 characters");
        await driver.type(i.text, signal);
        return { output: `Typed ${i.text.length} characters.` };
      }),
    mk("computer_key", "Press a key or shortcut, e.g. \"return\", \"tab\", \"escape\", \"cmd+c\", \"cmd+shift+t\". Modifiers: cmd, ctrl, alt, shift.", { keys: { type: "string" } }, ["keys"],
      (i) => ({ text: `Press ${clip(String(i.keys ?? ""), 40)}` }),
      async (i, signal) => {
        if (typeof i.keys !== "string") throw new Error("keys must be a string");
        await driver.key(i.keys, signal);
        return { output: `Pressed ${i.keys}.` };
      }),
    {
      def: { name: "computer_list_apps", description: "List the apps that are running, and which one is in front.", schema: { type: "object", properties: {}, required: [] } },
      kind: "computer",
      describe: () => ({ summary: "List running apps" }),
      async gate() {
        return { rule: "auto", summary: "List running apps" };
      },
      async run() {
        const [apps, front] = await Promise.all([driver.runningApps(), driver.frontApp()]);
        const lines = apps.filter((a) => !isDenied(a)).map((a) => `${a.name}${a.name === front.name ? " (in front)" : ""}`);
        return { output: `${lines.join("\n") || "(none)"}\n\nIn front: ${isDenied(front) ? "an app that is off limits" : front.name}`, is_error: false };
      },
    },
    {
      def: { name: "computer_open_app", description: "Open or switch to an app by name (e.g. \"Notes\"). Then take a screenshot.", schema: { type: "object", properties: { name: { type: "string" } }, required: ["name"] } },
      kind: "computer",
      describe: (i) => ({ summary: `Open ${clip(String(i.name ?? ""), 60)}` }),
      async gate(i) {
        const name = String(i.name ?? "").trim();
        const app = { name, bundle_id: "" };
        const summary = `Open ${clip(name, 60)}`;
        if (!APP_NAME.test(name) || name.startsWith("-")) return { rule: "deny", summary, reason: "That is not a valid app name." };
        if (isDenied(app)) return { rule: "deny", summary, reason: `${name} is never controlled.` };
        const r = store.ruleFor(app);
        if (r === "never") return { rule: "deny", summary, reason: `The user has blocked ${name}.` };
        return { rule: r === "always" ? "auto" : "ask", summary, app: name.toLowerCase() };
      },
      async run(i, ctx) {
        const name = String(i.name ?? "").trim();
        if (!APP_NAME.test(name) || name.startsWith("-") || isDenied({ name, bundle_id: "" })) throw new Error("That app cannot be opened.");
        await driver.openApp(name, ctx.signal);
        return { output: `Opened ${name}. Take a screenshot to see it.`, is_error: false };
      },
    },
  ];
}
