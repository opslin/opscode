// The notch page (notch.html in its own clear window, src/main/notch.ts). It is told what to show (the feed) and asks
// main to act. Three shapes, one black island that animates between them:
//   closed  the camera notch plus two ears: Ember (the character) on the left, the status on the right
//   peek    one line under the notch for a few seconds ("Done · chat title · what it said")
//   open    the panel: needs-you cards with Allow / Deny, the chats and what each does now, a message box with voice
// Behaviour (designed against the common notch-app complaints):
//   - clicks pass through everything except the drawn shape; it never opens just because the pointer flew past
//     (hover intent: the pointer has to settle on it)
//   - an approval opens it by itself with a red glow and a sound, and the glow stays until it is answered
//   - a finished chat peeks for a moment and leaves a badge until it is seen; nothing stays in the way of a video
//   - a button that just appeared ignores a click for 0.7 s unless the pointer moved (no accidental Allow)
//   - no animation loop when nothing changes

import { createCharacter, pixelNumber } from "./notchchar.js";
import { play, setSounds } from "./notchsound.js";
import { startCapture, micMessage } from "./voicecapture.js";
import { createTalk } from "./notchtalk.js";

const bridge = window.opscodeNotch ?? demoBridge();
const reducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

// ---------------------------------------------------------------- tiny DOM helpers
function h(tag, attrs = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k === "class") el.className = v;
    else if (k === "style") el.style.cssText = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "html") el.innerHTML = v;
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const c of kids.flat()) if (c !== null && c !== undefined && c !== false) el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  return el;
}
const svg = (d, extra = "") => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;
const ICON = {
  plus: svg('<path d="M12 5v14M5 12h14"/>'),
  up: svg('<path d="M12 19V5M6 11l6-6 6 6"/>', 'stroke-width="2.4"'),
  mic: svg('<path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z"/><path d="M19 11a7 7 0 0 1-14 0M12 18v3"/>'),
  open: svg('<path d="M15 3h6v6M10 14 21 3M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>'),
  stop: svg('<rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor" stroke="none"/>'),
  reply: svg('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>'),
  x: svg('<path d="M18 6 6 18M6 6l12 12"/>'),
  check: svg('<path d="M20 6 9 17l-5-5"/>'),
  vol: svg('<path d="M11 5 6 9H3v6h3l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/>'),
  mute: svg('<path d="M11 5 6 9H3v6h3l5 4z"/><path d="m22 9-6 6M16 9l6 6"/>'),
  chev: svg('<path d="m6 9 6 6 6-6"/>', 'stroke-width="2.4"'),
  micOff: svg('<path d="M2 2l20 20M9 9v3a3 3 0 0 0 5.1 2.1M15 9.3V6a3 3 0 0 0-5.7-1.3"/><path d="M17 16.9A7 7 0 0 1 5 11M19 11a7 7 0 0 1-.3 2M12 18v3"/>'),
  grid: svg('<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>'),
  mac: svg('<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>'),
  wave: svg('<path d="M3 10v4M7 7v10M11 4v16M15 8v8M19 10v4"/>', 'stroke-width="2.2"'),
};

// ---------------------------------------------------------------- state
let data = null; // { feed, hardware, bar, sounds, shortcut }
let mode = "closed";
let lastSeq = null;
let peekItem = null;
let peekTimer = 0;
let alertUntil = 0;
let alertTimer = 0;
let summoned = false;
let replyTo = null; // chat_id the next message goes to (null: a new chat)
let pickedWs = null;
/** The composer's "On my Mac" target (not a project). */
const MAC = "@mac";
let fresh = false;
let glowTimer = 0;
let transient = null; // "done" | "failed" glow for a moment

// ---------------------------------------------------------------- DOM
const stage = document.getElementById("stage");
const shell = h("div", { class: "shell", "data-mode": "closed" });
const bloom = h("div", { class: "bloom" });
const halo = h("div", { class: "halo" });
const ring = h("div", { class: "ring" });
const island = h("div", { class: "island" });
const fx = h("canvas", { class: "fx" });
const ember = createCharacter(3, 1.5);
const earL = h("div", { class: "ear l" }, ember.el);
const earR = h("div", { class: "ear r" });
const bandTitle = h("div", { class: "band-title" }, "Opscode");
const band = h("div", { class: "band" }, earL, h("div", { class: "band-mid" }, bandTitle), earR);
const peek = h("div", { class: "peek" });
const head = h("div", { class: "head stagger", style: "--i:0" });
const list = h("div", { class: "list" });
const ta = h("textarea", { rows: 1, placeholder: "Ask Opscode…", spellcheck: "false" });
const target = h("button", { class: "target", type: "button", title: "Where this message goes" });
const mic = h("button", { class: "mic", type: "button", title: "Click to dictate, or hold to talk and send", html: ICON.mic });
const send = h("button", { class: "send", type: "button", title: "Send (↵)", html: ICON.up });
const composer = h("div", { class: "composer stagger", style: "--i:6" }, target, ta, mic, send);
const toastEl = h("div", { class: "toast" });
const hint = h("div", { class: "hint stagger", style: "--i:7" });
const panel = h("div", { class: "panel" }, head, list, composer, toastEl, hint);
island.append(band, peek, panel, fx);
shell.append(bloom, halo, ring, island, h("i", { class: "flare l" }), h("i", { class: "flare r" }));
stage.append(shell);

