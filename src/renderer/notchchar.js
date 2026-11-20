// Opscode's notch character, "Ember": a small flame-topped creature drawn as pixel art in code (original art).
// Poses: sleeping (eyes shut, small dim flame, Z's float up), working (eyes dart, flame flickers, little bob),
// needs (waves, wide eyes, a blinking "!"), done (happy eyes, jumps, sparkles), error (X eyes, shakes).
// One timer per character, at the pose's own frame rate; nothing runs while the page is hidden.

const W = 18;
const H = 16;
// Body on a 13x11 grid, placed at (OX, OY) inside the W x H canvas (room around it for the flame tip, arm and particles).
const OX = 2;
const OY = 4;
const BODY = [
  "....bbbb.....",
  "..dbbbbbbbd..",
  ".dbhhbbbbbbd.",
  ".dbhbbbbbbbd.",
  ".dbbbbbbbbbd.",
  ".dbbbbbbbbbd.",
  ".dbbbbbbbbbd.",
  ".ddbbbbbbbdd.",
  "..ddddddddd..",
  "...d.....d...",
];
const PAL = {
  b: "#ff5a36", // body
  h: "#ffa27a", // highlight
  d: "#c9301c", // shade
  w: "#ffffff",
  p: "#1b0705",
  m: "#5b0f08", // mouth
  f1: "#ffd166", // flame core
  f2: "#ff8a3d",
  f3: "#ff3b30",
  z: "#9aa7c7",
  s: "#ffe9b0", // sparkle
  r: "#ff3b30", // alert red
};
const FPS = { sleeping: 4, working: 9, needs: 10, done: 12, error: 12, listen: 6, talk: 9 };

function px(g, x, y, c) { g.fillStyle = c; g.fillRect(x, y, 1, 1); }

function drawBody(g, dx, dy, dim) {
  for (let y = 0; y < BODY.length; y++) {
    const row = BODY[y];
    for (let x = 0; x < row.length; x++) {
      const k = row[x];
      if (k === ".") continue;
      px(g, OX + x + dx, OY + y + dy, PAL[k]);
    }
  }
  if (dim) { g.fillStyle = "rgba(0,0,0,.28)"; g.fillRect(0, 0, W, H); }
}

function flame(g, dx, dy, f, size) {
  // The tuft on top of the head, flickering between shapes.
  const x0 = OX + 6 + dx;
  const y0 = OY - 1 + dy;
  if (size === 0) { px(g, x0, y0, PAL.f2); return; }
  const shapes = [
    [[0, 0, "f2"], [0, -1, "f1"], [1, -1, "f2"], [0, -2, "f3"]],
    [[0, 0, "f2"], [-1, -1, "f2"], [0, -1, "f1"], [-1, -2, "f3"], [0, -3, "f3"]],
    [[0, 0, "f2"], [0, -1, "f1"], [1, -2, "f2"], [1, -3, "f3"]],
  ];
  for (const [x, y, c] of shapes[f % 3]) px(g, x0 + x, y0 + y, PAL[c]);
}

function eyes(g, kind, dx, dy, look = 0) {
  const L = OX + 3 + dx, R = OX + 8 + dx, Y = OY + 3 + dy;
  const pair = (fn) => { fn(L); fn(R); };
  switch (kind) {
    case "shut": pair((x) => { px(g, x, Y + 1, PAL.p); px(g, x + 1, Y + 1, PAL.p); }); break;
    case "happy": pair((x) => { px(g, x, Y + 1, PAL.p); px(g, x + 1, Y, PAL.p); px(g, x + 2, Y + 1, PAL.p); }); break;
    case "x": pair((x) => { px(g, x, Y, PAL.p); px(g, x + 1, Y + 1, PAL.p); px(g, x + 2, Y, PAL.p); px(g, x, Y + 2, PAL.p); px(g, x + 2, Y + 2, PAL.p); }); break;
    case "wide": pair((x) => { g.fillStyle = PAL.w; g.fillRect(x, Y, 2, 2); px(g, x + (look > 0 ? 1 : 0), Y + 1, PAL.p); }); break;
    default: pair((x) => { g.fillStyle = PAL.w; g.fillRect(x, Y, 2, 2); px(g, x + (look > 0 ? 1 : 0), Y + (look === 2 ? 0 : 1), PAL.p); });
  }
}

