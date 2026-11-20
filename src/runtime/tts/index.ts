import { tarProgram } from "../voice/models";
import { fork, spawn, type ChildProcess } from "node:child_process";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { createWriteStream, mkdirSync, renameSync, rmSync, statSync } from "node:fs";
import http from "node:http";
import https from "node:https";
import { join } from "node:path";
import type { RpcNotification } from "../../shared/protocol";
import { downloadModels } from "../voice/download";
import { LOCAL_VOICE_ERROR, localVoiceAvailable } from "../voice/localRuntime";
import { KITTEN_FILES, KITTEN_LANGUAGES, KITTEN_VOICES } from "./kitten";
import { speakableSentences } from "./speakable";

const FOLDER = "kitten-tts-2-mini";
const FIXTURE_FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const MODEL_BYTES = KITTEN_FILES.reduce((sum, file) => sum + file.bytes, 0);
const LICENSE_NOTE = "Kitten TTS 2 Mini by KittenML, Apache-2.0.";
// The fixture worker still tests migration from existing Pocket TTS settings.
const FIXTURE_VOICES = [{ id: "bria", name: "Bria", language: "en" }, { id: "loona", name: "Loona", language: "en" }];
export const VOICES = KITTEN_VOICES;

const LOOKAHEAD = 3; // sentences generated ahead of the one being played
const hostOk = (h: string): boolean => h === "github.com" || h.endsWith(".githubusercontent.com");

export interface TtsStatus {
  engine: "Kitten TTS 2 Mini";
  available: boolean;
  error?: string;
  install_error: string;
  languages: string[];
  installed: boolean;
  installing: { phase: string; progress: number; bytes: number; total: number } | null;
  download_bytes: number;
  disk_bytes: number;
  voices: typeof VOICES;
  loaded: boolean;
  license: string;
}

interface Session { id: string; sentences: string[]; voice: string; language: string; hint?: string; steps: number; next: number; played: number; inflight: boolean; stopped: boolean; done: boolean; /** More sentences may still be added (a reply that is being written). */ live?: boolean }

export class TtsService {
  private readonly root: string;
  private readonly spec: { url: string; bytes: number; sha256: string; files: Record<string, number>; test: boolean };
  private worker: ChildProcess | null = null;
  private ready: Promise<void> | null = null;
  private workerReady = false;
  private installError = "";
  private idle: NodeJS.Timeout | undefined;
  private session: Session | null = null;
  private installing: TtsStatus["installing"] = null;

  constructor(stateDir: string, private readonly broadcast: (n: RpcNotification) => void, private readonly log: (line: string) => void) {
    this.root = join(stateDir, "tts");
    const url = process.env.OPSCODE_TTS_URL;
    this.spec = url
      ? { url, bytes: 0, sha256: process.env.OPSCODE_TTS_SHA256 ?? "", files: Object.fromEntries((process.env.OPSCODE_TTS_FILES ?? "").split(",").filter(Boolean).map((f) => [f, -1])), test: true }
      : { url: "", bytes: MODEL_BYTES, sha256: "", files: Object.fromEntries(KITTEN_FILES.map((file) => [file.name, file.bytes])), test: false };
  }

  private get dir(): string { return join(this.root, this.spec.test ? FIXTURE_FOLDER : FOLDER); }

  private installed(): boolean {
    try {
      for (const [f, size] of Object.entries(this.spec.files)) {
        const s = statSync(join(this.dir, f));
        if (!s.isFile() || (size >= 0 && s.size !== size)) return false;
      }
      return Object.keys(this.spec.files).length > 0;
    } catch { return false; }
  }

  status(): TtsStatus {
    const available = this.spec.test || localVoiceAvailable();
    return { engine: "Kitten TTS 2 Mini", available, ...(available ? {} : { error: LOCAL_VOICE_ERROR }),
      installed: this.installed(), installing: this.installing, install_error: this.installError,
      download_bytes: this.spec.bytes, disk_bytes: this.spec.bytes, voices: VOICES, languages: KITTEN_LANGUAGES,
      loaded: this.workerReady, license: LICENSE_NOTE };
  }

