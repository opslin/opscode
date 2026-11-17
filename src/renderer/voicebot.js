// The voice agent as a little pixel robot on the voice stage. It shows what the agent is doing:
//   start   walks to a new worker's card carrying a parcel (the brief), lifts it in, comes back
//   visit   walks to a worker's card, steps inside to check on it, comes back out to tell you
//   peek    reads a page of the project next to the orb
//   browse  walks to the live browser screen: goes in to open a site, scrolls with its arm, taps, looks
//   home    walks back next to the orb
//   cheer   a happy hop with sparkles (a worker finished)
// Idle it breathes, blinks and looks around; thinking shows orbiting dots; talking shows an equalizer mouth.
// Own pixel art on a canvas (4 px cells) in the chat's crew colours. Reduced motion: no walking, no idle motion.

const CELL = 4;
const W = 15;
const H = 21; // 3 rows on top for thought dots and sparkles
const TOP = 3;
const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
const sleep = (ms) => new Promise((r) => setTimeout(r, reduced() ? Math.min(ms, 60) : ms));

// Rows below the effect rows. h head, H highlight, d head shade, v visor, o body, O body shade, c chest light,
// a antenna bulb, s antenna stem, k legs/feet. Eyes and mouth are drawn on the visor separately.
const HEAD = [
  ".......a.......",
  ".......s.......",
  "...hhhhhhhhh...",
  "..hHHhhhhhhhhd.",
  "..hvvvvvvvvvhd.",
  "..hvvvvvvvvvhd.",
  "..hvvvvvvvvvhd.",
  "..hhhhhhhhhhhd.",
  "...ddddddddd...",
];
const BODY = [
  "....ooooooo....",
  "...oOOOOOOOo...",
  "...oOOcccOOo...",
  "...oOOOOOOOo...",
  "....ooooooo....",
];
const LEGS = {
  stand: [".....kk.kk.....", ".....kk.kk.....", "....kkk.kkk...."],
  walkA: ["....kk...kk....", "...kk.....kk...", "..kkk.....kkk.."],
  walkB: [".....kkkk......", "......kk.......", ".....kkk......."],
  hop: ["....kk...kk....", "...kk.....kk...", "..............."],
};
// Arms: [x, y] cells relative to the body's top row (row 0 = first BODY row).
const ARMS = {
  down: [[2, 1], [2, 2], [2, 3], [12, 1], [12, 2], [12, 3]],
  up: [[1, -3], [1, -2], [2, -1], [2, 0], [13, -3], [13, -2], [12, -1], [12, 0]],
  forward: [[2, 1], [1, 2], [12, 1], [13, 2]],
  scrollUp: [[2, 1], [2, 2], [2, 3], [12, 0], [13, -1], [13, -2], [14, -3]],
  scrollDown: [[2, 1], [2, 2], [2, 3], [12, 1], [13, 2], [14, 3], [14, 4]],
  tap: [[2, 1], [2, 2], [2, 3], [12, 1], [13, 1], [14, 1]],
  waveA: [[2, 1], [2, 2], [2, 3], [12, 0], [13, -1], [14, -2], [14, -3]],
  waveB: [[2, 1], [2, 2], [2, 3], [12, 0], [13, -1], [13, -2], [12, -3]],
};

/** "#d97757" / "rgb(1, 2, 3)" -> [r, g, b] (canvas cannot use CSS colour-mix). */
function rgbOf(c, fallback = [217, 119, 87]) {
  const s = String(c).trim();
  let m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(s);
  if (m) { const h = m[1].length === 3 ? [...m[1]].map((x) => x + x).join("") : m[1]; return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)); }
  m = /^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/i.exec(s);
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : fallback;
}
const mix = (a, b, t) => `rgb(${a.map((v, i) => Math.round(v + (b[i] - v) * t)).join(",")})`;