// ---------------------------------------------------------------- voice mode (talking with the voice agent)
const talk = createTalk(bridge, {
  h, ICON,
  logo: (e, m) => logo(e, m),
  play: (k) => play(k),
  toast: (text) => toast(text),
  guarded: (e) => guarded(e),
  shortcut: () => `${data?.talkShortcut ?? "⌃⌥Space"} to stop`,
  onAsk: () => { alertUntil = Date.now() + 9000; setMode("open", "alert"); markChange(); },
  onChange: () => onTalkChange(),
});
let talkWas = false;
function onTalkChange() {
  if (!data) return;
  const on = talk.on;
  if (on !== talkWas) { talkWas = on; fresh = true; if (!on && peekItem?.kind === "talk") clearPeek(); }
  ember.setPose(poseNow());
  syncGlow();
  if (mode === "open") render();
  else if (on) showTalkPeek();
  layout();
}
function poseNow() {
  if (!data) return "sleeping";
  if (data.feed.counts.needs || talk.waiting) return "needs";
  if (talk.on) return talk.state === "speaking" ? "talk" : talk.state === "thinking" ? "working" : "listen";
  return data.feed.pose;
}
function showTalkPeek() {
  const l = talk.peekLine();
  peekItem = { kind: "talk", chat_id: null };
  clearTimeout(peekTimer);
  peek.replaceChildren(h("span", { class: "k", "data-tone": l.tone }, l.tag), h("span", { class: "s", style: "color:var(--ink)" }, l.text));
  if (mode !== "peek") setMode("peek");
}
bridge.onTalk?.((e) => talk.handle(e));
bridge.onTalkSummon?.(() => {
  if (talk.on) { talk.stop(); return; }
  setMode("open", "summon");
  void talk.start();
});

// ---------------------------------------------------------------- geometry
function geo() {
  const hw = data?.hardware?.width ?? 0;
  const hh = data?.hardware?.height ?? Math.max(24, Math.min(32, data?.bar || 28));
  const ear = 40;
  const closed = hw ? hw + ear * 2 : 200;
  return { hw, hh, ear, closed };
}

function size() {
  const g = geo();
  if (mode === "open") return { w: 500, h: g.hh + panel.offsetHeight, r: 26 };
  if (mode === "peek") return { w: Math.max(g.closed + 120, 400), h: g.hh + 34, r: 18 };
  const needs = data?.feed?.counts?.needs > 0;
  return { w: g.closed + (needs ? 16 : 0), h: g.hh, r: g.hw ? 11 : 12 };
}

function layout() {
  const g = geo();
  const s = size();
  shell.style.setProperty("--w", `${s.w}px`);
  shell.style.setProperty("--h", `${s.h}px`);
  shell.style.setProperty("--r", `${s.r}px`);
  shell.style.setProperty("--hh", `${g.hh}px`);
  shell.style.setProperty("--ear", `${g.ear}px`);
  shell.toggleAttribute("data-nohw", !g.hw);
  // The band keeps the camera notch clear in the middle.
  band.querySelector(".band-mid").style.flex = g.hw ? `0 0 ${g.hw}px` : "1";
  band.style.justifyContent = mode === "closed" ? "center" : "space-between";
  syncOver();
}

new ResizeObserver(() => { if (mode === "open") layout(); }).observe(panel);

function setMode(next, why = "") {
  if (next === "closed" && talk.on) { if (mode !== "peek" || peekItem?.kind !== "talk") { peekItem = { kind: "talk", chat_id: null }; next = "peek"; const l = talk.peekLine(); peek.replaceChildren(h("span", { class: "k", "data-tone": l.tone }, l.tag), h("span", { class: "s", style: "color:var(--ink)" }, l.text)); } else return; }
  if (next === mode) { layout(); return; }
  const rank = { closed: 0, peek: 1, open: 2 };
  shell.dataset.dir = rank[next] > rank[mode] ? "open" : "close";
  const was = mode;
  mode = next;
  shell.dataset.mode = mode;
  if (mode === "open") {
    fresh = true;
    render();
    if (was !== "open") { dissolve(); bloom.classList.remove("go"); void bloom.offsetWidth; bloom.classList.add("go"); }
    if (why === "hover" || why === "summon" || why === "click") play("open");
    markChange();
  }
  if (mode !== "open" && document.activeElement === ta) ta.blur();
  layout();
  if (mode === "open") requestAnimationFrame(() => layout());
}

// ---------------------------------------------------------------- pixel dissolve (the red/black opening)
function dissolve() {
  if (reducedMotion()) return;
  const W = 500, Hh = Math.min(620, geo().hh + Math.max(panel.offsetHeight, 160));
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  fx.width = Math.ceil(W * dpr);
  fx.height = Math.ceil(Hh * dpr);
  fx.style.width = `${W}px`;
  fx.style.height = `${Hh}px`;
  fx.style.left = "0";
  fx.style.right = "auto";
  const g = fx.getContext("2d");
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  const cell = 8;
  const cols = Math.ceil(W / cell), rows = Math.ceil(Hh / cell);
  const cx = W / 2;
  const max = Math.hypot(cx, Hh);
  const cells = [];
  const PAL = ["#000", "#050101", "#0d0302", "#1a0604", "#2b0905"];
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
    const d = Math.hypot(x * cell + cell / 2 - cx, y * cell) / max;
    const r = Math.random();
    cells.push({
      x: x * cell, y: y * cell,
      at: d * 300 + r * 160,
      base: PAL[(Math.random() * PAL.length) | 0],
      hot: r > 0.9 ? (r > 0.97 ? "#ffb48a" : r > 0.94 ? "#ff6a3d" : "#ff3b30") : null,
    });
  }
  const t0 = performance.now();
  const FADE = 170;
  const step = (now) => {
    const t = now - t0;
    g.clearRect(0, 0, W, Hh);
    let live = 0;
    for (const c of cells) {
      const k = (t - c.at) / FADE;
      if (k >= 1) continue;
      live++;
      if (k < 0) { g.globalAlpha = 1; g.fillStyle = c.base; g.fillRect(c.x, c.y, cell, cell); continue; }
      // At its moment a cell burns (red/ember for a few), then goes.
      g.globalAlpha = 1 - k;
      g.fillStyle = c.hot && k < 0.55 ? c.hot : c.base;
      g.fillRect(c.x + k * 2, c.y + k * 2, cell - k * 4, cell - k * 4);
    }
    g.globalAlpha = 1;
    if (live) requestAnimationFrame(step);
    else g.clearRect(0, 0, W, Hh);
  };
  requestAnimationFrame(step);
}