function mouth(g, kind, dx, dy) {
  const x = OX + 6 + dx, y = OY + 6 + dy;
  if (kind === "o") { g.fillStyle = PAL.m; g.fillRect(x, y, 1, 2); }
  else if (kind === "smile") { px(g, x - 1, y, PAL.m); px(g, x, y + 1, PAL.m); px(g, x + 1, y, PAL.m); }
  else if (kind === "flat") { px(g, x, y, PAL.m); px(g, x + 1, y, PAL.m); }
  else px(g, x, y, PAL.m);
}

const Z = [[0, 0], [1, 0], [2, 0], [1, 1], [0, 2], [1, 2], [2, 2]];

function frame(g, pose, f, t) {
  g.clearRect(0, 0, W, H);
  switch (pose) {
    case "sleeping": {
      const breathe = f % 8 < 4 ? 0 : 1; // slow breathing: the body sinks a pixel
      drawBody(g, 0, breathe, true);
      flame(g, 0, breathe, f, f % 6 < 3 ? 0 : 1);
      eyes(g, "shut", 0, breathe);
      // A "z" rising from the right, fading as it goes.
      const k = f % 12;
      const a = 1 - k / 12;
      g.globalAlpha = Math.max(0, a);
      for (const [x, y] of Z) px(g, 14 + x - Math.floor(k / 6), 6 - Math.floor(k / 2) + y, PAL.z);
      g.globalAlpha = 1;
      break;
    }
    case "working": {
      const bob = f % 4 === 1 ? -1 : 0;
      drawBody(g, 0, bob);
      flame(g, 0, bob, f, 2);
      const look = Math.floor(f / 6) % 4; // left, center, right, up
      eyes(g, "open", 0, bob, look === 2 ? 1 : look === 3 ? 2 : 0);
      mouth(g, "dot", 0, bob);
      // Two small sparks above the flame.
      if (f % 3 === 0) px(g, OX + 4 + (f % 5), 0, PAL.f1);
      break;
    }
    case "needs": {
      const up = f % 4 < 2;
      drawBody(g, 0, 0);
      flame(g, 0, 0, f, 2);
      eyes(g, "wide", 0, 0, 0);
      mouth(g, "o", 0, 0);
      // Waving arm on the right.
      const ax = OX + 12, ay = OY + 3;
      if (up) { px(g, ax, ay, PAL.b); px(g, ax + 1, ay - 1, PAL.b); px(g, ax + 1, ay - 2, PAL.h); }
      else { px(g, ax, ay, PAL.b); px(g, ax + 1, ay, PAL.b); px(g, ax + 2, ay - 1, PAL.h); }
      // A blinking "!" over the head.
      if (f % 6 < 4) { g.fillStyle = PAL.r; g.fillRect(2, 0, 1, 3); px(g, 2, 4, PAL.r); }
      break;
    }
    case "done": {
      const hop = [0, -2, -3, -2, 0, 0, 0, 0][f % 8];
      drawBody(g, 0, hop);
      flame(g, 0, hop, f, 2);
      eyes(g, "happy", 0, hop);
      mouth(g, "smile", 0, hop);
      const sp = [[1, 3], [16, 2], [15, 9], [0, 10]];
      sp.forEach(([x, y], i) => { if ((f + i * 2) % 6 < 2) { px(g, x, y, PAL.s); px(g, x + 1, y, "rgba(255,233,176,.5)"); } });
      break;
    }
    case "listen": {
      // Voice mode, waiting for the person: eyes on them, a slow blink, the flame steady.
      drawBody(g, 0, 0);
      flame(g, 0, 0, f, 2);
      if (f % 24 === 23) eyes(g, "shut", 0, 0); else eyes(g, "wide", 0, 0, 0);
      mouth(g, "dot", 0, 0);
      // A small "sound" arc beside the head while it listens.
      const k = f % 6;
      g.globalAlpha = k < 3 ? 0.9 : 0.4;
      px(g, 16, 6, PAL.f1); px(g, 17, 7, PAL.f1); px(g, 16, 8, PAL.f1);
      g.globalAlpha = 1;
      break;
    }
    case "talk": {
      // Voice mode, speaking: the mouth opens and closes, a tiny bob.
      const bob = f % 6 === 3 ? -1 : 0;
      drawBody(g, 0, bob);
      flame(g, 0, bob, f, 2);
      eyes(g, "open", 0, bob, 0);
      mouth(g, f % 3 === 0 ? "dot" : f % 3 === 1 ? "o" : "smile", 0, bob);
      break;
    }
    case "error": {
      const dx = [0, 1, 0, -1][f % 4];
      drawBody(g, dx, 0);
      flame(g, dx, 0, 1, 0);
      eyes(g, "x", dx, 0);
      mouth(g, "flat", dx, 0);
      break;
    }
  }
  void t;
}

