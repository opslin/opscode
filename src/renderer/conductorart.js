// The three mode characters, drawn as pixel art: SHINOBI (a crouching ninja with a
// katana and a hand sign), WARLORD (an armoured warrior with a greatsword), GODMODE
// (a floating, crowned figure holding two orbs). All original art.
//
// Each character is drawn as vector shapes on a 56x72 grid where 1 unit = 1 art
// pixel, rasterised once to that size, thresholded and snapped to a small palette
// (that is what makes it look like pixel art), then animated: scarf, cape and robe
// wave, blades and orbs glint, GODMODE floats.

const OL = "#0a0c14";
const W = 56;
const H = 72;

// ---- tiny shape helpers (every shape gets a dark outline, which becomes the 1px pixel outline) ----
const pts = (a) => a.map((p) => p.join(",")).join(" ");
const P = (a, fill) => `<polygon points="${pts(a)}" fill="${fill}" stroke="${OL}" stroke-width="1.1" stroke-linejoin="round"/>`;
const E = (cx, cy, rx, ry, fill, rot = 0) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" stroke="${OL}" stroke-width="1.1"${rot ? ` transform="rotate(${rot} ${cx} ${cy})"` : ""}/>`;
const R = (x, y, w, h, fill, rx = 0.8) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${OL}" stroke-width="1.1"/>`;
const L = (a, w, fill) => `<polyline points="${pts(a)}" fill="none" stroke="${OL}" stroke-width="${w + 2.2}" stroke-linecap="round" stroke-linejoin="round"/><polyline points="${pts(a)}" fill="none" stroke="${fill}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const D = (d, fill) => `<path d="${d}" fill="${fill}" stroke="${OL}" stroke-width="1.1" stroke-linejoin="round"/>`;
const line = (a, w, stroke) => `<polyline points="${pts(a)}" fill="none" stroke="${stroke}" stroke-width="${w}" stroke-linecap="round"/>`;
const svg = (inner) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${inner}</svg>`;

