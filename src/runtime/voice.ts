import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, rmSync, rmdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { downloadModels } from "./voice/download";
import { LOCAL_VOICE_ERROR, localVoiceAvailable } from "./voice/localRuntime";
import { WHISPER_ENGINE, WHISPER_FILES, WHISPER_LANGUAGES } from "./voice/whisper";
import { randomUUID } from "node:crypto";
import type { RpcNotification } from "../shared/protocol";

export interface VoiceStatus {
  helper: boolean;
  available: boolean;
  mic: string;
  os?: string;
  error?: string;
  /** Who listens to the microphone: the helper itself (Apple's) or the window (it sends audio with voice.audio). */
  capture: "helper" | "window";
  engine?: string;
  /** The speech model is on this computer (the first use downloads it). Only for the window-capture helper. */
  installed?: boolean;
  download_bytes?: number;
  installing?: { bytes: number; total: number; progress: number } | null;
  install_error?: string;
}

/**
 * Apple's recognizer splits words it does not know ("Ops code" for Opscode). Joins them back for the given
 * words, matching any spacing or case between their letters.
 */
export function fixWords(text: string, words: readonly string[]): string {
  let out = text;
  for (const w of words) {
    if (w.length < 6 || !/^[A-Za-z][A-Za-z0-9]+$/.test(w)) continue; // short words ("Codex") could eat real speech ("code x")
    const re = new RegExp(`\\b${[...w].map((c) => c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("\\s?")}\\b`, "gi");
    out = out.replace(re, w);
  }
  return out;
}

/** How to start the helper: a program, or a script run with Electron-as-Node (the same binary as the runtime). */
export function helperCommand(): { cmd: string; args: string[]; script: boolean } | undefined {
  const asScript = (path: string): { cmd: string; args: string[]; script: boolean } => ({ cmd: process.execPath, args: [path], script: true });
  const over = process.env.OPSCODE_VOICE_HELPER;
  if (over) return /\.(?:c|m)?js$/i.test(over) && process.platform === "win32" ? asScript(over) : { cmd: over, args: [], script: false };
  const file = process.env.OPSCODE_VOICE_ENGINE === "sherpa" ? "node-helper.js" : "whisper-helper.js";
  const node = join(__dirname, "voice", file);
  return existsSync(node) ? asScript(node) : undefined;
}

const usesWhisper = () => !process.env.OPSCODE_VOICE_HELPER && process.env.OPSCODE_VOICE_ENGINE !== "sherpa";
const downloadBytes = WHISPER_FILES.reduce((total, file) => total + file.bytes, 0);

export const helperPath = (): string | undefined => helperCommand()?.cmd;

export class VoiceService {
  private proc: ChildProcess | null = null;
  private buf = "";
  private installing: VoiceStatus["installing"] = null;
  private installError = "";
  private waiters: { want: string; resolve: (v: Record<string, unknown>) => void }[] = [];
  /** The listening session: its id and the words to fix in its text. */
  private session: { id: string; words: string[]; record?: string; /** Conversation: events go here instead of the window. */ sink?: (e: Record<string, unknown>) => void } | null = null;

  constructor(private readonly broadcast: (n: RpcNotification) => void, private readonly log: (line: string) => void, private readonly stateDir = "") {}

  private get modelDir(): string {
    return join(this.stateDir ? join(this.stateDir, "voice") : join(tmpdir(), "opscode-voice"), "whisper-large-v3-turbo-q5");
  }

  private installed(): boolean {
    return WHISPER_FILES.every((file) => statSync(join(this.modelDir, file.name), { throwIfNoEntry: false })?.size === file.bytes);
  }

  install(): { started: boolean } {
    if (!usesWhisper() || this.installing || this.installed()) return { started: false };
    if (!localVoiceAvailable()) throw new Error(LOCAL_VOICE_ERROR);
    this.installError = "";
    this.installing = { bytes: 0, total: downloadBytes, progress: 0 };
    let nextUpdate = 0;
    const notify = (phase: string) => this.broadcast({ method: "voice.event", params: { ev: "install", phase, ...this.installing, message: this.installError } });
    void downloadModels(this.modelDir, WHISPER_FILES, (bytes) => {
      this.installing = { bytes, total: downloadBytes, progress: bytes / downloadBytes };
      if (Date.now() >= nextUpdate) { nextUpdate = Date.now() + 250; notify("download"); }
    }).then(() => {
      this.installing = null;
      notify("done");
    }).catch((error) => {
      this.installing = null;
      this.installError = error instanceof Error ? error.message : String(error);
      this.log(`voice: install failed: ${this.installError}`);
      notify("error");
    });
    return { started: true };
  }

