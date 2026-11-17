// Side panel: a per-project column beside the chat with its own tabs. Each tab
// is a "surface" (Artifacts, Overview, Browser, Terminal, Actions, Files,
// Changes, Agents, Computer, or one file). The open tabs, the active tab and
// the width are remembered per project on this computer.

import { h, append } from "./dom.js";

/** replaceChildren that skips null/false (h() children rules). */
const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
import { icon } from "./icons.js";
import { state, toast, nav, readPref, writePref } from "./store.js";
import { openMenu } from "./popover.js";
import { createFiles, createFileView } from "./files.js";
import { createTerminalView } from "./terminal.js";
import { renderMarkdown } from "./markdown.js";
import { engineMark, modelName, effortName } from "./modelpicker.js";
import { contextOf } from "./modelfacts.js";

const isMac = /mac/i.test(navigator.platform);
const KEY = isMac ? { mod: "⌘", shift: "⇧", ctrl: "⌃" } : { mod: "Ctrl+", shift: "Shift+", ctrl: "Ctrl+" };

/** The tools, in the order the New tab shows them. identity: "one" = at most one tab of that kind. */
export const SURFACES = [
  { kind: "artifact", label: "Artifacts", description: "Files, pages, code, tables and links from this chat", icon: "layers", identity: "one" },
  { kind: "overview", label: "Overview", description: "Environment, changes and agents at work", icon: "grid", identity: "one" },
  { kind: "browser", label: "Browser", description: "Preview a page", icon: "browser", identity: "many", chord: `${KEY.shift}${KEY.mod}B` },
  { kind: "terminal", label: "Terminal", description: "Run a command in the project", icon: "terminal", identity: "many", chord: `${KEY.ctrl}\`` },
  { kind: "actions", label: "Actions", description: "The project's commands, one click away", icon: "play", identity: "one" },
  { kind: "files", label: "Files", description: "Browse the project", icon: "folder", identity: "one", chord: `${KEY.mod}P` },
  { kind: "diff", label: "Changes", description: "What changed in the working tree", icon: "diff", identity: "one", chord: `${KEY.ctrl}${KEY.shift}G` },
  { kind: "agents", label: "Agents", description: "The agent and its helpers at work", icon: "users", identity: "one" },
  { kind: "computer", label: "Computer", description: "Computer use on this Mac", icon: "laptop", identity: "one" },
  { kind: "simulator", label: "Simulator", description: "iOS Simulator the agent can use", icon: "phone", identity: "one" },
];
const EXTRA = {
  new: { kind: "new", label: "New tab", icon: "plus", identity: "many" },
  file: { kind: "file", label: "File", icon: "file", identity: "path" },
};
const spec = (kind) => SURFACES.find((s) => s.kind === kind) ?? EXTRA[kind];

// ---- persistence ------------------------------------------------------------------------------
const STORE = "panels.v1";
function loadAll() {
  try {
    const raw = JSON.parse(readPref(STORE) ?? "{}");
    return raw && typeof raw === "object" ? raw : {};
  } catch { return {}; }
}
let all = loadAll();
let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => writePref(STORE, JSON.stringify(Object.fromEntries(Object.entries(all).slice(-40)))), 200);
}

// ---- small shared pieces ----------------------------------------------------------------------
const empty = (title, body, ...actions) => h("div", { class: "sp-empty" }, h("strong", {}, title), body ? h("span", {}, body) : null, actions.length ? h("div", { class: "sp-empty-actions" }, ...actions) : null);
const card = (title, open, ...children) => {
  const d = h("details", { class: "sp-card", open }, h("summary", {}, icon("chevron-right", "icon sp-card-caret"), h("span", { class: "grow" }, title)), h("div", { class: "sp-card-body" }, ...children));
  return d;
};
const kv = (ic, label, meta, title) => h("div", { class: "sp-kv", title: title ?? label }, icon(ic), h("span", { class: "sp-kv-label" }, label), meta ? h("span", { class: "sp-kv-meta" }, meta) : null);
const ago = (ms) => { const s = Math.max(0, ms) / 1000; if (s < 10) return `${s.toFixed(1)}s`; if (s < 60) return `${Math.floor(s)}s`; const m = Math.floor(s / 60); return m < 60 ? `${m}m ${String(Math.floor(s % 60)).padStart(2, "0")}s` : `${Math.floor(m / 60)}h ${m % 60}m`; };

/** Address bar text -> an http(s) URL, or null. Bare hosts become https; localhost becomes http. */
export function toUrl(text) {
  const t = text.trim();
  if (!t) return null;
  let u = t;
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(u) && !/^(about|file|data|javascript|chrome|view-source):/i.test(u)) u = /^(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0)(:\d+)?(\/|$)/i.test(u) ? `http://${u}` : `https://${u}`;
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    if (!url.hostname.includes(".") && !/^(localhost|\[::1\])$/i.test(url.hostname) && !/^\d+\.\d+\.\d+\.\d+$/.test(url.hostname)) return null;
    return url.href;
  } catch { return null; }
}

