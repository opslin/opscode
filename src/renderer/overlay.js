// The overlay page (overlay.html in its own clear, click-through window; src/main/overlay.ts). Draws what main says:
//   working  pixel comets running round the screen's rounded edge, sparks, a breathing red glow, and a caption
//   rect     a frame of marching red pixels round the app window being used, with bright corner brackets and a tag
//   gallery  the workers' mini screens (their live step, the end of what they said, their ask as an input line)
// The animation loop runs only while something is shown (nothing runs when it is hidden).

const bridge = window.opscodeOverlay ?? demoBridge();
const canvas = document.querySelector(".px");
const g = canvas.getContext("2d");
const tag = document.querySelector(".frametag");
const caption = document.querySelector(".caption .what");
const gallery = document.querySelector(".gallery");
const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

let state = { working: false, summary: "", app: "", rect: null, gallery: false, feed: null };
let raf = 0;
let fade = 0; // 0..1, eases in and out so the light never pops
let shownRect = null; // the frame eases to the window's new place

const PX = 5;       // a "pixel" of the effect, in CSS px
const GRID = 6;     // they sit on a 6 px grid

// ---- geometry: a point at distance d along a rounded rectangle's edge (clockwise from the top-left corner's end) ----
function perimeter(x, y, w, h, r) {
  const straight = [w - 2 * r, h - 2 * r, w - 2 * r, h - 2 * r];
  const arc = (Math.PI / 2) * r;
  const total = 2 * (w + h) - 8 * r + 4 * arc;
  const at = (d) => {
    d = ((d % total) + total) % total;
    const segs = [
      [straight[0], (t) => [x + r + t, y]],
      [arc, (t) => { const a = -Math.PI / 2 + t / r; return [x + w - r + r * Math.cos(a), y + r + r * Math.sin(a)]; }],
      [straight[1], (t) => [x + w, y + r + t]],
      [arc, (t) => { const a = t / r; return [x + w - r + r * Math.cos(a), y + h - r + r * Math.sin(a)]; }],
      [straight[2], (t) => [x + w - r - t, y + h]],
      [arc, (t) => { const a = Math.PI / 2 + t / r; return [x + r + r * Math.cos(a), y + h - r + r * Math.sin(a)]; }],
      [straight[3], (t) => [x, y + h - r - t]],
      [arc, (t) => { const a = Math.PI + t / r; return [x + r + r * Math.cos(a), y + r + r * Math.sin(a)]; }],
    ];
    for (const [len, f] of segs) { if (d <= len) return f(d); d -= len; }
    return [x + r, y];
  };
  return { total, at };
}
const snap = (v) => Math.round(v / GRID) * GRID;
function sq(x, y, color, alpha, size = PX) {
  g.globalAlpha = alpha;
  g.fillStyle = color;
  g.fillRect(snap(x) - size / 2, snap(y) - size / 2, size, size);
}

// A comet: a bright head and a trail that cools from white to ember to red.
const TRAIL = ["#ffffff", "#ffe2cf", "#ffc2a3", "#ff9a6b", "#ff7a45", "#ff5a36", "#ff4433", "#ff3b30", "#e8342a", "#cc2c24", "#b02520", "#931e1a", "#7a1915", "#611311"];
function comet(path, head, dir, a) {
  for (let i = 0; i < TRAIL.length * 2; i++) {
    const [x, y] = path.at(head - dir * i * GRID);
    sq(x, y, TRAIL[Math.min(TRAIL.length - 1, i >> 1)], a * (1 - i / (TRAIL.length * 2)) * (i === 0 ? 1 : 0.95), i === 0 ? PX + 1 : PX);
  }
}

