// Pixel effects drawn on a throwaway <canvas> above the page:
//  - pixelBurst(): square sparks when effort goes up (warmer and more of them each step;
//    Max burns red).
//  - pixelReveal(): a new chat's welcome arrives through a dissolving grid of pixels.
// Both skip themselves when the person asks for reduced motion, and clean up on their own.

const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

function overlay(x, y, w, h) {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const c = document.createElement("canvas");
  c.className = "pfx";
  c.width = Math.ceil(w * dpr);
  c.height = Math.ceil(h * dpr);
  c.style.cssText = `left:${x}px;top:${y}px;width:${w}px;height:${h}px`;
  document.body.append(c);
  const g = c.getContext("2d");
  g.scale(dpr, dpr);
  return { c, g };
}

// Effort 0..4 -> palette: quiet grey, warm, orange, hot, red.
const RAMP = [
  ["#9a9a9e", "#c8c8cc"],
  ["#c8c8cc", "#e7b08f"],
  ["#e7b08f", "#D97757", "#f2c9a8"],
  ["#D97757", "#f08a4b", "#ffd2a6"],
  ["#ff4d4d", "#ff7a45", "#ffd166", "#D97757"],
];

/** Sparks out of `el` (or a point in it). level 0..4. */
export function pixelBurst(el, level = 2, at) {
  if (reduced() || !el?.isConnected) return;
  const r = el.getBoundingClientRect();
  const cx = at?.x ?? r.left + r.width / 2;
  const cy = at?.y ?? r.top + r.height / 2;
  const pad = 70 + level * 14;
  const { c, g } = overlay(cx - pad, cy - pad, pad * 2, pad * 2);
  const colors = RAMP[Math.max(0, Math.min(4, level))];
  const n = 8 + level * 7;
  const parts = Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2 + Math.random() * 0.6;
    const sp = 0.9 + Math.random() * (1.4 + level * 0.45);
    return { x: pad, y: pad, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - (0.6 + level * 0.25), s: Math.random() < 0.3 ? 3 : 2, col: colors[(Math.random() * colors.length) | 0], life: 26 + Math.random() * (18 + level * 6) };
  });
  let t = 0;
  const step = () => {
    t++;
    g.clearRect(0, 0, pad * 2, pad * 2);
    let alive = 0;
    for (const p of parts) {
      if (t > p.life) continue;
      alive++;
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.06; // a little gravity
      p.vx *= 0.97;
      g.globalAlpha = Math.max(0, 1 - t / p.life);
      g.fillStyle = p.col;
      // Snap to whole pixels so the sparks stay crisp squares.
      g.fillRect(Math.round(p.x), Math.round(p.y), p.s, p.s);
    }
    if (alive) requestAnimationFrame(step);
    else c.remove();
  };
  requestAnimationFrame(step);
}

/** Covers `el` with a pixel grid in the page colour and dissolves it, top-left to bottom-right with some noise. */
export function pixelReveal(el, { cell = 10, ms = 520 } = {}) {
  if (reduced() || !el?.isConnected) return;
  const r = el.getBoundingClientRect();
  if (r.width < 4 || r.height < 4) return;
  const { c, g } = overlay(r.left, r.top, r.width, r.height);
  const bg = getComputedStyle(document.body).backgroundColor || "#111";
  const cols = Math.ceil(r.width / cell);
  const rows = Math.ceil(r.height / cell);
  // Each cell's moment to vanish: a diagonal sweep plus noise, 0..1.
  const at = new Float32Array(cols * rows);
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) at[y * cols + x] = Math.min(1, ((x / cols) * 0.55 + (y / rows) * 0.45) * 0.75 + Math.random() * 0.25);
  const start = performance.now();
  const step = (now) => {
    const k = (now - start) / ms;
    g.clearRect(0, 0, r.width, r.height);
    g.fillStyle = bg;
    let left = 0;
    for (let i = 0; i < at.length; i++) {
      if (at[i] <= k) continue;
      left++;
      g.fillRect((i % cols) * cell, Math.floor(i / cols) * cell, cell, cell);
    }
    // A few bright pixels ride the edge of the sweep.
    g.fillStyle = "rgba(217,119,87,0.55)";
    for (let i = 0; i < at.length; i += 7) if (Math.abs(at[i] - k) < 0.025) g.fillRect((i % cols) * cell + cell / 2 - 1, Math.floor(i / cols) * cell + cell / 2 - 1, 2, 2);
    if (left && k < 1.1) requestAnimationFrame(step);
    else c.remove();
  };
  requestAnimationFrame(step);
}

