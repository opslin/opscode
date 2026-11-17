// image_generate: one image tool for every engine (Claude Code, Codex, Antigravity, Qoder, the built-in agent).
//
// The rule (IMAGE_NOTE) tells each agent to call this tool for every image request. The tool runs
// `codex exec` (Codex's own image generator) on a signed-in Codex account:
//   1. the account new chats use goes first, then the other Codex accounts, least used first;
//   2. an account the free limits read shows as used up is skipped without running anything;
//   3. an account that fails with "out of credits" / a usage limit is set aside until its reset time, and the
//      next account is tried at once; a sign-in failure does the same (and says so);
//   4. when no account can make an image, the tool answers with the time the first one is back (countdown and
//      clock time) so the agent can tell the person, and `imagegen.status` has the same facts for the app.
// Other failures (the model refused the brief, Codex crashed) are returned as they are: another account would
// not change them.
//
// Images are saved inside the project (save_as, or .opscode/images/ which ignores itself). Codex runs in an
// empty temp folder with a read-only sandbox, so it never sees or changes the project.

import { spawnProgram } from "./proc";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, extname, isAbsolute, join, relative, resolve } from "node:path";
import type { Tool } from "./agent/tools";
import { isAuthError } from "./engines/accounts";
import type { EngineLimits } from "./engines/limits";
import { IMAGE_NOTE } from "./imageNote";

export { IMAGE_NOTE };

/** Plan-limit and credit failures from `codex exec` (including the team plan's "out of credits"). */
const LIMIT_MSG = /usage limit|hit your (?:usage )?limit|limit reached|limit has been reached|out of (?:extra )?(?:usage|credits)|credits? (?:are |is |have been )?(?:depleted|exhausted)|add credits|(?:5-hour|five[- ]hour|weekly|session) limit|usage_limit|rate[ _-]?limit(?:ed| reached| exceeded| error)|quota exceeded|insufficient[_ ]quota|spend(?:ing)? limit|too many requests/i;
export const isImageLimitError = (msg: string | undefined): boolean => !!msg && LIMIT_MSG.test(msg);

const IMAGE_EXT = new Set([".png", ".jpg", ".jpeg", ".webp"]);
const REF_EXT = new Set([".png", ".jpg", ".jpeg", ".webp", ".gif"]);
const MAX_PROMPT = 8000;
const MAX_REFS = 4;
const MAX_REF_BYTES = 20 * 1024 * 1024;
const RUN_TIMEOUT_MS = 6 * 60_000;
const UNKNOWN_WAIT_MS = 30 * 60_000;
const SIGN_IN_RETRY_MS = 10 * 60_000;
const MAX_PARALLEL = 2;

// ---- time words ----------------------------------------------------------------------------------------------

/** "2h 3m", "45m", "3d 4h", "under a minute". */
export function fmtWait(ms: number): string {
  if (ms < 60_000) return "under a minute";
  const mins = Math.ceil(ms / 60_000);
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  if (h < 24) return `${h}h${mins % 60 ? ` ${mins % 60}m` : ""}`;
  const d = Math.floor(h / 24);
  return `${d}d${h % 24 ? ` ${h % 24}h` : ""}`;
}

/** "7:12 PM", "tomorrow 7:12 PM", "Mon 23 Nov, 7:12 PM" (this computer's clock). */
export function fmtAt(at: number, now: number): string {
  const d = new Date(at);
  const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const day = (x: Date): string => `${x.getFullYear()}-${x.getMonth()}-${x.getDate()}`;
  const today = new Date(now);
  const tomorrow = new Date(now + 86_400_000);
  if (day(d) === day(today)) return time;
  if (day(d) === day(tomorrow)) return `tomorrow ${time}`;
  return `${d.toLocaleDateString("en-US", { weekday: "short", day: "numeric", month: "short" })}, ${time}`;
}