  private emit(params: Record<string, unknown>): void {
    this.broadcast({ method: "tts.event", params });
  }

  // ---- install -------------------------------------------------------------------------------------------------------

  /** Downloads and unpacks the voice. Only called when the person said yes; progress arrives as tts.event install. */
  install(): { started: boolean } {
    if (this.installing || this.installed()) return { started: false };
    if (!this.spec.test && !localVoiceAvailable()) throw new Error(LOCAL_VOICE_ERROR);
    this.installError = "";
    this.installing = { phase: "download", progress: 0, bytes: 0, total: this.spec.bytes };
    void this.runInstall().catch((e) => {
      this.log(`tts: install failed: ${e instanceof Error ? e.message : String(e)}`);
      this.installing = null;
      this.installError = e instanceof Error ? e.message : String(e);
      this.emit({ ev: "install", phase: "error", message: this.installError });
    });
    return { started: true };
  }

  private async runInstall(): Promise<void> {
    if (!this.spec.test) {
      let last = 0;
      await downloadModels(this.dir, KITTEN_FILES, (bytes) => {
        if (Date.now() - last < 250) return;
        last = Date.now();
        const progress = bytes / MODEL_BYTES;
        this.installing = { phase: "download", progress, bytes, total: MODEL_BYTES };
        this.emit({ ev: "install", ...this.installing });
      });
      this.installing = null;
      this.emit({ ev: "install", phase: "done", progress: 1 });
      return;
    }
    mkdirSync(this.root, { recursive: true, mode: 0o700 });
    const tmp = join(this.root, "download.tmp");
    const work = join(this.root, `.extract-${randomBytes(4).toString("hex")}`);
    const set = (phase: string, progress: number, bytes = 0): void => {
      this.installing = { phase, progress, bytes, total: this.spec.bytes };
      this.emit({ ev: "install", phase, progress, bytes, total: this.spec.bytes });
    };
    try {
      rmSync(tmp, { force: true });
      let last = 0;
      const got = await this.download(this.spec.url, tmp, (bytes, total) => {
        const now = Date.now();
        if (now - last < 250) return;
        last = now;
        set("download", total ? bytes / total : 0, bytes);
      });
      set("verify", 1, got.bytes);
      if (!this.spec.test && got.bytes !== this.spec.bytes) throw new Error(`the download is ${got.bytes} bytes, expected ${this.spec.bytes}`);
      if (this.spec.sha256 && got.sha256 !== this.spec.sha256) throw new Error("the download does not match its checksum, so it was thrown away");
      set("extract", 1, got.bytes);
      mkdirSync(work, { recursive: true, mode: 0o700 });
      await this.untar(tmp, work);
      const unpacked = join(work, FIXTURE_FOLDER);
      for (const [f, size] of Object.entries(this.spec.files)) {
        const s = statSync(join(unpacked, f));
        if (size >= 0 && s.size !== size) throw new Error(`${f} has the wrong size after unpacking`);
      }
      rmSync(this.dir, { recursive: true, force: true });
      renameSync(unpacked, this.dir);
      this.installing = null;
      this.emit({ ev: "install", phase: "done", progress: 1 });
    } finally {
      rmSync(tmp, { force: true });
      rmSync(work, { recursive: true, force: true });
      if (this.installing) this.installing = null;
    }
  }