// ---------------------------------------------------------------- pointer: click-through, hover intent, click guard
let pointer = null;
let overSent = null;
let hoverTimer = 0;
let leaveTimer = 0;
let lastMove = { x: 0, y: 0, t: 0 };
let changedAt = 0;
let anchor = null;
let moved = true;

function insideShape(p) {
  if (!p) return false;
  const r = island.getBoundingClientRect();
  const m = 6;
  return p.x >= r.left - m - 10 && p.x <= r.right + m + 10 && p.y >= -2 && p.y <= r.bottom + m;
}
function syncOver() {
  const on = insideShape(pointer) || (mode === "open" && document.activeElement === ta);
  if (on !== overSent) { overSent = on; bridge.over(on); }
}
function markChange() { changedAt = performance.now(); anchor = pointer; moved = false; }
/** A pointer click on a button counts only if the button was there long enough or the pointer moved onto it. */
function guarded(e) {
  if (e.detail === 0) return true; // keyboard
  return moved || performance.now() - changedAt > 700;
}

window.addEventListener("mousemove", (e) => {
  const p = { x: e.clientX, y: e.clientY };
  const now = performance.now();
  const speed = Math.hypot(p.x - lastMove.x, p.y - lastMove.y) / Math.max(1, now - lastMove.t);
  lastMove = { ...p, t: now };
  pointer = p;
  if (!moved && (!anchor || Math.hypot(p.x - anchor.x, p.y - anchor.y) > 12)) moved = true;
  const inside = insideShape(p);
  syncOver();
  if (inside) {
    clearTimeout(leaveTimer);
    leaveTimer = 0;
    if (mode !== "open" && (!hoverTimer || speed > 1.4)) {
      // Hover intent: open once the pointer settles on the shape (a fast pass toward the menu bar or tabs does not).
      clearTimeout(hoverTimer);
      hoverTimer = setTimeout(() => { hoverTimer = 0; if (insideShape(pointer)) setMode("open", "hover"); }, speed > 1.4 ? 220 : 130);
    }
  } else {
    clearTimeout(hoverTimer);
    hoverTimer = 0;
    scheduleClose();
  }
});
document.documentElement.addEventListener("mouseleave", () => { pointer = null; syncOver(); clearTimeout(hoverTimer); hoverTimer = 0; scheduleClose(); });
bridge.onAway(() => { pointer = null; overSent = false; clearTimeout(hoverTimer); hoverTimer = 0; scheduleClose(); });

function holding() {
  return summoned || voice.on || talk.waiting || (document.activeElement === ta && ta.value.trim().length > 0) || Date.now() < alertUntil || (talk.on && document.activeElement?.classList?.contains("talk-type"));
}
function scheduleClose(delay = 320) {
  if (mode !== "open" || leaveTimer) return;
  leaveTimer = setTimeout(() => {
    leaveTimer = 0;
    if (insideShape(pointer) || holding()) return;
    if (talk.on) { showTalkPeek(); return; }
    setMode(peekItem ? "peek" : "closed");
  }, delay);
}
window.addEventListener("blur", () => { summoned = false; if (!insideShape(pointer)) scheduleClose(150); });

island.addEventListener("contextmenu", (e) => { e.preventDefault(); bridge.menu(); });
island.addEventListener("click", (e) => {
  // A click on the closed shape opens it at once; on the peek line, it opens that chat.
  if (mode === "closed") { setMode("open", "click"); return; }
  if (mode === "peek" && peekItem?.kind === "talk") { setMode("open", "click"); return; }
  if (mode === "peek" && peekItem && guarded(e)) { bridge.act({ type: "open", chat_id: peekItem.chat_id }); clearPeek(); }
});

// ---------------------------------------------------------------- feed
bridge.onState((s) => {
  const first = data === null;
  data = s;
  setSounds(s.sounds);
  const feed = s.feed;
  stage.toggleAttribute("data-ready", true);
  ember.setPose(poseNow());
  renderEars();
  if (first) { lastSeq = feed.pulse?.seq ?? 0; layout(); render(); return; }
  if (feed.pulse && feed.pulse.seq !== lastSeq) { lastSeq = feed.pulse.seq; onPulse(feed.pulse); }
  if (peekItem && peekItem.kind !== "talk") {
    const s2 = feed.sessions.find((x) => x.chat_id === peekItem.chat_id);
    if (!s2 || (!s2.unseen && peekItem.kind !== "needs")) clearPeek();
  }
  render();
  syncGlow();
  layout();
});

