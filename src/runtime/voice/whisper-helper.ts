// Whisper runs in a persistent native inference process. Keep capture and endpoint detection responsive while it decodes.
import { createInterface } from "node:readline";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { isNoise, pcmFromBase64, writeWav, type Sherpa } from "./engine";
import { LocalVoiceWorker } from "./localRuntime";
import { whisperLocale, WHISPER_ENGINE, WHISPER_MODEL } from "./whisper";

const rate = 16_000;
const maxUtterance = 26 * rate;
const out = (event: Record<string, unknown>) => process.stdout.write(JSON.stringify(event) + "\n");
const dir = join(process.env.OPSCODE_VOICE_DIR || join(tmpdir(), "opscode-voice"), "whisper-large-v3-turbo-q5");
let worker: LocalVoiceWorker | undefined;
let warm: Promise<Record<string, unknown>> | undefined;
let sherpa: Sherpa | undefined;

interface Audio { chunks: Buffer[]; size: number; quiet: number; lastPartial: number; text: string }
interface Session {
  mode: "dictate" | "converse";
  vad?: InstanceType<Sherpa["Vad"]>;
  language: string;
  prompt: string;
  endSamples: number;
  record?: string;
  recording: Int16Array[];
  total: number;
  floor: number;
  boost: number;
  flagged: number;
  ring: Buffer[];
  initial: Int16Array[];
  active?: Audio;
  pending: Audio[];
  full: string;
  processing: boolean;
  stopping: boolean;
}

let session: Session | undefined;
let idle: NodeJS.Timeout | undefined;

function touch(): void {
  clearTimeout(idle);
  idle = setTimeout(() => { if (session) touch(); else shutdown(); }, 180_000);
  idle.unref();
}
function shutdown(): void { worker?.close(); process.exit(0); }

function fail(s: Session, error: unknown): void {
  if (session !== s) return;
  session = undefined;
  worker?.close();
  worker = undefined;
  warm = undefined;
  out({ ev: "error", code: "audio", message: error instanceof Error ? error.message : String(error) });
}

async function begin(mode: Session["mode"], req: Record<string, unknown>): Promise<void> {
  if (session) return;
  const language = whisperLocale(String(req.locale ?? "auto"));
  const words = Array.isArray(req.words) ? req.words.filter((w) => typeof w === "string" && w.length <= 48).slice(0, 16) : [];
  const s: Session = {
    mode, language, prompt: words.join(", "), endSamples: rate * (Number(req.end_ms) || 1300) / 1000,
    record: typeof req.record === "string" ? req.record : undefined,
    recording: [], total: 0, floor: 0.004, boost: 1, flagged: 0, ring: [], initial: [],
    pending: [], full: "", processing: false, stopping: false,
  };
  session = s;
  try {
    sherpa ??= require("sherpa-onnx-node") as Sherpa;
    if (!warm) {
      const path = join(dir, WHISPER_MODEL);
      worker = new LocalVoiceWorker("whisper", path);
      warm = worker.call({ cmd: "load" }).catch((error) => {
        if (session !== s || process.platform !== "darwin" || process.env.OPSCODE_WHISPER_CPU === "1") throw error;
        worker?.close();
        worker = new LocalVoiceWorker("whisper", path, true);
        return worker.call({ cmd: "load" });
      });
    }
    await warm;
    if (session !== s) return;
    s.vad = new sherpa.Vad({
      sileroVad: { model: join(dir, "silero_vad.onnx"), threshold: 0.5, minSpeechDuration: 0.1, minSilenceDuration: 0.2, windowSize: 512, maxSpeechDuration: 30 },
      sampleRate: rate, numThreads: 1, provider: "cpu", debug: false,
    }, 30);
    out({ ev: "started", locale: language, engine: WHISPER_ENGINE, capture: "window" });
    for (const pcm of s.initial.splice(0)) accept(s, pcm);
    if (s.stopping) finish(s);
  } catch (error) { fail(s, error); }
}