// ---- data read from the chat beside the panel --------------------------------------------------
/** Artifacts: files the agent wrote, links, code blocks and tables, newest first. */
export function artifactsOf(snapshot) {
  const out = [];
  const seen = new Set();
  const add = (a) => { if (!seen.has(a.id)) { seen.add(a.id); out.push(a); } };
  for (const t of snapshot?.turns ?? []) {
    for (const p of t.parts) {
      if (p.kind === "tool" && ["write_file", "Write", "Edit", "MultiEdit"].includes(p.tool) && p.status === "done") {
        const paths = p.tool === "write_file" && /to (.+)$/.test(p.output ?? "") ? [/to (.+)$/.exec(p.output)[1]] : p.summary.replace(/^(Write|Edit) /, "").split(", ");
        for (const path of paths) if (path && !path.startsWith("/")) add({ id: `file:${path}`, kind: "file", title: path.split("/").pop(), meta: path, path });
      }
      if (p.kind !== "text") continue;
      for (const m of p.text.matchAll(/\bhttps?:\/\/[^\s<>()`"']+[^\s<>()`"'.,;:!?]/g)) add({ id: `link:${m[0]}`, kind: "link", title: m[0].replace(/^https?:\/\//, ""), meta: "Link", url: m[0] });
      for (const m of p.text.matchAll(/```([\w+-]*)\n([\s\S]*?)```/g)) {
        if (m[2].split("\n").length < 3) continue;
        add({ id: `code:${t.turnId}:${m.index}`, kind: "code", title: m[1] ? `Code · ${m[1]}` : "Code", meta: `${m[2].split("\n").length - 1} lines`, text: m[0] });
      }
      for (const m of p.text.matchAll(/(^|\n)(\|[^\n]+\|\n\|[\s:|-]+\|\n(?:\|[^\n]+\|(?:\n|$))+)/g)) add({ id: `table:${t.turnId}:${m.index}`, kind: "table", title: "Table", meta: `${m[2].trim().split("\n").length - 2} rows`, text: m[2] });
    }
  }
  return out.reverse();
}

/** Sub-agent runs in the chat: name, task, status, report, how many steps. */
export function agentRunsOf(snapshot) {
  const runs = [];
  for (const t of snapshot?.turns ?? []) {
    let n = 0;
    const byPrefix = new Map();
    for (const p of t.parts) {
      if (p.kind !== "tool") continue;
      if (p.tool === "run_agent") {
        n++;
        const r = { id: `${t.turnId}:${p.call_id}`, turnId: t.turnId, name: p.summary.replace(/^Sub-agent /, ""), task: p.detail ?? "", status: p.status, report: p.output ?? "", steps: 0 };
        runs.push(r);
        byPrefix.set(`sa${n}-`, r);
      } else {
        const m = /^(sa\d+-)/.exec(p.call_id);
        if (m && byPrefix.has(m[1])) byPrefix.get(m[1]).steps++;
      }
    }
  }
  return runs.reverse();
}

/** About how much of a 200k-token window the chat uses (characters / 4). An estimate, not a count. */
export function contextUse(snapshot) {
  let chars = 0;
  for (const u of snapshot?.users ?? []) chars += u.length;
  for (const t of snapshot?.turns ?? []) for (const p of t.parts) chars += p.kind === "text" ? p.text.length : (p.detail?.length ?? 0) + (p.output?.length ?? 0);
  const tokens = Math.round(chars / 4);
  return { tokens, percent: Math.min(100, Math.round((tokens / 200_000) * 100)) };
}

// =====================================================================================
// Surfaces. Each returns { el, show?(), refresh?(), dispose?(closing) }.
// ctx: { ws, tab, panel, chat(): snapshot provider }
// =====================================================================================

function newTabSurface(ctx) {
  const input = h("input", { class: "sp-launch-input", placeholder: "Search or enter a URL, file or tool", "aria-label": "Search or enter a URL, file or tool", autocomplete: "off", spellcheck: false });
  const results = h("div", { class: "sp-launch-results", role: "listbox", hidden: true });
  const servers = h("div");
  const tools = h("div", { class: "sp-tools" }, ...SURFACES.map((s) =>
    h("button", { class: "sp-tool", type: "button", dataset: { kind: s.kind }, title: s.description, onclick: () => ctx.panel.open(s.kind, {}, { replace: ctx.tab.id }) },
      icon(s.icon), h("span", { class: "grow" }, s.label), s.chord ? h("kbd", {}, s.chord) : null)));
  const idle = h("div", { class: "sp-launch-idle" }, h("h4", { class: "sp-h" }, "Tools"), tools, servers);
  const root = h("div", { class: "sp-scroll" }, h("div", { class: "sp-launch" }, h("label", { class: "sp-launch-field" }, icon("search"), input), results, idle));

  let items = [];
  let seq = 0;
  const go = (it) => it?.run();
  const paint = () => {
    results.hidden = items.length === 0;
    idle.hidden = input.value.trim() !== "";
    put(results, ...items.map((it, i) => h("button", { class: "sp-result", type: "button", role: "option", "aria-selected": String(i === 0), onclick: () => go(it) }, icon(it.icon), h("span", { class: "grow truncate" }, it.label), it.meta ? h("span", { class: "sp-result-meta" }, it.meta) : null)));
  };
  input.addEventListener("input", async () => {
    const q = input.value.trim();
    const my = ++seq;
    items = [];
    if (q) {
      const url = toUrl(q);
      if (url && /[.:/]/.test(q)) items.push({ icon: "browser", label: `Open ${url.replace(/^https?:\/\//, "").replace(/\/$/, "")}`, meta: "Browser", run: () => ctx.panel.open("browser", { url }, { replace: ctx.tab.id }) });
      for (const s of SURFACES) if (s.label.toLowerCase().includes(q.toLowerCase())) items.push({ icon: s.icon, label: s.label, meta: "Tool", run: () => ctx.panel.open(s.kind, {}, { replace: ctx.tab.id }) });
    }
    paint();
    if (!q) return;
    try {
      const { results: found } = await state.client.call("fs.search", { workspace_id: ctx.ws.id, query: q, limit: 8 });
      if (my !== seq) return;
      for (const f of found) items.push(f.kind === "dir"
        ? { icon: "folder", label: f.path, meta: "Folder", run: () => ctx.panel.open("files", { dir: f.path }, { replace: ctx.tab.id }) }
        : { icon: "file", label: f.path, meta: "File", run: () => ctx.panel.open("file", { path: f.path }, { replace: ctx.tab.id }) });
      paint();
    } catch { /* offline */ }
  });
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); go(items[0]); } });

  async function refresh() {
    try {
      const { servers: list } = await state.client.call("workspace.servers", { workspace_id: ctx.ws.id });
      put(servers, ...(list.length ? [h("h4", { class: "sp-h" }, "Local servers"), h("div", { class: "sp-list" }, ...list.map((s) =>
        h("button", { class: "sp-row", type: "button", onclick: () => ctx.panel.open("browser", { url: s.url }, { replace: ctx.tab.id }) }, icon("server"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, s.process_name), h("span", { class: "sp-row-sub mono" }, s.url.replace(/^https?:\/\//, ""))))))] : []));
    } catch { put(servers); }
  }
  void refresh();
  return { el: root, show: () => { input.focus(); void refresh(); }, refresh };
}

function artifactsSurface(ctx) {
  const list = h("div", { class: "sp-list" });
  const view = h("div", { class: "sp-artifact-view", hidden: true });
  const root = h("div", { class: "sp-scroll" }, h("div", { class: "sp-pad" }, list, view));
  let selected = null;
  function refresh() {
    const items = artifactsOf(ctx.chat());
    if (items.length === 0) {
      put(list, empty("No artifacts yet", "Files, pages, code, tables and links from this chat collect here."));
      view.hidden = true;
      return;
    }
    const ic = { file: "file", link: "link", code: "code", table: "table" };
    put(list, ...items.map((a) => h("button", { class: "sp-row", type: "button", "aria-current": String(selected === a.id), dataset: { artifact: a.kind }, onclick: () => openIt(a) },
      icon(ic[a.kind]), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, a.title), h("span", { class: "sp-row-sub" }, a.meta)))));
    const sel = items.find((a) => a.id === selected);
    view.hidden = !sel;
    if (sel) put(view, h("div", { class: "sp-view-head" }, h("strong", { class: "grow" }, sel.title), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: () => { selected = null; refresh(); } }, icon("x"))), renderMarkdown(sel.text, { root: ws.path }));
  }
  function openIt(a) {
    if (a.kind === "file") return ctx.panel.open("file", { path: a.path });
    if (a.kind === "link") return ctx.panel.open("browser", { url: a.url });
    selected = a.id;
    refresh();
  }
  refresh();
  return { el: root, show: refresh, refresh, onChat: refresh };
}

// ---- Overview: Environment, Context, Connectors, Changes, Servers, Agents -------------------
// Each section folds open and closed (grid-rows animation); a closed one shows its summary.

/** Cache expiry, estimated from when the engine last reported cached tokens. */
export function cacheExpiry(usage, now = Date.now()) {
  if (!usage?.reported_at || !(usage.cache_tokens > 0)) return { label: "No cache reported", detail: "An estimate appears after the engine reports cached tokens." };
  const at = Date.parse(usage.reported_at);
  const model = String(usage.model ?? "").toLowerCase().replace(/^(anthropic|openai)\//, "");
  const claude = model.startsWith("claude-") || /^(opus|sonnet|haiku)/.test(model);
  const openai = /^(gpt-|o[134](?:-|$)|codex)/.test(model);
  if ((!claude && !openai) || !Number.isFinite(at) || at > now) return { label: "Expiry unavailable", detail: "Cache retention or timing is not known for this report." };
  const MIN = 60_000;
  const age = now - at;
  const soonest = 5 * MIN - age;
  const latest = (claude ? 5 : 10) * MIN - age;
  const fmt = (ms) => { const t = Math.ceil(ms / 1000); const m = Math.floor(t / 60); return m === 0 ? `${t}s` : `${m}m${t % 60 ? ` ${t % 60}s` : ""}`; };
  return {
    label: latest <= 0 ? "Likely expired" : soonest <= 0 ? `May expire within ~${fmt(latest)}` : `~${fmt(soonest)}${openai ? `–${fmt(latest)}` : ""} remaining`,
    detail: claude
      ? "Estimated from the last cache report using Claude’s default 5-minute retention. Reports arrive at turn end; actual expiry may be earlier or retention longer."
      : "Estimated from the last cache report using OpenAI’s typical 5–10-minute idle retention. Reports arrive at turn end; actual expiry may be earlier or retention longer.",
  };
}
const shortNum = (n) => (n >= 1e6 ? `${Number((n / 1e6).toFixed(n % 1e6 ? 1 : 0))}M` : n >= 1000 ? `${Number((n / 1000).toFixed(1))}k` : String(n));
const homeShort = (p) => p.replace(/^\/Users\/[^/]+/, "~");
const parentOf = (p) => homeShort(p.replace(/\/[^/]+\/?$/, "") || "/");
const remoteCache = new Map(); // workspace id -> { at, result }

function section(title, { open = false, summary = null } = {}, ...children) {
  const fold = h("div", { class: "ov-fold" }, h("div", {}, ...children));
  const sum = h("span", { class: "ov-sum" });
  const btn = h("button", { class: "ov-head", type: "button", "aria-expanded": String(open) }, h("span", { class: "ov-title" }, title), icon("chevron-right", "icon ov-caret"), sum);
  const el = h("section", { class: "ov-sec", dataset: { section: title.toLowerCase() } }, btn, fold);
  const set = (o) => {
    open = o;
    btn.setAttribute("aria-expanded", String(o));
    fold.toggleAttribute("data-open", o);
    fold.inert = !o;
    sum.replaceChildren(...(!o && summary ? [summary] : []));
  };
  btn.addEventListener("click", () => set(!open));
  set(open);
  return { el, set, get open() { return open; } };
}
const row = (ic, label, meta, { title, mono, inline } = {}) => h("div", { class: `ov-row${inline ? " inline" : ""}`, title: title ?? label },
  typeof ic === "string" ? icon(ic) : ic, h("span", { class: `ov-label${mono ? " mono" : ""}` }, label), meta ? h("span", { class: "ov-meta" }, meta) : null);
const note = (text) => h("p", { class: "ov-note" }, text);

function overviewSurface(ctx) {
  const body = h("div", { class: "ov" });
  const root = h("div", { class: "sp-scroll" }, body);
  const open = { environment: true, context: ctx.tab.params?.focus === "context", connectors: false, changes: true, servers: false, agents: false };
  let secs = {};
  let busy = false;
  let tick = 0;

  async function checkRemote(force = false) {
    const c = remoteCache.get(ctx.ws.id);
    if (!force && c && (c.pending || Date.now() - c.at < 90_000)) return c.pending ?? c.result;
    const pending = state.client.call("workspace.remote_check", { workspace_id: ctx.ws.id }).catch((e) => ({ ok: false, remote: null, message: e.message }));
    remoteCache.set(ctx.ws.id, { at: Date.now(), pending, result: c?.result });
    const result = await pending;
    remoteCache.set(ctx.ws.id, { at: Date.now(), result });
    return result;
  }

  async function refresh() {
    if (busy) return;
    busy = true;
    const [env, ch, sv] = await Promise.all([
      state.client.call("workspace.env", { workspace_id: ctx.ws.id }).then((r) => r.env).catch(() => null),
      state.client.call("changes.diff", { workspace_id: ctx.ws.id }).catch(() => null),
      state.client.call("workspace.servers", { workspace_id: ctx.ws.id }).then((r) => r.servers).catch(() => []),
    ]);
    busy = false;
    // Read the folds now (not before the await), so a click made while loading sticks.
    for (const [k, sec] of Object.entries(secs)) open[k] = sec.open;
    const snap = ctx.chat();
    const runs = agentRunsOf(snap);
    const engine = snap?.engine ?? "api";

    // Environment
    const remoteMeta = h("span", { class: "ov-remote" }, env?.remote ? h("span", { class: "ov-dot wait" }) : null, env?.remote ? "Checking…" : env?.git ? "No remote" : "—");
    const recheck = h("button", { class: "ov-mini", type: "button", hidden: !env?.remote, title: "Check again", "aria-label": "Check the remote again", onclick: () => paintRemote(true) }, icon("reload"));
    async function paintRemote(force) {
      if (!env?.remote) return;
      remoteMeta.replaceChildren(h("span", { class: "ov-dot wait" }), "Checking…");
      const r = await checkRemote(force);
      remoteMeta.replaceChildren(h("span", { class: `ov-dot ${r.ok ? "ok" : "bad"}` }), r.ok ? r.message : "Unreachable");
      remoteMeta.title = r.ok ? `${r.remote} answered` : `${r.remote}: ${r.message}`;
    }
    const branchMeta = env?.worktree ? "Worktree" : env?.upstream ? [env.ahead ? `↑${env.ahead}` : "", env.behind ? `↓${env.behind}` : "", env.ahead || env.behind ? "" : "Up to date"].filter(Boolean).join(" ") : env?.git ? "No upstream" : null;
    const environment = section("Environment", { open: open.environment },
      row("code", env?.repo ?? ctx.ws.name, null),
      row("folder", ctx.ws.name, parentOf(ctx.ws.path), { title: ctx.ws.path }),
      env?.git ? row("branch", env.branch ?? "—", branchMeta, { mono: true, title: env.upstream ? `${env.branch} → ${env.upstream}` : env.branch }) : row("branch", "No git", "In the folder"),
      row("laptop", "This Mac", sv.length ? sv.map((s) => `:${s.port}`).join(" ") : null),
      h("div", { class: "ov-row", title: env?.remote ?? "This project has no git remote named origin." }, icon("cloud"), h("span", { class: "ov-label" }, "Remote"), h("span", { class: "ov-meta ov-remote-name mono" }, env?.remote ?? ""), remoteMeta, recheck));

    // Context
    const u = snap?.usage;
    const win = u?.context_window ?? contextOf(snap?.model) ?? (engine === "api" ? 200_000 : null);
    const used = u?.context_tokens ?? null;
    const est = contextUse(snap);
    const pct = used !== null && win ? Math.min(100, Math.round((used / win) * 100)) : engine === "api" && snap ? est.percent : null;
    const mini = pct === null ? h("span", { class: "ov-muted" }, "No reading yet") : h("span", { class: "ov-pct" }, `${pct}%`, h("span", { class: `ov-bar${pct >= 85 ? " warn" : ""}` }, h("span", { style: `width:${Math.max(pct, 4)}%` })));
    const expiry = h("div", { class: "ov-cache" });
    const paintExpiry = () => { const e = cacheExpiry(u); expiry.replaceChildren(h("div", { class: "ov-cache-head" }, h("span", { class: "ov-muted" }, "Cache expiry · estimated"), h("span", { class: "ov-cache-label" }, e.label)), h("p", { class: "ov-note" }, e.detail)); };
    paintExpiry();
    clearInterval(tick);
    if (u?.reported_at) tick = setInterval(() => { if (!root.isConnected) return clearInterval(tick); paintExpiry(); }, 1000);
    const using = snap ? h("div", { class: "ov-row" }, engineMark(engine, "icon em"), h("span", { class: "ov-label" }, modelName({ engine, model: snap.model ?? undefined })), engine === "api" ? null : h("span", { class: `ov-meta${snap.effort === "max" ? " max" : ""}` }, `${effortName(snap.effort ?? "medium")} effort`)) : null;
    const context = section("Context", { open: open.context, summary: mini },
      using,
      !snap ? note("No chat open.")
        : used !== null && win ? h("p", { class: "ov-text" }, h("span", { class: "ov-strong" }, shortNum(used)), " of ", shortNum(win), " tokens in the window.")
        : engine === "api" ? h("p", { class: "ov-text" }, `About ${shortNum(est.tokens)} of ${shortNum(200_000)} tokens (estimated from the text).`)
        : note("The engine has not reported its context use in this session."),
      u ? h("p", { class: "ov-note" }, `This chat so far: ${shortNum(u.input_tokens)} in · ${shortNum(u.output_tokens)} out · ${shortNum(u.cached_tokens)} from cache.`) : null,
      snap ? expiry : null);

    // Connectors: what the engine of this chat can actually call.
    let conRows = [];
    let conCount = null;
    let conNote = null;
    if (engine === "claude-code") {
      const list = snap?.connectors;
      if (list) { conRows = list.map((c) => row("plug", c.name, c.status === "connected" ? "MCP" : c.status, { mono: true })); conCount = list.length; }
      if (!list?.length) conNote = state.engineSettings?.claude_lean ? "Lean mode is on: Claude Code starts without your MCP servers, which saves tens of thousands of tokens a request. Turn it off in Models & keys." : list ? "Claude Code reported no MCP servers." : "Claude Code lists its MCP servers when the chat's first turn starts.";
    } else if (engine === "codex") {
      conNote = "Codex runs with the MCP servers in its own config (~/.codex/config.toml); it doesn't report them here.";
    } else {
      const mcp = (state.mcp ?? []).filter((m) => m.enabled);
      conRows = mcp.map((m) => row("plug", m.name, m.state === "connected" ? `${m.tools?.length ?? 0} tool${m.tools?.length === 1 ? "" : "s"}` : m.needs_key ? "needs a key" : m.state, { mono: true, title: m.error ?? m.name }));
      conCount = mcp.length;
      if (!mcp.length) conNote = "No MCP servers on this computer.";
    }
    const connectors = section("Connectors", { open: open.connectors, summary: h("span", { class: "ov-muted" }, conCount === null ? "…" : conCount === 0 ? "None" : `${conCount} MCP server${conCount === 1 ? "" : "s"}`) },
      ...conRows, conNote ? note(conNote) : null,
      h("button", { class: "ov-link", type: "button", onclick: () => nav.openSettings(engine === "api" ? "mcp" : "models") }, engine === "api" ? "Manage MCP servers" : "Models & keys"));

    const added = ch?.files.reduce((n, f) => n + f.added, 0) ?? 0;
    const removed = ch?.files.reduce((n, f) => n + f.removed, 0) ?? 0;
    const changes = section("Changes", { open: open.changes, summary: ch?.files.length ? h("span", { class: "ov-muted" }, `${ch.files.length} file${ch.files.length === 1 ? "" : "s"}`) : null },
      !ch ? note("Couldn't read the changes.") : !ch.git ? note("This folder isn't a git repository.") : ch.files.length === 0 ? note("No changes in the working tree.")
        : h("button", { class: "sp-row", type: "button", onclick: () => ctx.panel.open("diff") }, icon("diff"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, `${ch.files.length} file${ch.files.length === 1 ? "" : "s"} changed`), h("span", { class: "sp-row-sub" }, h("span", { class: "add" }, `+${added}`), " ", h("span", { class: "del" }, `−${removed}`)))));
    const servers = section("Servers", { open: open.servers || sv.length > 0, summary: h("span", { class: "ov-muted" }, sv.length ? String(sv.length) : "None") },
      sv.length === 0 ? note("No servers running from this project.")
        : h("div", { class: "sp-list" }, ...sv.map((s) => h("div", { class: "sp-row" }, icon("server"), h("button", { class: "grow sp-link", type: "button", title: `Open ${s.url} beside the chat`, onclick: () => ctx.panel.open("browser", { url: s.url }) }, h("span", { class: "sp-row-title" }, s.process_name), h("span", { class: "sp-row-sub mono" }, `localhost:${s.port}`)),
          h("button", { class: "icon-btn", type: "button", title: `Stop ${s.process_name}`, "aria-label": `Stop ${s.process_name}`, onclick: async () => { try { await state.client.call("workspace.servers.stop", { workspace_id: ctx.ws.id, pid: s.pid, port: s.port }); setTimeout(refresh, 600); } catch (e) { toast(e.message); } } }, icon("stop"))))));
    const agents = section("Agents", { open: open.agents || runs.length > 0, summary: runs.length ? h("span", { class: "ov-muted" }, String(runs.length)) : null },
      runs.length === 0 ? note("When the agent hands part of the work to a helper, it shows up here.")
        : h("button", { class: "sp-row", type: "button", onclick: () => ctx.panel.open("agents") }, icon("users"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, `${runs.length} helper run${runs.length === 1 ? "" : "s"}`), h("span", { class: "sp-row-sub" }, `${runs.filter((r) => r.status === "running" || r.status === "awaiting_approval").length} working`))));
    secs = { environment, context, connectors, changes, servers, agents };
    put(body, ...Object.values(secs).map((s) => s.el));
    void paintRemote(false);
  }
  void refresh();
  return {
    el: root,
    show: () => { if (ctx.tab.params?.focus === "context") { open.context = true; secs.context?.set(true); } void refresh(); },
    refresh,
    onChat: (ev) => { if (!ev || ev.type === "completed" || ev.type === "tool_end" || ev.type === "failed") void refresh(); },
    dispose: () => clearInterval(tick),
  };
}

function browserSurface(ctx) {
  const back = h("button", { class: "icon-btn", type: "button", "aria-label": "Back", disabled: true }, icon("arrow-left"));
  const fwd = h("button", { class: "icon-btn", type: "button", "aria-label": "Forward", disabled: true }, icon("arrow-right"));
  const reload = h("button", { class: "icon-btn", type: "button", "aria-label": "Reload" }, icon("reload"));
  const addr = h("input", { class: "sp-address", "aria-label": "Address", placeholder: "Enter an address", autocomplete: "off", spellcheck: false, value: ctx.tab.params.url ?? "" });
  const ext = h("button", { class: "icon-btn", type: "button", "aria-label": "Open in system browser", title: "Open in system browser" }, icon("external"));
  const stage = h("div", { class: "sp-browser-stage" });
  const overlay = h("div", { class: "sp-browser-overlay" });
  const pill = h("span", { class: "sp-agent", hidden: true, title: "Opscode's agent is using this tab" }, h("span", { class: "sp-agent-dot" }), h("span", { class: "sp-agent-label" }, "Opscode"));
  const root = h("div", { class: "sp-browser" }, h("div", { class: "sp-browser-bar" }, back, fwd, reload, addr, pill, ext), stage);
  let pillTimer = null;
  stage.append(overlay);
  let wv = null;

  const idle = async () => {
    overlay.hidden = false;
    put(overlay, empty("No page yet", "Enter an address above, or start a dev server. Servers running from this project show up here."));
    try {
      const { servers } = await state.client.call("workspace.servers", { workspace_id: ctx.ws.id });
      if (servers.length && !wv) overlay.append(h("div", { class: "sp-list sp-pad" }, ...servers.map((s) => h("button", { class: "sp-row", type: "button", onclick: () => navigate(s.url) }, icon("server"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, s.process_name), h("span", { class: "sp-row-sub mono" }, s.url))))));
    } catch { /* offline */ }
  };
  function navigate(text) {
    const url = toUrl(text);
    if (!url) { toast("Only http and https pages open in this browser."); return; }
    ctx.tab.params.url = url;
    ctx.panel.persist();
    addr.value = url;
    overlay.hidden = true;
    if (!wv) create(url);
    else wv.loadURL(url).catch(() => {});
  }
  function create(url) {
    wv = document.createElement("webview");
    wv.setAttribute("partition", "persist:opscode-guest");
    wv.className = "sp-webview";
    wv.addEventListener("did-navigate", (e) => sync(e.url));
    wv.addEventListener("did-navigate-in-page", (e) => { if (e.isMainFrame) sync(e.url); });
    wv.addEventListener("page-title-updated", (e) => ctx.panel.setTitle(ctx.tab.id, e.title || url));
    wv.addEventListener("did-fail-load", (e) => {
      if (!e.isMainFrame || e.errorCode === -3) return;
      overlay.hidden = false;
      put(overlay, empty("This site can't be reached", `${e.validatedURL || url} — ${e.errorDescription || "load failed"}`, h("button", { class: "btn btn-sm", type: "button", onclick: () => { overlay.hidden = true; wv.reload(); } }, "Try again")));
    });
    wv.addEventListener("did-start-loading", () => root.classList.add("loading"));
    wv.addEventListener("did-stop-loading", () => { root.classList.remove("loading"); syncNav(); });
    wv.setAttribute("src", url);
    stage.prepend(wv);
  }
  /** For the agent: the page's WebContents id (main drives it), making a blank page first if needed. */
  async function wcId() {
    if (!wv) { overlay.hidden = true; create("about:blank"); }
    for (const end = Date.now() + 6000; Date.now() < end; await new Promise((r) => setTimeout(r, 50))) {
      try { const id = wv.getWebContentsId(); if (id) return id; } catch { /* not attached yet */ }
    }
    throw new Error("the Browser tab did not start");
  }
  function activity(label) {
    pill.hidden = false;
    pill.querySelector(".sp-agent-label").textContent = `Opscode · ${label}`;
    root.classList.add("agent");
    clearTimeout(pillTimer);
    pillTimer = setTimeout(() => { pill.hidden = true; root.classList.remove("agent"); }, 4000);
  }
  function sync(url) {
    if (!/^https?:/i.test(url)) return;
    ctx.tab.params.url = url;
    ctx.panel.persist();
    if (document.activeElement !== addr) addr.value = url;
    syncNav();
  }
  function syncNav() {
    try { back.disabled = !wv?.canGoBack(); fwd.disabled = !wv?.canGoForward(); } catch { /* not attached yet */ }
  }
  addr.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); navigate(addr.value); } });
  back.addEventListener("click", () => wv?.goBack());
  fwd.addEventListener("click", () => wv?.goForward());
  reload.addEventListener("click", () => (wv ? wv.reload() : idle()));
  ext.addEventListener("click", () => { const u = toUrl(addr.value); if (u) window.open(u, "_blank"); });

  if (ctx.tab.params.url) navigate(ctx.tab.params.url);
  else void idle();
  return { el: root, show: () => { if (!wv && !ctx.tab.params.agent) addr.focus(); }, refresh: () => wv?.reload(), navigate, wcId, activity, info: () => ({ url: (() => { try { return wv?.getURL() ?? ""; } catch { return ctx.tab.params.url ?? ""; } })(), title: (() => { try { return wv?.getTitle() ?? ""; } catch { return ""; } })() }), dispose: () => clearTimeout(pillTimer) };
}