function onPulse(p) {
  const s = data.feed.sessions.find((x) => x.chat_id === p.chat_id);
  if (p.kind === "needs") {
    play("needs");
    alertUntil = Date.now() + 9000;
    clearTimeout(alertTimer);
    alertTimer = setTimeout(() => { if (!insideShape(pointer)) scheduleClose(0); }, 9100);
    setMode("open", "alert");
    markChange();
    return;
  }
  play(p.kind === "done" ? "done" : "failed");
  transient = p.kind;
  clearTimeout(glowTimer);
  glowTimer = setTimeout(() => { transient = null; syncGlow(); }, p.kind === "done" ? 1200 : 5000);
  syncGlow();
  if (mode !== "open" && s && !talk.on) showPeek({ kind: p.kind, chat_id: s.chat_id, title: s.title, line: s.line, engine: s.engine, model: s.model }, p.kind === "done" ? 4600 : 6500);
}

function syncGlow() {
  const needs = data?.feed?.counts?.needs > 0;
  shell.dataset.glow = needs || talk.waiting ? "needs" : transient ?? (talk.on ? "talk" : "");
  if (transient === "done") { ring.style.animation = "none"; void ring.offsetWidth; ring.style.animation = ""; }
}

function showPeek(item, ms) {
  peekItem = item;
  peek.replaceChildren(
    h("span", { class: "k", "data-tone": item.kind }, item.kind === "done" ? "Done" : item.kind === "failed" ? "Failed" : "Needs you"),
    h("span", { class: "t" }, item.title || "Chat"),
    h("span", { class: "s" }, item.line || ""),
  );
  setMode("peek");
  clearTimeout(peekTimer);
  peekTimer = setTimeout(() => clearPeek(), ms);
}
function clearPeek() {
  clearTimeout(peekTimer);
  peekItem = null;
  if (talk.on && mode !== "open") { showTalkPeek(); return; }
  if (mode === "peek") setMode("closed");
}

// ---------------------------------------------------------------- ears
function led(tone) {
  // 3x3 matrix; the ring order around the edge, the centre dim.
  const order = [0, 1, 2, 5, 8, 7, 6, 3];
  const el = h("div", { class: "led", "data-tone": tone });
  for (let i = 0; i < 9; i++) {
    const k = order.indexOf(i);
    el.append(h("i", k >= 0 ? { "data-k": "", style: `--k:${k}` } : {}));
  }
  return el;
}
let earKey = "";
function renderEars() {
  const c = data.feed.counts;
  const key = `${c.needs}|${c.working}|${c.unseen}`;
  if (key === earKey) return;
  const [pn, , pu] = earKey ? earKey.split("|").map(Number) : [0, 0, 0];
  const grew = !!earKey && c.needs + c.unseen > pn + pu;
  earKey = key;
  const kids = [];
  if (c.needs) kids.push(led("needs"), h("span", { class: `badge${grew ? " pop" : ""}` }, pixelNumber(c.needs, "#fff", 2, 1)));
  else if (c.working) { kids.push(led("work")); if (c.working > 1) kids.push(pixelNumber(c.working, "rgba(255,255,255,.8)", 2, 1)); }
  else if (c.unseen) kids.push(h("span", { class: `badge${grew ? " pop" : ""}`, "data-tone": "done" }, pixelNumber(c.unseen, "#000", 2, 1)));
  else kids.push(h("span", { class: "dot" }));
  earR.replaceChildren(...kids);
}

// ---------------------------------------------------------------- logos
function logo(engine, model) {
  const e = engine || "api";
  const m = (model || "").toLowerCase();
  const img = (src) => h("img", { src, alt: "", draggable: "false" });
  const mono = (src) => h("span", { class: "mono", style: `--src:url("${src}")` });
  if (e === "claude-code" || (e === "api" && /claude|anthropic|opus|sonnet|haiku|fable/.test(m))) return img("./brand/engines/claude.svg");
  if (e === "codex" || (e === "api" && /gpt|openai|o\d/.test(m))) return mono("./brand/engines/codex.svg");
  if (e === "antigravity") return img("./brand/engines/antigravity-color.svg");
  if (e === "qoder") return mono("./brand/engines/qoder.svg");
  return img("./brand/opscode-mark-128.png");
}