const sparks = [];
function draw(now) {
  raf = 0;
  const W = innerWidth, H = innerHeight;
  const dpr = Math.min(2, devicePixelRatio || 1);
  if (canvas.width !== Math.round(W * dpr)) { canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr); }
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.clearRect(0, 0, W, H);
  const want = state.working ? 1 : 0;
  fade += (want - fade) * 0.12;
  if (Math.abs(want - fade) < 0.01) fade = want;
  const t = now / 1000;

  if (fade > 0.01) {
    // Round the screen: two comets going opposite ways, and sparks that flicker along the edge.
    const edge = perimeter(4, 4, W - 8, H - 8, 14);
    const speed = reduced() ? 0 : 520;
    comet(edge, t * speed, 1, fade);
    comet(edge, edge.total / 2 - t * speed * 0.8, -1, fade * 0.8);
    if (!reduced() && Math.random() < 0.6) sparks.push({ d: Math.random() * edge.total, life: 1, c: Math.random() < 0.3 ? "#ffd2b8" : "#ff4433" });
    for (let i = sparks.length - 1; i >= 0; i--) {
      const s = sparks[i];
      s.life -= 0.035;
      if (s.life <= 0) { sparks.splice(i, 1); continue; }
      const [x, y] = edge.at(s.d);
      sq(x, y, s.c, s.life * 0.7 * fade, PX - 1);
    }
    if (sparks.length > 140) sparks.splice(0, sparks.length - 140);
  } else sparks.length = 0;

  // Round the app: marching red pixels, bright corner brackets.
  const target = state.rect && fade > 0.01 ? state.rect : null;
  if (target) {
    shownRect = shownRect ? Object.fromEntries(["x", "y", "w", "h"].map((k) => [k, shownRect[k] + (target[k] - shownRect[k]) * 0.25])) : { ...target };
    const r = { x: shownRect.x - 6, y: shownRect.y - 6, w: shownRect.w + 12, h: shownRect.h + 12 };
    const box = perimeter(r.x, r.y, r.w, r.h, 12);
    const step = GRID;
    const n = Math.floor(box.total / step);
    const march = reduced() ? 0 : Math.floor(t * 14);
    for (let i = 0; i < n; i++) {
      const [x, y] = box.at(i * step);
      const lit = (i + march) % 9 < 3;
      sq(x, y, lit ? ((i + march) % 9 === 2 ? "#ffd2b8" : "#ff7a45") : "#ff3b30", (lit ? 1 : 0.72) * fade, lit ? PX : PX - 1);
    }
    // Corner brackets: three pixels each way from every corner, white-hot.
    const corners = [[r.x, r.y, 1, 1], [r.x + r.w, r.y, -1, 1], [r.x, r.y + r.h, 1, -1], [r.x + r.w, r.y + r.h, -1, -1]];
    for (const [cx, cy, sx, sy] of corners) for (let k = 0; k < 4; k++) { sq(cx + sx * k * GRID, cy, k ? "#ffd2b8" : "#ffffff", fade); sq(cx, cy + sy * k * GRID, k ? "#ffd2b8" : "#ffffff", fade); }
    // A soft glow behind the frame.
    g.globalAlpha = 0.22 * fade;
    g.shadowColor = "rgba(255,50,30,0.9)"; g.shadowBlur = 28; g.strokeStyle = "rgba(255,60,40,0.6)"; g.lineWidth = 2;
    g.beginPath(); g.roundRect(r.x, r.y, r.w, r.h, 12); g.stroke(); g.shadowBlur = 0;
    tag.style.left = `${Math.max(8, r.x)}px`;
    tag.style.top = `${r.y > 34 ? r.y - 30 : r.y + 10}px`;
    tag.toggleAttribute("data-on", true);
  } else { shownRect = null; tag.removeAttribute("data-on"); }
  g.globalAlpha = 1;

  if (state.working || fade > 0.01) raf = requestAnimationFrame(draw);
  else g.clearRect(0, 0, W, H);
}
const kick = () => { if (!raf) raf = requestAnimationFrame(draw); };