  /** https download with redirects to GitHub's own hosts only; streams to a file and hashes as it goes. */
  private download(url: string, dest: string, onProgress: (bytes: number, total: number) => void, hops = 0): Promise<{ bytes: number; sha256: string }> {
    return new Promise((resolve, reject) => {
      if (hops > 5) return reject(new Error("too many redirects"));
      let u: URL;
      try { u = new URL(url); } catch { return reject(new Error("bad download address")); }
      const local = this.spec.test && (u.hostname === "127.0.0.1" || u.hostname === "localhost");
      if (!local && (u.protocol !== "https:" || !hostOk(u.hostname))) return reject(new Error(`will not download from ${u.hostname}`));
      const get = u.protocol === "http:" ? http.get : https.get;
      const req = get(u, { headers: { "User-Agent": "Opscode" } }, (res) => {
        const code = res.statusCode ?? 0;
        if ([301, 302, 303, 307, 308].includes(code) && res.headers.location) {
          res.resume();
          return resolve(this.download(new URL(res.headers.location, u).toString(), dest, onProgress, hops + 1));
        }
        if (code !== 200) { res.resume(); return reject(new Error(`the download server answered ${code}`)); }
        const total = Number(res.headers["content-length"] ?? 0);
        const hash = createHash("sha256");
        const out = createWriteStream(dest, { mode: 0o600 });
        let bytes = 0;
        res.on("data", (d: Buffer) => { bytes += d.length; hash.update(d); onProgress(bytes, total || this.spec.bytes); });
        res.pipe(out);
        out.on("finish", () => (total && bytes !== total ? reject(new Error("the download was cut short")) : resolve({ bytes, sha256: hash.digest("hex") })));
        out.on("error", reject);
        res.on("error", reject);
      });
      req.on("error", reject);
      req.setTimeout(30_000, () => req.destroy(new Error("the download stalled")));
    });
  }