/** How long Codex says to wait ("try again in 2 hours 31 minutes", "try again at Nov 17th, 2026 9:10 AM"). */
export function retryAfterMs(msg: string, now = Date.now()): number | null {
  const rel = /(?:try again|retry|resets?|available again|come back)\s+in\s+(.{0,80})/i.exec(msg);
  if (rel) {
    let total = 0;
    for (const m of rel[1].matchAll(/(\d+(?:\.\d+)?)\s*(d(?:ays?)?|h(?:ours?|rs?)?|m(?:in(?:ute)?s?)?|s(?:ec(?:ond)?s?)?)\b/gi)) {
      const n = Number(m[1]);
      const u = m[2][0].toLowerCase();
      total += n * (u === "d" ? 86_400_000 : u === "h" ? 3_600_000 : u === "m" ? 60_000 : 1000);
    }
    if (total > 0) return Math.round(total);
  }
  const abs = /(?:try again|retry|resets?)\s+(?:at|on)\s+([^.\n]{3,60})/i.exec(msg);
  if (abs) {
    const t = Date.parse(abs[1].replace(/(\d)(?:st|nd|rd|th)\b/g, "$1").trim());
    if (Number.isFinite(t) && t > now) return t - now;
  }
  return null;
}

/** When an account is back, from a limits reading: the latest reset among the windows that are used up (null = not used up, or unknown). */
export function limitBlockUntil(l: EngineLimits | undefined, now: number): number | null {
  if (!l || l.state === "missing") return null;
  const hit = l.windows.filter((w) => w.used_percent >= 100 && w.resets_at && Date.parse(w.resets_at) > now);
  return hit.length ? Math.max(...hit.map((w) => Date.parse(w.resets_at!))) : null;
}

const usedOf = (l: EngineLimits | undefined): number => Math.max(0, ...(l?.windows ?? []).filter((w) => w.kind !== "monthly").map((w) => w.used_percent));

// ---- accounts and status ---------------------------------------------------------------------------------------

export interface ImageAccount {
  id: string;
  /** 1-based place in the list ("account 2"); the model and the person see this, never an email. */
  position: number;
  /** The account new chats use. */
  active: boolean;
  /** The environment `codex` runs with for this account (CODEX_HOME for extra accounts). */
  env: NodeJS.ProcessEnv;
}
export interface ImageGenDeps {
  codexPath(): string | null;
  accounts(): ImageAccount[];
  limitsFor(accountId: string): EngineLimits | undefined;
  refreshLimits(accountId: string, force: boolean): Promise<EngineLimits | undefined>;
  changed?(status: ImageGenStatus): void;
  log?(msg: string): void;
  now?(): number;
  /** Time limit for one run. */
  timeoutMs?: number;
}
export interface ImageAccountStatus {
  id: string;
  position: number;
  active: boolean;
  state: "ready" | "waiting" | "sign_in";
  /** ISO time it is back (waiting). */
  until?: string;
  wait_ms?: number;
  /** True when Codex gave no time and this is a guess. */
  estimated?: boolean;
  why?: string;
  used_percent?: number;
}
export interface ImageGenStatus {
  state: "ready" | "waiting" | "unavailable";
  /** ISO time the first account is back (waiting). */
  next_at?: string;
  wait_ms?: number;
  accounts: ImageAccountStatus[];
  /** One plain sentence for the person (and the model). */
  message: string;
}

interface Block { until: number; reason: "limit" | "sign_in"; why: string; estimated: boolean }

export interface ImageRequest {
  prompt: string;
  count: number;
  size: string;
  /** Absolute paths of reference images. */
  refs: string[];
  signal: AbortSignal;
}
export type ImageResult =
  | { ok: true; files: string[]; account: number; skipped: ImageAccountStatus[] }
  | { ok: false; message: string; status: ImageGenStatus };

type RunOutcome = { ok: true; files: string[] } | { ok: false; kind: "limit" | "auth" | "refused" | "error" | "aborted"; message: string };

export class ImageGen {
  private readonly blocks = new Map<string, Block>();
  private running = 0;
  private readonly queue: (() => void)[] = [];

  constructor(private readonly d: ImageGenDeps) {}

  private now = (): number => this.d.now?.() ?? Date.now();

  private blockOf(a: ImageAccount): Block | null {
    const now = this.now();
    const b = this.blocks.get(a.id);
    if (b && b.until > now) return b;
    if (b) this.blocks.delete(a.id);
    const until = limitBlockUntil(this.d.limitsFor(a.id), now);
    return until ? { until, reason: "limit", why: "out of usage", estimated: false } : null;
  }