const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

/** A character on a canvas. scale = device pixels per art pixel. Returns { el, setPose(pose), destroy() }. */
export function createCharacter(scale = 3, cssScale = 1.5) {
  const el = document.createElement("canvas");
  el.className = "ember";
  el.width = W * scale;
  el.height = H * scale;
  el.style.width = `${W * cssScale}px`;
  el.style.height = `${H * cssScale}px`;
  el.setAttribute("aria-hidden", "true");
  const g = el.getContext("2d");
  g.imageSmoothingEnabled = false;
  g.scale(scale, scale);
  let pose = "sleeping";
  let f = 0;
  let timer = 0;
  const tick = () => {
    timer = 0;
    if (!el.isConnected) return;
    frame(g, pose, f++, performance.now());
    if (reduced() && pose !== "needs") return; // still picture
    if (!document.hidden) timer = setTimeout(tick, 1000 / FPS[pose]);
  };
  document.addEventListener("visibilitychange", () => { if (!document.hidden && !timer) tick(); });
  return {
    el,
    setPose(next) {
      if (next === pose && timer) return;
      if (next !== pose) f = 0;
      pose = FPS[next] ? next : "sleeping";
      clearTimeout(timer);
      timer = 0;
      queueMicrotask(tick);
    },
    get pose() { return pose; },
    destroy() { clearTimeout(timer); timer = 0; el.remove(); },
  };
}

// ---- pixel digits (3x5) for counts in the ears ----
const DIGITS = {
  0: "111101101101111", 1: "010110010010111", 2: "111001111100111", 3: "111001111001111", 4: "101101111001001",
  5: "111100111001111", 6: "111100111101111", 7: "111001010010010", 8: "111101111101111", 9: "111101111001111", "+": "000010111010000",
};

/** Draws a number in 3x5 pixel digits on a new canvas (device scale px per dot). */
export function pixelNumber(n, color = "#fff", scale = 2, cssDot = 1) {
  const text = n > 9 ? "9+" : String(n);
  const w = text.length * 4 - 1;
  const c = document.createElement("canvas");
  c.className = "pxnum";
  c.width = w * scale;
  c.height = 5 * scale;
  c.style.width = `${w * cssDot}px`;
  c.style.height = `${5 * cssDot}px`;
  const g = c.getContext("2d");
  g.fillStyle = color;
  [...text].forEach((ch, i) => {
    const bits = DIGITS[ch] ?? DIGITS[0];
    for (let k = 0; k < 15; k++) if (bits[k] === "1") g.fillRect((i * 4 + (k % 3)) * scale, Math.floor(k / 3) * scale, scale, scale);
  });
  return c;
}