  /** Lists the archive first (every entry must be inside the model folder, no "..") and then unpacks it. */
  private untar(file: string, into: string): Promise<void> {
    const run = (args: string[]): Promise<string> => new Promise((resolve, reject) => {
      const p = spawn(tarProgram(), args, { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
      let out = "", err = "";
      p.stdout.on("data", (d) => (out += d));
      p.stderr.on("data", (d) => (err += d));
      p.on("error", reject);
      p.on("exit", (c) => (c === 0 ? resolve(out) : reject(new Error(`tar failed: ${err.trim().slice(0, 200)}`))));
    });
    return run(["-tjf", file]).then((list) => {
      for (const name of list.split("\n").map((l) => l.trim()).filter(Boolean)) {
        if (name.startsWith("/") || name.split("/").includes("..") || !(name === `${FIXTURE_FOLDER}/` || name.startsWith(`${FIXTURE_FOLDER}/`))) throw new Error(`the archive holds an unexpected path: ${name.slice(0, 80)}`);
      }
      return run(["-xjf", file, "-C", into, "--no-same-owner"]).then(() => undefined);
    });
  }

  /** Deletes the installed Kitten voice files. */
  remove(): { freed: number } {
    if (this.installing) throw new Error("Wait for the voice download to finish before removing it.");
    this.installError = "";
    this.stop();
    this.killWorker();
    const freed = this.installed()
      ? Object.keys(this.spec.files).reduce((total, file) => total + statSync(join(this.dir, file)).size, 0)
      : 0;
    rmSync(this.dir, { recursive: true, force: true });
    return { freed };
  }

  // ---- the worker ---------------------------------------------------------------------------------------------------------

  /** While voice mode is on the voice stays loaded (no idle unload between replies): each reply starts at once. */
  private held = 0;

  /**
   * Loads the voice now, before the first sentence (voice mode starts it as soon as the person opens it, so the agent's
   * first words are not lost to the model loading). hold=true keeps it loaded until release().
   */
  warm(hold = false): void {
    if (!this.installed()) return;
    if (hold) this.held++;
    this.touch();
    this.ensureWorker().catch((e) => this.log(`tts: warm-up failed: ${e instanceof Error ? e.message : String(e)}`));
  }

  /** Voice mode ended: the voice may unload when idle again. */
  release(): void {
    this.held = Math.max(0, this.held - 1);
    this.touch();
  }

  private touch(): void {
    clearTimeout(this.idle);
    const ms = Number(process.env.OPSCODE_TTS_IDLE_MS) || 180_000;
    // Idle = nothing is being made: no session, or one that was stopped or has had all its audio sent.
    this.idle = setTimeout(() => { const s = this.session; if (!this.held && (!s || s.stopped || s.done)) this.killWorker(); else this.touch(); }, ms);
    this.idle.unref?.();
  }

  private killWorker(): void {
    clearTimeout(this.idle);
    const w = this.worker;
    this.worker = null;
    this.ready = null;
    this.workerReady = false;
    if (w && w.exitCode === null) { try { w.send({ t: "exit" }); } catch { /* gone */ } setTimeout(() => { try { w.kill(); } catch { /* gone */ } }, 1000).unref(); }
  }

  private ensureWorker(): Promise<void> {
    if (this.worker && this.worker.connected && this.ready) return this.ready;
    const path = process.env.OPSCODE_TTS_WORKER || join(__dirname, "worker.js");
    const w = fork(path, [], { serialization: "advanced", stdio: ["ignore", "pipe", "pipe", "ipc"], env: { ...process.env, ELECTRON_RUN_AS_NODE: "1" } });
    this.worker = w;
    w.stdout?.resume();
    w.stderr?.on("data", (d: Buffer) => this.log(`tts: ${String(d).trim().slice(0, 300)}`));
    this.ready = new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error("Kitten took too long to load"));
        if (this.worker === w) this.killWorker();
      }, 60_000);
      timer.unref?.();
      w.on("message", (m: Record<string, unknown>) => {
        if (m.t === "hello") w.send({ t: "init", dir: this.dir, threads: 2 });
        else if (m.t === "ready") { if (this.worker !== w) return; this.workerReady = true; clearTimeout(timer); this.log(`tts: voice loaded in ${m.ms} ms`); resolve(); }
        else if (m.t === "error" && !m.id) { clearTimeout(timer); reject(new Error(String(m.message))); if (this.worker === w) this.killWorker(); }
        else this.onWorker(m);
      });
      w.on("error", (error) => { clearTimeout(timer); reject(error); if (this.worker === w) this.killWorker(); });
      w.on("exit", () => {
        clearTimeout(timer);
        reject(new Error("the voice stopped"));
        if (this.worker !== w) return;
        this.worker = null; this.ready = null; this.workerReady = false;
        const s = this.session;
        if (s && !s.stopped) { s.stopped = true; this.emit({ session: s.id, ev: "error", message: "The voice stopped unexpectedly." }); }
      });
    });
    this.ready.catch(() => {});
    return this.ready;
  }

  private onWorker(m: Record<string, unknown>): void {
    const s = this.session;
    const id = typeof m.id === "string" ? m.id : "";
    const [sid, idx] = id.split(":");
    if (!s || s.id !== sid || s.stopped) return; // a stopped session's late answer
    s.inflight = false;
    if (m.t === "audio") {
      const i = Number(idx);
      const pcm = m.pcm as Int16Array;
      this.emit({ session: s.id, ev: "audio", i, n: s.sentences.length, text: s.sentences[i], rate: m.rate, ms: m.ms, pcm: Buffer.from(pcm.buffer, pcm.byteOffset, pcm.byteLength).toString("base64") });
      s.next = i + 1;
      if (s.next >= s.sentences.length) {
        if (s.live) { this.touch(); return; } // waits for the next sentence (feed) or the end (finish)
        s.done = true; this.emit({ session: s.id, ev: "done" }); this.touch(); return;
      }
      this.pump();
    } else if (m.t === "error") {
      s.stopped = true;
      this.emit({ session: s.id, ev: "error", message: String(m.message ?? "The voice failed.") });
    }
  }

  // ---- speaking -------------------------------------------------------------------------------------------------------------

  private voiceOptions(o: { voice?: string; language?: string; hint?: string }): Pick<Session, "voice" | "language" | "hint"> {
    const voices = this.spec.test ? FIXTURE_VOICES : VOICES;
    const chosen = voices.find((v) => v.id === o.voice);
    return { voice: chosen?.id ?? (this.spec.test ? voices[0].id : ""), language: o.language ?? chosen?.language ?? "auto", hint: o.hint };
  }

  /** Reads a reply aloud: the person's markdown in, sentences out as audio events. */
  speak(o: { text: string; voice?: string; language?: string; hint?: string; steps?: number }): { session: string; sentences: number } {
    if (!this.installed()) throw new Error("The voice is not installed yet.");
    const sentences = speakableSentences(o.text);
    if (!sentences.length) throw new Error("There is nothing to read aloud in this reply.");
    this.stop();
    const s: Session = { id: randomUUID(), sentences, ...this.voiceOptions(o), steps: o.steps ?? 5, next: 0, played: 0, inflight: false, stopped: false, done: false };
    this.session = s;
    this.emit({ session: s.id, ev: "started", n: sentences.length });
    this.touch();
    this.ensureWorker().then(() => this.pump()).catch((e) => {
      s.stopped = true;
      this.emit({ session: s.id, ev: "error", message: e instanceof Error ? e.message : String(e) });
    });
    return { session: s.id, sentences: sentences.length };
  }

  /** Starts a reply that is still being written: sentences arrive with feed(), the end with finish(). */
  speakLive(o: { voice?: string; language?: string; hint?: string; steps?: number } = {}): { session: string } {
    if (!this.installed()) throw new Error("The voice is not installed yet.");
    this.stop();
    const s: Session = { id: randomUUID(), sentences: [], ...this.voiceOptions(o), steps: o.steps ?? 5, next: 0, played: 0, inflight: false, stopped: false, done: false, live: true };
    this.session = s;
    this.emit({ session: s.id, ev: "started", n: 0, live: true });
    this.touch();
    this.ensureWorker().then(() => this.pump()).catch((e) => {
      s.stopped = true;
      this.emit({ session: s.id, ev: "error", message: e instanceof Error ? e.message : String(e) });
    });
    return { session: s.id };
  }

  /** Adds finished sentences to a live reply. False when that reply was stopped or replaced. */
  feed(session: string, sentences: string[]): boolean {
    const s = this.session;
    if (!s || s.id !== session || s.stopped || !s.live) return false;
    s.sentences.push(...sentences.filter((x) => /[\p{L}\p{N}]/u.test(x)));
    this.pump();
    return true;
  }

  /** What a live reply was going to say and how much of it the window had started playing (for "you were cut off after..."). */
  snapshot(session: string): { sentences: string[]; played: number } | undefined {
    const s = this.session;
    return s && s.id === session ? { sentences: s.sentences.slice(), played: s.played } : undefined;
  }

  /** Is this voice session still making or sending audio? (Not the same as the window having played it.) */
  busy(session: string): boolean {
    const s = this.session;
    return !!s && s.id === session && !s.stopped && !s.done;
  }

  /** The reply is complete: the session ends once its last sentence has been made. */
  finish(session: string): void {
    const s = this.session;
    if (!s || s.id !== session || s.stopped || !s.live) return;
    s.live = false;
    if (s.next >= s.sentences.length && !s.inflight && !s.done) { s.done = true; this.emit({ session: s.id, ev: "done" }); this.touch(); }
  }

  private pump(): void {
    const s = this.session;
    if (!s || s.stopped || s.inflight || s.next >= s.sentences.length || s.next - s.played > LOOKAHEAD || !this.workerReady || !this.worker?.connected) return;
    s.inflight = true;
    this.touch();
    this.worker.send({ t: "speak", id: `${s.id}:${s.next}`, text: s.sentences[s.next], voice: s.voice, language: s.language, hint: s.hint, steps: s.steps });
  }

  /** The window started playing sentence `played`: generation may run further ahead. */
  progress(session: string, played: number): void {
    const s = this.session;
    if (!s || s.id !== session || s.stopped) return;
    s.played = Math.max(s.played, Math.min(played, s.sentences.length));
    this.touch();
    this.pump();
  }

  stop(session?: string): { stopped: boolean } {
    const s = this.session;
    if (!s || (session && s.id !== session)) return { stopped: false };
    this.session = null;
    if (!s.stopped) {
      s.stopped = true;
      if (s.inflight) { try { this.worker?.send({ t: "cancel", id: `${s.id}:${s.next}` }); } catch { /* gone */ } }
      this.emit({ session: s.id, ev: "stopped" });
    }
    return { stopped: true };
  }

  close(): void {
    this.stop();
    this.killWorker();
  }
}

export { speakableSentences } from "./speakable";