  /** What is known right now (no checks run). */
  status(): ImageGenStatus {
    const now = this.now();
    const accts = this.d.accounts();
    const rows: ImageAccountStatus[] = accts.map((a) => {
      const b = this.blockOf(a);
      const used = usedOf(this.d.limitsFor(a.id));
      const base = { id: a.id, position: a.position, active: a.active, ...(used > 0 ? { used_percent: used } : {}) };
      if (!b) return { ...base, state: "ready" };
      if (b.reason === "sign_in") return { ...base, state: "sign_in", why: b.why };
      return { ...base, state: "waiting", until: new Date(b.until).toISOString(), wait_ms: b.until - now, why: b.why, ...(b.estimated ? { estimated: true } : {}) };
    });
    const waits = rows.filter((r) => r.state === "waiting").map((r) => Date.parse(r.until!));
    const state: ImageGenStatus["state"] = rows.some((r) => r.state === "ready") ? "ready" : waits.length ? "waiting" : "unavailable";
    const next = waits.length ? Math.min(...waits) : undefined;
    return { state, ...(next ? { next_at: new Date(next).toISOString(), wait_ms: next - now } : {}), accounts: rows, message: this.say(state, rows, next, now) };
  }

  /** The same, after reading every account's limits again (free). */
  async statusFresh(): Promise<ImageGenStatus> {
    await Promise.all(this.d.accounts().map((a) => this.d.refreshLimits(a.id, true).catch(() => undefined)));
    return this.status();
  }

  private say(state: ImageGenStatus["state"], rows: ImageAccountStatus[], next: number | undefined, now: number): string {
    if (rows.length === 0) return "No Codex account is set up. Sign in to Codex in Settings -> Models & keys to make images.";
    if (state === "ready") return "Image generation is ready.";
    const lines = rows.map((r) => `Account ${r.position}: ${r.state === "waiting" ? `out of usage, back in ${fmtWait(r.wait_ms ?? 0)} (${fmtAt(Date.parse(r.until!), now)})${r.estimated ? ", Codex gave no time so this is an estimate" : ""}` : "not signed in (Settings -> Models & keys)"}`);
    if (state === "unavailable") return `Image generation is unavailable: no Codex account is signed in. ${lines.join(". ")}.`;
    return `Image generation is paused: every Codex account is out of usage. The first one is back in ${fmtWait(next! - now)}, at ${fmtAt(next!, now)}. ${lines.join(". ")}.`;
  }

  private async slot<T>(fn: () => Promise<T>): Promise<T> {
    if (this.running >= MAX_PARALLEL) await new Promise<void>((r) => this.queue.push(r));
    this.running++;
    try { return await fn(); } finally { this.running--; this.queue.shift()?.(); }
  }

  async generate(req: ImageRequest): Promise<ImageResult> {
    const done = (r: ImageResult): ImageResult => { try { this.d.changed?.(this.status()); } catch { /* the event is a convenience */ } return r; };
    const bin = this.d.codexPath();
    const accts = this.d.accounts();
    if (!bin) return { ok: false, message: "Codex isn't installed on this computer, so images can't be made. Install Codex (or the ChatGPT app) and sign in under Settings -> Models & keys.", status: this.status() };
    if (!accts.length) return { ok: false, message: this.status().message, status: this.status() };
    // Fresh readings (free; each account is read at most once a minute), so a used-up account costs no run.
    await Promise.all(accts.map((a) => this.d.refreshLimits(a.id, false).catch(() => undefined)));
    const ready = accts.filter((a) => !this.blockOf(a)).sort((x, y) => (x.active === y.active ? usedOf(this.d.limitsFor(x.id)) - usedOf(this.d.limitsFor(y.id)) : x.active ? -1 : 1));
    const skippedAtStart = this.status().accounts.filter((r) => r.state !== "ready");
    const failed: ImageAccountStatus[] = [];
    for (const a of ready) {
      if (req.signal.aborted) return done({ ok: false, message: "Stopped.", status: this.status() });
      const r = await this.slot(() => this.run(bin, a, req));
      if (r.ok) return done({ ok: true, files: r.files, account: a.position, skipped: [...skippedAtStart, ...failed] });
      if (r.kind === "aborted") return done({ ok: false, message: "Stopped.", status: this.status() });
      if (r.kind === "limit") {
        const now = this.now();
        await this.d.refreshLimits(a.id, true).catch(() => undefined);
        const known = limitBlockUntil(this.d.limitsFor(a.id), now);
        const told = retryAfterMs(r.message, now);
        const until = known ?? (told ? now + told : now + UNKNOWN_WAIT_MS);
        this.blocks.set(a.id, { until, reason: "limit", why: r.message.slice(0, 160), estimated: !known && !told });
        this.d.log?.(`image: account ${a.position} is out of usage until ${new Date(until).toISOString()}`);
      } else if (r.kind === "auth") {
        this.blocks.set(a.id, { until: this.now() + SIGN_IN_RETRY_MS, reason: "sign_in", why: r.message.slice(0, 160), estimated: false });
        this.d.log?.(`image: account ${a.position} is not signed in`);
      } else {
        // The brief was refused or Codex failed: another account would not change that.
        return done({ ok: false, message: `Image generation failed on Codex account ${a.position}: ${r.message}`, status: this.status() });
      }
      failed.push(this.status().accounts.find((x) => x.id === a.id)!);
    }
    const status = this.status();
    return done({ ok: false, message: status.message, status });
  }

