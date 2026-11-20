// The notch's sounds, made in code with Web Audio (original; no sound files). Short and soft, 8-bit flavoured:
//   done    "pu-pu-pu-pu" rising blips, then a bright three-note chime
//   needs   a rising two-tone call, played twice, the second softer
//   failed  two falling low notes
//   open / close / send   tiny ticks
// play(kind) does nothing while sounds are off.

let ctx = null;
let master = null;
let on = true;

function audio() {
  if (ctx) return ctx;
  ctx = new AudioContext();
  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -18;
  comp.ratio.value = 4;
  master = ctx.createGain();
  master.gain.value = 0.32;
  master.connect(comp).connect(ctx.destination);
  return ctx;
}

/** One note: oscillator type, start offset (s), length (s), frequency (Hz), peak gain, optional pitch bend factor. */
function note(type, at, len, freq, peak, bend = 1, attack = 0.006) {
  const a = audio();
  const t = a.currentTime + at;
  const o = a.createOscillator();
  const g = a.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq * bend, t);
  if (bend !== 1) o.frequency.exponentialRampToValueAtTime(freq, t + Math.min(0.05, len * 0.6));
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(peak, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + len);
  o.connect(g).connect(master);
  o.start(t);
  o.stop(t + len + 0.02);
}

function tick(at, freq, peak) {
  const a = audio();
  const t = a.currentTime + at;
  const len = 0.03;
  const buf = a.createBuffer(1, Math.floor(a.sampleRate * len), a.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length) ** 3;
  const src = a.createBufferSource();
  src.buffer = buf;
  const f = a.createBiquadFilter();
  f.type = "bandpass";
  f.frequency.value = freq;
  f.Q.value = 3;
  const g = a.createGain();
  g.gain.value = peak;
  src.connect(f).connect(g).connect(master);
  src.start(t);
}

const SOUNDS = {
  done() {
    // pu pu pu pu
    [523, 587, 698, 784].forEach((f, i) => note("triangle", i * 0.085, 0.075, f, 0.5, 1.35, 0.004));
    // success chime: a strummed bright chord with a sparkle on top
    const s = 0.38;
    note("sine", s, 0.75, 1047, 0.38);
    note("sine", s + 0.035, 0.7, 1319, 0.3);
    note("sine", s + 0.07, 0.65, 1568, 0.26);
    note("square", s + 0.07, 0.09, 2093, 0.05);
    note("sine", s + 0.16, 0.5, 2637, 0.08);
  },
  needs() {
    note("triangle", 0, 0.13, 659, 0.55, 0.92);
    note("triangle", 0.12, 0.22, 988, 0.5, 0.94);
    note("square", 0.12, 0.05, 1976, 0.04);
    note("triangle", 0.42, 0.11, 659, 0.28, 0.92);
    note("triangle", 0.52, 0.2, 988, 0.26, 0.94);
  },
  failed() {
    note("square", 0, 0.16, 392, 0.16);
    note("triangle", 0, 0.16, 392, 0.35);
    note("square", 0.17, 0.3, 262, 0.14, 1.06);
    note("triangle", 0.17, 0.3, 262, 0.35, 1.06);
  },
  open() { tick(0, 2400, 0.35); note("sine", 0, 0.08, 1760, 0.05); },
  close() { tick(0, 1500, 0.25); },
  send() { note("triangle", 0, 0.07, 880, 0.3, 0.8); note("triangle", 0.06, 0.1, 1320, 0.26, 0.85); },
};

export function setSounds(enabled) { on = enabled !== false; }

export function play(kind) {
  if (!on || !SOUNDS[kind]) return;
  try {
    const a = audio();
    if (a.state === "suspended") void a.resume();
    SOUNDS[kind]();
  } catch { /* no audio device */ }
}