// ================================ SHINOBI ================================
const S = { navy: "#2b3a78", navyD: "#161d44", navyL: "#4560c0", blue: "#7da0ff", red: "#ff4d55", redD: "#b8323a", ember: "#ff9a4a", skin: "#f1c9a0", white: "#ffffff", steel: "#c9d1d9", steelD: "#8b95a7", gold: "#f5c451", glove: "#0f1426" };
const shinobi = {
  id: "shinobi",
  palette: [OL, S.navy, S.navyD, S.navyL, S.blue, S.red, S.redD, S.ember, S.skin, S.white, S.steel, S.steelD, S.gold, S.glove],
  accent: "#4f7cff", accent2: "#e5484d",
  emblem: [14, 2, 30, 28],
  layers: [
    // scarf tails (waving), anchored at the headband knot
    { wave: { kind: "x", amp: 2.4, freq: 0.55, speed: 5, anchor: 24 }, svg: svg(
      D("M24 11 L15 7.5 L6 10.5 L12 12.6 L3 17.5 L14 15.5 L24 14 Z", S.red) + D("M24 12.5 L16 15 L8 21 L15 19.8 L10 26 L24 15.5 Z", S.ember) + line([[22, 11.2], [8, 11.6]], 0.9, "#ffd0d2")) },
    { svg: svg(
      // back leg, torso, front leg
      L([[30, 47], [19, 58], [11, 66]], 7, S.navyD) + line([[28, 49], [17, 59.5]], 1, S.navy) + R(5, 65, 10, 5, S.navyD, 1.4) +
      P([[25, 24], [38, 22], [42, 45], [27, 49]], S.navy) + P([[28, 26], [36, 25], [37, 30], [29, 32]], S.navyL) + line([[28, 33], [40, 41]], 1.8, S.navyL) + line([[40, 33], [29, 41]], 1.8, S.navyL) + line([[25.6, 26], [27.6, 44]], 1, S.blue) +
      P([[26, 43], [42, 41], [42, 45.5], [27, 48]], S.red) + P([[26, 45], [22, 50], [25, 51]], S.redD) +
      L([[35, 47], [44, 58], [40, 67]], 7.6, S.navy) + line([[37, 49], [45, 58.5]], 1, S.navyL) + R(35, 66, 14, 5, S.navyD, 1.4) + R(35.5, 69.2, 13, 1.5, S.steel, 0.4) +
      // head: hood, face opening, eyes, headband
      R(28.5, 20, 7, 5, S.navyD, 1) + E(32, 14, 9.2, 8.8, S.navy) + line([[25.5, 8], [32, 4.6], [38.5, 8]], 1.1, S.navyL) +
      R(26, 11, 12, 4.4, S.skin, 1.6) + R(27.2, 11.8, 4, 2.3, S.white, 0.4) + R(33.2, 11.8, 4, 2.3, S.white, 0.4) + R(29.4, 12.1, 1.6, 1.8, S.glove, 0.2) + R(35.4, 12.1, 1.6, 1.8, S.glove, 0.2) +
      P([[23, 8.4], [41.5, 7.4], [41.8, 10.8], [23.4, 11.9]], S.red) + line([[25, 9], [40, 8.3]], 0.9, "#ff8b8f") + E(23.4, 10.4, 2.2, 2.2, S.redD) +
      // front arm: hand sign with two raised fingers
      L([[38, 28], [47, 34], [51.5, 28.5]], 5, S.navy) + line([[39, 27], [47, 32.4]], 0.9, S.navyL) + E(52.6, 26.4, 2.7, 2.7, S.skin) + R(51.5, 20.4, 1.9, 6.4, S.skin, 0.9) + R(54.2, 21.2, 1.9, 5.8, S.skin, 0.9) +
      // back arm and the katana (held diagonally over the head)
      L([[27, 28], [19, 33], [17.5, 25]], 5, S.navy) + line([[26, 27], [19, 31.4]], 0.9, S.navyL) +
      R(14.2, 22.6, 4, 7.4, S.red, 1) +
      P([[18.6, 21.8], [49.6, 2.2], [51.4, 4.4], [21, 24.6]], S.steel) + line([[21, 22], [49, 3.6]], 1.2, S.white) +
      E(20.2, 23, 3.5, 1.9, S.gold, -34) + E(17.4, 24.4, 2.9, 2.9, S.glove)) },
  ],
  sparkles: [[50.5, 2.6, "#ffffff", 0], [36, 11.6, "#bcd0ff", 1.3], [28, 17.2, "#ffffff", 2.4], [54, 20, "#7aa2ff", 0.7]],
  float: 0,
};