/**
 * `el` breaks into pixels that scatter and fade (the text box leaving when voice mode opens). The element itself is
 * hidden by the caller; this paints cells of its colours over its area, each drifting off after a short delay.
 */
export function pixelVanish(el, { cell = 8, ms = 520, fill: fillColor } = {}) {
  if (reduced() || !el?.isConnected) return;
  const r = el.getBoundingClientRect();
  if (r.width < 4 || r.height < 4) return;
  const pad = 40;
  const { c, g } = overlay(r.left - pad, r.top - pad, r.width + pad * 2, r.height + pad * 2);
  const cs = getComputedStyle(document.body);
  const bg = fillColor || getComputedStyle(el).backgroundColor;
  const fill = bg && bg !== "rgba(0, 0, 0, 0)" ? bg : cs.backgroundColor || "#1b1c1b";
  const ink = cs.color || "#ddd";
  const cols = Math.ceil(r.width / cell);
  const rows = Math.ceil(r.height / cell);
  const cells = [];
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
    const speck = Math.random() < 0.16;
    cells.push({ x: pad + x * cell, y: pad + y * cell, col: speck ? (Math.random() < 0.3 ? "rgba(217,119,87,0.9)" : ink) : fill, a: speck ? 0.9 : 1, delay: (x / cols) * 0.45 + Math.random() * 0.2, vx: (Math.random() - 0.35) * 2.6, vy: (Math.random() - 0.75) * 2.2, ox: 0, oy: 0 });
  }
  const start = performance.now();
  const W = r.width + pad * 2;
  const H = r.height + pad * 2;
  const step = (now) => {
    const k = (now - start) / ms;
    g.clearRect(0, 0, W, H);
    let alive = 0;
    for (const p of cells) {
      const q = (k - p.delay) / 0.55;
      if (q >= 1) continue;
      alive++;
      if (q > 0) { p.ox += p.vx; p.oy += p.vy + q * 0.6; }
      g.globalAlpha = q <= 0 ? p.a : p.a * (1 - q);
      g.fillStyle = p.col;
      g.fillRect(Math.round(p.x + p.ox), Math.round(p.y + p.oy), cell, cell);
    }
    if (alive && k < 1.6) requestAnimationFrame(step);
    else c.remove();
  };
  requestAnimationFrame(step);
}

// ---- launch: a mode's pixel animation from Send until the work starts ----------------------
// GODMODE: golden rays and a halo burst from the centre. WARLORD: embers and flames rise.
// SHINOBI: fast diagonal slashes and smoke. Normal: warm pixels drift upward.
// It covers `host`'s box (fixed to the window, so it survives switching to the Conductor page)
// and stays until endLaunch() — called when the first output arrives — or 30 s pass.

const LAUNCH_LINES = { normal: "Starting", godmode: "GODMODE rising", warlord: "WARLORD marching", shinobi: "SHINOBI moving" };
let current = null;