  private run(bin: string, a: ImageAccount, req: ImageRequest): Promise<RunOutcome> {
    const work = mkdtempSync(join(tmpdir(), "opscode-img-"));
    const home = a.env.CODEX_HOME || process.env.OPSCODE_CODEX_HOME || join(homedir(), ".codex");
    // The prompt goes in on stdin: `-i` takes several values and would swallow a prompt given as an argument.
    const args = ["exec", "-", "--json", "--skip-git-repo-check", "--ephemeral", "-s", "read-only", "-C", work];
    for (const r of req.refs) args.push("-i", r);
    return new Promise<RunOutcome>((resolveRun) => {
      let settled = false;
      let thread = "";
      let lastMsg = "";
      let errMsg = "";
      let completed = false;
      let stderr = "";
      let buf = "";
      const child = spawnProgram(bin, args, { cwd: work, env: a.env, stdio: ["pipe", "pipe", "pipe"] });
      const finish = (o: RunOutcome): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        req.signal.removeEventListener("abort", onAbort);
        if (child.exitCode === null) child.kill("SIGTERM");
        try { rmSync(work, { recursive: true, force: true }); } catch { /* temp folder */ }
        resolveRun(o);
      };
      const timer = setTimeout(() => finish({ ok: false, kind: "error", message: `Codex took longer than ${Math.round((this.d.timeoutMs ?? RUN_TIMEOUT_MS) / 60_000)} minutes and was stopped.` }), this.d.timeoutMs ?? RUN_TIMEOUT_MS);
      const onAbort = (): void => finish({ ok: false, kind: "aborted", message: "Stopped." });
      req.signal.addEventListener("abort", onAbort, { once: true });
      child.on("error", (e) => finish({ ok: false, kind: "error", message: `could not start Codex: ${e.message}` }));
      child.stdin.on("error", () => {});
      child.stdin.end(brief(req));
      child.stderr.on("data", (d: Buffer) => (stderr = (stderr + d.toString("utf8")).slice(-1500)));
      child.stdout.on("data", (d: Buffer) => {
        buf += d.toString("utf8");
        if (buf.length > 8_000_000 && buf.indexOf("\n") < 0) { buf = ""; return; }
        let i: number;
        while ((i = buf.indexOf("\n")) >= 0) {
          const line = buf.slice(0, i).trim();
          buf = buf.slice(i + 1);
          let m: Record<string, unknown>;
          try { m = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
          const item = (m.item ?? {}) as Record<string, unknown>;
          if (m.type === "thread.started" && typeof m.thread_id === "string") thread = m.thread_id;
          else if (m.type === "item.completed" && item.type === "agent_message" && typeof item.text === "string") lastMsg = item.text;
          else if (m.type === "error" && typeof m.message === "string") errMsg = m.message;
          else if (m.type === "turn.failed") errMsg = String((m.error as { message?: unknown } | undefined)?.message ?? errMsg);
          else if (m.type === "turn.completed") completed = true;
        }
      });
      child.on("close", (code) => {
        if (settled) return;
        if (completed && code === 0) {
          const dir = join(home, "generated_images", thread);
          let files: string[] = [];
          try { files = readdirSync(dir).filter((f) => IMAGE_EXT.has(extname(f).toLowerCase())).sort().map((f) => join(dir, f)); } catch { /* none */ }
          if (thread && files.length) return finish({ ok: true, files: files.slice(0, 8) });
          return finish({ ok: false, kind: "refused", message: `Codex finished without making an image${lastMsg ? `: ${lastMsg.slice(0, 300)}` : "."}` });
        }
        const msg = (errMsg || stderr.split("\n").filter((l) => l.trim() && !/rmcp::|WARN|^Reading additional input/.test(l)).slice(-2).join(" ") || `Codex stopped (code ${code}).`).trim();
        finish({ ok: false, kind: isImageLimitError(msg) ? "limit" : isAuthError(msg) ? "auth" : "error", message: msg.slice(0, 400) });
      });
    });
  }
}