// ---------------------------------------------------------------- panel
const ago = (ms) => {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${String(s % 60).padStart(2, "0")}s`;
  return `${Math.floor(m / 60)}h ${m % 60}m`;
};

function render() {
  if (!data) return;
  const f = data.feed;
  const talking = talk.on;
  head.hidden = talking;
  composer.hidden = talking;
  hint.hidden = talking;
  if (talking) {
    list.replaceChildren(talk.view(fresh));
    fresh = false;
    measureMarquees();
    return;
  }
  if (pickedWs !== MAC && (!pickedWs || !f.workspaces.some((w) => w.id === pickedWs))) pickedWs = f.workspace_id;
  if (replyTo && !f.sessions.some((s) => s.chat_id === replyTo)) replyTo = null;

  // Header
  const c = f.counts;
  const bits = [];
  if (c.needs) bits.push(h("span", { class: "nr" }, h("b", { style: "color:inherit" }, c.needs), " need you"));
  if (c.working) bits.push(h("span", {}, h("b", {}, c.working), " working"));
  if (c.unseen) bits.push(h("span", {}, h("b", {}, c.unseen), " new"));
  if (!bits.length) bits.push(h("span", {}, f.sessions.length ? "All caught up" : "All quiet"));
  const sum = h("div", { class: "sum" }, ...bits.flatMap((b, i) => (i ? [h("span", { style: "opacity:.4" }, "·"), b] : [b])));
  head.replaceChildren(
    h("span", { class: "ttl" }, "Opscode"), sum,
    h("button", { class: "ibtn", type: "button", title: "Show the workers on screen", html: ICON.grid, onclick: (e) => { if (guarded(e)) bridge.act({ type: "workers" }); } }),
    h("button", { class: "ibtn talkbtn", type: "button", title: `Talk to Opscode (${data.talkShortcut ?? "⌃⌥Space"})`, html: ICON.wave, onclick: (e) => { if (guarded(e)) void talk.start(); } }),
    h("button", { class: "ibtn", type: "button", title: data.sounds ? "Sounds on" : "Sounds off", html: data.sounds ? ICON.vol : ICON.mute, onclick: (e) => guarded(e) && bridge.act({ type: "sounds", on: !data.sounds }) }),
    h("button", { class: "ibtn", type: "button", title: "New chat in Opscode", html: ICON.plus, onclick: (e) => guarded(e) && bridge.act({ type: "newchat", workspace_id: pickedWs ?? undefined }) }),
    h("button", { class: "ibtn", type: "button", title: "Open Opscode", html: ICON.open, onclick: (e) => guarded(e) && bridge.act({ type: "open" }) }),
  );

  // List
  const kids = [];
  let i = 1;
  const needs = f.sessions.filter((s) => s.status === "needs");
  const working = f.sessions.filter((s) => s.status === "working");
  const finished = f.sessions.filter((s) => s.status === "done" || s.status === "failed");
  const recent = f.sessions.filter((s) => s.status === "idle").slice(0, Math.max(0, 5 - working.length - finished.length));
  if (needs.length) {
    kids.push(h("div", { class: "sect stagger", style: `--i:${i++}` }, "Needs you"));
    for (const s of needs) for (const a of s.approvals.slice(0, 2)) kids.push(approvalCard(s, a, i++));
  }
  if (working.length) { kids.push(h("div", { class: "sect stagger", style: `--i:${i++}` }, "Working")); for (const s of working) kids.push(row(s, i++)); }
  if (finished.length) {
    kids.push(h("div", { class: "sect stagger", style: `--i:${i++}` }, "Finished", h("span", { style: "flex:1" }),
      h("button", { class: "ibtn", type: "button", title: "Mark all seen", style: "width:20px;height:20px", html: ICON.check, onclick: (e) => guarded(e) && bridge.act({ type: "seen", all: true }) })));
    for (const s of finished) kids.push(row(s, i++));
  }
  if (recent.length) { kids.push(h("div", { class: "sect stagger", style: `--i:${i++}` }, "Recent")); for (const s of recent) kids.push(row(s, i++)); }
  if (!f.sessions.length) {
    const big = createCharacter(4, 2.2);
    big.setPose(f.pose);
    kids.push(h("div", { class: "empty stagger", style: "--i:1" }, h("div", { class: "big" }, big.el), h("div", { class: "t" }, "All quiet"), h("div", {}, "Press ", h("kbd", {}, data.shortcut), " anywhere to start a chat.")));
  }
  list.replaceChildren(...kids);
  if (!fresh) for (const el of panel.querySelectorAll(".stagger")) el.style.animation = "none";
  else for (const el of panel.querySelectorAll(".stagger")) el.style.animation = "";
  fresh = false;
  renderComposer();
  measureMarquees();
}

function approvalCard(s, a, i) {
  const allow = (e, extra = {}) => {
    if (!guarded(e)) return;
    e.currentTarget.disabled = true;
    bridge.act({ type: "approve", turn_id: a.turn_id, call_id: a.call_id, allow: true, ...extra });
  };
  const deny = (e) => { if (!guarded(e)) return; e.currentTarget.disabled = true; bridge.act({ type: "approve", turn_id: a.turn_id, call_id: a.call_id, allow: false }); };
  const btns = a.choices?.length
    ? [h("button", { class: "wbtn", type: "button", onclick: deny }, "Deny"), ...a.choices.slice(0, 3).map((ch, k) => h("button", { class: `wbtn${k === 0 ? " lit" : ""}`, type: "button", title: ch.hint ?? "", onclick: (e) => allow(e, { choice: ch.id }) }, ch.label))]
    : [
      h("button", { class: "wbtn", type: "button", onclick: deny }, "Deny"),
      h("button", { class: "wbtn", type: "button", title: "Allow, and don't ask again for this in this project", onclick: (e) => allow(e, { remember: "allow" }) }, "Always"),
      h("button", { class: "wbtn lit", type: "button", onclick: (e) => allow(e) }, "Allow"),
    ];
  return h("div", { class: "card stagger", style: `--i:${i}` },
    h("div", { class: "top" },
      h("div", { class: "mark" }, logo(s.engine, s.model)),
      h("div", { class: "who" }, h("div", { class: "t" }, s.title), h("div", { class: "p" }, s.project)),
      h("span", { class: "tag" }, led("needs"), "Approval")),
    h("div", { class: "what" }, h("b", {}, a.tool.replace(/_/g, " ")), a.summary ? ` · ${a.summary}` : ""),
    a.detail ? h("pre", {}, a.detail) : null,
    h("div", { class: "btns" }, ...btns),
  );
}

function row(s, i) {
  const now = Date.now();
  const time = s.status === "working" && s.started_at ? ago(now - s.started_at) : s.ended_at ? `${ago(now - s.ended_at)} ago` : "";
  const acts = [];
  acts.push(h("button", { class: "ibtn", type: "button", title: "Reply from here", html: ICON.reply, onclick: (e) => { e.stopPropagation(); if (!guarded(e)) return; replyTo = s.chat_id; renderComposer(); ta.focus(); } }));
  if (s.status === "working" && s.turn_id) acts.push(h("button", { class: "ibtn", type: "button", title: "Stop", html: ICON.stop, onclick: (e) => { e.stopPropagation(); if (guarded(e)) bridge.act({ type: "stop", turn_id: s.turn_id }); } }));
  if (s.unseen) acts.push(h("button", { class: "ibtn", type: "button", title: "Dismiss", html: ICON.x, onclick: (e) => { e.stopPropagation(); if (guarded(e)) bridge.act({ type: "seen", chat_id: s.chat_id }); } }));
  const side = h("div", { class: "side" }, h("span", { class: "tm", "data-start": s.status === "working" ? s.started_at ?? "" : "" }, time), h("div", { class: "acts" }, ...acts));
  if (s.status === "working") side.prepend(led("work"));
  return h("div", {
    class: "row stagger", style: `--i:${i}`, "data-status": s.status, title: "Open in Opscode",
    onclick: (e) => { if (guarded(e)) bridge.act({ type: "open", chat_id: s.chat_id }); },
  },
    h("div", { class: "mark" }, logo(s.engine, s.model), h("i", { class: "st" })),
    h("div", { class: "txt" },
      h("div", { class: "l1" }, h("span", { class: "t" }, s.title), s.project ? h("span", { class: "p" }, s.project) : null),
      h("div", { class: "l2" }, h("span", {}, s.line || (s.status === "idle" ? "Idle" : "…")))),
    side,
  );
}

function measureMarquees() {
  requestAnimationFrame(() => {
    for (const l2 of list.querySelectorAll(".l2")) {
      const span = l2.firstElementChild;
      const over = span.scrollWidth - l2.clientWidth;
      if (over > 4) { l2.dataset.long = ""; l2.style.setProperty("--mx", `${-over - 6}px`); l2.style.setProperty("--mq", `${Math.max(4, over / 28)}s`); }
    }
  });
}

// Elapsed times tick once a second, only while the panel is open.
setInterval(() => {
  if (mode !== "open") return;
  const now = Date.now();
  for (const el of list.querySelectorAll(".tm[data-start]")) { const t = Number(el.dataset.start); if (t) el.textContent = ago(now - t); }
}, 1000);

// ---------------------------------------------------------------- composer
function renderComposer() {
  const f = data.feed;
  const chat = replyTo ? f.sessions.find((s) => s.chat_id === replyTo) : null;
  const ws = f.workspaces.find((w) => w.id === pickedWs);
  if (!chat && pickedWs === MAC) {
    delete target.dataset.reply;
    target.dataset.mac = "";
    target.replaceChildren(h("span", { html: ICON.mac, style: "width:12px;height:12px;display:inline-flex" }), h("span", {}, "On my Mac"), h("span", { html: ICON.chev, style: "width:11px;height:11px;display:inline-flex;opacity:.7" }));
    target.title = "Opscode does it on your Mac (open apps, click, type). Click to switch to a project.";
    ta.placeholder = "Do it on my Mac — “open Chrome and search for USB-C hubs”";
    send.toggleAttribute("data-ready", ta.value.trim().length > 0);
    hint.replaceChildren(h("span", {}, "↵ do it · only risky steps ask"), h("span", {}, "esc close"));
    return;
  }
  delete target.dataset.mac;
  if (chat) {
    target.dataset.reply = "";
    target.replaceChildren(h("span", { html: ICON.reply, style: "width:12px;height:12px;display:inline-flex" }), h("span", {}, chat.title));
    target.title = "Replying to this chat. Click to start a new chat instead.";
    ta.placeholder = `Reply to “${chat.title}”…`;
  } else {
    delete target.dataset.reply;
    target.replaceChildren(h("span", {}, ws ? ws.name : "No project"), f.workspaces.length > 1 ? h("span", { html: ICON.chev, style: "width:11px;height:11px;display:inline-flex;opacity:.7" }) : "");
    target.title = f.workspaces.length > 1 ? "New chat in this project. Click to switch project." : "New chat in this project.";
    ta.placeholder = ws ? "Ask anything — starts a new chat" : "Add a project in Opscode first";
  }
  send.toggleAttribute("data-ready", ta.value.trim().length > 0);
  hint.replaceChildren(h("span", {}, "↵ send · ⇧↵ new line · esc close"), h("span", {}, "hold ", h("b", {}, "mic"), " to talk"));
}

target.addEventListener("click", (e) => {
  if (!guarded(e)) return;
  if (replyTo) { replyTo = null; renderComposer(); ta.focus(); return; }
  // Projects, then "On my Mac", then round again.
  const order = [...data.feed.workspaces.map((w) => w.id), MAC];
  const k = order.indexOf(pickedWs);
  pickedWs = order[(k + 1) % order.length];
  renderComposer();
});

function autosize() { ta.style.height = "28px"; ta.style.height = `${Math.min(90, ta.scrollHeight)}px`; }
ta.addEventListener("input", () => { autosize(); send.toggleAttribute("data-ready", ta.value.trim().length > 0); });
ta.addEventListener("focus", () => { bridge.act({ type: "focus", on: true }); syncOver(); });
ta.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey && !e.isComposing) { e.preventDefault(); submit(); }
  else if (e.key === "Escape") { e.preventDefault(); if (voice.on) return voiceCancel(); if (ta.value) { ta.value = ""; autosize(); renderComposer(); return; } summoned = false; ta.blur(); play("close"); setMode("closed"); }
});
window.addEventListener("keydown", (e) => { if (e.key === "Escape" && mode === "open" && document.activeElement !== ta) { summoned = false; setMode("closed"); } });
send.addEventListener("click", (e) => { if (guarded(e)) submit(); });

function submit() {
  const text = ta.value.trim();
  if (!text) return;
  const chat = replyTo ? data.feed.sessions.find((s) => s.chat_id === replyTo) : null;
  if (!chat && pickedWs === MAC) {
    bridge.act({ type: "mac", text });
    play("send");
    ta.value = "";
    autosize();
    renderComposer();
    toast("On it…", true);
    return;
  }
  if (!chat && !pickedWs) { toast("Add a project in Opscode first."); return; }
  bridge.act(chat ? { type: "send", text, chat_id: chat.chat_id } : { type: "send", text, workspace_id: pickedWs });
  play("send");
  ta.value = "";
  autosize();
  renderComposer();
  toast(chat ? `Sent to “${chat.title}”` : "Started a new chat", true);
}

let toastTimer = 0;
function toast(text, quiet = false) {
  toastEl.textContent = text;
  toastEl.style.color = quiet ? "var(--muted)" : "";
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toastEl.textContent = ""; }, 3500);
  if (mode !== "open" && !quiet) setMode("open", "toast");
}
bridge.onToast((t) => toast(t, /^(On it|Opened|Done|Switched|Quit)/.test(t)));

// ---------------------------------------------------------------- summon (global shortcut)
bridge.onSummon(() => {
  summoned = true;
  setMode("open", "summon");
  setTimeout(() => ta.focus(), 60);
});

// ---------------------------------------------------------------- voice: click to dictate, hold to talk and send
// One press starts; the next press (quick or slow) stops. Held down for a moment = talk, and letting go stops and sends.
const voice = { on: false, hold: false, base: "", committed: "", holdTimer: 0, stopOnUp: false, down: false, guard: 0 };
mic.addEventListener("pointerdown", (e) => {
  if (e.button !== 0 || !guarded(e)) return;
  voice.down = true;
  if (voice.on) { voice.stopOnUp = true; return; }
  voice.hold = false;
  voice.holdTimer = setTimeout(() => { if (voice.down && voice.on) voice.hold = true; }, 320);
  voiceStart();
});
const micUp = () => {
  if (!voice.down) return;
  voice.down = false;
  clearTimeout(voice.holdTimer);
  if (voice.stopOnUp) { voice.stopOnUp = false; voiceStop(); return; }
  if (voice.hold) { voice.hold = false; voice.autoSend = true; voiceStop(); }
};
mic.addEventListener("pointerup", micUp);
mic.addEventListener("pointerleave", () => { if (voice.down && voice.hold) micUp(); });
function voiceStart() {
  voice.on = true;
  voice.autoSend = false;
  voice.base = ta.value && !/\s$/.test(ta.value) ? `${ta.value} ` : ta.value;
  voice.committed = "";
  mic.toggleAttribute("data-on", true);
  bridge.act({ type: "voice", op: "start" });
}
let voiceCapture = null;
let captureGeneration = 0;
function stopVoiceCapture() { captureGeneration++; voiceCapture?.stop(); voiceCapture = null; }
function voiceStop() {
  stopVoiceCapture();
  mic.dataset.stopping = "";
  bridge.act({ type: "voice", op: "stop" });
  // If the recognizer never answers, never leave the button stuck red.
  clearTimeout(voice.guard);
  voice.guard = setTimeout(() => { if (voice.on) { voiceEnd(); bridge.act({ type: "voice", op: "cancel" }); } }, 45000);
}
function voiceCancel() { stopVoiceCapture(); voice.autoSend = false; bridge.act({ type: "voice", op: "cancel" }); }
function voiceEnd() { stopVoiceCapture(); voice.on = false; voice.hold = false; voice.stopOnUp = false; clearTimeout(voice.guard); mic.removeAttribute("data-on"); delete mic.dataset.stopping; mic.style.removeProperty("--lvl"); }
function writeVoice(text) { ta.value = voice.base + text; autosize(); send.toggleAttribute("data-ready", ta.value.trim().length > 0); }
bridge.onVoice((v) => {
  switch (v.ev) {
    case "started": break;
    case "level": mic.style.setProperty("--lvl", String(Math.max(0, Math.min(1, v.rms ?? 0)))); break;
    case "capture": {
      const generation = ++captureGeneration;
      void startCapture({
        onChunk: (pcm) => {
          if (voice.on && captureGeneration === generation) bridge.act({ type: "voice_audio", pcm });
        },
      }).then((mic) => {
        if (!voice.on || captureGeneration !== generation) mic.stop();
        else voiceCapture = mic;
      }).catch((e) => {
        if (captureGeneration !== generation) return;
        voiceCancel();
        toast(micMessage(e));
      });
      break;
    }
    case "partial": writeVoice(voice.committed + (voice.committed && v.text ? " " : "") + (v.text ?? "")); break;
    case "final": voice.committed = v.full ?? voice.committed; writeVoice(voice.committed); break;
    case "done": {
      writeVoice((v.text ?? voice.committed).trim());
      const go = voice.autoSend;
      voiceEnd();
      if (go && ta.value.trim()) submit();
      else ta.focus();
      break;
    }
    case "cancelled": voiceEnd(); writeVoice(""); break;
    case "error": voiceEnd(); if (v.message) toast(v.message); break;
  }
});

// ---------------------------------------------------------------- demo (notch.html?demo=… in a plain browser)
function demoBridge() {
  const q = new URLSearchParams(location.search);
  const kind = q.get("demo") ?? "open";
  const now = Date.now();
  const ws = [{ id: "w1", name: "dealker-app" }, { id: "w2", name: "opscode" }];
  const sessions = [
    { chat_id: "c1", workspace_id: "w1", title: "Fix the checkout total", project: "dealker-app", engine: "claude-code", status: "needs", line: "Running npm test", turn_id: "t1", approvals: [{ turn_id: "t1", call_id: "k1", tool: "run_command", summary: "npm run migrate", detail: "npm run migrate -- --env staging", at: now }], started_at: now - 95_000, unseen: false, updated: now },
    { chat_id: "c2", workspace_id: "w2", title: "Notch window animations", project: "opscode", engine: "codex", status: "working", line: "Editing src/renderer/notch.css — tightening the spring on open and the blur on the panel content", turn_id: "t2", approvals: [], started_at: now - 42_000, unseen: false, updated: now },
    { chat_id: "c3", workspace_id: "w2", title: "Usage page numbers", project: "opscode", engine: "api", model: "claude-opus-5-5", status: "done", line: "All 42 checks pass. The page now shows the weekly limit.", approvals: [], ended_at: now - 30_000, unseen: true, updated: now },
    { chat_id: "c4", workspace_id: "w1", title: "Lead scout robots.txt", project: "dealker-app", engine: "antigravity", status: "idle", line: "Done", approvals: [], ended_at: now - 3_600_000, unseen: false, updated: now - 3_600_000 },
  ];
  const pick = { sleep: [], working: sessions.slice(1, 2), done: sessions.slice(2, 3), needs: sessions.slice(0, 2), open: sessions }[kind] ?? sessions;
  const counts = { working: pick.filter((s) => s.status === "working").length, needs: pick.filter((s) => s.status === "needs").length, unseen: pick.filter((s) => s.unseen).length };
  const pose = counts.needs ? "needs" : counts.working ? "working" : counts.unseen ? "done" : "sleeping";
  const feed = { sessions: pick, counts, pose, pulse: null, workspaces: ws, workspace_id: "w2" };
  const state = { feed, hardware: { width: 185, height: 32 }, bar: 33, sounds: false, shortcut: "⌘⇧Space" };
  document.documentElement.style.background = q.has("light") ? "#d8d8de" : "#2a2a30";
  document.body.style.background = "transparent";
  return {
    onState: (fn) => {
      setTimeout(() => fn(state), 30);
      if (kind === "open" || kind === "needs" || kind === "talk") setTimeout(() => setMode("open", "click"), 400);
      if (kind === "done") setTimeout(() => { fn({ ...state, feed: { ...feed, pulse: { seq: 1, kind: "done", chat_id: "c3" } } }); }, 600);
    },
    onAway: () => {}, onSummon: () => {}, onVoice: () => {}, onToast: () => {}, onTalkSummon: () => {},
    onTalk: (fn) => {
      if (kind !== "talk") return;
      // A scripted conversation (no microphone in the demo): what voice mode looks like.
      const ev = (e, ms) => setTimeout(() => fn(e), ms);
      ev({ kind: "on", session: "demo" }, 700);
      ev({ kind: "agent", ev: "picks", brain: { engine: "claude-code", model: "claude-sonnet-5-5" }, worker: { engine: "codex", model: "gpt-6.1-sol", effort: "high" } }, 750);
      ev({ kind: "agent", ev: "state", state: "hearing" }, 900);
      ev({ kind: "agent", ev: "partial", text: "fix the login in deal car server and use codex with high" }, 1100);
      ev({ kind: "agent", ev: "heard", text: "Fix the login in the dealker server, and use Codex with high effort." }, 1500);
      ev({ kind: "agent", ev: "state", state: "thinking" }, 1550);
      ev({ kind: "agent", ev: "tool", summary: "Find the project: deal car server" }, 1600);
      ev({ kind: "agent", ev: "worker", id: "w1", title: "Server login fix", project: "dealker-server", engine: "codex", model: "gpt-6.1-sol", effort: "high", status: "running", current: "Reading src/routes/auth.ts", started_at: Date.now() }, 1900);
      ev({ kind: "agent", ev: "worker", id: "w2", title: "Billing PDF totals", project: "billing-tool", engine: "claude-code", model: "claude-opus-5-5", status: "running", current: "Waiting", started_at: Date.now() - 60000, ask: { call_id: "k9", summary: "Run cargo run --bin migrate", detail: "cargo run --bin migrate -- --apply" } }, 2000);
      ev({ kind: "agent", ev: "state", state: "speaking" }, 2100);
      ev({ kind: "agent", ev: "say", text: "Starting it in the dealker server on Codex, high effort. The billing one wants to run a migration. Go ahead?" }, 2150);
    },
    act: (a) => console.log("act", a), over: () => {}, menu: () => {},
  };
}