function terminalSurface(ctx) {
  const v = createTerminalView(ctx.ws, ctx.tab.params, {
    onStarted: (id) => { ctx.tab.params.terminalId = id; ctx.panel.persist(); },
    onTitle: (t) => ctx.panel.setTitle(ctx.tab.id, t),
  });
  ctx.panel.terminals.add(v);
  return { el: v.el, show: v.show, dispose: (closing) => { ctx.panel.terminals.delete(v); v.dispose(closing); } };
}

const ACTION_ICON = { play: "play", test: "check", lint: "eye", configure: "sliders", build: "zap", debug: "search", diff: "diff" };
function actionsSurface(ctx) {
  const body = h("div", { class: "sp-pad" });
  const root = h("div", { class: "sp-scroll" }, body);
  let data = null;
  let runs = new Map();
  let form = null; // null | { index?: number, name, command }
  let tick = null;

  async function load() {
    try {
      data = await state.client.call("actions.list", { workspace_id: ctx.ws.id });
      const { terminals } = await state.client.call("term.list", { workspace_id: ctx.ws.id });
      runs = new Map();
      for (const t of [...terminals].sort((a, b) => a.created_at.localeCompare(b.created_at))) if (t.command) runs.set(t.command, t);
    } catch (e) { data = { actions: [], suggestions: [], error: e.message }; }
    paint();
  }
  const personal = () => data.actions.filter((a) => a.source === "personal");
  async function savePersonal(list) {
    try { await state.client.call("actions.save", { workspace_id: ctx.ws.id, actions: list.map(({ id, name, command, icon: ic }) => ({ id, name, command, ...(ic ? { icon: ic } : {}) })) }); form = null; await load(); }
    catch (e) { toast(e.message); }
  }
  async function runIt(a) {
    try {
      const info = await state.client.call("term.open", { workspace_id: ctx.ws.id, command: a.command, cols: 100, rows: 30 });
      runs.set(a.command, info);
      paint();
    } catch (e) { toast(e.message); }
  }
  async function stopIt(t) {
    try { await state.client.call("term.write", { terminal_id: t.terminal_id, data: "\x03" }); } catch { /* exited */ }
    setTimeout(async () => {
      const { terminals } = await state.client.call("term.list", { workspace_id: ctx.ws.id }).catch(() => ({ terminals: [] }));
      if (terminals.some((x) => x.terminal_id === t.terminal_id && x.running)) await state.client.call("term.close", { terminal_id: t.terminal_id }).catch(() => {});
      void load();
    }, 1500);
  }
  function row(a, i) {
    const r = runs.get(a.command);
    const running = r?.running;
    const result = r && !running ? (r.exit_code === 0 ? h("span", { class: "pill pill-ok" }, "Passed") : h("span", { class: "pill pill-warn" }, r.exit_code === null ? "Stopped" : `Failed (${r.exit_code})`)) : null;
    return h("div", { class: "sp-action", dataset: { action: a.id, running: String(!!running) } },
      h("button", { class: "sp-action-run", type: "button", title: running ? `Stop ${a.name}` : `Run ${a.name}`, "aria-label": running ? `Stop ${a.name}` : `Run ${a.name}`, onclick: () => (running ? stopIt(r) : runIt(a)) }, running ? icon("stop") : icon(ACTION_ICON[a.icon] ?? "play")),
      h("div", { class: "grow sp-action-main" },
        h("div", { class: "sp-row-title" }, a.name),
        h("div", { class: "sp-row-sub mono", title: a.command }, a.command)),
      running ? h("span", { class: "sp-elapsed", dataset: { since: String(Date.parse(r.created_at)) } }, ago(Date.now() - Date.parse(r.created_at))) : result,
      r ? h("button", { class: "icon-btn", type: "button", title: "Show output", "aria-label": `Show ${a.name}'s output`, onclick: () => ctx.panel.open("terminal", { terminalId: r.terminal_id, command: a.command }) }, icon("terminal")) : null,
      a.source === "personal" ? h("button", { class: "icon-btn", type: "button", "aria-label": `More for ${a.name}`, onclick: (e) => openMenu(e.currentTarget, [
        { label: "Edit", icon: "compose", onSelect: () => { form = { index: i, name: a.name, command: a.command }; paint(); } },
        { label: "Delete", icon: "trash", danger: true, onSelect: () => void savePersonal(personal().filter((_, j) => j !== i)) }], { up: false, width: 180 }) }, icon("more")) : null);
  }
  function formEl() {
    const name = h("input", { class: "input", placeholder: "Deploy preview", "aria-label": "Name", value: form.name ?? "", maxLength: 60 });
    const cmd = h("input", { class: "input mono", placeholder: "./scripts/deploy.sh staging", "aria-label": "Command", value: form.command ?? "", maxLength: 2000, spellcheck: false });
    const commit = () => {
      const next = personal().map((x) => ({ ...x }));
      const item = { name: name.value.trim() || cmd.value.trim().split(" ")[0], command: cmd.value.trim() };
      if (!item.command) { toast("Enter a command."); return; }
      if (form.index !== undefined) next[form.index] = { ...next[form.index], ...item };
      else next.push(item);
      void savePersonal(next);
    };
    for (const el of [name, cmd]) el.addEventListener("keydown", (e) => { if (e.key === "Enter") commit(); if (e.key === "Escape") { form = null; paint(); } });
    queueMicrotask(() => name.focus());
    return h("div", { class: "sp-form" }, name, cmd, h("div", { class: "row-actions" }, h("span", { class: "grow" }),
      h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { form = null; paint(); } }, "Cancel"),
      h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: commit }, "Save")));
  }
  function paint() {
    if (!data) return;
    const proj = data.actions.filter((a) => a.source === "project");
    const mine = personal();
    put(body, 
      h("div", { class: "sp-toolbar" }, h("span", { class: "grow sp-note" }, "Commands you run often. Share them with the team in .opscode/actions.toml."), h("button", { class: "btn btn-sm", type: "button", onclick: () => { form = {}; paint(); } }, icon("plus"), "New action")),
      data.error ? h("p", { class: "sp-alert", role: "alert" }, data.error) : null,
      form ? formEl() : null,
      proj.length ? h("div", {}, h("h4", { class: "sp-h" }, "Project"), h("div", { class: "sp-list" }, ...proj.map((a) => row(a)))) : null,
      mine.length ? h("div", {}, h("h4", { class: "sp-h", title: "Kept on this computer" }, "Just me"), h("div", { class: "sp-list" }, ...mine.map((a, i) => row(a, i)))) : null,
      !proj.length && !mine.length && !form ? empty("No actions yet", "Save a command you run often, or add the scripts found in package.json.") : null,
      data.suggestions.length ? h("div", {}, h("h4", { class: "sp-h" }, "Found in package.json"), h("div", { class: "sp-chips" }, ...data.suggestions.map((s) =>
        h("button", { class: "chip", type: "button", title: `Add ${s.command}`, onclick: () => void savePersonal([...personal(), s]) }, icon("plus"), s.name)))) : null,
    );
    clearInterval(tick);
    if ([...runs.values()].some((r) => r.running)) tick = setInterval(() => { for (const el of body.querySelectorAll(".sp-elapsed")) el.textContent = ago(Date.now() - Number(el.dataset.since)); }, 1000);
  }
  void load();
  return { el: root, show: () => void load(), refresh: load, onTermExit: () => void load(), onActions: () => void load(), dispose: () => clearInterval(tick) };
}

