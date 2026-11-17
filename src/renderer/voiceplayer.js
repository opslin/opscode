// Plays the agent's voice in voice mode. The runtime sends one sentence at a time as 24 kHz Int16 (tts.event); they are
// scheduled back to back on a WebAudio clock, so there are no gaps, and stop() cuts them off at once (barge-in).
// Playing in this window is what lets Chromium's echo canceller remove the agent's voice from the microphone.

import { state } from "./store.js";
import { applyTone } from "./voicetone.js";

const RATE = 24000;

/** tone(): { speed, pitch } for the next sentence (voice mode settings). */
export function createVoicePlayer({ onPlaying, tone = () => ({ speed: 1, pitch: 0 }) }) {
  let ctx = null;
  let out = null;
  let analyser = null;
  let data = null;
  const sources = new Set();
  const timers = new Set();
  let session = null;
  let nextAt = 0;
  let ended = false; // the runtime has sent every sentence
  let playing = false;

  const ensure = () => {
    if (!ctx) {
      ctx = new AudioContext({ latencyHint: "interactive" });
      out = ctx.createGain();
      analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      data = new Uint8Array(analyser.fftSize);
      out.connect(analyser);
      analyser.connect(ctx.destination);
    }
    if (ctx.state === "suspended") void ctx.resume();
    return ctx;
  };
  const setPlaying = (p) => { if (p === playing) return; playing = p; onPlaying(p); };
  const settle = () => { if (ended && sources.size === 0) setPlaying(false); };

  /** A new spoken reply (runtime tts session id). Anything still playing from an older one is cut. */
  function open(id) {
    cut();
    session = id;
    ended = false;
    nextAt = 0;
  }

  /** { session, i, pcm } from a tts.event of the open session. */
  function add(msg) {
    if (msg.session !== session || !msg.pcm) return;
    const c = ensure();
    const bin = atob(msg.pcm);
    const n = bin.length >> 1;
    const rate = Number(msg.rate) > 0 ? Number(msg.rate) : RATE;
    const raw = new Float32Array(n);
    for (let k = 0; k < n; k++) {
      const v = bin.charCodeAt(2 * k) | (bin.charCodeAt(2 * k + 1) << 8);
      raw[k] = (v > 32767 ? v - 65536 : v) / 32768;
    }
    const t = applyTone(raw, tone(), rate);
    const buf = c.createBuffer(1, t.samples.length, rate);
    buf.copyToChannel(t.samples, 0);
    const src = c.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = t.playbackRate;
    src.connect(out);
    const at = Math.max(c.currentTime + 0.04, nextAt);
    src.start(at);
    nextAt = at + buf.duration / t.playbackRate;
    sources.add(src);
    setPlaying(true);
    // Sentence i begins at `at`: let the runtime generate further ahead.
    const sid = msg.session;
    const tm = setTimeout(() => { timers.delete(tm); void state.client.call("tts.progress", { session: sid, played: (msg.i ?? 0) + 1 }).catch(() => {}); }, Math.max(0, (at - c.currentTime) * 1000));
    timers.add(tm);
    src.onended = () => { sources.delete(src); settle(); };
  }

  /** The runtime sent the last sentence of this reply. */
  function done(id) {
    if (id !== session) return;
    ended = true;
    settle();
  }

  function cut() {
    for (const s of sources) { try { s.onended = null; s.stop(); } catch { /* already over */ } }
    sources.clear();
    for (const t of timers) clearTimeout(t);
    timers.clear();
    nextAt = 0;
  }

  /** Stops talking now. */
  function stop() {
    cut();
    session = null;
    ended = true;
    setPlaying(false);
  }

  /** How loud the voice is right now, 0..1 (for the orb). */
  function level() {
    if (!analyser || !playing) return 0;
    analyser.getByteTimeDomainData(data);
    let sum = 0;
    for (let i = 0; i < data.length; i++) { const v = (data[i] - 128) / 128; sum += v * v; }
    return Math.min(1, Math.sqrt(sum / data.length) * 3.2);
  }

  return { open, add, done, stop, level, get playing() { return playing; }, get session() { return session; }, close: () => { stop(); void ctx?.close().catch(() => {}); ctx = null; } };
}
