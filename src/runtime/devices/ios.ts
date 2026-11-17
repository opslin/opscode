// iOS Simulator control. Lifecycle, screenshots, apps, URLs, appearance and
// logs go through `xcrun simctl`; touches, keys and hardware buttons go through
// Opscode's own helper (native/opscode-sim), which sends HID events straight to
// the simulated device, so nothing depends on the Simulator.app window.
// Coordinates are device points from the top-left; screenshots are scaled to
// points so a picture's pixels are tap points.

import { execFile, spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import type { PermissionMode } from "../../shared/protocol";
import { policy, type GateResult, type Tool, type ToolResult } from "../agent/tools";

export interface SimDevice { udid: string; name: string; state: string; runtime: string; }
interface Screen { width: number; height: number }

const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}\n… (cut)` : s);
const UDID = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i;
const BUNDLE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$/;

/** HID keyboard usages (US layout): [usage, needs shift]. */
const USAGE: Record<string, [number, boolean]> = (() => {
  const m: Record<string, [number, boolean]> = {};
  for (let i = 0; i < 26; i++) { m[String.fromCharCode(97 + i)] = [4 + i, false]; m[String.fromCharCode(65 + i)] = [4 + i, true]; }
  "1234567890".split("").forEach((c, i) => (m[c] = [30 + i, false]));
  "!@#$%^&*()".split("").forEach((c, i) => (m[c] = [30 + i, true]));
  const pairs: [string, string, number][] = [["-", "_", 45], ["=", "+", 46], ["[", "{", 47], ["]", "}", 48], ["\\", "|", 49], [";", ":", 51], ["'", "\"", 52], ["`", "~", 53], [",", "<", 54], [".", ">", 55], ["/", "?", 56]];
  for (const [a, b, u] of pairs) { m[a] = [u, false]; m[b] = [u, true]; }
  m[" "] = [44, false]; m["\n"] = [40, false]; m["\t"] = [43, false];
  return m;
})();
const SHIFT = 225, CMD = 227;
const KEYS: Record<string, number[]> = {
  return: [40], delete: [42], forward_delete: [76], tab: [43], escape: [41], space: [44],
  left: [80], right: [79], up: [82], down: [81], home: [74], end: [77], page_up: [75], page_down: [78],
  select_all: [CMD, 4], undo: [CMD, 29], redo: [CMD, SHIFT, 29], copy: [CMD, 6], paste: [CMD, 25], cut: [CMD, 27],
};

export function simctlHelp(): string {
  return "No iOS simulator is available. Install a simulator runtime in Xcode (Settings → Components) or with `xcodebuild -downloadPlatform iOS`, then create a device in Xcode → Window → Devices and Simulators.";
}

/** One opscode-sim process per booted device (JSON lines). */
class Helper {
  private proc: ChildProcess;
  private buf = "";
  private seq = 0;
  private readonly waiting = new Map<number, (m: Record<string, unknown>) => void>();
  readonly ready: Promise<Screen>;
  dead = false;

