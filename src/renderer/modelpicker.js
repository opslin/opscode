// The model picker: search, a rail of engines (Home = starred, Claude Code,
// Codex, API keys, + to connect), model rows (mark, name, Default, check,
// smarter bars and price at the chosen effort), a "More models" fold, a hover
// card that plots smarter against pricier, and an effort slider at the bottom.

import { h, append, svg } from "./dom.js";
import { icon } from "./icons.js";
import { state, nav, readPref, writePref } from "./store.js";
import { runOf, barsFor, priceFor, money, PLOT, px, py, FACTS_SOURCE } from "./modelfacts.js";
import { pixelBurst } from "./pixelfx.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const EFFORT = { none: "None", minimal: "Minimal", low: "Low", medium: "Medium", high: "High", xhigh: "Extra high", max: "Max" };
const ENGINE_NAME = { "claude-code": "Claude Agent", codex: "Codex", antigravity: "Antigravity", qoder: "Qoder", api: "API keys" };
const STARS = "model-stars";
const ALIAS_NAME = { opus: "Opus (latest)", sonnet: "Sonnet (latest)", haiku: "Haiku (latest)" };

/** The mark for an engine (Claude, Codex, a key for API). */
export function engineMark(engine, cls = "icon em") {
  const el = icon(engine === "claude-code" ? "engine-claude" : engine === "codex" ? "engine-codex" : engine === "antigravity" ? "engine-antigravity" : engine === "qoder" ? "engine-qoder" : "key", cls);
  el.dataset.engine = engine;
  return el;
}

/** Every model the person can pick: [{ engine, id, label, efforts, more, description }]. */
export function catalog() {
  const out = [];
  for (const e of state.engines ?? []) {
    if (!e.found) continue;
    for (const m of e.models) out.push({ engine: e.id, ...m });
    if (!e.models.length) out.push({ engine: e.id, id: "", label: `${e.label} default` });
  }
  for (const p of (state.providers ?? []).filter((x) => x.configured)) out.push({ engine: "api", id: p.id, label: `${p.label} · ${p.model}`, provider: p.id, active: p.active });
  return out;
}

/** Display name for a value, e.g. "Claude Haiku 5.5", "GPT-6.1-Sol", "claude-…". */
export function modelName(v) {
  const eng = v.engine ?? "api";
  if (eng === "api") {
    const p = (state.providers ?? []).find((x) => x.active);
    return p ? p.model : "No model";
  }
  const m = catalog().find((x) => x.engine === eng && x.id === (v.model ?? ""));
  if (eng === "claude-code") return m ? `Claude ${m.label}` : v.model ? `Claude ${ALIAS_NAME[v.model] ?? v.model}` : "Claude Code";
  return m ? m.label : v.model || "Codex";
}
export const effortName = (e) => EFFORT[e] ?? "Medium";
export const effortLevel = (e) => Math.max(0, ["low", "medium", "high", "xhigh", "max"].indexOf(e ?? "medium"));

let current = null;
export function closeModelPicker() {
  if (!current) return;
  const { el, card, down, resize } = current;
  current = null;
  document.removeEventListener("mousedown", down, true);
  window.removeEventListener("resize", resize);
  card.remove();
  el.classList.add("mp-leave");
  el.addEventListener("animationend", () => el.remove(), { once: true });
  setTimeout(() => el.remove(), 200);
}

/** A row's bars and price at this effort (nothing when it was never measured). */
function meter(m, effort) {
  const run = m.engine === "api" ? null : runOf(m.id, effort);
  const bars = h("span", { class: "mp-bars", title: run ? `Intelligence ${run[0]}` : "Not measured yet" }, ...[1, 2, 3, 4, 5].map((n) => h("i", { class: run && n <= barsFor(run[0]) ? "on" : "" })));
  const price = h("span", { class: "mp-price", title: run ? `About ${money(run[1])} a task` : "" }, run ? "$".repeat(priceFor(run[1])) : "");
  return [run ? bars : h("span", { class: "mp-bars mp-bars-none" }), price];
}

/**
 * opts: { value: { engine, model, effort }, onChange(next), defaults?: { engine, model }, onMakeDefault?(v), engines?: ["claude-code","codex","api"] }
 */