function diffSurface(ctx) {
  const head = h("div", { class: "sp-toolbar sp-pad-x" });
  const body = h("div", { class: "sp-diff" });
  const root = h("div", { class: "sp-col" }, head, h("div", { class: "sp-scroll" }, body));
  const STATUS = { added: "A", modified: "M", deleted: "D", renamed: "R", untracked: "U" };
  async function refresh() {
    put(head, h("span", { class: "grow sp-note" }, "Loading…"));
    let ch;
    try { ch = await state.client.call("changes.diff", { workspace_id: ctx.ws.id }); }
    catch (e) { put(head); put(body, empty("Couldn't load the changes", e.message, h("button", { class: "btn btn-sm", type: "button", onclick: refresh }, "Retry"))); return; }
    const reload = h("button", { class: "icon-btn", type: "button", "aria-label": "Refresh", title: "Refresh", onclick: refresh }, icon("reload"));
    if (!ch.git) { put(head, h("span", { class: "grow" }), reload); put(body, empty("No git here", "This folder isn't a git repository, so there's nothing to compare against.")); return; }
    if (ch.files.length === 0) { put(head, h("span", { class: "grow sp-note" }, ch.branch ? `On ${ch.branch}` : ""), reload); put(body, empty("No changes yet", "Edits in the working tree show up here.")); return; }
    const add = ch.files.reduce((n, f) => n + f.added, 0);
    const del = ch.files.reduce((n, f) => n + f.removed, 0);
    put(head, h("span", { class: "grow" }, h("strong", {}, `${ch.files.length} file${ch.files.length === 1 ? "" : "s"}`), " ", h("span", { class: "add" }, `+${add}`), " ", h("span", { class: "del" }, `−${del}`), ch.branch ? h("span", { class: "sp-note" }, ` · ${ch.branch}`) : null), reload);
    // Split the unified diff per file.
    const sections = new Map();
    for (const chunk of ch.diff.split(/(?=^diff --git )/m)) {
      const m = /^diff --git a\/(.+?) b\/(.+)$/m.exec(chunk);
      if (m) sections.set(m[2], chunk);
    }
    const list = h("ul", { class: "sp-files", "aria-label": "Changed files" }, ...ch.files.map((f) => h("li", {},
      h("button", { class: "sp-file", type: "button", onclick: () => body.querySelector(`[data-file="${CSS.escape(f.path)}"]`)?.scrollIntoView({ block: "start" }) },
        h("span", { class: `sp-st sp-st-${f.status}`, title: f.status }, STATUS[f.status]),
        h("span", { class: "grow truncate mono" }, f.path),
        f.binary ? h("span", { class: "sp-note" }, "binary") : h("span", { class: "sp-counts" }, h("span", { class: "add" }, `+${f.added}`), " ", h("span", { class: "del" }, `−${f.removed}`))))));
    const blocks = ch.files.map((f) => {
      const text = sections.get(f.path) ?? "";
      const lines = text.split("\n").filter((l, i) => i > 0 && !/^(index |--- |\+\+\+ |new file|deleted file|similarity|rename (from|to)|old mode|new mode)/.test(l));
      return h("section", { class: "sp-diff-file", dataset: { file: f.path } },
        h("header", {}, h("span", { class: "grow mono truncate" }, f.old_path ? `${f.old_path} → ${f.path}` : f.path), h("button", { class: "icon-btn", type: "button", title: "Open file", "aria-label": `Open ${f.path}`, onclick: () => ctx.panel.open("file", { path: f.path }), disabled: f.status === "deleted" }, icon("file"))),
        h("pre", { class: "sp-diff-pre" }, ...lines.map((l) => h("div", { class: l.startsWith("@@") ? "hunk" : l.startsWith("+") ? "ins" : l.startsWith("-") ? "rem" : "ctx" }, l || " "))));
    });
    put(body, list, ...blocks, ch.truncated ? h("p", { class: "sp-note sp-pad" }, "The diff is long, so the rest was left out.") : null);
  }
  void refresh();
  return { el: root, show: () => void refresh(), refresh, onChat: (ev) => { if (ev?.type === "completed") void refresh(); } };
}