function accept(s: Session, pcm: Int16Array): void {
  if (!pcm.length) return;
  if (!s.vad) {
    // Preserve speech during cold model load, including quick push-to-talk.
    if (s.initial.length < 300) s.initial.push(pcm);
    return;
  }
  const samples = Float32Array.from(pcm, (v) => v / 32768);
  const rms = Math.sqrt(samples.reduce((sum, v) => sum + v * v, 0) / samples.length);
  const bytes = Buffer.from(pcm.buffer, pcm.byteOffset, pcm.byteLength);
  s.total += pcm.length;
  if (s.mode === "dictate") {
    if (s.record) {
      s.recording.push(pcm);
      if (s.total >= 15 * 60 * rate) { s.stopping = true; finish(s); return; }
    }
    out({ ev: "level", rms: Math.min(1, rms * 6) });
  }

  s.vad.acceptWaveform(samples);
  while (!s.vad.isEmpty()) s.vad.pop();
  const voiced = s.vad.isDetected() && rms >= Math.max(0.003, s.floor * 1.4);
  if (!voiced && !s.active) s.floor = Math.max(0.0015, Math.min(0.04, s.floor * 0.95 + rms * 0.05));
  if (!s.active) {
    s.ring.push(bytes);
    if (s.ring.length > 6) s.ring.shift();
    const heard = voiced && (s.boost <= 1 || rms >= Math.max(0.008, s.floor * 2) * s.boost);
    s.flagged = heard ? s.flagged + 1 : 0;
    if (s.flagged < (s.boost > 1 ? 2 : 1)) return;
    s.active = { chunks: s.ring, size: s.ring.reduce((sum, c) => sum + c.length / 2, 0), quiet: 0, lastPartial: 0, text: "" };
    s.ring = [];
    s.flagged = 0;
    if (s.mode === "converse") out({ ev: "speech" });
    return;
  }
  const a = s.active;
  a.chunks.push(bytes);
  a.size += pcm.length;
  a.quiet = voiced ? 0 : a.quiet + pcm.length;
  if (a.quiet >= s.endSamples || a.size >= maxUtterance) finish(s);
  else if (!s.processing && !s.pending.length && voiced && a.size - a.lastPartial >= rate * 1.15) {
    a.lastPartial = a.size;
    void decode(s, a, false);
  }
}

function finish(s: Session): void {
  if (s.active) {
    if (s.pending.length >= 8) { fail(s, new Error("Speech recognition is falling behind. Try again after other intensive work finishes.")); return; }
    s.pending.push(s.active);
    s.active = undefined;
  }
  advance(s);
}

function advance(s: Session): void {
  if (session !== s || s.processing) return;
  const next = s.pending.shift();
  if (next) { void decode(s, next, true); return; }
  if (!s.stopping) return;
  let file: string | undefined;
  if (s.record && s.recording.length) {
    const path = s.record.replace(/\.[A-Za-z0-9]+$/, "") + ".wav";
    try { writeWav(path, s.recording); file = path; }
    catch (error) { fail(s, error); return; }
  }
  session = undefined;
  out({ ev: "done", text: s.full, secs: Math.round(s.total / rate * 10) / 10, ...(file ? { file } : {}) });
}

async function decode(s: Session, a: Audio, final: boolean): Promise<void> {
  s.processing = true;
  try {
    const audio = Buffer.concat(a.chunks);
    const length = final ? Math.min(audio.length, (a.size - Math.max(0, a.quiet - rate * 0.25)) * 2) : audio.length;
    const result = await worker!.call({ cmd: "decode", pcm: audio.subarray(0, length).toString("base64"), language: s.language, prompt: s.prompt, partial: !final });
    if (session !== s) return;
    const text = String(result.text ?? "").replace(/\s+/g, " ").trim();
    const language = String(result.language ?? s.language);
    const usable = !isNoise(text) && /[\p{L}\p{N}]/u.test(text) && !/^[[({].*[\])}]$/.test(text);
    if (!final) {
      if (s.active === a && usable && text !== a.text) { a.text = text; out({ ev: "partial", text, language }); }
    } else if (s.mode === "converse") {
      const ms = Math.round((a.size - a.quiet) / rate * 1000);
      out(usable ? { ev: "utterance", text, language, ms } : { ev: "noise", ms });
      // New speech can start while the previous decode is still in flight.
      if (s.active || s.pending.length) out({ ev: "speech" });
    } else if (usable) {
      s.full = s.full ? `${s.full} ${text}` : text;
      out({ ev: "final", text, full: s.full, language });
    } else if (a.text) out({ ev: "partial", text: "" });
  } catch (error) { fail(s, error); }
  finally { s.processing = false; advance(s); }
}

const lines = createInterface({ input: process.stdin });
lines.on("line", (line) => {
  let req: Record<string, unknown>;
  try { req = JSON.parse(line) as Record<string, unknown>; } catch { return; }
  const s = session;
  touch();
  try {
    switch (req.cmd) {
      case "start": void begin("dictate", req); break;
      case "converse": void begin("converse", req); break;
      case "audio": if (s && !s.stopping && typeof req.pcm === "string") accept(s, pcmFromBase64(req.pcm)); break;
      case "vad": if (s) s.boost = Math.max(1, Math.min(4, Number(req.boost) || 1)); break;
      case "stop":
        if (s) { s.stopping = true; if (s.vad) finish(s); }
        break;
      case "cancel":
        session = undefined;
        if (s && (s.processing || !s.vad)) { worker?.close(); worker = undefined; warm = undefined; }
        out({ ev: "cancelled" });
        break;
    }
  } catch (error) { if (s) fail(s, error); }
});
lines.on("close", shutdown);
touch();
