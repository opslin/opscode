// Modes in the interface: the character picker ("Start a chat": Normal, GODMODE,
// WARLORD, SHINOBI), the small emblems used in the sidebar and the header, and the
// animated big character on a Conductor's welcome screen.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { showDialog, closeDialog } from "./dialogs.js";
import { ART_SIZE, MODE_COLORS, drawArt, emblemUrl, loadArt } from "./conductorart.js";

export const MODE_INFO = {
  godmode: { name: "GODMODE", line: "Ultimate multi-agent. Full power." },
  warlord: { name: "WARLORD", line: "Strong development. Balanced." },
  shinobi: { name: "SHINOBI", line: "Stealthy. Efficient. Low cost." },
};
export const MODE_ORDER = ["godmode", "warlord", "shinobi"];
export const isMode = (m) => m in MODE_INFO;

// One animation loop for every character on screen; it stops by itself when none is.
const live = new Set();
let raf = 0;
function tick(now) {
  raf = 0;
  for (const a of live) {
    if (!a.canvas.isConnected) { live.delete(a); continue; }
    if (a.canvas.offsetParent === null || document.hidden) continue;
    drawArt(a.ctx, a.loaded, now / 1000 + a.phase, a.scale);
  }
  if (live.size) raf = requestAnimationFrame(tick);
}

/** The big animated character on a canvas (scale = screen pixels per art pixel). */
export function modeCharacter(id, scale = 4, cls = "mode-char") {
  const canvas = h("canvas", { class: cls, "aria-hidden": "true" });
  canvas.width = ART_SIZE.w * scale;
  canvas.height = (ART_SIZE.h + 2) * scale;
  canvas.style.width = `${canvas.width / 2}px`;
  canvas.style.height = `${canvas.height / 2}px`;
  const ctx = canvas.getContext("2d");
  void loadArt(id).then((loaded) => {
    drawArt(ctx, loaded, 0, scale, { still: true });
    live.add({ canvas, ctx, loaded, scale, phase: Math.random() * 3 });
    if (!raf) raf = requestAnimationFrame(tick);
  });
  return canvas;
}

const emblemCache = new Map();
/** A small head-and-shoulders picture of the mode's character. */
export function modeEmblem(id, px = 18, cls = "mode-emblem") {
  const img = h("img", { class: cls, alt: "", width: px, height: px, draggable: false, title: MODE_INFO[id]?.name ?? "" });
  const key = `${id}:${px}`;
  if (!emblemCache.has(key)) emblemCache.set(key, emblemUrl(id, px));
  void emblemCache.get(key).then((url) => { img.src = url; }).catch(() => {});
  return img;
}

/** "Start a chat": Normal, or one of the three modes. onPick(null) = Normal, onPick("warlord") etc. */
export function openModePicker({ onPick, project }) {
  const pick = (m) => { closeDialog(); onPick(m); };
  const card = (id) => {
    const info = MODE_INFO[id];
    const [c1] = MODE_COLORS[id];
    return h("button", { class: "mode-card", type: "button", dataset: { mode: id }, style: `--mc:${c1}`, onclick: () => pick(id), "aria-label": `${info.name}: ${info.line}` },
      h("span", { class: "mode-stage" }, modeCharacter(id, 6)),
      h("span", { class: "mode-name" }, info.name),
      h("span", { class: "mode-line" }, info.line));
  };
  const normal = h("button", { class: "mode-card mode-normal", type: "button", dataset: { mode: "normal" }, onclick: () => pick(null), "aria-label": "Normal chat: you and one model" },
    h("span", { class: "mode-stage" }, h("img", { class: "mode-normal-mark", src: "brand/opscode-mark-128.png", alt: "", width: 88, height: 88, draggable: false })),
    h("span", { class: "mode-name" }, "NORMAL"),
    h("span", { class: "mode-line" }, "You and one model. As always."));
  const el = h("div", { class: "dialog mode-dialog", role: "dialog", "aria-label": "Start a chat" },
    h("div", { class: "dialog-head" }, h("h2", {}, project ? `Start a chat in ${project}` : "Start a chat"), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: closeDialog }, icon("x"))),
    h("div", { class: "mode-grid" }, normal, ...MODE_ORDER.map(card)));
  showDialog(el);
  queueMicrotask(() => el.querySelector(".mode-card")?.focus());
  return el;
}

/**
 * How each mode looks on the new-chat screen: frame colours (c1, c2), the star palette and
 * trail of the background, the sonar dot colour and ping pace. "normal" is Opscode's orange.
 */
export const CREW_THEME = {
  normal: { c1: "#D97757", c2: "#f2c9a8", stars: ["#FFFFFF", "#FFE2CC", "#F2C9A8", "#D97757", "#AAAAFF"], trail: "242, 201, 168", dot: "#D97757", ping: 3.2 },
  godmode: { c1: "#f5c451", c2: "#7a5cff", stars: ["#FFFFFF", "#FFF3B0", "#F5C451", "#B9A6FF", "#7A5CFF"], trail: "255, 228, 140", dot: "#f5c451", ping: 1.8 },
  warlord: { c1: "#d63a3f", c2: "#f5c451", stars: ["#FFD2A6", "#FF7A45", "#D63A3F", "#F5C451", "#FFFFFF"], trail: "255, 140, 90", dot: "#e5484d", ping: 2.2 },
  shinobi: { c1: "#4f7cff", c2: "#e5484d", stars: ["#FFFFFF", "#AAC4FF", "#4F7CFF", "#7FE0FF", "#E5484D"], trail: "150, 190, 255", dot: "#4f7cff", ping: 2.8 },
};
export const crewTheme = (id) => CREW_THEME[id] ?? CREW_THEME.normal;