function agentsSurface(ctx) {
  const body = h("div", { class: "sp-pad" });
  const root = h("div", { class: "sp-scroll" }, body);
  const open = new Set();
  const STATUS = { running: "Working", awaiting_approval: "Needs approval", done: "Done", error: "Failed", denied: "Denied" };
  function refresh() {
    const snap = ctx.chat();
    const runs = agentRunsOf(snap);
    const lead = snap?.running;
    const stop = () => snap?.stop?.();
    put(body, 
      h("h4", { class: "sp-h" }, "Lead"),
      h("div", { class: "sp-list" }, h("div", { class: "sp-row" }, icon("mark"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, "Opscode"), h("span", { class: "sp-row-sub" }, snap ? (lead ? "Working on this chat" : "Idle") : "No chat open")),
        lead ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: stop }, "Stop") : null)),
      h("h4", { class: "sp-h" }, "Helpers"),
      runs.length === 0 ? empty("No helpers yet", "When the agent hands part of the work to a sub-agent, it shows up here.")
        : h("div", { class: "sp-list" }, ...runs.map((r) => h("div", { class: "sp-agent", dataset: { status: r.status } },
          h("button", { class: "sp-row", type: "button", "aria-expanded": String(open.has(r.id)), onclick: () => { if (open.has(r.id)) open.delete(r.id); else open.add(r.id); refresh(); } },
            icon("users"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, r.name), h("span", { class: "sp-row-sub truncate" }, r.task.split("\n")[0])),
            h("span", { class: `pill ${r.status === "done" ? "pill-ok" : r.status === "error" || r.status === "denied" ? "pill-warn" : ""}` }, STATUS[r.status] ?? r.status),
            h("span", { class: "sp-note" }, `${r.steps} step${r.steps === 1 ? "" : "s"}`)),
          open.has(r.id) ? h("div", { class: "sp-agent-body" }, h("div", { class: "sp-note" }, "Task"), h("pre", { class: "tool-pre" }, r.task), r.report ? h("div", { class: "sp-note" }, "Report") : null, r.report ? renderMarkdown(r.report, { root: ws.path }) : null) : null))),
    );
  }
  refresh();
  return { el: root, show: refresh, refresh, onChat: refresh };
}