// ---- the workers' mini screens ----------------------------------------------------------------------------------------
function el(tagName, attrs = {}, ...kids) {
  const e = document.createElement(tagName);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === "class") e.className = v; else if (k === "style") e.style.cssText = v; else if (k.startsWith("on")) e.addEventListener(k.slice(2), v); else e.setAttribute(k, v === true ? "" : String(v));
  }
  for (const c of kids.flat()) if (c != null && c !== false) e.append(c instanceof Node ? c : document.createTextNode(String(c)));
  return e;
}
function logo(engine, model) {
  const m = (model || "").toLowerCase();
  const img = (src) => el("img", { src, alt: "" });
  const mono = (src) => el("span", { class: "mono", style: `--src:url("${src}")` });
  if (engine === "claude-code" || (engine === "api" && /claude|opus|sonnet|haiku|fable/.test(m))) return img("./brand/engines/claude.svg");
  if (engine === "codex" || (engine === "api" && /gpt|openai/.test(m))) return mono("./brand/engines/codex.svg");
  if (engine === "antigravity") return img("./brand/engines/antigravity-color.svg");
  if (engine === "qoder") return mono("./brand/engines/qoder.svg");
  return img("./brand/opscode-mark-128.png");
}
const ago = (ms) => { const s = Math.max(0, Math.round(ms / 1000)); return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`; };
const STATUS = { working: "Working", needs: "Needs you", done: "Done", failed: "Failed", idle: "Idle" };
let galleryKey = "";
function renderGallery() {
  const on = !!state.gallery;
  gallery.hidden = !on;
  if (!on) { galleryKey = ""; return; }
  const sessions = (state.feed?.sessions ?? []).filter((s) => s.status !== "idle").concat((state.feed?.sessions ?? []).filter((s) => s.status === "idle")).slice(0, 9);
  const key = JSON.stringify(sessions.map((s) => [s.chat_id, s.status, s.line, (s.tail ?? "").length]));
  if (key === galleryKey) return;
  const fresh = !galleryKey;
  galleryKey = key;
  const cols = Math.max(1, Math.min(3, sessions.length || 1));
  const now = Date.now();
  const screens = sessions.map((s, i) => el("div", { class: "screen", "data-status": s.status, style: `--i:${fresh ? i : 0}${fresh ? "" : ";animation:none"}`, onclick: () => bridge.act({ type: "open", chat_id: s.chat_id }), title: "Open in Opscode" },
    el("div", { class: "bar" }, el("span", { class: "dots" }, el("i"), el("i"), el("i")), el("span", { class: "logo" }, logo(s.engine, s.model)), el("span", { class: "t" }, s.title || "Chat"), el("span", { class: "st" }, STATUS[s.status] ?? s.status)),
    el("div", { class: "body" },
      el("div", { class: "now" }, el("i", { class: "spin" }), s.status === "needs" && s.approvals?.[0] ? `Wants to: ${s.approvals[0].summary}` : s.line || (s.status === "working" ? "Thinking…" : "—")),
      el("div", { class: "tail" }, (s.tail ?? "").trim().split("\n").slice(-7).join("\n"))),
    el("div", { class: "input" }, el("span", { class: "chev" }, "›"), el("span", { class: "q" }, s.title || "…"), s.status === "working" ? el("i", { class: "caret" }) : null),
    el("div", { class: "foot" }, el("span", {}, s.project || ""), el("span", {}, s.status === "working" && s.started_at ? ago(now - s.started_at) : s.model || s.engine || ""))));
  gallery.replaceChildren(
    el("div", { class: "g-head" }, el("span", { class: "ttl" }, "Workers"), el("span", {}, sessions.length ? `${sessions.filter((s) => s.status === "working").length} at work · ${sessions.length} shown` : ""), el("span", {}, el("kbd", {}, "esc"), " to close"), el("button", { class: "g-close", type: "button", onclick: () => bridge.act({ type: "close" }), "aria-label": "Close" }, "✕")),
    sessions.length ? el("div", { class: "g-grid", style: `--cols:${cols}` }, ...screens) : el("div", { class: "g-empty" }, "No chats at work right now."),
  );
}
gallery.addEventListener("click", (e) => { if (e.target === gallery) bridge.act({ type: "close" }); });
window.addEventListener("keydown", (e) => { if (e.key === "Escape" && state.gallery) bridge.act({ type: "close" }); });

bridge.onState((s) => {
  state = { ...state, ...s };
  document.body.toggleAttribute("data-working", !!state.working);
  tag.querySelector("span").textContent = state.app ? `· ${state.app}` : "";
  caption.replaceChildren(...(state.working ? ["Opscode is using ", Object.assign(document.createElement("b"), { textContent: state.app || "your Mac" }), state.summary ? ` · ${state.summary}` : ""] : []));
  renderGallery();
  kick();
});

function demoBridge() {
  const q = new URLSearchParams(location.search).get("demo") ?? "working";
  // A pretend desktop behind the overlay, and a hook that draws frames on demand (a hidden preview tab runs no animation).
  const desk = document.createElement("div");
  desk.style.cssText = "position:fixed;inset:0;z-index:-1;background:linear-gradient(135deg,#2b3a55,#5a3d6b 60%,#c97b5a)";
  document.body.prepend(desk);
  window.__frames = (n = 30) => { let t = performance.now(); for (let i = 0; i < n; i++) { t += 16; raf = 0; draw(t); } cancelAnimationFrame(raf); raf = 0; return n; };
  const now = Date.now();
  const feed = { sessions: [
    { chat_id: "a", title: "Fix the checkout total", project: "dealker-app", engine: "claude-code", model: "claude-opus-5-5", status: "working", line: "Running npm test", tail: "Found the bug in cart.ts: the discount\nwas applied twice when a coupon and a\nloyalty point were both used.\nPatching applyDiscount() now.", started_at: now - 95000 },
    { chat_id: "b", title: "Server login fix", project: "dealker-server", engine: "codex", model: "gpt-6.1-sol", status: "needs", line: "Wants to run the migration", approvals: [{ summary: "npm run migrate" }], tail: "Added the 401 message.\nThe users table needs a new column.", started_at: now - 40000 },
    { chat_id: "c", title: "Billing PDF totals", project: "billing-tool", engine: "antigravity", status: "done", line: "All 42 checks pass.", tail: "Totals now round per line, then sum.\nAll 42 checks pass." },
  ] };
  return {
    onState: (fn) => setTimeout(() => fn(q === "workers" ? { gallery: true, feed } : { working: true, app: "Google Chrome", summary: "Clicking “Search”", rect: { x: 260, y: 140, w: Math.min(1100, innerWidth - 520), h: Math.min(640, innerHeight - 260) } }), 50),
    act: (a) => console.log("act", a),
  };
}