function brief(req: ImageRequest): string {
  const head = [
    `Create ${req.count === 1 ? "one image" : `${req.count} separate images (one image-generation call each)`} with your built-in image generation tool, following the brief below exactly.`,
    "Do not write, copy, move or edit files and do not run commands. Put no text, caption or watermark in the image unless the brief asks for it.",
    req.refs.length ? `The attached image${req.refs.length > 1 ? "s are" : " is"} the reference for the brief.` : "",
    req.size ? `Format: ${req.size}.` : "",
    "When the image exists, reply with only the word: done",
  ].filter(Boolean);
  return `${head.join("\n")}\n\nBrief:\n${req.prompt}\n`;
}

// ---- where images go -------------------------------------------------------------------------------------------

const inside = (root: string, p: string): boolean => { const r = relative(root, p); return r !== "" && !r.startsWith("..") && !isAbsolute(r); };

/** The nearest existing folder's real path must stay inside the project (no symlink out). */
function realInside(root: string, p: string): boolean {
  let cur = p;
  while (!existsSync(cur)) { const up = dirname(cur); if (up === cur) return false; cur = up; }
  try { const r = realpathSync(cur); const rr = realpathSync(root); return r === rr || inside(rr, r); } catch { return false; }
}

const slugOf = (prompt: string): string => prompt.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().split(" ").slice(0, 4).join("-").slice(0, 32) || "image";
const stamp = (d: Date): string => `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}-${String(d.getHours()).padStart(2, "0")}${String(d.getMinutes()).padStart(2, "0")}${String(d.getSeconds()).padStart(2, "0")}`;
const numbered = (p: string, n: number, k: number): string => (n === 1 ? p : p.replace(/(\.[A-Za-z0-9]+)$/, `-${k + 1}$1`));

/** Where the images will be saved, checked before any quota is spent. Throws a sentence the model can act on. */
export function planTargets(root: string, saveAs: unknown, prompt: string, count: number, now = new Date()): { paths: (n: number) => string[]; isDefault: boolean } {
  let base: string;
  const isDefault = !(typeof saveAs === "string" && saveAs.trim());
  if (!isDefault) {
    const p = resolve(root, (saveAs as string).trim());
    if (!inside(root, p) || p.split(/[\\/]/).includes(".git")) throw new Error("save_as must be a path inside the project (for example assets/logo.png).");
    if (extname(p).toLowerCase() !== ".png") throw new Error("Codex makes PNG images: end save_as with .png.");
    if (!realInside(root, p)) throw new Error("save_as points outside the project through a link.");
    base = p;
  } else {
    base = join(root, ".opscode", "images", `${slugOf(prompt)}-${stamp(now)}.png`);
  }
  for (let k = 0; k < count; k++) { const t = numbered(base, count, k); if (existsSync(t)) throw new Error(`${relative(root, t)} already exists. Pick another save_as name; nothing was generated.`); }
  return { paths: (n) => Array.from({ length: n }, (_, k) => numbered(base, n, k)), isDefault };
}

function checkRefs(root: string, refs: unknown): string[] {
  if (refs === undefined) return [];
  if (!Array.isArray(refs) || refs.some((r) => typeof r !== "string")) throw new Error("references must be a list of image file paths inside the project.");
  if (refs.length > MAX_REFS) throw new Error(`At most ${MAX_REFS} reference images.`);
  return (refs as string[]).map((r) => {
    const p = resolve(root, r);
    if (!inside(root, p) || !realInside(root, p)) throw new Error(`Reference ${r} is not inside the project.`);
    if (!REF_EXT.has(extname(p).toLowerCase())) throw new Error(`Reference ${r} is not an image (png, jpg, webp or gif).`);
    let size = 0;
    try { const s = statSync(p); if (!s.isFile()) throw new Error("x"); size = s.size; } catch { throw new Error(`Reference ${r} was not found.`); }
    if (size > MAX_REF_BYTES) throw new Error(`Reference ${r} is over 20 MB.`);
    return p;
  });
}

