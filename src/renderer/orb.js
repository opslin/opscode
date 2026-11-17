// The voice orb: a ring of square pixels around a pixel microphone that listens, hears, thinks and speaks.
// Drawn on a canvas with every pixel snapped to a 3 px grid (own art; colours come from the chat's --crew-1 / --crew-2).
//   listening  a slow breathing ring       hearing   the ring swells with your voice
//   thinking   a comet circles the ring    speaking  waves roll out with the agent's voice
//   muted      grey and still              starting  pixels fly in and form the ring

const CELL = 3;
const RINGS = [{ r: 62, n: 72, s: 4 }, { r: 50, n: 56, s: 3 }, { r: 38, n: 40, s: 3 }];
const MIC = [
  "...###...",
  "..#####..",
  "..#####..",
  "..#####..",
  "..#####..",
  "..#####..",
  "..#####..",
  "...###...",
  "#.......#",
  "#.......#",
  ".#.....#.",
  "..#####..",
  "....#....",
  "....#....",
  "..#####..",
];
const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
const ease = (k) => 1 - Math.pow(1 - Math.min(1, Math.max(0, k)), 3);
const TAU = Math.PI * 2;

export function createOrb({ size = 176 } = {}) {
  const canvas = document.createElement("canvas");
  canvas.className = "orb-canvas";
  canvas.setAttribute("aria-hidden", "true");
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  canvas.width = Math.round(size * dpr);
  canvas.height = Math.round(size * dpr);
  canvas.style.width = `${size}px`;
  canvas.style.height = `${size}px`;
  const g = canvas.getContext("2d");
  g.scale(dpr, dpr);
  const cx = size / 2;
  const cy = size / 2;

  let phase = "idle";
  let muted = false;
  let source = () => 0; // current loudness 0..1
  let lv = 0;
  let born = performance.now();
  let leaving = 0; // performance.now() when the dissolve began
  let leaveMs = 0;
  let leaveDone = null;
  let raf = 0;
  let c1 = "#D97757";
  let c2 = "#f2c9a8";
  // Where each pixel flies in from.
  const scatter = RINGS.map((ring) => Array.from({ length: ring.n }, () => ({ a: Math.random() * TAU, d: 40 + Math.random() * 90 })));
  const drift = RINGS.map((ring) => Array.from({ length: ring.n }, () => ({ a: Math.random() * TAU, v: 0.4 + Math.random() })));

  const readColors = () => {
    const cs = getComputedStyle(canvas);
    c1 = cs.getPropertyValue("--crew-1").trim() || "#D97757";
    c2 = cs.getPropertyValue("--crew-2").trim() || "#f2c9a8";
  };
  const snap = (v) => Math.round(v / CELL) * CELL;

  function frame(now) {
    raf = requestAnimationFrame(frame);
    if (!canvas.isConnected) return;
    const t = now / 1000;
    const k = reduced() ? 1 : ease((now - born) / 800);
    const out = leaving ? Math.min(1, (now - leaving) / leaveMs) : 0;
    lv += (Math.min(1, source()) - lv) * 0.35;
    g.clearRect(0, 0, size, size);
    const state = muted ? "muted" : phase;
    RINGS.forEach((ring, ri) => {
      for (let i = 0; i < ring.n; i++) {
        const a = (i / ring.n) * TAU + ri * 0.07;
        let amp = 0;
        let alpha = 0.2 + ri * 0.03;
        let col = c1;
        switch (state) {
          case "listening":
          case "idle":
            amp = 1.4 * Math.sin(t * 1.1 + i * 0.42 + ri) + lv * 5;
            alpha += 0.14 * (0.5 + 0.5 * Math.sin(t * 1.1 + i * 0.42));
            break;
          case "hearing":
            amp = lv * (11 + ri * 2) * (0.55 + 0.45 * Math.sin(i * 1.7 + t * 10)) + 1;
            alpha = 0.5 + 0.45 * lv;
            col = i % 5 === 0 ? c2 : c1;
            break;
          case "thinking": {
            const head = (t * (2.4 + ri * 0.35)) % TAU;
            let d = (head - a) % TAU;
            if (d < 0) d += TAU;
            const tail = Math.max(0, 1 - d / 1.7);
            alpha = 0.16 + 0.8 * tail;
            amp = tail * 4;
            col = tail > 0.8 ? c2 : c1;
            break;
          }
          case "speaking":
            amp = lv * 13 * (0.5 + 0.5 * Math.sin(i * 0.9 - t * 8 + ri * 1.3)) + 1.2 * Math.sin(t * 2 + i);
            alpha = 0.36 + 0.55 * Math.min(1, lv * 1.4);
            col = (i + Math.floor(t * 12)) % 6 === 0 ? c2 : c1;
            break;
          case "muted":
            alpha = 0.13;
            col = "#8d8d92";
            break;
          default: // starting
            alpha = 0.18;
        }
        let r = ring.r + amp;
        let x = cx + Math.cos(a) * r;
        let y = cy + Math.sin(a) * r;
        if (k < 1) { // flying in
          const sc = scatter[ri][i];
          x = cx + Math.cos(sc.a) * sc.d * (1 - k) + (x - cx) * k;
          y = cy + Math.sin(sc.a) * sc.d * (1 - k) + (y - cy) * k;
          alpha *= 0.3 + 0.7 * k;
        }
        if (out > 0) { // dissolving: every pixel drifts outward and fades
          const dr = drift[ri][i];
          x += Math.cos(dr.a) * out * 70 * dr.v;
          y += Math.sin(dr.a) * out * 70 * dr.v + out * out * 40;
          alpha *= 1 - out;
        }
        g.globalAlpha = Math.max(0, Math.min(1, alpha));
        g.fillStyle = col;
        g.fillRect(snap(x) - ring.s / 2, snap(y) - ring.s / 2, ring.s, ring.s);
      }
    });
    // The pixel microphone in the middle.
    const mw = MIC[0].length * CELL;
    const mh = MIC.length * CELL;
    const mx = Math.round(cx - mw / 2);
    const my = Math.round(cy - mh / 2);
    const pulse = state === "speaking" ? 0.65 + 0.35 * Math.min(1, lv * 1.6) : state === "thinking" ? 0.55 + 0.35 * Math.sin(t * 5) ** 2 : state === "muted" ? 0.4 : 0.92;
    g.globalAlpha = Math.max(0, pulse * k * (1 - out));
    g.fillStyle = state === "muted" ? "#9a9a9f" : state === "hearing" ? "#ffffff" : c1;
    for (let y = 0; y < MIC.length; y++) for (let x = 0; x < MIC[y].length; x++) if (MIC[y][x] === "#") g.fillRect(mx + x * CELL, my + y * CELL, CELL, CELL);
    if (state === "muted") { // a slash through it
      g.fillStyle = "#ef6a6a";
      for (let s = 0; s < 18; s++) g.fillRect(mx - 3 + s * 2.4, my + s * 2.6, CELL, CELL);
    }
    g.globalAlpha = 1;
    if (out >= 1) { leaving = 0; const done = leaveDone; leaveDone = null; done?.(); }
  }

  return {
    el: canvas,
    /** "starting" | "listening" | "hearing" | "thinking" | "speaking" */
    set(p) { phase = p; },
    setMuted(m) { muted = !!m; },
    /** A function returning the current loudness, 0..1. */
    levelFrom(fn) { source = fn; },
    start() { readColors(); born = performance.now(); leaving = 0; cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); },
    /** The pixels drift apart and fade (resolves when done). */
    dissolve(ms = 420) {
      if (reduced()) return Promise.resolve();
      return new Promise((resolve) => { leaving = performance.now(); leaveMs = ms; leaveDone = resolve; });
    },
    stop() { cancelAnimationFrame(raf); raf = 0; },
  };
}