  constructor(bin: string, udid: string, log: (s: string) => void) {
    this.proc = spawn(bin, ["serve", "--udid", udid], { stdio: ["pipe", "pipe", "pipe"] });
    let readyFn!: (s: Screen) => void;
    let failFn!: (e: Error) => void;
    this.ready = new Promise<Screen>((res, rej) => { readyFn = res; failFn = rej; });
    this.ready.catch(() => {});
    const timer = setTimeout(() => failFn(new Error("the simulator input helper did not start")), 15_000);
    this.proc.stdout!.on("data", (d: Buffer) => {
      this.buf += d.toString("utf8");
      let i: number;
      while ((i = this.buf.indexOf("\n")) >= 0) {
        const line = this.buf.slice(0, i);
        this.buf = this.buf.slice(i + 1);
        let m: Record<string, unknown>;
        try { m = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
        if (m.id === 0) {
          clearTimeout(timer);
          if (m.ok) readyFn({ width: Number(m.width), height: Number(m.height) });
          else failFn(new Error(String(m.error ?? "the simulator input helper failed")));
          continue;
        }
        this.waiting.get(Number(m.id))?.(m);
        this.waiting.delete(Number(m.id));
      }
    });
    this.proc.stderr!.on("data", (d: Buffer) => log(`opscode-sim: ${d.toString("utf8").trim().slice(0, 300)}`));
    this.proc.stdin!.on("error", () => {});
    this.proc.on("error", (e) => { clearTimeout(timer); failFn(e); });
    this.proc.on("exit", () => {
      this.dead = true;
      clearTimeout(timer);
      failFn(new Error("the simulator input helper stopped"));
      for (const w of this.waiting.values()) w({ ok: false, error: "the simulator input helper stopped" });
      this.waiting.clear();
    });
  }

  async send(cmd: Record<string, unknown>): Promise<void> {
    await this.ready;
    const id = ++this.seq;
    const r = await new Promise<Record<string, unknown>>((res) => {
      const t = setTimeout(() => { this.waiting.delete(id); res({ ok: false, error: "the simulator did not answer" }); }, 10_000);
      this.waiting.set(id, (m) => { clearTimeout(t); res(m); });
      this.proc.stdin!.write(`${JSON.stringify({ id, ...cmd })}\n`);
    });
    if (!r.ok) throw new Error(String(r.error ?? "input failed"));
  }

  close(): void {
    if (!this.dead) this.proc.kill();
  }
}

export class IosSimulators {
  private readonly helpers = new Map<string, Helper>();
  /** udid -> label of what the agent last did (for the panel's "Opscode is using it" badge). */
  onActivity?: (udid: string, label: string) => void;

  constructor(
    private readonly xcrun: string,
    private readonly helperBin: string | undefined,
    private readonly log: (s: string) => void,
  ) {}

  static create(log: (s: string) => void): IosSimulators | undefined {
    if (process.env.OPSCODE_XCRUN === "none") return undefined;
    const xcrun = process.env.OPSCODE_XCRUN || (process.platform === "darwin" && existsSync("/usr/bin/xcrun") ? "/usr/bin/xcrun" : "");
    if (!xcrun) return undefined;
    const built = join(dirname(dirname(__dirname)), "native", "opscode-sim"); // dist/runtime/devices -> dist/native
    const helper = process.env.OPSCODE_SIM_HELPER || (existsSync(built) ? built : undefined);
    return new IosSimulators(xcrun, helper, log);
  }

  run(args: string[], opts: { timeoutMs?: number; input?: string; maxBuffer?: number } = {}): Promise<string> {
    return new Promise((resolve, reject) => {
      const child = execFile(this.xcrun, ["simctl", ...args], { timeout: opts.timeoutMs ?? 30_000, maxBuffer: opts.maxBuffer ?? 16 * 1024 * 1024, encoding: "utf8" }, (err, stdout, stderr) => {
        if (err) reject(new Error(`simctl ${args[0]}: ${(stderr || err.message).trim().split("\n").slice(-3).join(" ").slice(0, 600)}`));
        else resolve(stdout);
      });
      if (opts.input !== undefined) { child.stdin?.end(opts.input); }
    });
  }

  private known: { at: number; any: boolean } | undefined;
  private checking = false;
  /** Whether any simulator exists (cached; refreshed in the background), so agents are not offered a tool
   *  that cannot do anything (it costs prompt tokens on every turn). */
  hasDevices(): boolean {
    if ((!this.known || Date.now() - this.known.at > 60_000) && !this.checking) {
      this.checking = true;
      void this.list().then((l) => (this.known = { at: Date.now(), any: l.length > 0 }), () => (this.known = { at: Date.now(), any: false })).finally(() => (this.checking = false));
    }
    return this.known?.any ?? false;
  }

  async list(): Promise<SimDevice[]> {
    const j = JSON.parse(await this.run(["list", "devices", "available", "-j"])) as { devices?: Record<string, { udid: string; name: string; state: string; isAvailable?: boolean }[]> };
    const out: SimDevice[] = [];
    for (const [rt, devs] of Object.entries(j.devices ?? {})) {
      const runtime = rt.replace(/^com\.apple\.CoreSimulator\.SimRuntime\./, "").replace(/-(\d+)-(\d+)$/, " $1.$2").replace(/-(\d+)$/, " $1");
      for (const d of devs) if (d.isAvailable !== false && UDID.test(d.udid)) out.push({ udid: d.udid, name: d.name, state: d.state, runtime });
    }
    this.known = { at: Date.now(), any: out.length > 0 };
    return out.sort((a, b) => Number(b.state === "Booted") - Number(a.state === "Booted") || a.runtime.localeCompare(b.runtime) || a.name.localeCompare(b.name));
  }

