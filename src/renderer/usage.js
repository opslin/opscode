// Usage limits page: how much of each plan window is left on Claude Code and
// Codex (5-hour session and weekly), when each refills, and whether the current
// pace lasts until then. Pixel art throughout: a "pixel sea" whose water level is
// what's left of the session, waving pixel meters, and dot-matrix countdowns.

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { engineMark } from "./modelpicker.js";
import { accountsOf, accountTitle, signedIn } from "./accounts.js";
import { createTokensView } from "./usagetokens.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
const NAME = { "claude-code": "Claude Code", codex: "Codex" };
const PLAN = (p) => (p ? p.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()) : null);
const COLOR = { "claude-code": [217, 119, 87], codex: [122, 157, 255] };
const levelColor = (engine, left) => (left < 5 ? [239, 68, 68] : left < 20 ? [240, 160, 60] : COLOR[engine] ?? [200, 200, 200]);
const rgb = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;

// ---- time words ----------------------------------------------------------------------------
const pad = (n) => String(n).padStart(2, "0");
function parts(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 };
}
function spoken(ms) {
  const p = parts(ms);
  if (p.d) return `${p.d}d ${p.h}h`;
  if (p.h) return `${p.h}h ${p.m}m`;
  if (p.m) return `${p.m}m ${p.s}s`;
  return `${p.s}s`;
}
function when(iso) {
  const d = new Date(iso);
  const now = new Date();
  const time = d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  const day = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const diff = Math.round((day(d) - day(now)) / 86400000);
  if (diff === 0) return `today at ${time}`;
  if (diff === 1) return `tomorrow at ${time}`;
  return `${d.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" })} at ${time}`;
}
const ago = (iso) => { const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000); return s < 10 ? "just now" : s < 60 ? `${Math.floor(s)}s ago` : s < 3600 ? `${Math.floor(s / 60)} min ago` : `${Math.floor(s / 3600)} h ago`; };

/** Will this pace last until the window refills? */
function pace(w, now = Date.now()) {
  if (!w.resets_at || !w.window_mins) return null;
  const total = w.window_mins * 60_000;
  const end = Date.parse(w.resets_at);
  const elapsed = Math.max(0, Math.min(total, total - (end - now)));
  const gone = elapsed / total;
  if (w.used_percent >= 100) return { gone, text: `Used up. It refills ${when(w.resets_at)}.`, tone: "bad" };
  if (elapsed < 60_000 || w.used_percent < 0.5) return { gone, text: w.kind === "session" ? "Barely touched. Plenty left for this window." : "Barely touched this week.", tone: "ok" };
  const rate = w.used_percent / elapsed; // percent per ms
  const outAt = now + (100 - w.used_percent) / rate;
  if (outAt < end) return { gone, text: `At this pace it runs out around ${when(new Date(outAt).toISOString())}, ${spoken(end - outAt)} before it refills.`, tone: "warn" };
  return { gone, text: `Used ${Math.round(w.used_percent)}% with ${Math.round(gone * 100)}% of the window gone: this pace lasts until it refills.`, tone: "ok" };
}

// ---- dot-matrix digits (3x5) -----------------------------------------------------------------
const GLYPH = {
  0: "111101101101111", 1: "010110010010111", 2: "111001111100111", 3: "111001111001111", 4: "101101111001001",
  5: "111100111001111", 6: "111100111101111", 7: "111001010010010", 8: "111101111101111", 9: "111101111001111",
  D: "110101101101110", ":": "0101000101", " ": "0000000000",
};
function pixelClock() {
  const el = h("span", { class: "px-clock", role: "timer" });
  let shown = "";
  return {
    el,
    set(text, label) {
      el.setAttribute("aria-label", label);
      el.dataset.text = text;
      if (text === shown) return;
      const old = shown;
      shown = text;
      if (el.childElementCount !== text.length) { el.replaceChildren(); for (const ch of text) el.append(glyph(ch, true)); return; }
      [...text].forEach((ch, i) => { if (old[i] !== ch) el.children[i].replaceWith(glyph(ch, false)); });
    },
  };
}
function glyph(ch, first) {
  const bits = GLYPH[ch] ?? GLYPH[" "];
  const cols = bits.length / 5;
  const g = h("span", { class: `px-glyph${first ? "" : " flip"}`, style: `--cols:${cols}` });
  [...bits].forEach((b, i) => g.append(h("i", { class: b === "1" ? "on" : "", style: `--d:${(i % cols) * 25 + Math.floor(i / cols) * 18}ms` })));
  return g;
}
const clockText = (ms) => { const p = parts(ms); return p.d ? `${p.d}D ${pad(p.h)}:${pad(p.m)}` : `${pad(p.h)}:${pad(p.m)}:${pad(p.s)}`; };