  remove(): { freed: number } {
    if (!usesWhisper()) return { freed: 0 };
    if (this.session || this.installing) throw new Error("Stop listening and wait for the download before removing the speech model.");
    const freed = this.installed() ? downloadBytes : 0;
    this.close();
    rmSync(this.modelDir, { recursive: true, force: true });
    this.installError = "";
    return { freed };
  }

  private checkReady(): void {
    if (!helperPath()) throw new Error("Voice input is unavailable in this build.");
    if (!usesWhisper()) return;
    if (!localVoiceAvailable()) throw new Error(LOCAL_VOICE_ERROR);
    if (!this.installed()) throw new Error("Download Whisper in Settings → General → Voice before using the microphone.");
  }

  private ensure(): ChildProcess | null {
    if (this.proc && this.proc.exitCode === null) return this.proc;
    const c = helperCommand();
    if (!c) return null;
    const p = spawn(c.cmd, c.args, { stdio: ["pipe", "pipe", "pipe"], windowsHide: true, env: { ...process.env, ELECTRON_RUN_AS_NODE: "1", ...(this.stateDir ? { OPSCODE_VOICE_DIR: join(this.stateDir, "voice") } : {}) } });
    this.proc = p;
    this.buf = "";
    p.stdout?.setEncoding("utf8");
    p.stdout?.on("data", (d: string) => {
      if (this.proc !== p) return;
      this.buf += d;
      let i: number;
      while ((i = this.buf.indexOf("\n")) >= 0) {
        const line = this.buf.slice(0, i).trim();
        this.buf = this.buf.slice(i + 1);
        if (!line) continue;
        try { this.onEvent(JSON.parse(line) as Record<string, unknown>); } catch { this.log(`voice: bad line ${line.slice(0, 120)}`); }
      }
    });
    p.stderr?.on("data", (d: Buffer) => this.log(`voice: ${String(d).trim().slice(0, 300)}`));
    p.stdin?.on("error", (e) => this.log(`voice: ${e.message}`));
    p.on("close", (code) => {
      if (this.proc !== p) return;
      this.proc = null;
      for (const w of this.waiters.splice(0)) w.resolve({ ev: "error", code: "helper_exit", message: `The voice helper stopped (${code}).` });
      this.onEvent({ ev: "error", code: "helper_exit", message: "The voice helper stopped." });
    });
    p.on("error", (e) => this.log(`voice: could not start the helper: ${e.message}`));
    return p;
  }

  private send(cmd: Record<string, unknown>): boolean {
    const p = this.ensure();
    if (!p?.stdin?.writable) return false;
    p.stdin.write(JSON.stringify(cmd) + "\n");
    return true;
  }

  /** Waits for the next event of a kind (status, locales). */
  private ask(cmd: Record<string, unknown>, want: string, ms = 8000): Promise<Record<string, unknown>> {
    return new Promise((resolve) => {
      if (!this.send(cmd)) return resolve({ ev: "error", code: "no_helper", message: "Voice input is not available (the helper is missing)." });
      const w = { want, resolve };
      this.waiters.push(w);
      setTimeout(() => { const i = this.waiters.indexOf(w); if (i >= 0) { this.waiters.splice(i, 1); resolve({ ev: "error", code: "timeout", message: "The voice helper did not answer." }); } }, ms).unref();
    });
  }

  private onEvent(e: Record<string, unknown>): void {
    const ev = String(e.ev ?? "");
    const wi = this.waiters.findIndex((w) => w.want === ev);
    if (wi >= 0) { this.waiters.splice(wi, 1)[0].resolve(e); return; }
    if (ev === "ready") return;
    const s = this.session;
    if (!s) return;
    const fixed: Record<string, unknown> = { ...e };
    for (const k of ["text", "full"]) if (typeof fixed[k] === "string") fixed[k] = fixWords(fixed[k] as string, s.words);
    if (ev === "done" || ev === "cancelled" || (ev === "error" && ["mic_denied", "locale", "asset", "audio", "unavailable", "helper_exit"].includes(String(e.code)))) {
      this.session = null;
      // A voice note that was not kept (cancelled, or the microphone failed): its empty folder goes too.
      if (s.record && ev !== "done") { try { rmdirSync(dirname(s.record)); } catch { /* not empty or gone */ } }
    }
    if (s.sink) { try { s.sink(fixed); } catch (err) { this.log(`voice: listener failed: ${err instanceof Error ? err.message : String(err)}`); } return; }
    this.broadcast({ method: "voice.event", params: { session: s.id, ...fixed } });
  }