const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
const mb = (n: number): string => (n >= 1_048_576 ? `${(n / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`);

/** The tool every engine gets. Kind "edit": it writes files in the project and spends plan usage, so it is hidden when read-only and asks when supervised. */
export function imageTool(gen: ImageGen): Tool {
  return {
    def: {
      name: "image_generate",
      description: "Make an image with Codex's image generator (any image request). Saves PNGs in the project, returns their paths.",
      schema: {
        type: "object",
        properties: {
          prompt: { type: "string", description: "Full brief: subject, style, hex colors, background, composition." },
          save_as: { type: "string", description: "Project-relative .png path, e.g. assets/logo.png (default .opscode/images/)." },
          count: { type: "integer", minimum: 1, maximum: 4 },
          size: { type: "string", description: "square, wide 16:9, portrait 9:16, transparent background..." },
          references: { type: "array", items: { type: "string" }, description: "Project images to edit or match (max 4)." },
        },
        required: ["prompt"],
      },
    },
    kind: "edit",
    describe: (i) => {
      const p = typeof i.prompt === "string" ? i.prompt.trim() : "";
      return { summary: `Generate image: ${clip(p.replace(/\s+/g, " "), 70) || "(no brief)"}`, detail: [clip(p, 1500), typeof i.save_as === "string" && i.save_as ? `Save as: ${i.save_as}` : "", typeof i.count === "number" && i.count > 1 ? `Count: ${i.count}` : ""].filter(Boolean).join("\n") };
    },
    async run(i, ctx) {
      const err = (output: string) => ({ output, is_error: true as const });
      const prompt = typeof i.prompt === "string" ? i.prompt.trim() : "";
      if (!prompt) return err("prompt is required: write the full brief for the image.");
      if (prompt.length > MAX_PROMPT) return err(`The brief is over ${MAX_PROMPT} characters: shorten it.`);
      const count = Math.max(1, Math.min(4, Math.floor(Number(i.count ?? 1)) || 1));
      let targets: ReturnType<typeof planTargets>;
      let refs: string[];
      try { targets = planTargets(ctx.root, i.save_as, prompt, count); refs = checkRefs(ctx.root, i.references); } catch (e) { return err(e instanceof Error ? e.message : String(e)); }
      const r = await gen.generate({ prompt, count, size: typeof i.size === "string" ? i.size.trim().slice(0, 80) : "", refs, signal: ctx.signal });
      if (!r.ok) return err(r.message);
      const dest = targets.paths(r.files.length);
      const saved: string[] = [];
      try {
        for (let k = 0; k < r.files.length; k++) {
          mkdirSync(dirname(dest[k]), { recursive: true });
          // The default folder ignores itself, so generated drafts never end up in a commit by accident.
          if (targets.isDefault) { try { const ig = join(dirname(dest[k]), ".gitignore"); if (!existsSync(ig)) writeFileSync(ig, "*\n"); } catch { /* the ignore file is a courtesy */ } }
          copyFileSync(r.files[k], dest[k]);
          saved.push(dest[k]);
        }
      } catch (e) { return err(`The image was made but could not be saved: ${e instanceof Error ? e.message : String(e)}. Codex's copy: ${r.files[0]}`); }
      const now = Date.now();
      const skipped = r.skipped.map((s) => (s.state === "waiting" ? `Account ${s.position} is out of usage until ${fmtAt(Date.parse(s.until!), now)} (in ${fmtWait(s.wait_ms ?? 0)}${s.estimated ? ", an estimate: Codex gave no time" : ""}).` : `Account ${s.position} is not signed in.`));
      const lines = [
        `Made ${saved.length} image${saved.length > 1 ? "s" : ""} with Codex (account ${r.account}).`,
        ...skipped,
        ...saved.map((p) => `${p} (${mb(statSync(p).size)})`),
        `Show ${saved.length > 1 ? "them" : "it"} in your reply as a link, for example [${relative(ctx.root, saved[0]).split("/").pop()}](${saved[0]}).${targets.isDefault ? " Saved under .opscode/images (not committed): copy it to where the project needs it." : ""}`,
      ];
      return { output: lines.join("\n"), is_error: false };
    },
  };
}
