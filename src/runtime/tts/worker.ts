// The Pocket TTS worker (read aloud, V3). Runs as its own child process of the runtime so the model's memory
// (about 750 MB while loaded) is returned to the Mac when it is not needed: the service stops this process after
// a few idle minutes. Pocket TTS (Kyutai) through sherpa-onnx, on the CPU. Nothing leaves the Mac.
//
//   parent -> worker  { t: "init", dir, threads }   { t: "speak", id, text, voice, steps }   { t: "cancel", id }
//   worker -> parent  { t: "ready", ms, rate }      { t: "audio", id, pcm: Int16Array, rate, ms }
//                     { t: "cancelled", id }        { t: "error", id?, message }
// Messages use Node's "advanced" serialization (typed arrays pass as they are).

import { existsSync } from "node:fs";
import { join } from "node:path";

type Wave = { samples: Float32Array; sampleRate: number };
interface Sherpa {
  OfflineTts: { createAsync(config: unknown): Promise<Tts> };
  GenerationConfig: new (o: Record<string, unknown>) => unknown;
  readWave(file: string, enableExternalBuffer?: boolean): Wave;
}
interface Tts { sampleRate: number; generateAsync(o: Record<string, unknown>): Promise<{ samples: Float32Array; sampleRate: number }> }

const send = (m: Record<string, unknown>): void => { try { process.send?.(m); } catch { /* the parent is gone */ } };

let sherpa: Sherpa | undefined;
let tts: Tts | undefined;
let dir = "";
const voices = new Map<string, Wave>();
const cancelled = new Set<string>();
let chain: Promise<void> = Promise.resolve();

async function init(d: string, threads: number): Promise<void> {
  const t0 = Date.now();
  dir = d;
  sherpa = require("sherpa-onnx-node") as Sherpa;
  tts = await sherpa.OfflineTts.createAsync({
    model: {
      pocket: {
        lmFlow: join(d, "lm_flow.int8.onnx"),
        lmMain: join(d, "lm_main.int8.onnx"),
        encoder: join(d, "encoder.onnx"),
        decoder: join(d, "decoder.int8.onnx"),
        textConditioner: join(d, "text_conditioner.onnx"),
        vocabJson: join(d, "vocab.json"),
        tokenScoresJson: join(d, "token_scores.json"),
        voiceEmbeddingCacheCapacity: 8,
      },
      debug: false,
      numThreads: Math.max(1, Math.min(4, threads)),
      provider: "cpu",
    },
    maxNumSentences: 1,
  });
  send({ t: "ready", ms: Date.now() - t0, rate: tts.sampleRate });
}

function voiceWave(name: string): Wave {
  const hit = voices.get(name);
  if (hit) return hit;
  if (!/^[a-z0-9_-]{1,40}$/i.test(name)) throw new Error(`bad voice name ${name}`);
  const file = join(dir, "test_wavs", `${name}.wav`);
  if (!existsSync(file)) throw new Error(`voice ${name} is not installed`);
  const w = sherpa!.readWave(file, false); // Electron's Node refuses external buffers
  voices.set(name, w);
  return w;
}

async function speak(id: string, text: string, voice: string, steps: number): Promise<void> {
  if (cancelled.has(id)) { cancelled.delete(id); send({ t: "cancelled", id }); return; }
  try {
    if (!tts || !sherpa) throw new Error("the voice is not loaded");
    const t0 = Date.now();
    const ref = voiceWave(voice);
    const cfg = new sherpa.GenerationConfig({ speed: 1.0, referenceAudio: ref.samples, referenceSampleRate: ref.sampleRate, numSteps: steps, extra: { max_reference_audio_len: 10, seed: 42 } });
    const audio = await tts.generateAsync({ text, enableExternalBuffer: false /* Electron's Node refuses external buffers */, generationConfig: cfg, onProgress: () => (cancelled.has(id) ? 0 : 1) });
    if (cancelled.has(id)) { cancelled.delete(id); send({ t: "cancelled", id }); return; }
    const f = audio.samples;
    const pcm = new Int16Array(f.length);
    for (let i = 0; i < f.length; i++) pcm[i] = Math.max(-32768, Math.min(32767, Math.round(f[i] * 32767)));
    send({ t: "audio", id, pcm, rate: audio.sampleRate, ms: Date.now() - t0 });
  } catch (e) {
    send({ t: "error", id, message: e instanceof Error ? e.message : String(e) });
  }
}

process.on("message", (m: Record<string, unknown>) => {
  switch (m.t) {
    case "init": chain = chain.then(() => init(String(m.dir), Number(m.threads) || 2)).catch((e) => send({ t: "error", message: `could not load the voice: ${e instanceof Error ? e.message : String(e)}` })); break;
    case "speak": chain = chain.then(() => speak(String(m.id), String(m.text), String(m.voice), Number(m.steps) || 5)); break;
    case "cancel": cancelled.add(String(m.id)); break;
    case "exit": process.exit(0);
  }
});
process.on("disconnect", () => process.exit(0));
send({ t: "hello" });
