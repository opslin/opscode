// Speech recognition on the CPU for computers without Apple's recognizer (Windows, Linux), through sherpa-onnx:
// Kroko's streaming English model for the words, Silero for "is someone speaking". The window captures the microphone
// and sends 16 kHz mono Int16 chunks; everything here runs on that audio's own clock (no timers), so a file fed
// faster than real time behaves exactly like a person talking. It speaks the events of native/opscode-voice.
//
//   dictation  (start)     one running stream; the model's own endpoints close sentences: partial, final, done
//   conversation (converse) Silero decides when speech starts and ends: speech, partial, utterance | noise

import { writeFileSync } from "node:fs";
import { speechFiles } from "./models";

interface Stream { acceptWaveform(o: { samples: Float32Array; sampleRate: number }): void; inputFinished(): void }
interface Recognizer { createStream(): Stream; isReady(s: Stream): boolean; decode(s: Stream): void; getResult(s: Stream): { text: string }; isEndpoint(s: Stream): boolean; reset(s: Stream): void }
interface Vad { acceptWaveform(samples: Float32Array): void; isDetected(): boolean; isEmpty(): boolean; pop(): void }
export interface Sherpa {
  OnlineRecognizer: new (config: unknown) => Recognizer;
  Vad: new (config: unknown, bufferSeconds: number) => Vad;
}
export type Emit = (event: Record<string, unknown>) => void;

const RATE = 16_000;
const PAD_SECONDS = 1.5; // the model needs about this much trailing silence to release its last words
const PRE_ROLL_CHUNKS = 8; // audio kept from before speech is noticed
const FILLER = /^(?:the|a|an|uh|um|hm+|mm+|oh|ah|huh|eh|and|so)[.,!?]?$/i;