/** Starts the launch animation over `host`. colors = [c1, c2, ...extra]. */
export function launchFx(host, mode, colors) {
  endLaunch(true);
  if (!host?.isConnected) return null;
  const r = host.getBoundingClientRect();
  const W = Math.max(1, r.width), H = Math.max(1, r.height);
  const { c, g } = overlay(r.left, r.top, W, H);
  c.classList.add("pfx-launch");
  const cap = document.createElement("div");
  cap.className = "pfx-launch-cap";
  cap.dataset.mode = mode;
  cap.style.cssText = `left:${r.left + W / 2}px;top:${r.top + H * 0.42}px;--c1:${colors[0]};--c2:${colors[1]}`;
  cap.innerHTML = `<i></i><span></span><i></i>`;
  cap.querySelector("span").textContent = LAUNCH_LINES[mode] ?? "Starting";
  document.body.append(cap);
  const still = reduced();
  const P = 4; // art pixel size
  const cx = W / 2, cy = H * 0.42;
  const parts = [];
  const pick = () => colors[(Math.random() * colors.length) | 0];
  const spawn = () => {
    if (mode === "godmode") {
      for (let i = 0; i < 6; i++) {
        const a = Math.random() * Math.PI * 2, sp = 2 + Math.random() * 4;
        parts.push({ x: cx, y: cy, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: 50 + Math.random() * 30, col: pick(), s: P, kind: "ray" });
      }
    } else if (mode === "warlord") {
      for (let i = 0; i < 7; i++) parts.push({ x: Math.random() * W, y: H + 4, vx: (Math.random() - 0.5) * 0.8, vy: -(1.5 + Math.random() * 3.2), life: 70 + Math.random() * 60, col: pick(), s: Math.random() < 0.3 ? P * 2 : P, kind: "ember" });
    } else if (mode === "shinobi") {
      if (Math.random() < 0.55) {
        const y = Math.random() * H;
        parts.push({ x: -40, y, vx: 14 + Math.random() * 10, vy: 5 + Math.random() * 3, life: 60, col: pick(), s: P, kind: "slash" });
      }
      for (let i = 0; i < 3; i++) parts.push({ x: Math.random() * W, y: H * (0.3 + Math.random() * 0.6), vx: (Math.random() - 0.5) * 0.6, vy: -0.4 - Math.random() * 0.5, life: 50 + Math.random() * 40, col: "rgba(200,210,235,0.5)", s: P * 2, kind: "smoke" });
    } else {
      for (let i = 0; i < 5; i++) parts.push({ x: Math.random() * W, y: H + 4, vx: 0, vy: -(2 + Math.random() * 3), life: 90, col: pick(), s: P, kind: "rain" });
    }
  };
  let t = 0, raf = 0, fade = 1, ending = false, haloR = 0;
  const snap = (v) => Math.round(v / P) * P;
  const step = () => {
    t++;
    g.clearRect(0, 0, W, H);
    if (!ending && t % 2 === 0) spawn();
    if (mode === "godmode") {
      // A stepped pixel halo that keeps pulsing outward.
      haloR = (haloR + 3) % (Math.max(W, H) * 0.7);
      g.globalAlpha = fade * Math.max(0, 0.6 - haloR / (Math.max(W, H) * 0.7));
      g.fillStyle = colors[0];
      for (let a = 0; a < Math.PI * 2; a += 0.06) g.fillRect(snap(cx + Math.cos(a) * haloR), snap(cy + Math.sin(a) * haloR * 0.8), P, P);
    }
    let alive = 0;
    for (const p of parts) {
      if (p.life <= 0) continue;
      p.life--;
      alive++;
      p.x += p.vx;
      p.y += p.vy;
      if (p.kind === "ray") { p.vx *= 1.04; p.vy *= 1.04; }
      if (p.kind === "ember") p.vx += (Math.random() - 0.5) * 0.3;
      if (p.kind === "smoke") p.s += 0.08;
      g.globalAlpha = fade * Math.min(1, p.life / 30) * (p.kind === "ember" && Math.random() < 0.15 ? 0.4 : 1);
      g.fillStyle = p.col;
      if (p.kind === "slash") {
        // A streak: a run of pixels behind the head, thinning out.
        for (let k = 0; k < 9; k++) { g.globalAlpha = fade * (1 - k / 9); g.fillRect(snap(p.x - k * p.vx * 0.5), snap(p.y - k * p.vy * 0.5), P, P); }
      } else if (p.kind === "ray") {
        g.fillRect(snap(p.x), snap(p.y), P, P);
        g.globalAlpha *= 0.45;
        g.fillRect(snap(p.x - p.vx * 1.5), snap(p.y - p.vy * 1.5), P, P);
      } else {
        g.fillRect(snap(p.x), snap(p.y), snap(p.s) || P, snap(p.s) || P);
      }
    }
    for (let i = parts.length - 1; i >= 0; i--) if (parts[i].life <= 0) parts.splice(i, 1);
    if (ending) fade -= 0.06;
    if (ending && (fade <= 0 || alive === 0)) return finish();
    raf = requestAnimationFrame(step);
  };
  const finish = () => { cancelAnimationFrame(raf); c.remove(); cap.remove(); if (current === handle) current = null; };
  const started = performance.now();
  const handle = {
    done(now = false) {
      if (ending) return;
      if (now || still) return finish();
      // Keep it on screen at least ~0.9 s so it reads as an effect, not a flicker.
      const wait = Math.max(0, 900 - (performance.now() - started));
      setTimeout(() => { ending = true; cap.classList.add("out"); }, wait);
    },
  };
  current = handle;
  if (!still) raf = requestAnimationFrame(step);
  setTimeout(() => handle.done(), 30000);
  return handle;
}

/** Ends the running launch animation (the first output arrived). */
export function endLaunch(now = false) { current?.done(now); }