  /** A device by UDID or name; with none given, the booted one (the only booted one, or the first). */
  async resolve(device: unknown, mustBeBooted = true): Promise<SimDevice> {
    const all = await this.list();
    if (!all.length) throw new Error(simctlHelp());
    let d: SimDevice | undefined;
    if (typeof device === "string" && device.trim()) {
      const want = device.trim();
      d = all.find((x) => x.udid.toLowerCase() === want.toLowerCase()) ?? all.find((x) => x.name.toLowerCase() === want.toLowerCase() && x.state === "Booted") ?? all.find((x) => x.name.toLowerCase() === want.toLowerCase());
      if (!d) throw new Error(`No simulator named ${JSON.stringify(want)}. Use action "list" to see them.`);
    } else {
      d = all.find((x) => x.state === "Booted");
      if (!d) throw new Error(`No simulator is booted. Boot one with action "boot" (device = a name or UDID from "list"), e.g. ${JSON.stringify(all.find((x) => /iPhone/.test(x.name))?.name ?? all[0].name)}.`);
    }
    if (mustBeBooted && d.state !== "Booted") throw new Error(`${d.name} is not booted (it is ${d.state}). Boot it with action "boot".`);
    return d;
  }

  private helper(udid: string): Helper {
    if (!this.helperBin) throw new Error("Touch and key input need Opscode's simulator helper (opscode-sim), which is not built in this copy of Opscode.");
    let h = this.helpers.get(udid);
    if (!h || h.dead) {
      h = new Helper(this.helperBin, udid, this.log);
      this.helpers.set(udid, h);
    }
    return h;
  }

  /** Screen size in points (from the helper; falls back to the screenshot at 3x/2x). */
  async screen(udid: string): Promise<Screen | undefined> {
    if (!this.helperBin) return undefined;
    try { return await this.helper(udid).ready; } catch { return undefined; }
  }

  async boot(d: SimDevice): Promise<string> {
    if (d.state !== "Booted") {
      await this.run(["boot", d.udid], { timeoutMs: 120_000 }).catch((e: Error) => { if (!/current state: Booted/i.test(e.message)) throw e; });
    }
    await this.run(["bootstatus", d.udid, "-b"], { timeoutMs: 240_000 });
    return `${d.name} (${d.runtime}) is booted.`;
  }

  async shutdown(d: SimDevice): Promise<string> {
    this.helpers.get(d.udid)?.close();
    this.helpers.delete(d.udid);
    if (d.state === "Booted") await this.run(["shutdown", d.udid], { timeoutMs: 60_000 });
    return `${d.name} is shut down.`;
  }