/** Capital letter, "I", a full stop on a finished sentence. The model already sets capitals and commas itself. */
export function tidy(text: string, final: boolean): string {
  let t = text.replace(/\s+/g, " ").trim();
  if (!t) return "";
  t = t.replace(/\bi\b/g, "I").replace(/\bi'(m|ve|ll|d)\b/g, "I'$1");
  t = t[0]!.toUpperCase() + t.slice(1);
  if (final && /[A-Za-z0-9]$/.test(t) && t.split(" ").length >= 3) t += ".";
  return t;
}

/** Sound with no words in it: nothing, or one filler word the model made up from noise. */
export const isNoise = (text: string): boolean => { const t = text.trim(); return t.length < 2 || FILLER.test(t); };

export function pcmFromBase64(b64: string): Int16Array {
  const buf = Buffer.from(b64, "base64");
  const n = buf.length >> 1;
  const out = new Int16Array(n);
  for (let i = 0; i < n; i++) out[i] = buf.readInt16LE(2 * i);
  return out;
}

function writeWav(path: string, chunks: Int16Array[]): void {
  const n = chunks.reduce((a, c) => a + c.length, 0);
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write("WAVE", 8); buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22); buf.writeUInt32LE(RATE, 24); buf.writeUInt32LE(RATE * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write("data", 36); buf.writeUInt32LE(n * 2, 40);
  let o = 44;
  for (const c of chunks) for (let i = 0; i < c.length; i++, o += 2) buf.writeInt16LE(c[i]!, o);
  writeFileSync(path, buf);
}

interface Sess {
  mode: "converse" | "dictate";
  endSamples: number;
  vad: Vad;
  stream: Stream | null;
  ring: Float32Array[];
  flagged: number; // consecutive chunks the detector called speech while idle
  startedAt: number;
  lastVoiced: number;
  partial: string;
  floor: number; // the quiet level of the room, followed slowly
  // dictation
  full: string;
  record: string | null;
  audio: Int16Array[];
}

export class SpeechEngine {
  private rec: Recognizer | null = null;
  private s: Sess | null = null;
  private samples = 0; // the session's audio clock
  private boost = 1;

  constructor(private readonly sherpa: Sherpa, private readonly dir: string, private readonly emit: Emit) {}

  active(): boolean { return this.s !== null; }

  /** Loads the model (about a second the first time). */
  load(): void {
    if (this.rec) return;
    const f = speechFiles(this.dir);
    const cores = Number(process.env.OPSCODE_VOICE_THREADS) || 2;
    this.rec = new this.sherpa.OnlineRecognizer({
      featConfig: { sampleRate: RATE, featureDim: 80 },
      modelConfig: { transducer: { encoder: f.encoder, decoder: f.decoder, joiner: f.joiner }, tokens: f.tokens, numThreads: cores, provider: "cpu", debug: 0 },
      decodingMethod: "greedy_search",
      enableEndpoint: 0, // Silero decides where a sentence ends (the model's own endpoint rules never fired for this model)
    });
  }

  /** Frees the model's memory (the helper exits when nobody has talked for a while). */
  unload(): void { this.rec = null; }
  loaded(): boolean { return this.rec !== null; }

  start(kind: "dictate" | "converse", o: { endMs?: number; record?: string } = {}): void {
    if (this.s) throw new Error("Already listening");
    this.load();
    this.samples = 0;
    this.boost = 1;
    const f = speechFiles(this.dir);
    const vad = new this.sherpa.Vad({ sileroVad: { model: f.vad, threshold: 0.5, minSpeechDuration: 0.1, minSilenceDuration: 0.5, windowSize: 512, maxSpeechDuration: 30 }, sampleRate: RATE, numThreads: 1, provider: "cpu", debug: false }, 30);
    // A conversation ends an utterance after 1.1 s of quiet; dictation waits a little longer (people think while they dictate).
    const endMs = o.endMs ?? (kind === "dictate" ? 1300 : 1100);
    this.s = { mode: kind, endSamples: Math.round((endMs / 1000) * RATE), vad, stream: null, ring: [], flagged: 0, startedAt: 0, lastVoiced: 0, partial: "", floor: 0.004, full: "", record: o.record ?? null, audio: [] };
  }

  /** Makes "speech" harder to trigger while the agent itself is talking (1 = normal). */
  setBoost(b: number): void { this.boost = Number.isFinite(b) ? Math.max(1, Math.min(4, b)) : 1; }

  audio(pcm: Int16Array): void {
    const s = this.s;
    if (!s || !pcm.length) return;
    const x = new Float32Array(pcm.length);
    let sum = 0;
    for (let i = 0; i < pcm.length; i++) { const v = pcm[i]! / 32768; x[i] = v; sum += v * v; }
    const rms = Math.sqrt(sum / pcm.length);
    this.samples += pcm.length;
    if (s.mode === "dictate") {
      if (s.record) s.audio.push(pcm.slice());
      this.emit({ ev: "level", rms: Math.min(1, rms * 6) });
    }
    this.listen(s, x, rms);
  }

  private decode(stream: Stream): string {
    const rec = this.rec!;
    while (rec.isReady(stream)) rec.decode(stream);
    return rec.getResult(stream).text;
  }

  private flush(stream: Stream): string {
    stream.acceptWaveform({ sampleRate: RATE, samples: new Float32Array(Math.round(RATE * PAD_SECONDS)) });
    stream.inputFinished();
    return this.decode(stream);
  }

  /** Speech starts when Silero says so and ends after the quiet gap; the words are recognised while it lasts. */
  private listen(s: Sess, x: Float32Array, rms: number): void {
    s.vad.acceptWaveform(x);
    while (!s.vad.isEmpty()) s.vad.pop();
    let det = s.vad.isDetected();
    if (!det) s.floor = Math.max(0.0015, Math.min(0.05, s.floor * 0.95 + rms * 0.05));
    // The agent's own voice, a little of it left after the browser's echo cancelling, is quieter than a person who means it.
    if (det && s.mode === "converse" && this.boost > 1 && !s.stream) det = rms >= Math.max(0.01, s.floor * 2.5) * this.boost;
    if (!s.stream) {
      s.ring.push(x);
      if (s.ring.length > PRE_ROLL_CHUNKS) s.ring.shift();
      s.flagged = det ? s.flagged + 1 : 0;
      if (s.flagged >= (s.mode === "converse" && this.boost > 1 ? 2 : 1)) {
        s.stream = this.rec!.createStream();
        for (const c of s.ring) s.stream.acceptWaveform({ sampleRate: RATE, samples: c });
        s.startedAt = this.samples - s.ring.reduce((a, c) => a + c.length, 0);
        s.lastVoiced = this.samples;
        s.ring = [];
        s.flagged = 0;
        s.partial = "";
        if (s.mode === "converse") this.emit({ ev: "speech" });
        this.partialOf(s);
      }
      return;
    }
    s.stream.acceptWaveform({ sampleRate: RATE, samples: x });
    this.partialOf(s);
    if (det) s.lastVoiced = this.samples;
    if (this.samples - s.lastVoiced >= s.endSamples || this.samples - s.startedAt > RATE * 60) this.finish(s);
  }

  private partialOf(s: Sess): void {
    const text = this.decode(s.stream!);
    if (text !== s.partial) {
      s.partial = text;
      const t = tidy(text, false);
      if (t) this.emit({ ev: "partial", text: t });
    }
  }

  /** The sentence is over: its words are final (dictation) or an utterance / noise (conversation). */
  private finish(s: Sess): void {
    const stream = s.stream;
    if (!stream) return;
    const text = this.flush(stream);
    const ms = Math.round(((s.lastVoiced - s.startedAt) / RATE) * 1000);
    s.stream = null;
    s.partial = "";
    if (s.mode === "dictate") {
      if (isNoise(text)) return;
      const seg = tidy(text, true);
      s.full = s.full ? `${s.full} ${seg}` : seg;
      this.emit({ ev: "final", text: seg, full: s.full });
    } else if (isNoise(text)) this.emit({ ev: "noise", ms });
    else this.emit({ ev: "utterance", text: tidy(text, true), ms });
  }

  // ---- end ------------------------------------------------------------------------------------------------------------------
  stop(): void {
    const s = this.s;
    if (!s) return;
    this.s = null;
    const secs = Math.round((this.samples / RATE) * 10) / 10;
    if (s.mode === "converse") { this.emit({ ev: "done", text: "", secs }); return; }
    if (s.stream) { s.lastVoiced = this.samples; this.finish(s); } // what was still being said becomes final
    let file: string | undefined;
    if (s.record && s.audio.length) {
      file = s.record.replace(/\.[A-Za-z0-9]+$/, "") + ".wav";
      try { writeWav(file, s.audio); } catch (e) { this.emit({ ev: "error", code: "audio", message: `Could not save the recording: ${e instanceof Error ? e.message : String(e)}` }); file = undefined; }
    }
    this.emit({ ev: "done", text: s.full, secs, ...(file ? { file } : {}) });
  }

  cancel(): void {
    if (!this.s) return;
    this.s = null;
    this.emit({ ev: "cancelled" });
  }
}