export function createVoiceBot(host) {
  const el = document.createElement("div");
  el.className = "vox-bot";
  el.setAttribute("aria-hidden", "true");
  const cv = document.createElement("canvas");
  const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
  cv.width = W * CELL * dpr;
  cv.height = H * CELL * dpr;
  cv.style.width = `${W * CELL}px`;
  cv.style.height = `${H * CELL}px`;
  const shadow = document.createElement("i");
  shadow.className = "vox-bot-shadow";
  el.append(shadow, cv);
  const g = cv.getContext("2d");
  g.scale(dpr, dpr);

  let x = 0, y = 0; // top-left in the host
  let face = 1; // 1 = right, -1 = left
  let pose = "stand"; // stand | walk | up | forward | scroll | tap | read | carry | wave
  let mood = "listening"; // listening | hearing | thinking | speaking | muted
  let frame = 0;
  let raf = 0;
  let running = false;
  let gen = 0; // bumps on every new action: an older walk stops
  let lastT = 0;
  let blinkAt = performance.now() + 2400;
  let look = 0, lookAt = performance.now() + 3000;
  let hopUntil = 0, hopFrom = 0;
  let palette = null;

  const colors = () => {
    if (palette) return palette;
    const st = getComputedStyle(host);
    const c1 = rgbOf(st.getPropertyValue("--crew-1"));
    const c2 = rgbOf(st.getPropertyValue("--crew-2"), [242, 201, 168]);
    const white = [236, 234, 230];
    palette = {
      h: "rgb(236,234,230)", H: "#ffffff", d: "rgb(196,192,186)", v: "#121418", s: "rgb(160,156,150)", k: "#2b2e35",
      o: mix(c1, c1, 0), O: mix(c1, [0, 0, 0], 0.28), E: mix(c1, white, 0.45), Eglow: mix(c1, white, 0.75),
      a1: mix(c1, white, 0.2), a2: mix(c1, [0, 0, 0], 0.2), c1: mix(c2, white, 0.3), c2: mix(c1, c2, 0.5),
      arm: "rgb(214,210,204)", box: mix(c2, c1, 0.25), boxHi: mix(c2, white, 0.35), page: "#f4f1ea", ink: "#2b2e35", spark: mix(c1, white, 0.6),
    };
    return palette;
  };

  function draw(now) {
    const C = colors();
    g.clearRect(0, 0, W * CELL, H * CELL);
    const still = reduced();
    const breathe = !still && (pose === "stand" || pose === "wave") && Math.floor(now / 700) % 2 === 1 ? 1 : 0;
    let lift = 0;
    if (now < hopUntil) { const k = (now - hopFrom) / (hopUntil - hopFrom); lift = Math.round(Math.sin(k * Math.PI * 2) ** 2 * 3); }
    const legs = pose === "walk" ? (frame % 2 ? LEGS.walkA : LEGS.walkB) : lift > 1 ? LEGS.hop : LEGS.stand;
    const put = (cx, cy, col) => {
      if (cx < 0 || cx >= W || cy < 0 || cy >= H) return;
      const px = face === 1 ? cx : W - 1 - cx;
      g.fillStyle = col;
      g.fillRect(px * CELL, cy * CELL, CELL, CELL);
    };
    // Upper body moves with breathing and hops; legs stay on the ground except in a hop.
    const up = TOP - lift;
    const headY = up + breathe;
    HEAD.forEach((row, ry) => [...row].forEach((ch, cx) => {
      if (ch === ".") return;
      let col = C[ch] ?? C.h;
      if (ch === "a") col = Math.floor(now / 450) % 2 ? C.a1 : C.a2;
      put(cx, headY + ry, col);
    }));
    // Eyes on the visor: blink, look left/right, look up while thinking.
    if (now > lookAt) { look = [-1, 0, 0, 1][Math.floor(Math.random() * 4)]; lookAt = now + 1800 + Math.random() * 2600; }
    const lk = pose === "walk" ? 1 : look;
    const blink = now > blinkAt && now < blinkAt + 130;
    if (now > blinkAt + 130) blinkAt = now + 2000 + Math.random() * 2800;
    const eyeRow = headY + (mood === "thinking" ? 4 : 5);
    if (blink) { for (const ex of [4, 5, 9, 10]) put(ex + lk, headY + 5, C.d); }
    else {
      for (const ex of [4, 9]) { put(ex + lk, eyeRow, C.E); put(ex + 1 + lk, eyeRow, C.E); put(ex + lk, eyeRow + 1, C.E); put(ex + 1 + lk, eyeRow + 1, C.Eglow); }
    }
    // Mouth: an equalizer while talking, a small smile otherwise.
    if (mood === "speaking" && pose !== "walk" && !still) {
      for (let i = 0; i < 5; i++) { const hgt = 1 + ((Math.floor(now / 90) + i * 7) % 3 === 0 ? 1 : 0); for (let k = 0; k < hgt; k++) put(5 + i, headY + 7 - k, C.E); }
    } else if (mood !== "thinking") { put(6, headY + 7, C.E); put(7, headY + 7, C.E); put(8, headY + 7, C.E); }
    // Body.
    const bodyY = up + HEAD.length;
    BODY.forEach((row, ry) => [...row].forEach((ch, cx) => {
      if (ch === ".") return;
      let col = C[ch] ?? C.o;
      if (ch === "c") col = Math.floor(now / 600) % 2 ? C.c1 : C.c2;
      put(cx, bodyY + ry, col);
    }));
    // Legs.
    const legY = TOP + HEAD.length + BODY.length - (lift > 1 ? lift - 1 : 0);
    legs.forEach((row, ry) => [...row].forEach((ch, cx) => { if (ch !== ".") put(cx, legY + ry, C.k); }));
    // Arms.
    let arms = ARMS.down;
    if (pose === "up") arms = ARMS.up;
    else if (pose === "forward" || pose === "carry" || pose === "read") arms = ARMS.forward;
    else if (pose === "scroll") arms = Math.floor(now / 260) % 2 ? ARMS.scrollUp : ARMS.scrollDown;
    else if (pose === "tap") arms = Math.floor(now / 200) % 2 ? ARMS.tap : ARMS.forward;
    else if (pose === "wave") arms = Math.floor(now / 220) % 2 ? ARMS.waveA : ARMS.waveB;
    else if (mood === "speaking" && pose === "stand" && Math.floor(now / 1400) % 3 === 0) arms = Math.floor(now / 220) % 2 ? ARMS.waveA : ARMS.waveB;
    for (const [ax, ay] of arms) put(ax, bodyY + ay, C.arm);
    // Props.
    if (pose === "carry") for (let cx = 4; cx <= 10; cx++) for (let cy = 1; cy <= 4; cy++) put(cx, bodyY + cy, cy === 1 || cx === 7 ? C.boxHi : C.box);
    if (pose === "read") for (let cx = 4; cx <= 10; cx++) for (let cy = 1; cy <= 5; cy++) put(cx, bodyY + cy, (cy === 2 || cy === 4) && cx > 4 && cx < 10 ? C.ink : C.page);
    // Thought dots orbiting above the head; sparkles after a hop.
    if (mood === "thinking" && !still) {
      for (let i = 0; i < 3; i++) { const t = now / 380 + i * 2.1; put(7 + Math.round(Math.cos(t) * 4), 1 + Math.round(Math.sin(t) * 1), i === 0 ? C.a1 : C.spark); }
    }
    if (hopUntil && now < hopUntil + 500) {
      const k = Math.floor((now - hopFrom) / 120);
      for (const [sx, sy] of [[1, 2], [13, 1], [3, 0], [11, 3], [0, 6], [14, 5]]) if ((sx + sy + k) % 3 === 0) put(sx, sy, C.spark);
    }
  }

  function loop(t) {
    if (!running) { raf = 0; return; }
    if (t - lastT > 120) { frame++; lastT = t; }
    draw(t);
    raf = requestAnimationFrame(loop);
  }

  const place = () => { el.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`; };

  /** Walks to (tx, ty) at about 300 px/s; resolves when there (false if a newer action took over). */
  function walk(tx, ty, my) {
    if (reduced()) { x = tx; y = ty; place(); return Promise.resolve(my === gen); }
    const dist = Math.hypot(tx - x, ty - y);
    if (dist < 2) return Promise.resolve(my === gen);
    face = tx >= x ? 1 : -1;
    const carry = pose === "carry";
    pose = "walk";
    const x0 = x, y0 = y;
    const ms = Math.max(260, (dist / 300) * 1000);
    const t0 = performance.now();
    el.classList.add("vox-bot-walking");
    return new Promise((resolve) => {
      const step = (t) => {
        if (my !== gen) { el.classList.remove("vox-bot-walking"); return resolve(false); }
        const k = Math.min(1, (t - t0) / ms);
        const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
        x = x0 + (tx - x0) * e;
        y = y0 + (ty - y0) * e;
        place();
        if (k < 1) requestAnimationFrame(step);
        else { el.classList.remove("vox-bot-walking"); pose = carry ? "carry" : "stand"; resolve(true); }
      };
      requestAnimationFrame(step);
    });
  }

  const BOT_W = W * CELL, BOT_H = H * CELL;
  const rel = (r) => { const h = host.getBoundingClientRect(); return { left: r.left - h.left, top: r.top - h.top, right: r.right - h.left, bottom: r.bottom - h.top, width: r.width, height: r.height }; };
  let homeFn = () => ({ x: 20, y: 20 });

  async function vanish(on) {
    if (el.classList.contains("vox-bot-in") === on) return;
    el.classList.toggle("vox-bot-in", on);
    await sleep(300);
  }

  const api = {
    el,
    size: { w: BOT_W, h: BOT_H },
    /** Where home is (next to the orb), as a function of the host's current layout. */
    setHome(fn) { homeFn = fn; },
    start() {
      palette = null;
      if (!el.isConnected) host.append(el);
      const h = homeFn();
      x = h.x; y = h.y; face = 1; pose = "wave";
      el.classList.remove("vox-bot-in");
      place();
      running = true;
      if (!raf) raf = requestAnimationFrame(loop);
      setTimeout(() => { if (pose === "wave") pose = "stand"; }, 1400);
    },
    stop() { running = false; gen++; cancelAnimationFrame(raf); raf = 0; },
    /** What the agent is doing: listening, hearing, thinking, speaking, muted. */
    setMood(m) { mood = m; el.dataset.mood = m; },
    /** A worker finished: a happy hop with sparkles. */
    cheer() { hopFrom = performance.now(); hopUntil = hopFrom + 700; },
    async home() {
      const my = ++gen;
      await vanish(false);
      const h = homeFn();
      if (await walk(h.x, h.y, my)) { face = 1; pose = "stand"; }
    },
    /** Carries the brief to a new worker's card. */
    async deliver(card) {
      const my = ++gen;
      await vanish(false);
      pose = "carry";
      const t = api.spotBy(card);
      if (!(await walk(t.x, t.y, my))) return;
      face = t.face;
      await sleep(320);
      if (my !== gen) return;
      pose = "up";
      card?.classList.add("vw-got");
      setTimeout(() => card?.classList.remove("vw-got"), 900);
      await sleep(460);
      if (my === gen) void api.home();
    },
    /** Steps into a worker's card to check on it, then comes back out. */
    async visit(card) {
      const my = ++gen;
      await vanish(false);
      const t = api.spotBy(card);
      if (!(await walk(t.x, t.y, my))) return;
      face = t.face;
      pose = "forward";
      await sleep(200);
      if (my !== gen) return;
      card?.classList.add("vw-checking");
      await vanish(true);
      await sleep(1100);
      card?.classList.remove("vw-checking");
      if (my !== gen) return;
      await vanish(false);
      pose = "up";
      await sleep(300);
      if (my === gen) void api.home();
    },
    /** Reads a page of the project next to the orb. */
    async peek() {
      const my = ++gen;
      await vanish(false);
      const h = homeFn();
      if (!(await walk(h.x - 26, h.y, my))) return;
      pose = "read";
    },
    /** Goes to the browser screen and works there: "enter" | "scroll" | "tap" | "look". */
    async browse(screen, how) {
      const my = ++gen;
      const r = rel(screen.getBoundingClientRect());
      const leftOfIt = r.left > BOT_W + 8;
      const tx = leftOfIt ? r.left - BOT_W + 4 : r.left + 8;
      const ty = leftOfIt ? Math.max(0, r.bottom - BOT_H) : Math.max(0, r.top - BOT_H + 10);
      if (Math.hypot(tx - x, ty - y) > 4) { await vanish(false); if (!(await walk(tx, ty, my))) return; }
      face = 1;
      if (how === "enter") {
        pose = "forward";
        await sleep(160);
        if (my !== gen) return;
        await vanish(true);
        await sleep(900);
        if (my !== gen) return;
        await vanish(false);
        pose = "scroll";
        return;
      }
      await vanish(false);
      pose = how === "tap" ? "tap" : how === "look" ? "forward" : "scroll";
    },
    /** Where to stand next to a card (outside it, facing it). */
    spotBy(card) {
      if (!card) { const h = homeFn(); return { x: h.x, y: h.y, face: 1 }; }
      const r = rel(card.getBoundingClientRect());
      const hostW = host.getBoundingClientRect().width;
      const mid = r.left + r.width / 2;
      void mid;
      // Narrow layout (cards in a row under the orb): stand on top of the card, at its left.
      if (hostW <= 760) return { x: Math.max(0, r.left + 6), y: Math.max(0, r.top - BOT_H + 6), face: 1 };
      const leftSide = mid < hostW / 2;
      const ty = Math.max(0, Math.min(r.top + r.height / 2 - BOT_H / 2, r.bottom - BOT_H));
      return leftSide ? { x: r.right + 4, y: ty, face: -1 } : { x: r.left - BOT_W - 4, y: ty, face: 1 };
    },
  };
  return api;
}