  /** PNG from simctl, scaled to device points and re-encoded as JPEG (cheap for the model). */
  async screenshot(d: SimDevice, jpeg = true): Promise<{ data: string; media_type: string; width: number; height: number }> {
    const dir = mkdtempSync(join(tmpdir(), "opscode-sim-"));
    try {
      const png = join(dir, "s.png");
      await this.run(["io", d.udid, "screenshot", "--type=png", png], { timeoutMs: 20_000 });
      const px = pngSize(readFileSync(png));
      const pts = (await this.screen(d.udid)) ?? (px ? { width: Math.round(px.width / (px.width > 1000 ? 3 : 2)), height: Math.round(px.height / (px.width > 1000 ? 3 : 2)) } : undefined);
      if (!jpeg || !pts || !px) {
        const b = readFileSync(png);
        return { data: b.toString("base64"), media_type: "image/png", width: px?.width ?? 0, height: px?.height ?? 0 };
      }
      const out = join(dir, "s.jpg");
      await new Promise<void>((res, rej) => execFile("/usr/bin/sips", ["-z", String(pts.height), String(pts.width), "-s", "format", "jpeg", "-s", "formatOptions", "70", png, "--out", out], { timeout: 20_000 }, (e) => (e ? rej(new Error(`could not scale the screenshot: ${e.message}`)) : res())));
      return { data: readFileSync(out).toString("base64"), media_type: "image/jpeg", width: pts.width, height: pts.height };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }

  // ---- input --------------------------------------------------------------------------------
  private async touch(udid: string, phase: "down" | "move" | "up", x: number, y: number, two?: { x2: number; y2: number }): Promise<void> {
    await this.helper(udid).send({ cmd: "touch", phase, x, y, ...(two ?? {}) });
  }

  async tap(udid: string, x: number, y: number, holdS = 0): Promise<void> {
    await this.touch(udid, "down", x, y);
    await pause(Math.min(Math.max(holdS, 0.05), 10) * 1000);
    await this.touch(udid, "up", x, y);
  }

  async path(udid: string, pts: { x: number; y: number; dt_ms?: number }[]): Promise<void> {
    if (pts.length < 2) throw new Error("a path needs at least two points");
    await this.touch(udid, "down", pts[0].x, pts[0].y);
    try {
      for (const p of pts.slice(1, -1)) { await pause(Math.min(Math.max(p.dt_ms ?? 16, 0), 1000)); await this.touch(udid, "move", p.x, p.y); }
      const last = pts[pts.length - 1];
      await pause(Math.min(Math.max(last.dt_ms ?? 16, 0), 1000));
      await this.touch(udid, "move", last.x, last.y);
    } finally {
      const last = pts[pts.length - 1];
      await this.touch(udid, "up", last.x, last.y);
    }
  }

  async path2(udid: string, pts: { x1: number; y1: number; x2: number; y2: number; dt_ms?: number }[]): Promise<void> {
    if (pts.length < 2) throw new Error("a two-finger path needs at least two samples");
    const at = (p: (typeof pts)[number], phase: "down" | "move" | "up") => this.touch(udid, phase, p.x1, p.y1, { x2: p.x2, y2: p.y2 });
    await at(pts[0], "down");
    try {
      for (const p of pts.slice(1)) { await pause(Math.min(Math.max(p.dt_ms ?? 16, 0), 1000)); await at(p, "move"); }
    } finally {
      await at(pts[pts.length - 1], "up");
    }
  }

  async swipe(udid: string, x: number, y: number, x2: number, y2: number, durationS = 0.3): Promise<void> {
    const steps = Math.max(2, Math.round((Math.min(Math.max(durationS, 0.05), 5) * 1000) / 16));
    const pts = Array.from({ length: steps + 1 }, (_, i) => ({ x: x + ((x2 - x) * i) / steps, y: y + ((y2 - y) * i) / steps, dt_ms: i ? 16 : 0 }));
    await this.path(udid, pts);
  }

  async keys(udid: string, usages: number[]): Promise<void> {
    const h = this.helper(udid);
    for (const u of usages) await h.send({ cmd: "key", usage: u, phase: "down" });
    for (const u of [...usages].reverse()) await h.send({ cmd: "key", usage: u, phase: "up" });
  }

  /** Types text with key presses; anything a US keyboard cannot type goes in by pasting. */
  async text(udid: string, text: string): Promise<string> {
    if ([...text].every((c) => USAGE[c])) {
      for (const c of text) {
        const [u, shift] = USAGE[c];
        await this.keys(udid, shift ? [SHIFT, u] : [u]);
      }
      return `Typed ${JSON.stringify(clip(text, 60))}.`;
    }
    await this.run(["pbcopy", udid], { input: text });
    await this.keys(udid, [CMD, 25]);
    return `Pasted ${JSON.stringify(clip(text, 60))} (it has characters a US keyboard cannot type).`;
  }

  async button(udid: string, name: string, holdS = 0): Promise<void> {
    const h = this.helper(udid);
    if (name === "applepay") { // a double press of the side button
      for (let i = 0; i < 2; i++) { await h.send({ cmd: "button", name: "side", phase: "down" }); await pause(60); await h.send({ cmd: "button", name: "side", phase: "up" }); await pause(120); }
      return;
    }
    await h.send({ cmd: "button", name, phase: "down" });
    await pause(Math.min(Math.max(holdS, 0.08), 10) * 1000);
    await h.send({ cmd: "button", name, phase: "up" });
  }

  closeAll(): void {
    for (const h of this.helpers.values()) h.close();
    this.helpers.clear();
  }
}

/** Width/height of a PNG from its IHDR, or undefined. */
export function pngSize(b: Buffer): { width: number; height: number } | undefined {
  if (b.length < 24 || b.readUInt32BE(12) !== 0x49484452) return undefined;
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

// ---- the tool ------------------------------------------------------------------------------

const READ_ACTIONS = new Set(["list", "screenshot", "appearance", "list_apps", "logs"]);
const ACTIONS = ["list", "boot", "shutdown", "screenshot", "tap", "swipe", "touch_path", "touch2_path", "text", "press_key", "button", "launch", "terminate", "open_url", "set_appearance", "appearance", "list_apps", "logs", "set_location"] as const;

const num = (v: unknown, name: string): number => {
  if (typeof v !== "number" || !Number.isFinite(v)) throw new Error(`${name} must be a number`);
  return v;
};

export function iosTool(sims: IosSimulators, scope: { mode(): PermissionMode }): Tool {
  const shot = async (d: SimDevice, lead: string): Promise<ToolResult> => {
    const s = await sims.screenshot(d);
    return { output: `${lead}${lead ? " " : ""}Screenshot of ${d.name}, ${s.width}x${s.height} points: its pixels are tap points.`, is_error: false, image: { media_type: s.media_type, data: s.data } };
  };
  return {
    def: {
      name: "ios_simulator",
      description: [
        "Drive an iOS Simulator on this Mac (no window needed; the user can watch it in Opscode's side panel). device: a name or UDID from list; default = the booted one.",
        "list | boot | shutdown | screenshot (a picture scaled to device points) | tap x,y (duration>0.5 long-press) | swipe x,y → x2,y2 (duration) |",
        "touch_path points [{x,y,dt_ms}] (one finger: drags, long-press-then-drag) | touch2_path points2 [{x1,y1,x2,y2,dt_ms}] (pinch/rotate) |",
        "text | press_key key (return, delete, forward_delete, tab, escape, left/right/up/down, home, end, page_up, page_down, select_all, undo, redo, copy, paste, cut; count) |",
        "button name (home, lock, side, siri, applepay) | launch bundle_id or app_path (a built .app: installs, then launches) | terminate bundle_id | open_url url |",
        "set_appearance state light/dark | appearance | list_apps | logs (seconds, process or bundle_id) | set_location latitude,longitude.",
        "Coordinates are device points from the top-left of the last screenshot. Set screenshot_after to get a picture after an action.",
      ].join(" "),
      schema: {
        type: "object",
        properties: {
          action: { type: "string", enum: [...ACTIONS] },
          device: { type: "string" },
          x: { type: "number" }, y: { type: "number" }, x2: { type: "number" }, y2: { type: "number" }, duration: { type: "number" },
          points: { type: "array", items: { type: "object", properties: { x: { type: "number" }, y: { type: "number" }, dt_ms: { type: "number" } }, required: ["x", "y"] } },
          points2: { type: "array", items: { type: "object", properties: { x1: { type: "number" }, y1: { type: "number" }, x2: { type: "number" }, y2: { type: "number" }, dt_ms: { type: "number" } }, required: ["x1", "y1", "x2", "y2"] } },
          text: { type: "string" }, key: { type: "string" }, count: { type: "number" }, name: { type: "string", enum: ["home", "lock", "side", "siri", "applepay"] },
          bundle_id: { type: "string" }, app_path: { type: "string" }, url: { type: "string" }, state: { type: "string", enum: ["light", "dark"] },
          seconds: { type: "number" }, process: { type: "string" }, latitude: { type: "number" }, longitude: { type: "number" },
          screenshot_after: { type: "boolean" },
        },
        required: ["action"],
        additionalProperties: false,
      },
    },
    kind: "read",
    describe: (i) => {
      const a = String(i.action ?? "");
      const at = typeof i.x === "number" ? ` at ${i.x},${i.y}` : "";
      const extra = a === "text" ? ` "${String(i.text ?? "").slice(0, 40)}"` : a === "press_key" ? ` ${String(i.key ?? "")}` : a === "button" ? ` ${String(i.name ?? "")}` : a === "launch" || a === "terminate" ? ` ${String(i.bundle_id ?? i.app_path ?? "")}` : a === "open_url" ? ` ${String(i.url ?? "")}` : "";
      return { summary: `iOS Simulator: ${a.replace(/_/g, " ")}${at}${extra}`.slice(0, 120) };
    },
    // Looking is free in every mode; touching and changing the device follow the mode like browser actions.
    gate: async (i): Promise<GateResult> => {
      const a = String(i.action ?? "");
      const summary = `iOS Simulator: ${a.replace(/_/g, " ")}`;
      if (READ_ACTIONS.has(a)) return { rule: "auto", summary };
      const rule = policy(scope.mode(), "browser");
      return rule === "hide" ? { rule: "deny", summary, reason: "This chat is read-only: it can look at the simulator (list, screenshot, logs) but not use it." } : { rule, summary };
    },
    run: async (i) => {
      const a = String(i.action ?? "");
      if (!(ACTIONS as readonly string[]).includes(a)) return { output: `Unknown action "${a}". Use one of: ${ACTIONS.join(", ")}.`, is_error: true };
      if (a === "list") {
        const all = await sims.list();
        if (!all.length) return { output: simctlHelp(), is_error: false };
        return { output: all.map((d) => `${d.state === "Booted" ? "* " : "  "}${d.name} (${d.runtime}) ${d.udid} ${d.state}`).join("\n"), is_error: false };
      }
      const d = await sims.resolve(i.device, a !== "boot" && a !== "shutdown");
      sims.onActivity?.(d.udid, a.replace(/_/g, " "));
      let done = "";
      switch (a) {
        case "boot": return { output: await sims.boot(d), is_error: false };
        case "shutdown": return { output: await sims.shutdown(d), is_error: false };
        case "screenshot": return shot(d, "");
        case "tap": await sims.tap(d.udid, num(i.x, "x"), num(i.y, "y"), typeof i.duration === "number" ? i.duration : 0); done = `Tapped ${i.x},${i.y}${typeof i.duration === "number" && i.duration > 0.5 ? " (long press)" : ""}.`; break;
        case "swipe": await sims.swipe(d.udid, num(i.x, "x"), num(i.y, "y"), num(i.x2, "x2"), num(i.y2, "y2"), typeof i.duration === "number" ? i.duration : 0.3); done = `Swiped ${i.x},${i.y} → ${i.x2},${i.y2}.`; break;
        case "touch_path": {
          const pts = Array.isArray(i.points) ? (i.points as Record<string, unknown>[]).slice(0, 600).map((p, n) => ({ x: num(p.x, `points[${n}].x`), y: num(p.y, `points[${n}].y`), dt_ms: typeof p.dt_ms === "number" ? p.dt_ms : 16 })) : [];
          await sims.path(d.udid, pts);
          done = `Dragged along ${pts.length} points.`;
          break;
        }
        case "touch2_path": {
          const pts = Array.isArray(i.points2) ? (i.points2 as Record<string, unknown>[]).slice(0, 600).map((p, n) => ({ x1: num(p.x1, `points2[${n}].x1`), y1: num(p.y1, "y1"), x2: num(p.x2, "x2"), y2: num(p.y2, "y2"), dt_ms: typeof p.dt_ms === "number" ? p.dt_ms : 16 })) : [];
          await sims.path2(d.udid, pts);
          done = `Two-finger gesture over ${pts.length} samples.`;
          break;
        }
        case "text": {
          const t = String(i.text ?? "");
          if (!t) return { output: "text is empty.", is_error: true };
          done = await sims.text(d.udid, t.slice(0, 4000));
          break;
        }
        case "press_key": {
          const k = String(i.key ?? "").toLowerCase();
          const codes = KEYS[k];
          if (!codes) return { output: `Unknown key "${k}". Use one of: ${Object.keys(KEYS).join(", ")}.`, is_error: true };
          const n = Math.min(Math.max(Math.round(Number(i.count) || 1), 1), 20);
          for (let c = 0; c < n; c++) await sims.keys(d.udid, codes);
          done = `Pressed ${k}${n > 1 ? ` ${n} times` : ""}.`;
          break;
        }
        case "button": {
          const b = String(i.name ?? "");
          if (!["home", "lock", "side", "siri", "applepay"].includes(b)) return { output: "name must be home, lock, side, siri or applepay.", is_error: true };
          await sims.button(d.udid, b, typeof i.duration === "number" ? i.duration : 0);
          done = `Pressed ${b}.`;
          break;
        }
        case "launch": {
          let bundle = typeof i.bundle_id === "string" ? i.bundle_id : "";
          if (typeof i.app_path === "string" && i.app_path) {
            const app = i.app_path;
            if (!app.startsWith("/") || !app.endsWith(".app") || !existsSync(join(app, "Info.plist"))) return { output: "app_path must be the absolute path of a built .app (with its Info.plist), for example from xcodebuild's Debug-iphonesimulator folder.", is_error: true };
            bundle = await new Promise<string>((res, rej) => execFile("/usr/bin/plutil", ["-extract", "CFBundleIdentifier", "raw", join(app, "Info.plist")], { encoding: "utf8" }, (e, out) => (e ? rej(new Error("could not read the app's bundle id")) : res(out.trim()))));
            await sims.run(["install", d.udid, app], { timeoutMs: 180_000 });
          }
          if (!BUNDLE.test(bundle)) return { output: "launch needs bundle_id (or app_path).", is_error: true };
          const out = await sims.run(["launch", "--terminate-running-process", d.udid, bundle], { timeoutMs: 60_000 });
          done = `Launched ${bundle}${typeof i.app_path === "string" ? " (installed it first)" : ""}${/:\s*(\d+)/.test(out) ? ` (pid ${/:\s*(\d+)/.exec(out)![1]})` : ""}.`;
          break;
        }
        case "terminate": {
          const b = String(i.bundle_id ?? "");
          if (!BUNDLE.test(b)) return { output: "terminate needs bundle_id.", is_error: true };
          await sims.run(["terminate", d.udid, b]);
          done = `Stopped ${b}.`;
          break;
        }
        case "open_url": {
          const u = String(i.url ?? "");
          if (!/^[a-z][a-z0-9+.-]*:/i.test(u) || u.length > 4000 || /^(file|javascript):/i.test(u)) return { output: "url must be a link or deep link such as https://… or myapp://path.", is_error: true };
          await sims.run(["openurl", d.udid, u]);
          done = `Opened ${u}.`;
          break;
        }
        case "set_appearance": {
          const s = i.state === "dark" ? "dark" : i.state === "light" ? "light" : "";
          if (!s) return { output: "state must be light or dark.", is_error: true };
          await sims.run(["ui", d.udid, "appearance", s]);
          done = `${d.name} is now in ${s} mode.`;
          break;
        }
        case "appearance": return { output: `${d.name} is in ${(await sims.run(["ui", d.udid, "appearance"])).trim()} mode.`, is_error: false };
        case "list_apps": {
          const plist = await sims.run(["listapps", d.udid], { maxBuffer: 64 * 1024 * 1024 });
          const ids = [...plist.matchAll(/CFBundleIdentifier = "?([A-Za-z0-9._-]+)"?;/g)].map((m) => m[1]);
          const user = [...new Set(ids)].filter((x) => !x.startsWith("com.apple."));
          return { output: `${user.length ? `Installed apps: ${user.join(", ")}` : "No apps besides Apple's."}\n(${[...new Set(ids)].length - user.length} Apple apps not listed)`, is_error: false };
        }
        case "logs": {
          const secs = Math.min(Math.max(Math.round(Number(i.seconds) || 60), 5), 900);
          const who = typeof i.process === "string" && /^[\w .-]{1,80}$/.test(i.process) ? `process == "${i.process}"` : typeof i.bundle_id === "string" && BUNDLE.test(i.bundle_id) ? `subsystem BEGINSWITH "${i.bundle_id}" OR process == "${i.bundle_id.split(".").pop()}"` : "";
          const out = await sims.run(["spawn", d.udid, "log", "show", "--style", "compact", "--last", `${secs}s`, ...(who ? ["--predicate", who] : [])], { timeoutMs: 60_000, maxBuffer: 64 * 1024 * 1024 });
          const lines = out.split("\n").filter((l) => l.trim() && !/^Timestamp|^Filtering/.test(l));
          return { output: lines.length ? clip(lines.slice(-300).join("\n"), 16_000) : `No log lines in the last ${secs}s${who ? ` for ${who}` : ""}.`, is_error: false };
        }
        case "set_location": {
          const lat = num(i.latitude, "latitude"), lon = num(i.longitude, "longitude");
          if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return { output: "latitude/longitude out of range.", is_error: true };
          await sims.run(["location", d.udid, "set", `${lat},${lon}`]);
          done = `Location set to ${lat},${lon}.`;
          break;
        }
      }
      if (i.screenshot_after === true) { await pause(400); return shot(d, done); }
      return { output: done, is_error: false };
    },
  };
}