// iOS Simulator: pick a device, boot it, watch it (a fresh picture about every second while this tab is
// on screen), and tap it yourself by clicking. The agent drives the same device with the ios_simulator tool.
function simulatorSurface(ctx) {
  const pick = h("select", { class: "sp-sim-pick", "aria-label": "Simulator" });
  const boot = h("button", { class: "btn btn-sm", type: "button", hidden: true }, "Boot");
  const home = h("button", { class: "icon-btn", type: "button", title: "Home", "aria-label": "Home button" }, icon("home"));
  const pill = h("span", { class: "sp-agent", hidden: true }, h("span", { class: "sp-agent-dot" }), h("span", { class: "sp-agent-label" }, "Opscode"));
  const img = h("img", { class: "sp-sim-screen", alt: "iOS Simulator screen", draggable: false });
  const msg = h("div", { class: "sp-pad" });
  const stage = h("div", { class: "sp-sim-stage" }, img);
  const root = h("div", { class: "sp-sim" }, h("div", { class: "sp-browser-bar" }, icon("phone"), pick, boot, pill, home), msg, stage);
  let devices = [];
  let size = null;
  let timer = null;
  let busy = false;
  let alive = true;
  let pillTimer = null;
  const current = () => devices.find((d) => d.udid === pick.value);

  async function load() {
    let r;
    try { r = await state.client.call("ios.list"); } catch (e) { r = { available: false, devices: [], help: e.message }; }
    devices = r.devices ?? [];
    const keep = ctx.tab.params.udid && devices.some((d) => d.udid === ctx.tab.params.udid) ? ctx.tab.params.udid : (devices.find((d) => d.state === "Booted") ?? devices.find((d) => /iPhone/.test(d.name)) ?? devices[0])?.udid;
    put(pick, ...devices.map((d) => h("option", { value: d.udid }, `${d.name} · ${d.runtime}${d.state === "Booted" ? "" : " (off)"}`)));
    pick.hidden = !devices.length;
    if (keep) pick.value = keep;
    if (!devices.length) { stage.hidden = true; put(msg, empty(r.available === false ? "Not available here" : "No simulators yet", r.help ?? "")); return; }
    sync();
  }
  function sync() {
    const d = current();
    ctx.tab.params.udid = d?.udid;
    ctx.panel.persist();
    const on = d?.state === "Booted";
    boot.hidden = on;
    home.disabled = !on;
    stage.hidden = !on;
    if (!on) put(msg, empty(`${d?.name ?? "The simulator"} is off`, "Boot it to watch it here. The agent can boot it too.")); else put(msg);
    if (on) void frame();
  }
  async function frame() {
    const d = current();
    if (!alive || busy || !d || d.state !== "Booted" || !root.isConnected || root.offsetParent === null) return;
    busy = true;
    try {
      const s = await state.client.call("ios.screen", { udid: d.udid });
      img.src = s.data_url;
      size = { w: s.width, h: s.height };
    } catch (e) { put(msg, empty("Can't show the screen", e.message)); }
    finally { busy = false; }
  }
  pick.addEventListener("change", sync);
  boot.addEventListener("click", async () => {
    const d = current();
    if (!d) return;
    boot.disabled = true;
    boot.textContent = "Booting…";
    try { await state.client.call("ios.boot", { udid: d.udid }); } catch (e) { toast(e.message); }
    boot.disabled = false;
    boot.textContent = "Boot";
    await load();
  });
  home.addEventListener("click", () => { const d = current(); if (d) state.client.call("ios.button", { udid: d.udid, name: "home" }).then(frame, (e) => toast(e.message)); });
  img.addEventListener("click", (e) => {
    const d = current();
    if (!d || !size) return;
    const r = img.getBoundingClientRect();
    const x = Math.round(((e.clientX - r.left) / r.width) * size.w);
    const y = Math.round(((e.clientY - r.top) / r.height) * size.h);
    state.client.call("ios.tap", { udid: d.udid, x, y }).then(() => setTimeout(frame, 300), (err) => toast(err.message));
  });
  timer = setInterval(frame, 1000);
  void load();
  return {
    el: root,
    show: () => void load(),
    refresh: () => void load(),
    onIos: (p) => {
      if (p.udid !== current()?.udid) { void load(); return; }
      pill.hidden = false;
      pill.querySelector(".sp-agent-label").textContent = `Opscode · ${p.label}`;
      clearTimeout(pillTimer);
      pillTimer = setTimeout(() => { pill.hidden = true; }, 4000);
      setTimeout(frame, 350);
    },
    dispose: () => { alive = false; clearInterval(timer); clearTimeout(pillTimer); },
  };
}