// ---- waving pixel meter -----------------------------------------------------------------------
const CELLS = 40;
function meter(engine, left) {
  const lit = Math.round((left / 100) * CELLS);
  const col = levelColor(engine, left);
  const m = h("div", { class: "px-meter", role: "meter", "aria-valuemin": 0, "aria-valuemax": 100, "aria-valuenow": Math.round(left), "aria-label": `${Math.round(left)}% left`, style: `--c:${rgb(col)};--c2:${rgb(col, 0.35)}` });
  for (let i = 0; i < CELLS; i++) m.append(h("i", { class: i < lit ? "on" : "", style: `--i:${i}` }));
  return m;
}

// ---- pixel sea: the water level is what's left of the session --------------------------------
function pixelSea(engine) {
  const c = h("canvas", { class: "px-sea", "aria-hidden": "true" });
  const g = c.getContext("2d");
  let level = 1; // 0..1 target
  let shownLevel = 0;
  let col = COLOR[engine];
  let raf = 0;
  let t = Math.random() * 100;
  const P = 4; // pixel size
  const draw = () => {
    const w = c.clientWidth;
    const hgt = c.clientHeight;
    if (!w || !hgt) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    if (c.width !== Math.round(w * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(hgt * dpr); }
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, w, hgt);
    shownLevel += (level - shownLevel) * 0.06;
    const rows = Math.floor(hgt / P);
    const cols = Math.ceil(w / P);
    const base = rows * (1 - shownLevel);
    for (let x = 0; x < cols; x++) {
      const y1 = base + Math.sin(x * 0.22 + t) * 1.6 + Math.sin(x * 0.07 - t * 0.6) * 1.2;
      const top = Math.max(0, Math.round(y1));
      for (let y = top; y < rows; y++) {
        const depth = (y - top) / Math.max(1, rows - top);
        g.fillStyle = y === top ? rgb([255, 255, 255], 0.55) : rgb(col, 0.55 - depth * 0.35);
        g.fillRect(x * P, y * P, P - 1, P - 1);
      }
      // a second, fainter wave behind
      const y2 = Math.round(base + Math.sin(x * 0.15 - t * 0.8 + 2) * 2.2) - 1;
      if (y2 >= 0 && y2 < top) { g.fillStyle = rgb(col, 0.18); g.fillRect(x * P, y2 * P, P - 1, P - 1); }
    }
    // sparkles on the surface
    for (let k = 0; k < 3; k++) {
      const x = Math.floor(((t * 7 + k * 37) % cols + cols) % cols);
      const y = Math.round(base + Math.sin(x * 0.22 + t) * 1.6 + Math.sin(x * 0.07 - t * 0.6) * 1.2) - 1;
      if (y >= 0) { g.fillStyle = "rgba(255,255,255,0.8)"; g.fillRect(x * P, y * P, P - 1, P - 1); }
    }
  };
  const loop = () => {
    raf = 0;
    if (!c.isConnected || c.offsetParent === null || document.hidden) return; // paused while off screen
    t += 0.045;
    draw();
    raf = requestAnimationFrame(loop);
  };
  return {
    el: c,
    set(left, engineColor) { level = Math.max(0, Math.min(1, left / 100)); col = engineColor; if (reduced()) { shownLevel = level; draw(); } else if (!raf) raf = requestAnimationFrame(loop); },
    wake() { if (reduced()) { shownLevel = level; draw(); } else if (!raf) raf = requestAnimationFrame(loop); },
  };
}