// ================================ WARLORD ================================
const Wd = { steel: "#aeb8c8", steelL: "#e4ebf5", steelD: "#6b7587", dark: "#2a2f3d", gold: "#f5c451", red: "#d63a3f", redD: "#8f2429", ember: "#ff8a3d", bone: "#f0e6cf", leather: "#5a3a28", visor: "#0d1018" };
const warlord = {
  id: "warlord",
  palette: [OL, Wd.steel, Wd.steelL, Wd.steelD, Wd.dark, Wd.gold, Wd.red, Wd.redD, Wd.ember, Wd.bone, Wd.leather, Wd.visor],
  accent: "#d63a3f", accent2: "#f5c451",
  emblem: [12, 0, 32, 30],
  layers: [
    { wave: { kind: "y", amp: 2, freq: 0.34, speed: 3.4, top: 22 }, svg: svg(
      P([[17, 22], [39, 22], [51, 64], [46, 70], [40, 65.5], [34, 71], [28, 66], [22, 71], [16, 65.5], [10, 70], [5, 64]], Wd.red) +
      P([[24, 24], [32, 24], [35, 66], [28, 71], [21, 66]], Wd.redD)) },
    { svg: svg(
      // legs, knee guards, boots
      L([[23, 46], [20.5, 62]], 8.4, Wd.steelD) + L([[33, 46], [35.5, 62]], 8.4, Wd.steelD) + E(22, 53, 4.3, 3.6, Wd.steel) + E(34, 53, 4.3, 3.6, Wd.steel) +
      R(14.5, 62, 14, 7.6, Wd.dark, 2) + R(27.5, 62, 14, 7.6, Wd.dark, 2) + line([[16, 64], [27, 64]], 1, Wd.steelD) + line([[29, 64], [40, 64]], 1, Wd.steelD) +
      // tassets, torso plate, belt, emblem
      P([[20.5, 47], [35.5, 47], [38, 57], [18, 57]], Wd.steelD) + P([[18, 25], [38, 25], [35.5, 47], [20.5, 47]], Wd.steel) + P([[20.5, 27], [28, 26.2], [26.2, 36], [21.6, 35]], Wd.steelL) +
      P([[20, 43.5], [36, 43.5], [36, 47.8], [20, 47.8]], Wd.leather) + R(25, 43.8, 6, 3.8, Wd.gold, 0.8) +
      P([[28, 28.5], [31.5, 33.4], [28, 39], [24.5, 33.4]], Wd.ember) +
      // pauldrons with rim and spikes
      P([[10.6, 24.4], [13.2, 17.4], [15.8, 23.6]], Wd.steelL) + P([[45.4, 24.4], [42.8, 17.4], [40.2, 23.6]], Wd.steelL) +
      E(15.4, 27, 6.8, 5.8, Wd.steel) + E(40.6, 27, 6.8, 5.8, Wd.steel) + line([[10, 28.6], [15, 31.6], [20, 28.6]], 1.3, Wd.gold) + line([[36, 28.6], [41, 31.6], [46, 28.6]], 1.3, Wd.gold) +
      // greatsword planted point-down, both hands on the grip
      P([[26.2, 43], [29.8, 43], [29.8, 66], [28, 71], [26.2, 66]], Wd.steelL) + line([[28, 44], [28, 65]], 1, Wd.steelD) + R(20.4, 40.6, 15.2, 3.4, Wd.gold, 1) +
      R(26.9, 31.5, 2.2, 9.4, Wd.leather, 0.6) + E(28, 31, 2.5, 2.2, Wd.gold) +
      L([[16, 31], [20.4, 38], [26.6, 36.6]], 6, Wd.steelD) + L([[40, 31], [35.6, 38], [29.4, 36.6]], 6, Wd.steelD) + E(26.4, 36.6, 3.2, 3.2, Wd.steel) + E(29.6, 36.6, 3.2, 3.2, Wd.steel) +
      // head: cheek guards, helmet, visor with glowing eyes, horns, crest
      P([[19, 15.5], [22, 22.6], [26.5, 22.4], [24.5, 16.5]], Wd.steelD) + P([[37, 15.5], [34, 22.6], [29.5, 22.4], [31.5, 16.5]], Wd.steelD) +
      D("M20.6 11 Q8.5 10.4 8.4 0.8 Q13.5 3.4 22.6 7.4 Z", Wd.bone) + D("M35.4 11 Q47.5 10.4 47.6 0.8 Q42.5 3.4 33.4 7.4 Z", Wd.bone) +
      E(28, 14.4, 9.4, 9.2, Wd.steel) + line([[21.5, 9.2], [28, 5.6], [34.5, 9.2]], 1.2, Wd.steelL) +
      R(20.5, 12.8, 15, 3.6, Wd.visor, 1.2) + R(22.6, 13.6, 3.6, 1.9, Wd.ember, 0.4) + R(29.8, 13.6, 3.6, 1.9, Wd.ember, 0.4) +
      D("M24.4 6.6 Q28 -0.4 33.2 6.6 L30.4 7.8 Q28 3.4 26.8 7.8 Z", Wd.red)) },
  ],
  sparkles: [[12.6, 17.8, "#ffffff", 0], [42.6, 17.8, "#ffffff", 1.6], [28, 62, "#ffffff", 0.8], [28, 33, "#ffd9a6", 2.4]],
  float: 0,
};