function computerSurface(ctx) {
  const body = h("div", { class: "sp-pad" });
  const root = h("div", { class: "sp-scroll" }, body);
  let shot = null;
  async function look() {
    try { shot = await state.client.call("computer.preview"); } catch (e) { toast(e.message); }
    refresh();
  }
  function refresh() {
    const c = state.computer;
    const settings = h("button", { class: "btn btn-sm", type: "button", onclick: () => nav.openSettings("computer") }, "Open Settings");
    if (!c) return put(body, empty("Checking computer use…", null));
    if (!c.supported) return put(body, empty("Not available here", "Computer use works on macOS only."));
    if (!c.enabled) return put(body, empty("Computer use is off", "Agents can't use apps on this Mac until you turn it on. Each action asks you first.", settings));
    const pill = (v, yes, no) => h("span", { class: `pill ${v === true ? "pill-ok" : v === false ? "pill-warn" : ""}` }, v === true ? yes : v === false ? no : "Unknown");
    put(body, 
      h("div", { class: "sp-list" },
        h("div", { class: "sp-row" }, icon("shield"), h("span", { class: "grow sp-row-title" }, "Accessibility"), pill(c.permissions.accessibility, "Granted", "Not granted")),
        h("div", { class: "sp-row" }, icon("monitor"), h("span", { class: "grow sp-row-title" }, "Screen Recording"), pill(c.permissions.screen_recording, "Granted", "Off")),
        h("div", { class: "sp-row" }, icon("check"), h("span", { class: "grow sp-row-title" }, "App rules"), h("span", { class: "sp-note" }, `${c.rules.length}`))),
      h("div", { class: "sp-toolbar" }, h("span", { class: "grow sp-note" }, shot?.front ? `In front: ${shot.front}` : "See what the agent would see."), h("button", { class: "btn btn-sm", type: "button", onclick: look }, icon("eye"), shot ? "Look again" : "Take a look"), settings),
      shot ? h("img", { class: "sp-shot", src: shot.image, alt: "Screenshot of this Mac" }) : empty("No screenshot yet", "Take a look to see the screen as the agent sees it. A blank image means Screen Recording is off."),
    );
  }
  refresh();
  return { el: root, show: refresh, refresh, onComputer: refresh };
}

function filesSurface(ctx) {
  const v = createFiles(ctx.ws);
  if (ctx.tab.params.dir) void v.open?.(ctx.tab.params.dir);
  void v.refresh();
  return { el: v.el, show: () => void v.refresh() };
}
function fileSurface(ctx) {
  const v = createFileView(ctx.ws, ctx.tab.params.path);
  return { el: v.el, show: () => void v.refresh() };
}

const BUILD = { new: newTabSurface, artifact: artifactsSurface, overview: overviewSurface, browser: browserSurface, terminal: terminalSurface, actions: actionsSurface, files: filesSurface, file: fileSurface, diff: diffSurface, agents: agentsSurface, computer: computerSurface, simulator: simulatorSurface };

// =====================================================================================
// The panel
// =====================================================================================

/**
 * opts: { chat(): snapshot of the chat beside the panel or null, onChange() }
 */
