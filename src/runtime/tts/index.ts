// Read aloud (V3): Pocket TTS (Kyutai) on this Mac, through sherpa-onnx. The voice files (about 98 MB to download,
// 212 MB on disk) are fetched once from the sherpa-onnx project's GitHub release when the person agrees, checked
// against a pinned SHA-256, and unpacked into <state>/tts. A reply is cleaned to speakable sentences (speakable.ts),
// each sentence is turned into speech by a worker process (worker.ts, started on first use, stopped when idle) and
// sent to the window as `tts.event` audio. The window plays it, so pause, stop and speed need no round trip.
//
// Test overrides: OPSCODE_TTS_URL + OPSCODE_TTS_SHA256 + OPSCODE_TTS_FILES (names, comma separated),
// OPSCODE_TTS_WORKER (a stand-in worker), OPSCODE_TTS_IDLE_MS.

import { tarProgram } from "../voice/models";
import { fork, spawn, type ChildProcess } from "node:child_process";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { createWriteStream, mkdirSync, renameSync, rmSync, statSync } from "node:fs";
import http from "node:http";
import https from "node:https";
import { join } from "node:path";
import type { RpcNotification } from "../../shared/protocol";
import { speakableSentences } from "./speakable";

const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const REAL = {
  url: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${FOLDER}.tar.bz2`,
  bytes: 98_336_520,
  sha256: "2f3b88823cbbb9bf0b2477ec8ae7b3fec417b3a87b6bb5f256dba66f2ad967cb",
  files: {
    "lm_flow.int8.onnx": 9_962_530, "lm_main.int8.onnx": 76_341_079, "encoder.onnx": 72_713_165, "decoder.int8.onnx": 22_693_618,
    "text_conditioner.onnx": 16_388_343, "vocab.json": 69_478, "token_scores.json": 123_616,
    "test_wavs/bria.wav": 2_152_986, "test_wavs/loona.wav": 50_478,
  } as Record<string, number>,
  disk: 212_000_000,
};
export const VOICES = [{ id: "bria", name: "Bria" }, { id: "loona", name: "Loona" }];
export const LICENSE_NOTE = "Pocket TTS by Kyutai, as exported to ONNX by KevinAHM and packaged by sherpa-onnx. Creative Commons Attribution 4.0; the export's README asks for personal, non-commercial use. Do not use it to imitate a real person.";

const LOOKAHEAD = 3; // sentences generated ahead of the one being played
const hostOk = (h: string): boolean => h === "github.com" || h.endsWith(".githubusercontent.com");

export interface TtsStatus {
  engine: "Pocket TTS";
  installed: boolean;
  installing: { phase: string; progress: number; bytes: number; total: number } | null;
  download_bytes: number;
  disk_bytes: number;
  voices: { id: string; name: string }[];
  loaded: boolean;
  license: string;
}

interface Session { id: string; sentences: string[]; voice: string; steps: number; next: number; played: number; inflight: boolean; stopped: boolean; done: boolean; /** More sentences may still be added (a reply that is being written). */ live?: boolean }

export class TtsService {
  private readonly root: string;
  private readonly spec: { url: string; bytes: number; sha256: string; files: Record<string, number>; test: boolean };
  private worker: ChildProcess | null = null;
  private ready: Promise<void> | null = null;
  private idle: NodeJS.Timeout | undefined;
  private session: Session | null = null;
  private installing: TtsStatus["installing"] = null;

  constructor(stateDir: string, private readonly broadcast: (n: RpcNotification) => void, private readonly log: (line: string) => void) {
    this.root = join(stateDir, "tts");
    const url = process.env.OPSCODE_TTS_URL;
    this.spec = url
      ? { url, bytes: 0, sha256: process.env.OPSCODE_TTS_SHA256 ?? "", files: Object.fromEntries((process.env.OPSCODE_TTS_FILES ?? "").split(",").filter(Boolean).map((f) => [f, -1])), test: true }
      : { ...REAL, test: false };
  }

  private get dir(): string { return join(this.root, FOLDER); }

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
    return { engine: "Pocket TTS", installed: this.installed(), installing: this.installing, download_bytes: this.spec.test ? 0 : REAL.bytes, disk_bytes: REAL.disk, voices: VOICES, loaded: !!this.worker && this.worker.connected, license: LICENSE_NOTE };
  }

  private emit(params: Record<string, unknown>): void {
    this.broadcast({ method: "tts.event", params });
  }

  // ---- install -------------------------------------------------------------------------------------------------------

  /** Downloads and unpacks the voice. Only called when the person said yes; progress arrives as tts.event install. */
  install(): { started: boolean } {
    if (this.installing || this.installed()) return { started: false };
    this.installing = { phase: "download", progress: 0, bytes: 0, total: this.spec.bytes };
    void this.runInstall().catch((e) => {
      this.log(`tts: install failed: ${e instanceof Error ? e.message : String(e)}`);
      this.installing = null;
      this.emit({ ev: "install", phase: "error", message: e instanceof Error ? e.message : String(e) });
    });
    return { started: true };
  }

  private async runInstall(): Promise<void> {
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
      const unpacked = join(work, FOLDER);
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
        if (name.startsWith("/") || name.split("/").includes("..") || !(name === `${FOLDER}/` || name.startsWith(`${FOLDER}/`))) throw new Error(`the archive holds an unexpected path: ${name.slice(0, 80)}`);
      }
      return run(["-xjf", file, "-C", into, "--no-same-owner"]).then(() => undefined);
    });
  }

  /** Deletes the voice files (about 212 MB). */
  remove(): { freed: number } {
    this.stop();
    this.killWorker();
    const had = this.installed();
    rmSync(this.dir, { recursive: true, force: true });
    return { freed: had ? REAL.disk : 0 };
  }

  // ---- the worker ---------------------------------------------------------------------------------------------------------

  private touch(): void {
    clearTimeout(this.idle);
    const ms = Number(process.env.OPSCODE_TTS_IDLE_MS) || 180_000;
    // Idle = nothing is being made: no session, or one that was stopped or has had all its audio sent.
    this.idle = setTimeout(() => { const s = this.session; if (!s || s.stopped || s.done) this.killWorker(); else this.touch(); }, ms);
    this.idle.unref?.();
  }

  private killWorker(): void {
    clearTimeout(this.idle);
    const w = this.worker;
    this.worker = null;
    this.ready = null;
    if (w && w.exitCode === null) { try { w.send({ t: "exit" }); } catch { /* gone */ } setTimeout(() => { try { w.kill(); } catch { /* gone */ } }, 1000).unref(); }
  }

  private ensureWorker(): Promise<void> {
    if (this.worker && this.worker.connected && this.ready) return this.ready;
    const path = process.env.OPSCODE_TTS_WORKER || join(__dirname, "worker.js");
    const w = fork(path, [], { serialization: "advanced", stdio: ["ignore", "pipe", "pipe", "ipc"], env: { ...process.env, ELECTRON_RUN_AS_NODE: "1" } });
    this.worker = w;
    w.stderr?.on("data", (d: Buffer) => this.log(`tts: ${String(d).trim().slice(0, 300)}`));
    this.ready = new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("the voice took too long to load")), 60_000);
      timer.unref?.();
      w.on("message", (m: Record<string, unknown>) => {
        if (m.t === "hello") w.send({ t: "init", dir: this.dir, threads: 2 });
        else if (m.t === "ready") { clearTimeout(timer); this.log(`tts: voice loaded in ${m.ms} ms`); resolve(); }
        else if (m.t === "error" && !m.id) { clearTimeout(timer); reject(new Error(String(m.message))); }
        else this.onWorker(m);
      });
      w.on("exit", () => {
        clearTimeout(timer);
        if (this.worker === w) { this.worker = null; this.ready = null; }
        const s = this.session;
        if (s && !s.stopped) { s.stopped = true; this.emit({ session: s.id, ev: "error", message: "The voice stopped unexpectedly." }); }
        reject(new Error("the voice stopped"));
      });
    });
    this.ready.catch(() => {});
    return this.ready;
  }

  private onWorker(m: Record<string, unknown>): void {
    const s = this.session;
    const id = typeof m.id === "string" ? m.id : "";
    const [sid, idx] = id.split(":");
    if (!s || s.id !== sid) return; // a stopped session's late answer
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

  /** Reads a reply aloud: the person's markdown in, sentences out as audio events. */
  speak(o: { text: string; voice?: string; steps?: number }): { session: string; sentences: number } {
    if (!this.installed()) throw new Error("The voice is not installed yet.");
    const sentences = speakableSentences(o.text);
    if (!sentences.length) throw new Error("There is nothing to read aloud in this reply.");
    const voice = VOICES.some((v) => v.id === o.voice) ? (o.voice as string) : VOICES[0].id;
    this.stop();
    const s: Session = { id: randomUUID(), sentences, voice, steps: o.steps ?? 5, next: 0, played: 0, inflight: false, stopped: false, done: false };
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
  speakLive(o: { voice?: string; steps?: number } = {}): { session: string } {
    if (!this.installed()) throw new Error("The voice is not installed yet.");
    const voice = VOICES.some((v) => v.id === o.voice) ? (o.voice as string) : VOICES[0].id;
    this.stop();
    const s: Session = { id: randomUUID(), sentences: [], voice, steps: o.steps ?? 5, next: 0, played: 0, inflight: false, stopped: false, done: false, live: true };
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
    if (!s || s.stopped || s.inflight || s.next >= s.sentences.length || s.next - s.played > LOOKAHEAD || !this.worker?.connected) return;
    s.inflight = true;
    this.touch();
    this.worker.send({ t: "speak", id: `${s.id}:${s.next}`, text: s.sentences[s.next], voice: s.voice, steps: s.steps });
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