// ================================ GODMODE ================================
const G = { gold: "#f5c451", goldD: "#c08a1c", robe: "#f1f0ff", robeD: "#b9b4ee", violet: "#7a5cff", deep: "#3a2a8a", cyan: "#5ee0ff", skin: "#f1c9a0", hair: "#2a1d5c", white: "#ffffff" };
const godmode = {
  id: "godmode",
  palette: [OL, G.gold, G.goldD, G.robe, G.robeD, G.violet, G.deep, G.cyan, G.skin, G.hair, G.white],
  accent: "#f5c451", accent2: "#7a5cff",
  emblem: [8, 0, 40, 34],
  float: 1.6,
  layers: [
    // halo behind the head (a ring of gold)
    { svg: svg(`<circle cx="28" cy="14.5" r="12.4" fill="none" stroke="${OL}" stroke-width="4.6"/><circle cx="28" cy="14.5" r="12.4" fill="none" stroke="${G.gold}" stroke-width="2.4"/>`) },
    { wave: { kind: "y", amp: 1.7, freq: 0.3, speed: 2.6, top: 28 }, svg: svg(
      P([[18, 26], [38, 26], [43, 44], [51, 66], [28, 71.4], [5, 66], [13, 44]], G.robe) +
      P([[24, 27], [32, 27], [34.5, 45], [41, 66], [28, 70], [15, 66], [21.5, 45]], G.violet) +
      line([[28, 30], [28, 69]], 1.2, G.deep) + line([[17, 62], [39, 62]], 2.4, G.gold) + line([[12, 55.5], [44, 55.5]], 1.8, G.goldD)) },
    { svg: svg(
      // raised arms and the two orbs
      L([[19.4, 29], [9, 25], [6.4, 15]], 5.2, G.robe) + L([[36.6, 29], [47, 25], [49.6, 15]], 5.2, G.robe) + E(6.2, 12.6, 2.8, 2.8, G.skin) + E(49.8, 12.6, 2.8, 2.8, G.skin) +
      E(6, 6, 4.8, 4.8, G.cyan) + E(5, 5, 2, 2, G.white) + E(50, 6, 4.8, 4.8, G.cyan) + E(49, 5, 2, 2, G.white) +
      // chest sigil
      P([[28, 29.5], [32, 34], [28, 39.5], [24, 34]], G.gold) + P([[28, 32], [29.8, 34], [28, 36.4], [26.2, 34]], G.violet) +
      // head: face, hair, closed eyes, crown, third-eye gem
      R(25.8, 21, 4.4, 4.6, G.skin, 1) + E(28, 16.6, 6.8, 7.4, G.skin) + P([[21, 14], [22, 7.6], [25.4, 11], [28, 6], [30.6, 11], [34, 7.6], [35, 14], [31, 11.2], [25, 11.2]], G.hair) +
      R(23.4, 16.2, 3.4, 1.1, G.deep, 0.5) + R(29.2, 16.2, 3.4, 1.1, G.deep, 0.5) + P([[28, 8.2], [29.4, 10.2], [28, 12.4], [26.6, 10.2]], G.cyan) +
      P([[20.4, 10.4], [21.4, 4.6], [24.4, 8.6], [28, 2.6], [31.6, 8.6], [34.6, 4.6], [35.6, 10.4]], G.gold) +
      E(28, 10.2, 1.6, 1.9, G.cyan)) },
  ],
  sparkles: [[6, 5, "#ffffff", 0], [50, 5, "#ffffff", 1.1], [16, 5, "#fff3b0", 2.2], [40, 4, "#fff3b0", 0.5], [28, 1.5, "#ffffff", 1.7]],
};

export const ART = { shinobi, warlord, godmode };
export const MODE_COLORS = { shinobi: ["#4f7cff", "#e5484d"], warlord: ["#d63a3f", "#f5c451"], godmode: ["#f5c451", "#7a5cff"] };

// ---- rasterise: draw the SVG at its pixel size, threshold the alpha, snap each pixel to the palette ----
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const cache = new Map();