export function openModelPicker(anchor, opts) {
  if (current?.anchor === anchor) return closeModelPicker();
  if (current) { current.el.remove(); current.card.remove(); document.removeEventListener("mousedown", current.down, true); window.removeEventListener("resize", current.resize); current = null; }
  let value = { ...opts.value };
  const allowed = opts.engines ?? ["claude-code", "codex", "antigravity", "qoder", "api"];
  const all = () => catalog().filter((m) => allowed.includes(m.engine));
  const stars = () => { try { return JSON.parse(readPref(STARS) ?? "[]"); } catch { return []; } };
  const key = (m) => `${m.engine}:${m.id}`;
  const rails = () => [{ id: "home", label: "Home" }, ...allowed.filter((e) => all().some((m) => m.engine === e)).map((e) => ({ id: e, label: ENGINE_NAME[e] }))];
  let tab = all().some((m) => m.engine === value.engine) ? value.engine : rails()[1]?.id ?? "home";
  let query = "";
  let moreOpen = all().some((m) => m.more && isCurrent(m));
  let active = 0;
  let rows = [];
  let hoverKey = null;

  const search = h("input", { class: "mp-search", placeholder: "Search models", "aria-label": "Search models", autocomplete: "off", spellcheck: false });
  const rail = h("div", { class: "mp-rail", role: "group", "aria-label": "Harnesses" });
  const list = h("div", { class: "mp-list", role: "listbox", "aria-label": "Models" });
  const foot = h("div", { class: "mp-foot" });
  const el = h("div", { class: "mp", role: "dialog", "aria-label": "Choose a model" }, h("div", { class: "mp-head" }, search), h("div", { class: "mp-main" }, rail, list), foot);
  const card = h("div", { class: "mp-card", "aria-hidden": "true" });

  function isCurrent(m) { return m.engine === (value.engine ?? "api") && (m.engine === "api" ? !!m.active : m.id === (value.model ?? "")); }
  const isDefault = (m) => !!opts.defaults && opts.defaults.engine === m.engine && (opts.defaults.model ?? "") === m.id;
  const pick = (m) => {
    value = { engine: m.engine, model: m.engine === "api" ? undefined : m.id || undefined, effort: m.efforts?.includes(value.effort) ? value.effort : m.efforts?.includes("medium") ? "medium" : undefined, provider: m.provider };
    opts.onChange(value);
    render();
  };
  const toggleStar = (m) => {
    const s = stars();
    const k = key(m);
    writePref(STARS, JSON.stringify(s.includes(k) ? s.filter((x) => x !== k) : [...s, k].slice(-20)));
    render();
  };

  function row(m) {
    const starred = stars().includes(key(m));
    const r = h("div", { class: "mp-row", role: "option", "aria-selected": String(isCurrent(m)), dataset: { model: key(m) }, title: m.description ?? "", onclick: () => pick(m) },
      engineMark(m.engine, "icon em mp-mark"),
      h("span", { class: "mp-name" }, m.label),
      isDefault(m) ? h("span", { class: "mp-default", title: "New chats start on this model" }, "Default") : null,
      isCurrent(m) ? icon("check", "icon mp-check") : null,
      h("span", { class: "grow" }),
      opts.onMakeDefault && !isDefault(m) ? h("button", { class: "mp-mkdef", type: "button", title: "New chats start on this model", onclick: (e) => { e.stopPropagation(); opts.onMakeDefault({ engine: m.engine, model: m.id }); opts.defaults = { engine: m.engine, model: m.id }; render(); } }, "Make default") : null,
      ...(m.engine === "api" ? [] : meter(m, value.effort)),
      h("button", { class: `mp-star${starred ? " on" : ""}`, type: "button", title: starred ? "Remove from Home" : "Keep it on Home", "aria-label": starred ? `Unstar ${m.label}` : `Star ${m.label}`, onclick: (e) => { e.stopPropagation(); toggleStar(m); } }, icon("star")));
    r.addEventListener("pointerenter", () => { const i = rows.findIndex((x) => x.el === r); if (i >= 0 && i !== active) { active = i; paintActive(false); } showCard(m, r); });
    rows.push({ el: r, m });
    return r;
  }

  function render() {
    rows = [];
    put(rail, ...rails().map((r) => h("button", { class: "mp-rail-btn", type: "button", "aria-pressed": String(tab === r.id), title: r.label, "aria-label": r.label, onclick: () => { tab = r.id; moreOpen = false; hideCard(); render(); list.scrollTop = 0; } }, r.id === "home" ? icon("home") : engineMark(r.id, "icon em"))),
      h("span", { class: "grow" }),
      h("button", { class: "mp-rail-btn", type: "button", title: "Connect models", "aria-label": "Connect models", onclick: () => { closeModelPicker(); nav.openSettings("models"); } }, icon("plus")));
    const q = query.trim().toLowerCase();
    let shown;
    let title;
    if (q) { shown = all().filter((m) => `${m.label} ${m.id} ${ENGINE_NAME[m.engine]}`.toLowerCase().includes(q)); title = null; }
    else if (tab === "home") { const s = stars(); shown = all().filter((m) => s.includes(key(m)) || isDefault(m) || isCurrent(m)); title = null; }
    else { shown = all().filter((m) => m.engine === tab); title = ENGINE_NAME[tab]; }
    const main = q || tab === "home" ? shown : shown.filter((m) => !m.more);
    const more = q || tab === "home" ? [] : shown.filter((m) => m.more);
    const kids = [];
    if (title) kids.push(h("div", { class: "mp-group" }, title));
    if (!shown.length) kids.push(h("div", { class: "mp-empty" }, q ? `No model matches “${query.trim()}”.` : tab === "home" ? "Star a model to keep it here." : "This engine reports no models."));
    kids.push(...main.map(row));
    if (more.length) {
      const fold = h("div", { class: "mp-fold", dataset: moreOpen ? { open: "" } : {} }, h("div", {}, ...more.map(row)));
      if (!moreOpen) fold.inert = true;
      const btn = h("button", { class: "mp-more", type: "button", "aria-expanded": String(moreOpen), onclick: () => {
        moreOpen = !moreOpen;
        btn.setAttribute("aria-expanded", String(moreOpen));
        btn.querySelector(".mp-caret").classList.toggle("open", moreOpen);
        fold.toggleAttribute("data-open", moreOpen);
        fold.inert = !moreOpen;
        if (moreOpen) setTimeout(() => btn.scrollIntoView({ block: "start", behavior: "smooth" }), 30);
        setTimeout(syncFade, 240);
      } }, "More models", h("span", { class: "mp-count" }, String(more.length)), h("span", { class: "grow" }), icon("chevron-down", `icon mp-caret${moreOpen ? " open" : ""}`));
      kids.push(btn, fold);
    }
    const keepScroll = list.scrollTop;
    put(list, ...kids);
    list.scrollTop = keepScroll;
    active = Math.max(0, rows.findIndex((r) => isCurrent(r.m)));
    paintActive(false);
    renderFoot();
    requestAnimationFrame(syncFade);
    const hovered = rows.find((r) => key(r.m) === hoverKey);
    if (hovered) showCard(hovered.m, hovered.el, true);
  }

  function renderFoot() {
    const sel = all().find(isCurrent);
    const efforts = sel?.efforts ?? [];
    if (efforts.length <= 1) { foot.hidden = true; return; }
    let idx = Math.max(0, efforts.indexOf(value.effort ?? "medium"));
    const last = efforts.length - 1;
    const isMax = efforts[idx] === "max";
    const track = h("div", { class: `mp-effort${isMax ? " max" : ""}`, role: "slider", tabindex: 0, "aria-label": "Effort", "aria-valuemin": 0, "aria-valuemax": last, "aria-valuenow": idx, "aria-valuetext": effortName(efforts[idx]) });
    track.style.setProperty("--pos", String(idx / last));
    append(track, [h("span", { class: "mp-fill" }), ...efforts.map((e, i) => h("span", { class: `mp-tick${e === "max" ? " max" : ""}`, style: `--at:${i / last}` })), h("span", { class: "mp-knob" })]);
    const at = (clientX) => { const r = track.getBoundingClientRect(); return Math.round(((clientX - r.left - 12) / (r.width - 24)) * last); };
    track.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      try { track.setPointerCapture(e.pointerId); } catch { /* synthetic pointer */ }
      track.focus();
      setEffort(at(e.clientX));
      const move = (ev) => setEffort(at(ev.clientX));
      track.addEventListener("pointermove", move);
      track.addEventListener("pointerup", () => track.removeEventListener("pointermove", move), { once: true });
    });
    track.addEventListener("keydown", (e) => {
      if (e.key === "ArrowRight" || e.key === "ArrowUp") { e.preventDefault(); setEffort(idx + 1); }
      if (e.key === "ArrowLeft" || e.key === "ArrowDown") { e.preventDefault(); setEffort(idx - 1); }
    });
    put(foot, h("span", { class: "mp-foot-label" }, "Effort"), track, h("span", { class: `mp-effort-name${isMax ? " max" : ""}` }, effortName(efforts[idx])));
    foot.hidden = false;
    function setEffort(i) {
      const n = Math.max(0, Math.min(last, i));
      if (n === idx) return;
      const up = n > idx;
      idx = n;
      value = { ...value, effort: efforts[n] };
      opts.onChange(value);
      // Update in place so the knob slides (and the rows' bars and price follow).
      track.style.setProperty("--pos", String(n / last));
      track.classList.toggle("max", efforts[n] === "max");
      track.setAttribute("aria-valuenow", String(n));
      track.setAttribute("aria-valuetext", effortName(efforts[n]));
      const name = foot.querySelector(".mp-effort-name");
      name.textContent = effortName(efforts[n]);
      name.classList.toggle("max", efforts[n] === "max");
      for (const r of rows) {
        if (r.m.engine === "api") continue;
        const [b, p] = meter(r.m, value.effort);
        r.el.querySelector(".mp-bars").replaceWith(b);
        r.el.querySelector(".mp-price").replaceWith(p);
      }
      if (up) {
        const tr = track.getBoundingClientRect();
        pixelBurst(track, effortLevel(efforts[n]), { x: tr.left + 12 + (tr.width - 24) * (n / last), y: tr.top + tr.height / 2 });
      }
      const hovered = rows.find((r) => key(r.m) === hoverKey);
      if (hovered) showCard(hovered.m, hovered.el, true);
    }
  }

  // ---- hover card: where this model sits, smarter against pricier ----
  let cardTimer = 0;
  function showCard(m, rowEl, now = false) {
    clearTimeout(cardTimer);
    hoverKey = key(m);
    const draw = () => {
      if (current?.el !== el || !rowEl.isConnected) return;
      const run = m.engine === "api" ? null : runOf(m.id, value.effort);
      const cur = all().find(isCurrent);
      const curRun = cur && key(cur) !== key(m) && cur.engine !== "api" ? runOf(cur.id, value.effort) : null;
      const others = rows.filter((r) => key(r.m) !== key(m) && (!cur || key(r.m) !== key(cur)) && r.m.engine !== "api").map((r) => runOf(r.m.id, value.effort)).filter(Boolean);
      let body;
      if (run) {
        const g = svg([], "mp-plot");
        g.setAttribute("viewBox", `0 0 ${PLOT.w} ${PLOT.h}`);
        g.setAttribute("role", "img");
        g.setAttribute("aria-label", `${m.label}: intelligence ${run[0]}, ${money(run[1])} a task`);
        const NS = "http://www.w3.org/2000/svg";
        const add = (tag, attrs, text) => { const n = document.createElementNS(NS, tag); for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v); if (text) n.textContent = text; g.append(n); return n; };
        add("text", { x: 8, y: 16, class: "mp-plot-axis" }, "Smarter");
        add("text", { x: 208, y: 114, "text-anchor": "end", class: "mp-plot-axis" }, "Pricier");
        for (const o of others) add("circle", { r: 2.5, class: "mp-plot-other", style: `transform:translate(${px(o[1]).toFixed(1)}px,${py(o[0]).toFixed(1)}px)` });
        if (curRun) {
          const gg = document.createElementNS(NS, "g");
          gg.setAttribute("class", "mp-plot-move");
          gg.setAttribute("style", `transform:translate(${px(curRun[1]).toFixed(1)}px,${py(curRun[0]).toFixed(1)}px)`);
          const ring = document.createElementNS(NS, "circle");
          for (const [k, v] of Object.entries({ r: 6, fill: "none", "stroke-width": 1.5, class: "mp-plot-ring" })) ring.setAttribute(k, v);
          gg.append(ring);
          if (Math.hypot(px(run[1]) - px(curRun[1]), py(run[0]) - py(curRun[0])) > 18) {
            const t = document.createElementNS(NS, "text");
            for (const [k, v] of Object.entries({ y: 17, "text-anchor": "middle", class: "mp-plot-cur" })) t.setAttribute(k, v);
            t.textContent = "Current";
            gg.append(t);
          }
          g.append(gg);
        }
        add("circle", { r: 4.5, class: "mp-plot-me mp-plot-move", style: `transform:translate(${px(run[1]).toFixed(1)}px,${py(run[0]).toFixed(1)}px)` });
        body = [g, h("div", { class: "mp-card-facts" }, `Intelligence ${run[0]} · about ${money(run[1])} a task at ${effortName(value.effort).toLowerCase()} effort`), h("div", { class: "mp-card-src" }, FACTS_SOURCE)];
      } else body = [h("p", { class: "mp-card-none" }, m.engine === "api" ? "Runs on your API key." : "Not measured yet"), m.description ? h("p", { class: "mp-card-desc" }, m.description) : null];
      put(card, h("div", { class: "mp-card-title" }, m.label), ...body);
      // Beside the picker: left when there is room, else right; level with the row.
      const pr = el.getBoundingClientRect();
      const rr = rowEl.getBoundingClientRect();
      const w = 240;
      const left = pr.left - w - 8 >= 8 ? pr.left - w - 8 : Math.min(window.innerWidth - w - 8, pr.right + 8);
      card.style.left = `${left}px`;
      card.classList.add("show");
      const ch = card.offsetHeight;
      card.style.top = `${Math.max(8, Math.min(window.innerHeight - ch - 8, rr.top + rr.height / 2 - ch / 2))}px`;
    };
    if (now || card.classList.contains("show")) draw();
    else cardTimer = setTimeout(draw, 220);
  }
  function hideCard() { clearTimeout(cardTimer); hoverKey = null; card.classList.remove("show"); }
  list.addEventListener("pointerleave", hideCard);

  // ---- scroll: fade the edges that have more behind them ----
  function syncFade() {
    const top = list.scrollTop > 2;
    const bottom = list.scrollTop + list.clientHeight < list.scrollHeight - 2;
    list.classList.toggle("fade-top", top);
    list.classList.toggle("fade-bottom", bottom);
  }
  list.addEventListener("scroll", () => { syncFade(); if (card.classList.contains("show")) hideCard(); }, { passive: true });

  function paintActive(scroll = true) {
    rows.forEach((r, i) => r.el.classList.toggle("active", i === active));
    if (scroll) rows[active]?.el.scrollIntoView({ block: "nearest" });
  }

  search.addEventListener("input", () => { query = search.value; hideCard(); render(); });
  el.addEventListener("keydown", (e) => {
    if (e.key === "Escape") { e.preventDefault(); closeModelPicker(); anchor.focus(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); active = Math.min(rows.length - 1, active + 1); paintActive(); showCard(rows[active].m, rows[active].el); }
    else if (e.key === "ArrowUp") { e.preventDefault(); active = Math.max(0, active - 1); paintActive(); showCard(rows[active].m, rows[active].el); }
    else if (e.key === "Enter" && rows[active] && document.activeElement?.tagName !== "BUTTON") { e.preventDefault(); pick(rows[active].m); closeModelPicker(); }
    else if ((e.key === "ArrowLeft" || e.key === "ArrowRight") && document.activeElement === search && !search.value) {
      const t = foot.querySelector(".mp-effort");
      if (t) { e.preventDefault(); t.dispatchEvent(new KeyboardEvent("keydown", { key: e.key })); }
    }
  });

  render();
  document.body.append(el, card);
  const place = () => {
    // Above the anchor, right-aligned, inside the window; below it when there is no room above.
    const r = anchor.getBoundingClientRect();
    const w = el.offsetWidth;
    const hgt = el.offsetHeight;
    const left = Math.max(8, Math.min(window.innerWidth - w - 8, r.right - w));
    const above = r.top - hgt - 8 >= 8;
    const top = above ? r.top - hgt - 8 : Math.max(8, Math.min(window.innerHeight - hgt - 8, r.bottom + 8));
    el.style.left = `${left}px`;
    el.style.top = `${top}px`;
    el.style.transformOrigin = `${Math.min(w, Math.max(0, r.left + r.width / 2 - left))}px ${above ? "100%" : "0"}`;
  };
  place();
  el.classList.add("mp-enter");
  const down = (e) => { if (!el.contains(e.target) && !anchor.contains(e.target)) closeModelPicker(); };
  const resize = () => { place(); hideCard(); };
  document.addEventListener("mousedown", down, true);
  window.addEventListener("resize", resize);
  current = { el, card, anchor, down, resize };
  queueMicrotask(() => search.focus());
}