export function createPanel(ws, opts) {
  const st = (all[ws.id] ??= { open: false, active: null, tabs: [], width: null });
  st.tabs = (st.tabs ?? []).filter((t) => t && typeof t.id === "string" && spec(t.kind));
  const strip = h("div", { class: "sp-tabs", role: "tablist", "aria-label": "Side panel tabs" });
  const stage = h("div", { class: "sp-stage" });
  const grip = h("div", { class: "sp-grip", role: "separator", "aria-label": "Resize side panel", "aria-orientation": "vertical", tabindex: 0 });
  const el = h("aside", { class: "sp", "aria-label": "Side panel", hidden: true }, grip, h("div", { class: "sp-head" }, strip,
    h("button", { class: "icon-btn sp-close", type: "button", title: "Hide panel", "aria-label": "Hide panel", onclick: () => setOpen(false) }, icon("x"))), stage);
  const live = new Map(); // tab id -> surface instance
  const terminals = new Set();
  let seq = 0;

  const persist = () => { all[ws.id] = st; save(); };

  function identity(kind, params) {
    const s = spec(kind);
    if (s.identity === "one") return kind;
    if (s.identity === "path") return `file:${params.path}`;
    if (kind === "terminal" && params.command && !params.terminalId) return null;
    return null;
  }

  function open(kind, params = {}, { replace, focus = true } = {}) {
    if (replace && !st.tabs.some((t) => t.id === replace)) replace = undefined;
    const id = identity(kind, params) ?? `${kind}:${Date.now().toString(36)}${(seq++).toString(36)}`;
    let tab = st.tabs.find((t) => t.id === id);
    if (tab && replace && replace !== id) closeTab(replace, { keepActive: true });
    if (tab) {
      const changed = Object.entries(params).some(([k, v]) => tab.params[k] !== v);
      tab.params = { ...tab.params, ...params };
      if (changed && kind === "browser" && params.url) live.get(id)?.navigate?.(params.url);
      if (changed && kind === "files" && params.dir) { live.get(id)?.dispose?.(false); live.get(id)?.el.remove(); live.delete(id); }
    } else {
      tab = { id, kind, params: { ...params }, title: null };
      const at = replace ? st.tabs.findIndex((t) => t.id === replace) : -1;
      if (at >= 0) { closeTab(replace, { keepActive: true }); st.tabs.splice(at, 0, tab); }
      else st.tabs.push(tab);
    }
    if (focus) { st.active = id; st.open = true; }
    persist();
    render();
    return id;
  }

  function closeTab(id, { keepActive = false } = {}) {
    const i = st.tabs.findIndex((t) => t.id === id);
    if (i < 0) return;
    const inst = live.get(id);
    inst?.dispose?.(true);
    inst?.el.remove();
    live.delete(id);
    st.tabs.splice(i, 1);
    if (!keepActive && st.active === id) st.active = (st.tabs[i] ?? st.tabs[i - 1])?.id ?? null;
    if (!keepActive && st.tabs.length === 0) st.open = false;
    persist();
    if (!keepActive) render();
  }

  function setOpen(on) {
    if (on && st.tabs.length === 0) { open("new"); return; }
    st.open = on;
    if (on && !st.tabs.some((t) => t.id === st.active)) st.active = st.tabs[0]?.id ?? null;
    persist();
    render();
  }

  /** Opens the tool, or hides the panel when that tool is already in front. */
  function toggleKind(kind) {
    const tab = [...st.tabs].reverse().find((t) => t.kind === kind);
    if (tab && st.open && st.active === tab.id) return setOpen(false);
    if (tab) { st.active = tab.id; st.open = true; persist(); render(); return; }
    open(kind);
  }

  function setTitle(id, title) {
    const t = st.tabs.find((x) => x.id === id);
    if (!t || t.title === title) return;
    t.title = title;
    persist();
    renderStrip();
  }

  const titleOf = (t) => t.title || (t.kind === "file" ? t.params.path.split("/").pop() : t.kind === "browser" && t.params.url ? t.params.url.replace(/^https?:\/\//, "").replace(/\/$/, "") : t.kind === "terminal" && t.params.command ? t.params.command : spec(t.kind).label);

  function renderStrip() {
    put(strip, ...st.tabs.map((t, i) => h("div", { class: "sp-tab", role: "tab", tabindex: 0, "aria-selected": String(t.id === st.active), dataset: { kind: t.kind }, title: titleOf(t),
      onclick: () => { st.active = t.id; persist(); render(); },
      onkeydown: (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); st.active = t.id; persist(); render(); } },
      onauxclick: (e) => { if (e.button === 1) closeTab(t.id); },
      oncontextmenu: (e) => { e.preventDefault(); openMenu(e.currentTarget, [
        { label: "Close", onSelect: () => closeTab(t.id) },
        { label: "Close others", disabled: st.tabs.length < 2, onSelect: () => { for (const x of st.tabs.filter((y) => y.id !== t.id)) closeTab(x.id); } },
        { label: "Close to the right", disabled: i === st.tabs.length - 1, onSelect: () => { for (const x of st.tabs.slice(i + 1)) closeTab(x.id); } },
        ...(live.get(t.id)?.refresh ? [{ separator: true }, { label: "Reload tab", onSelect: () => live.get(t.id)?.refresh() }] : []),
      ], { up: false, width: 200 }); } },
      icon(spec(t.kind).icon), h("span", { class: "sp-tab-label" }, titleOf(t)),
      h("button", { class: "sp-tab-x", type: "button", "aria-label": `Close ${titleOf(t)}`, onclick: (e) => { e.stopPropagation(); closeTab(t.id); } }, icon("x")))),
    h("button", { class: "icon-btn sp-tab-new", type: "button", title: "New tab", "aria-label": "New tab", onclick: () => open("new") }, icon("plus")));
    strip.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }

  function render() {
    el.hidden = !st.open || (opts.visible ? !opts.visible() : false);
    el.style.width = st.width ? `${st.width}px` : "";
    renderStrip();
    for (const [id, inst] of live) inst.el.hidden = id !== st.active;
    if (!st.open) { opts.onChange?.(); return; }
    const tab = st.tabs.find((t) => t.id === st.active);
    if (tab && !live.has(tab.id)) {
      const ctx = { ws, tab, panel: api, chat: () => opts.chat() };
      let inst;
      try { inst = BUILD[tab.kind](ctx); } catch (e) { inst = { el: h("div", { class: "sp-pad" }, empty("This tab stopped working", e.message)) }; }
      inst.el.classList.add("sp-surface");
      inst.el.dataset.surface = tab.kind;
      live.set(tab.id, inst);
      stage.append(inst.el);
    } else if (tab) live.get(tab.id)?.show?.();
    opts.onChange?.();
  }

  // Resize by dragging the left edge.
  grip.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    grip.setPointerCapture(e.pointerId);
    const startX = e.clientX;
    const startW = el.getBoundingClientRect().width;
    const move = (ev) => {
      const max = Math.max(360, Math.round(window.innerWidth * 0.7));
      st.width = Math.round(Math.min(max, Math.max(320, startW + (startX - ev.clientX))));
      el.style.width = `${st.width}px`;
    };
    const up = () => { grip.removeEventListener("pointermove", move); grip.removeEventListener("pointerup", up); persist(); };
    grip.addEventListener("pointermove", move);
    grip.addEventListener("pointerup", up);
  });
  grip.addEventListener("dblclick", () => { st.width = null; persist(); render(); });

  const each = (fn) => { for (const inst of live.values()) fn(inst); };
  const api = {
    el,
    terminals,
    open,
    setOpen,
    toggle: () => setOpen(!st.open),
    toggleKind,
    setTitle,
    persist,
    get isOpen() { return st.open; },
    render,
    /** The chat beside the panel changed (a turn event, or another chat was selected). */
    chatChanged: (ev) => each((i) => i.onChat?.(ev)),
    termOutput: (p) => { for (const t of terminals) if (t.owns(p.terminal_id)) t.onOutput(p); },
    termExit: (p) => { for (const t of terminals) if (t.owns(p.terminal_id)) t.onExit(p); each((i) => i.onTermExit?.(p)); },
    actionsChanged: () => each((i) => i.onActions?.()),
    computerChanged: () => each((i) => i.onComputer?.()),
    iosActivity: (p) => each((i) => i.onIos?.(p)),
    // ---- the agent's browser (main drives the page; see src/main/browserHost.ts) ----
    /** Opens (or finds) the Browser tab the agent works in and returns its WebContents id. */
    async agentBrowser(a) {
      let tab = a.tab_id ? st.tabs.find((t) => t.id === a.tab_id && t.kind === "browser") : undefined;
      if (a.tab_id && !tab && !a.new) throw new Error(`no tab ${a.tab_id}`);
      if (!tab && !a.new) tab = st.tabs.find((t) => t.id === st.active && t.kind === "browser") ?? [...st.tabs].reverse().find((t) => t.kind === "browser");
      if (!tab) {
        const id = open("browser", { agent: true, ...(a.url ? { url: a.url } : {}) }, { focus: true });
        tab = st.tabs.find((t) => t.id === id);
      } else if (st.active !== tab.id || !st.open) {
        tab.params.agent = true;
        st.active = tab.id;
        st.open = true;
        persist();
        render();
      }
      const inst = live.get(tab.id);
      if (!inst?.wcId) throw new Error("the Browser tab did not open");
      return { tab_id: tab.id, wc_id: await inst.wcId() };
    },
    browserList: () => st.tabs.filter((t) => t.kind === "browser").map((t) => ({ tab_id: t.id, ...(live.get(t.id)?.info?.() ?? { url: t.params.url ?? "", title: t.title ?? "" }), active: false })),
    selectTab(id) { if (!st.tabs.some((t) => t.id === id)) throw new Error(`no tab ${id}`); st.active = id; st.open = true; persist(); render(); },
    closeTabById(id) { if (!st.tabs.some((t) => t.id === id)) throw new Error(`no tab ${id}`); closeTab(id); },
    /** The Browser tab the agent works in (active one first) as a WebContents id, or null. */
    async browserWcId() {
      const tab = st.tabs.find((t) => t.id === st.active && t.kind === "browser") ?? [...st.tabs].reverse().find((t) => t.kind === "browser" && t.params.agent) ?? [...st.tabs].reverse().find((t) => t.kind === "browser");
      const inst = tab ? live.get(tab.id) : undefined;
      try {
        if (!inst?.wcId) return null;
        const id = await inst.wcId();
        const r = inst.el?.querySelector("webview")?.getBoundingClientRect();
        return { id, ...(r && r.width > 40 && r.height > 40 ? { rect: { x: r.left, y: r.top, width: r.width, height: r.height } } : {}) };
      } catch { return null; }
    },
    agentActivity(id, label) { live.get(id)?.activity?.(String(label ?? "").slice(0, 40)); },
    /** After a runtime restart: rebuild every tab (terminal ids and runs are gone). */
    reset() { each((i) => { i.dispose?.(false); i.el.remove(); }); live.clear(); terminals.clear(); for (const t of st.tabs) if (t.kind === "terminal") delete t.params.terminalId; persist(); render(); },
    dispose() { each((i) => { i.dispose?.(false); i.el.remove(); }); live.clear(); el.remove(); },
  };
  render();
  return api;
}