async function rasterLayer(layer, palette) {
  const img = new Image();
  img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(layer.svg)}`;
  await img.decode();
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const g = c.getContext("2d", { willReadFrequently: true });
  g.drawImage(img, 0, 0, W, H);
  const d = g.getImageData(0, 0, W, H).data;
  const pal = palette.map(hex);
  const out = new Uint8Array(W * H).fill(255);
  for (let i = 0; i < W * H; i++) {
    if (d[i * 4 + 3] < 120) continue;
    let best = 0, bd = 1e9;
    for (let k = 0; k < pal.length; k++) {
      const dr = d[i * 4] - pal[k][0], dg = d[i * 4 + 1] - pal[k][1], db = d[i * 4 + 2] - pal[k][2];
      const dist = dr * dr + dg * dg + db * db;
      if (dist < bd) { bd = dist; best = k; }
    }
    out[i] = best;
  }
  return { grid: out, wave: layer.wave ?? null };
}

/** Loads (and caches) a character: its pixel layers ready to draw. */
export function loadArt(id) {
  if (!cache.has(id)) {
    const a = ART[id];
    cache.set(id, Promise.all(a.layers.map((l) => rasterLayer(l, a.palette))).then((layers) => ({ id, art: a, layers, pal: a.palette })));
  }
  return cache.get(id);
}

/** Draws one frame at time t (seconds). `scale` canvas pixels per art pixel. */
export function drawArt(ctx, loaded, t, scale, { still = false } = {}) {
  const { art, layers, pal } = loaded;
  ctx.clearRect(0, 0, W * scale, H * scale + 2 * scale);
  const bob = still || !art.float ? 0 : Math.round(Math.sin(t * 1.8) * art.float);
  const oy = 1 + bob;
  for (const l of layers) {
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const k = l.grid[y * W + x];
        if (k === 255) continue;
        let dx = 0, dy = 0;
        const w = l.wave;
        if (w && !still) {
          if (w.kind === "x") dy = Math.round(Math.sin(t * w.speed - Math.abs(x - w.anchor) * w.freq) * w.amp * Math.min(1, Math.abs(x - w.anchor) / 14));
          else dx = Math.round(Math.sin(t * w.speed - y * w.freq) * w.amp * Math.max(0, Math.min(1, (y - w.top) / (H - w.top))));
        }
        ctx.fillStyle = pal[k];
        ctx.fillRect((x + dx) * scale, (y + dy + oy) * scale, scale, scale);
      }
    }
  }
  // glints: a plus-shaped sparkle that swells and fades
  if (!still) {
    for (const [sx, sy, color, phase] of art.sparkles) {
      const a = Math.max(0, Math.sin(t * 2.6 + phase * 2.1));
      if (a < 0.15) continue;
      const r = a > 0.7 ? 2 : 1;
      ctx.globalAlpha = Math.min(1, a * 1.2);
      ctx.fillStyle = color;
      ctx.fillRect(Math.round(sx) * scale, (Math.round(sy) + oy) * scale, scale, scale);
      for (let k = 1; k <= r; k++) {
        ctx.fillRect((Math.round(sx) - k) * scale, (Math.round(sy) + oy) * scale, scale, scale);
        ctx.fillRect((Math.round(sx) + k) * scale, (Math.round(sy) + oy) * scale, scale, scale);
        ctx.fillRect(Math.round(sx) * scale, (Math.round(sy) - k + oy) * scale, scale, scale);
        ctx.fillRect(Math.round(sx) * scale, (Math.round(sy) + k + oy) * scale, scale, scale);
      }
      ctx.globalAlpha = 1;
    }
  }
}

export const ART_SIZE = { w: W, h: H };

/** A small head-and-shoulders emblem as an image data URL (for the sidebar and header). */
export async function emblemUrl(id, px = 24) {
  const loaded = await loadArt(id);
  const [ex, ey, ew, eh] = loaded.art.emblem;
  const src = document.createElement("canvas");
  const scale = 4;
  src.width = W * scale; src.height = (H + 2) * scale;
  drawArt(src.getContext("2d"), loaded, 0, scale, { still: true });
  const out = document.createElement("canvas");
  const size = Math.max(16, px) * 2; // 2x for crisp rendering
  out.width = size; out.height = size;
  const g = out.getContext("2d");
  g.imageSmoothingEnabled = false;
  const side = Math.max(ew, eh);
  g.drawImage(src, (ex - (side - ew) / 2) * scale, (ey + 1) * scale - ((side - eh) / 2) * scale, side * scale, side * scale, 0, 0, size, size);
  return out.toDataURL("image/png");
}