  async status(): Promise<VoiceStatus> {
    if (usesWhisper()) {
      const helper = !!helperPath();
      const available = helper && localVoiceAvailable();
      return { helper, available, mic: "window", capture: "window", engine: WHISPER_ENGINE, installed: this.installed(),
        download_bytes: downloadBytes, installing: this.installing, install_error: this.installError,
        ...(available ? {} : { error: LOCAL_VOICE_ERROR }) };
    }
    if (!helperPath()) return { helper: false, available: false, mic: "unknown", capture: "helper" };
    const r = await this.ask({ cmd: "status" }, "status");
    if (r.ev === "error") return { helper: true, available: false, mic: "unknown", capture: "helper", error: String(r.message ?? "") };
    return {
      helper: true, available: r.available === true, mic: String(r.mic ?? "unknown"), capture: r.capture === "window" ? "window" : "helper",
      ...(typeof r.os === "string" ? { os: r.os } : {}), ...(typeof r.engine === "string" ? { engine: r.engine } : {}), ...(typeof r.installed === "boolean" ? { installed: r.installed } : {}),
      ...(typeof r.error === "string" ? { error: r.error } : {}),
    };
  }

  async locales(): Promise<{ speech: string[]; dictation: string[]; installed: string[] }> {
    if (usesWhisper()) return { speech: WHISPER_LANGUAGES, dictation: WHISPER_LANGUAGES, installed: this.installed() ? WHISPER_LANGUAGES : [] };
    const r = await this.ask({ cmd: "locales" }, "locales", 15000);
    const list = (k: string): string[] => (Array.isArray(r[k]) ? (r[k] as unknown[]).map(String) : []);
    return { speech: list("speech"), dictation: list("dictation"), installed: list("installed") };
  }

  /** Starts listening. Words: names to keep whole (the project, Opscode, …). */
  start(o: { locale?: string; words?: string[]; record?: string; endMs?: number }): { session: string } {
    if (this.session) throw new Error("Already listening");
    this.checkReady();
    // Each word once, whatever its case; the first spelling wins ("Opscode" over a folder's "opscode").
    const seen = new Set<string>();
    const words = ["Opscode", "Claude", "Codex", ...(o.words ?? [])].filter((w) => { const k = w.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; }).slice(0, 100);
    const id = randomUUID();
    this.session = { id, words, ...(o.record ? { record: o.record } : {}) };
    if (!this.send({ cmd: "start", locale: o.locale || "auto", words, end_ms: o.endMs, ...(o.record ? { record: o.record } : {}) })) { this.session = null; throw new Error("Could not start the voice helper."); }
    return { session: id };
  }

  /**
   * Conversation: the window sends its microphone audio with audio() (16 kHz mono Int16, base64) and the helper
   * reports speech, partial, utterance and noise events to `sink`. One session at a time, shared with dictation.
   */
  converse(o: { locale?: string; words?: string[]; endMs?: number }, sink: (e: Record<string, unknown>) => void): { session: string } {
    if (this.session) throw new Error("Already listening");
    this.checkReady();
    const seen = new Set<string>();
    const words = ["Opscode", "Claude", "Codex", ...(o.words ?? [])].filter((w) => { const k = w.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; }).slice(0, 100);
    const id = randomUUID();
    this.session = { id, words, sink };
    if (!this.send({ cmd: "converse", locale: o.locale || "auto", words, end_ms: o.endMs ?? 1100, speech_ms: 240 })) { this.session = null; throw new Error("Could not start the voice helper."); }
    return { session: id };
  }

  /** One chunk of the window's microphone (a conversation, or dictation when the window captures the microphone). */
  audio(session: string, pcm: string): boolean {
    if (!this.session || this.session.id !== session) return false;
    return this.send({ cmd: "audio", pcm });
  }

  /** Makes the detector less eager to hear speech (while the agent itself is talking). 1 = normal. */
  vad(session: string, boost: number): void {
    if (this.session?.sink && this.session.id === session) this.send({ cmd: "vad", boost });
  }

  /** True while this conversation owns the microphone helper. */
  conversing(session: string): boolean { return !!this.session?.sink && this.session.id === session; }

  stop(cancel = false): { stopped: boolean } {
    if (!this.session) return { stopped: false };
    this.send({ cmd: cancel ? "cancel" : "stop" });
    return { stopped: true };
  }

  close(): void {
    const p = this.proc;
    this.proc = null;
    if (!p) return;
    p.stdin?.end();
    setTimeout(() => p.kill(), 1500).unref();
  }
}