// ---- the page --------------------------------------------------------------------------------
export function createUsagePage() {
  const refreshBtn = h("button", { class: "btn btn-sm us-refresh", type: "button", onclick: () => load(true) }, icon("reload"), "Check now");
  const checked = h("span", { class: "us-checked" });
  const grid = h("div", { class: "us-grid" });
  const help = h("details", { class: "us-help" },
    h("summary", {}, icon("chevron-right", "icon us-help-caret"), "How these limits work"),
    h("ul", {},
      h("li", {}, h("strong", {}, "5-hour session. "), "Your plan allows a set amount of use in a rolling 5-hour window. The window starts with your first message after it refills; when the timer reaches zero it refills to 100% and the next session starts with your next message."),
      h("li", {}, h("strong", {}, "Weekly. "), "A second, larger limit over 7 days. It refills at the time shown, whatever the session timer says. When it runs out, sessions can't refill until it does."),
      h("li", {}, h("strong", {}, "Shared. "), "These limits count everything on your account: the Claude or ChatGPT apps, the CLIs, and Opscode's chats. Opscode reads them from Claude Code and Codex without running a model, so checking costs nothing."),
      h("li", {}, h("strong", {}, "Pace. "), "Compares how much you've used with how much of the window has passed, and says whether the current rate lasts until it refills.")));
  const tokens = createTokensView();
  tokens.el.hidden = true;
  let tab = "limits";
  const title = h("h1", {}, "Usage limits");
  const sub = h("p", {}, "How much of your Claude and Codex plans is left, and when it refills.");
  const tabBtn = (id, label) => h("button", { class: "us-tab", type: "button", dataset: { tab: id }, "aria-pressed": String(tab === id), onclick: () => setTab(id) }, label);
  const tabs = h("div", { class: "us-tabs", role: "group", "aria-label": "Usage views" }, tabBtn("limits", "Limits"), tabBtn("tokens", "Where tokens go"));
  function setTab(id) {
    tab = id;
    for (const b of tabs.children) b.setAttribute("aria-pressed", String(b.dataset.tab === id));
    const limitsTab = id === "limits";
    grid.hidden = !limitsTab; help.hidden = !limitsTab; checked.hidden = !limitsTab; refreshBtn.hidden = !limitsTab; tokens.el.hidden = limitsTab;
    title.textContent = limitsTab ? "Usage limits" : "Where tokens go";
    sub.textContent = limitsTab ? "How much of your Claude and Codex plans is left, and when it refills." : "What your Claude Code and Codex sessions burn, and what to change.";
    if (!limitsTab) tokens.show();
  }
  const root = h("div", { class: "us-page pane-surface" },
    h("div", { class: "us-scroll" },
      h("div", { class: "us-inner" },
        h("header", { class: "us-head" }, h("div", { class: "grow" }, title, sub), checked, refreshBtn),
        tabs, grid, help, tokens.el)));
  let limits = [];
  const cards = new Map(); // engine -> { sea, clocks: Map(window id -> clock), el }
  let timer = 0;
  let poll = 0;
  let busy = false;

  async function load(force) {
    if (busy) return;
    busy = true;
    refreshBtn.classList.add("spin");
    refreshBtn.disabled = true;
    try { const r = await state.client.call("limits.get", { refresh: !!force, all_accounts: true }); state.limitsByAccount = r.by_account ?? []; update(r.limits); }
    catch (e) { toast(`Couldn't read the limits: ${e.message}`); }
    finally { busy = false; refreshBtn.classList.remove("spin"); refreshBtn.disabled = false; }
  }

  function update(next) {
    limits = next ?? [];
    state.limits = limits;
    render();
  }

  /** More than one signed-in account on an engine: it gets a card per account. */
  const multi = (e) => accountsOf(e).filter(signedIn).length > 1;
  function render() {
    const order = ["claude-code", "codex"];
    const list = order.flatMap((e) => multi(e)
      ? accountsOf(e).filter(signedIn).map((a) => (state.limitsByAccount ?? []).find((l) => l.engine === e && l.account_id === a.id) ?? { engine: e, account_id: a.id, state: "loading", windows: [] })
      : [limits.find((l) => l.engine === e) ?? { engine: e, state: "loading", windows: [] }]);
    const kids = list.map(card);
    put(grid, ...kids);
    tick();
  }

  function card(l) {
    const session = l.windows.find((w) => w.kind === "session");
    const left = session ? 100 - session.used_percent : l.windows[0] ? 100 - l.windows[0].used_percent : null;
    const sea = pixelSea(l.engine);
    const clocks = new Map();
    const acct = l.account_id ? accountsOf(l.engine).find((a) => a.id === l.account_id) : null;
    const status = l.state === "loading" ? "Checking…" : l.state === "missing" ? "Not installed" : l.state === "unavailable" ? "No plan limits" : l.state === "error" && !l.windows.length ? "Couldn't check" : null;
    const head = h("div", { class: "us-card-head" },
      h("span", { class: "us-mark" }, engineMark(l.engine, "icon em")),
      h("div", { class: "grow" }, h("div", { class: "us-name" }, NAME[l.engine], l.plan ? h("span", { class: "us-plan" }, PLAN(l.plan)) : null, multi(l.engine) && acct ? h("span", { class: "us-acct", title: "The account these numbers belong to" }, accountTitle(acct)) : null), h("div", { class: "us-sub" }, status ?? (l.checked_at ? `Checked ${ago(l.checked_at)}` : ""))),
      left !== null ? h("div", { class: "us-big", style: `--c:${rgb(levelColor(l.engine, left))}` }, h("span", { class: "us-big-n" }, `${Math.round(left)}%`), h("span", { class: "us-big-l" }, "left this session")) : null);
    const seaWrap = h("div", { class: "us-sea" }, sea.el);
    const rows = l.windows.map((w) => {
      const wl = 100 - w.used_percent;
      const clock = pixelClock();
      clocks.set(w.id, clock);
      const p = pace(w);
      const elapsed = h("div", { class: "us-elapsed", title: "How much of this window has passed" }, h("span", { style: `width:${p ? Math.round(p.gone * 100) : 0}%` }));
      return h("div", { class: "us-win", dataset: { window: w.id } },
        h("div", { class: "us-win-top" }, h("span", { class: "us-win-label" }, w.label), h("span", { class: "us-win-left", style: `--c:${rgb(levelColor(l.engine, wl))}` }, `${Math.round(wl)}% left`), h("span", { class: "us-win-used" }, `${Math.round(w.used_percent)}% used`)),
        meter(l.engine, wl),
        w.resets_at ? h("div", { class: "us-win-reset" },
          h("div", { class: "us-reset-text" }, h("span", { class: "us-muted" }, w.kind === "session" ? "Next session in" : w.kind === "weekly" ? "Week refills in" : "Refills in"), clock.el),
          h("div", { class: "us-reset-when" }, `Refills ${when(w.resets_at)}`)) : h("div", { class: "us-win-reset us-muted" }, w.kind === "monthly" ? "Resets with your billing month." : "No reset time reported yet."),
        w.resets_at && w.window_mins ? elapsed : null,
        p ? h("p", { class: `us-pace ${p.tone}` }, p.text) : null);
    });
    const notes = [];
    if (l.reached) notes.push(h("p", { class: "us-note bad" }, `Limit reached (${l.reached.replace(/_/g, " ")}). Work waits until it refills.`));
    // Free resets the account holds: how many, when each expires, and a note that new ones show up here when granted.
    const credits = l.reset_credit_list ?? [];
    const creditClocks = [];
    if (l.reset_credits || credits.length) {
      const items = credits.map((c) => {
        const left = h("span", { class: "us-credit-left" });
        if (c.expires_at) creditClocks.push({ el: left, at: Date.parse(c.expires_at) });
        return h("li", { class: "us-credit" }, icon("star"), h("div", { class: "grow" }, h("div", { class: "us-credit-title" }, c.title), h("div", { class: "us-credit-sub" }, c.expires_at ? `Use it by ${when(c.expires_at)}` : "No expiry reported", c.granted_at ? ` · granted ${new Date(c.granted_at).toLocaleDateString([], { month: "short", day: "numeric" })}` : "")), left);
      });
      notes.push(h("div", { class: "us-credits", dataset: { credits: String(l.reset_credits ?? credits.length) } },
        h("div", { class: "us-credits-head" }, h("span", {}, "Free resets"), h("span", { class: "us-credits-n" }, String(l.reset_credits ?? credits.length))),
        items.length ? h("ul", {}, ...items) : null,
        h("p", { class: "us-credits-note" }, "A reset refills the 5-hour session and the week to 100% at once. Opscode only shows them; use one from the ", NAME[l.engine], " app. When a new one is granted it appears here, and an unused one disappears when it expires.")));
    } else if (l.engine === "claude-code" && l.state === "ok") {
      notes.push(h("p", { class: "us-note" }, icon("star"), "Claude Code doesn't report a free reset for this account. If your Claude plan gives you one, it shows here as soon as Claude Code reports it."));
    }
    if (l.message && l.state !== "ok") notes.push(h("p", { class: "us-note" }, l.message));
    const el = h("section", { class: `us-card${l.state === "loading" ? " loading" : ""}`, dataset: { engine: l.engine } }, seaWrap, head, ...rows, ...notes);
    if (!rows.length && l.state === "loading") el.append(h("div", { class: "us-skel" }, h("i"), h("i"), h("i")));
    cards.set(l.account_id ? `${l.engine}:${l.account_id}` : l.engine, { sea, clocks, el, l, creditClocks });
    requestAnimationFrame(() => sea.set(left ?? 0, left === null ? [120, 120, 120] : levelColor(l.engine, left)));
    return el;
  }

  function tick() {
    const now = Date.now();
    let refill = false;
    for (const { clocks, l } of cards.values()) {
      for (const w of l.windows) {
        const c = clocks.get(w.id);
        if (!c || !w.resets_at) continue;
        const ms = Date.parse(w.resets_at) - now;
        if (ms <= 0) { refill = true; c.set("00:00:00", "Refilled"); continue; }
        c.set(clockText(ms), `${w.label} refills in ${spoken(ms)}`);
      }
    }
    for (const { creditClocks } of cards.values()) {
      for (const c of creditClocks) {
        const ms = c.at - now;
        c.el.textContent = ms <= 0 ? "Expired" : `${spoken(ms)} left`;
        c.el.classList.toggle("soon", ms > 0 && ms < 3 * 86400_000);
      }
    }
    for (const [engine, { el, l }] of cards) {
      const sub = el.querySelector(".us-sub");
      if (sub && l.checked_at && l.state === "ok") sub.textContent = `Checked ${ago(l.checked_at)}`;
      void engine;
    }
    const newest = limits.map((l) => l.checked_at).filter(Boolean).sort().at(-1);
    checked.textContent = newest ? `Checked ${ago(newest)}` : "";
    // A window just refilled: read the new numbers (at most once a minute).
    if (refill && !busy && (!newest || now - Date.parse(newest) > 60_000)) void load(true);
  }

  return {
    el: root,
    tokens,
    show() {
      clearInterval(timer);
      clearInterval(poll);
      timer = setInterval(() => { if (root.offsetParent === null) return; tick(); }, 1000);
      poll = setInterval(() => { if (root.offsetParent !== null && !document.hidden) void load(true); }, 5 * 60_000);
      if (!limits.length) render();
      if (tab === "tokens") tokens.show();
      void load(false);
      for (const c of cards.values()) c.sea.wake();
    },
    /** limits.changed from the runtime (a check, or an engine reporting during a chat). */
    changed(next) { if (root.offsetParent !== null) update(next); else { limits = next; state.limits = next; } },
  };
}

/** Lowest "% left" across engines' session windows, for the sidebar badge. */
export function lowestLeft(limits) {
  const lefts = (limits ?? []).flatMap((l) => l.windows.filter((w) => w.kind !== "monthly").map((w) => 100 - w.used_percent));
  return lefts.length ? Math.min(...lefts) : null;
}
