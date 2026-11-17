// Full-page views opened from the sidebar: Plugins (catalog, installed plugins,
// MCP servers, skills, rules) and Review (what changed in each project).

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast, nav } from "./store.js";
import { showDialog, closeDialog, confirmDialog } from "./dialogs.js";
import { chooseFolder } from "./settings.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const toggle = (on, onChange, label) => h("button", { class: "switch", type: "button", role: "switch", "aria-checked": String(on), "aria-label": label, onclick: (e) => { e.stopPropagation(); onChange(!on); } });
const tile = (mark, kind = "") => h("span", { class: `pl-tile ${kind}` }, mark);

// =====================================================================================
// Plugins
// =====================================================================================
export function createPluginsPage() {
  const search = h("input", { class: "pl-search-input", placeholder: "Search plugins, MCP servers and skills", "aria-label": "Search plugins, MCP servers and skills", autocomplete: "off", spellcheck: false });
  const tabs = h("div", { class: "pl-tabs", role: "tablist" });
  const warn = h("div", { class: "pl-warn" });
  const body = h("div", { class: "pl-body" });
  const add = h("button", { class: "icon-btn", type: "button", title: "Add", "aria-label": "Add" }, icon("plus"));
  const root = h("div", { class: "pl-page pane-surface" },
    h("div", { class: "pl-head" }, h("label", { class: "pl-search" }, icon("search"), search), h("span", { class: "grow" }), add),
    h("div", { class: "pl-subhead" }, tabs, h("span", { class: "grow" }), warn),
    h("div", { class: "pl-scroll" }, body));
  let tab = "all";
  let catalog = null;
  let showAllInstalled = false;

  const q = () => search.value.trim().toLowerCase();
  const match = (...parts) => !q() || parts.join(" ").toLowerCase().includes(q());

  async function loadCatalog() {
    try { catalog = (await state.client.call("mcp.catalog")).catalog; } catch { catalog = []; }
    render();
  }

  function addCatalog(e) {
    const inputs = e.inputs.map((i) => ({ i, el: h("input", { class: "input", type: "password", autocomplete: "off", spellcheck: false, placeholder: i.label, "aria-label": `${e.name} ${i.label}` }) }));
    const msg = h("p", { class: "field-help", role: "status" });
    const go = async () => {
      const values = Object.fromEntries(inputs.map(({ i, el }) => [i.key, el.value]));
      try { await state.client.call("mcp.catalog.add", { id: e.id, ...(inputs.length ? { values } : {}) }); closeDialog(); toast(`Added ${e.name}`); void loadCatalog(); }
      catch (err) { msg.textContent = err.message; }
    };
    showDialog(h("div", { class: "dialog", role: "dialog", "aria-modal": "true", "aria-label": `Add ${e.name}` },
      h("div", { class: "dialog-head" }, tile(e.mark), h("h2", {}, `Add ${e.name}`)),
      h("div", { class: "dialog-body" },
        h("p", { class: "field-help" }, e.description),
        h("div", { class: "pl-runs" }, h("span", { class: "field-label" }, e.transport === "stdio" ? "Runs on this computer" : "Connects to"), h("code", {}, e.target)),
        e.needs ? h("p", { class: "field-help" }, `Needs: ${e.needs}.`) : null,
        ...inputs.map(({ i, el }) => h("label", { class: "field" }, h("span", { class: "field-label" }, i.label), el, h("span", { class: "field-help" }, i.help))),
        inputs.length ? h("p", { class: "field-help" }, "Keys stay on this computer, in Opscode's private data folder. Agents see the server's tools, never the key.") : null,
        msg),
      h("div", { class: "dialog-foot" },
        h("a", { class: "link", href: e.docs, target: "_blank", rel: "noreferrer" }, "About this server"),
        h("span", { class: "grow" }),
        h("button", { class: "btn btn-sm", type: "button", onclick: closeDialog }, "Cancel"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: go }, "Add"))));
    inputs[0]?.el.focus();
  }

  function editKeys(s) {
    const entry = catalog?.find((c) => c.id === s.catalog);
    const names = entry ? entry.inputs : (s.secrets ?? []).map((k) => ({ key: k, label: k, help: "" }));
    if (!names.length) return;
    const inputs = names.map((i) => ({ i, el: h("input", { class: "input", type: "password", autocomplete: "off", placeholder: `New ${i.label}`, "aria-label": `${s.name} ${i.label}` }) }));
    const msg = h("p", { class: "field-help", role: "status" });
    const go = async () => {
      const values = Object.fromEntries(inputs.filter(({ el }) => el.value.trim()).map(({ i, el }) => [i.key, el.value.trim()]));
      if (!Object.keys(values).length) { msg.textContent = "Enter a new value."; return; }
      try { await state.client.call("mcp.set_secrets", { id: s.id, values }); closeDialog(); toast(`Updated ${s.name}`); }
      catch (err) { msg.textContent = err.message; }
    };
    showDialog(h("div", { class: "dialog", role: "dialog", "aria-modal": "true", "aria-label": `Keys for ${s.name}` },
      h("div", { class: "dialog-head" }, h("h2", {}, `Keys for ${s.name}`)),
      h("div", { class: "dialog-body" }, ...inputs.map(({ i, el }) => h("label", { class: "field" }, h("span", { class: "field-label" }, i.label), el, i.help ? h("span", { class: "field-help" }, i.help) : null)), msg),
      h("div", { class: "dialog-foot" }, h("span", { class: "grow" }), h("button", { class: "btn btn-sm", type: "button", onclick: closeDialog }, "Cancel"), h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: go }, "Save"))));
  }

  const card = ({ mark, kind, title, sub, dot, action, onclick, data }) =>
    h("div", { class: "pl-card", dataset: data ?? {}, onclick, role: onclick ? "button" : undefined, tabindex: onclick ? 0 : undefined },
      tile(mark, kind), h("div", { class: "pl-card-text" }, h("div", { class: "pl-card-title" }, title), h("div", { class: "pl-card-sub" }, dot ? h("span", { class: "pl-dot" }) : null, sub)), action ?? null);
  const section = (id, title, count, items, more) => (tab === "all" || tab === id) && items.length
    ? h("section", { class: "pl-section", dataset: { section: id } }, h("h3", {}, title, count !== null ? h("span", { class: "pl-count" }, String(count)) : null), h("div", { class: "pl-grid" }, ...items), more ?? null)
    : null;

  function render() {
    const servers = state.mcp ?? [];
    const plugins = state.plugins ?? [];
    const skills = state.skills ?? [];
    const rules = (state.notes ?? []).filter((n) => n.state === "kept" || n.pinned);
    const cat = (catalog ?? []).filter((e) => match(e.name, e.description));
    const needs = servers.filter((s) => s.needs_key || s.state === "error");
    const counts = { featured: catalog?.length ?? 0, installed: plugins.length, mcp: servers.length, skills: skills.length, rules: rules.length };
    put(tabs, ...[["featured", "Featured"], ["installed", "Installed"], ["mcp", "MCP servers"], ["skills", "Skills"], ["rules", "Rules"]].map(([id, label]) =>
      h("button", { class: "pl-tab", type: "button", role: "tab", "aria-selected": String(tab === id), onclick: () => { tab = tab === id ? "all" : id; render(); } }, label, h("span", { class: "pl-count" }, String(counts[id])))));
    put(warn, needs.length ? h("span", {}, h("span", { class: "pl-dot" }), `${needs.length} need${needs.length === 1 ? "s" : ""} a key or can't start`) : null);

    const featured = cat.map((e) => card({ mark: e.mark, title: e.name, sub: e.description, data: { catalog: e.id },
      action: e.added ? h("span", { class: "pl-added", title: "Added" }, icon("check")) : h("button", { class: "pl-plus", type: "button", "aria-label": `Add ${e.name}`, title: `Add ${e.name}`, onclick: (ev) => { ev.stopPropagation(); addCatalog(e); } }, icon("plus")) }));
    const inst = plugins.filter((p) => match(p.name, p.description)).map((p) => card({ mark: p.name.slice(0, 1).toUpperCase(), kind: "pl-tile-soft", title: p.name, sub: p.description || `${p.skills.length} skills · ${p.mcp_servers.length} servers`, data: { plugin: p.id },
      action: toggle(p.enabled, (on) => state.client.call("plugin.set_enabled", { id: p.id, enabled: on }).catch((e) => toast(e.message)), `Turn ${p.name} ${p.enabled ? "off" : "on"}`) }));
    const shownInst = tab === "installed" || showAllInstalled ? inst : inst.slice(0, 8);
    const mcp = servers.filter((s) => match(s.name, s.target)).map((s) => {
      const sub = s.needs_key ? "Needs a key" : s.state === "error" ? (s.error ?? "Can't start") : s.state === "ready" ? `${s.tools.length} tool${s.tools.length === 1 ? "" : "s"}${s.source ? ` · From ${s.source}` : ""}` : s.state === "connecting" ? "Starting…" : s.source ? `From ${s.source}` : s.plugin ? `From ${s.plugin}` : s.enabled ? "Off" : "Off";
      return card({ mark: (catalog?.find((c) => c.id === s.catalog)?.mark) ?? "", kind: s.catalog ? "" : "pl-tile-mcp", title: s.name, sub, dot: s.needs_key || s.state === "error", data: { server: s.id },
        onclick: s.secrets?.length && !s.plugin ? () => editKeys(s) : undefined,
        action: s.plugin ? h("span", { class: "pl-note" }, "Plugin") : toggle(s.enabled, (on) => state.client.call("mcp.set_enabled", { id: s.id, enabled: on }).catch((e) => toast(e.message)), `Turn ${s.name} ${s.enabled ? "off" : "on"}`) });
    });
    const addServer = card({ mark: "+", kind: "pl-tile-ghost", title: "Add an MCP server", sub: "Paste its URL, or the command that starts it", onclick: () => nav.openSettings("mcp") });
    const sk = skills.filter((s) => match(s.name, s.description)).map((s) => card({ mark: "/", kind: "pl-tile-soft", title: s.name, sub: `${s.scope === "project" ? "This project" : s.scope === "plugin" ? `From ${s.plugin}` : "Yours"} · ${s.description}`, onclick: () => nav.openSettings("skills") }));
    const ru = rules.filter((n) => match(n.title, n.body)).map((n) => card({ mark: "R", kind: "pl-tile-soft", title: n.title || n.body.slice(0, 40), sub: n.body, onclick: () => nav.openSettings("memory") }));

    put(body,
      catalog === null ? h("div", { class: "sp-empty" }, h("span", {}, "Loading…")) : null,
      section("featured", "Featured", null, featured),
      section("installed", "Installed", inst.length, shownInst, inst.length > 8 && tab === "all" ? h("button", { class: "link pl-more", type: "button", onclick: () => { showAllInstalled = !showAllInstalled; render(); } }, showAllInstalled ? "Show fewer" : `Show all ${inst.length}`) : null),
      tab === "installed" && !inst.length ? h("div", { class: "sp-empty" }, h("strong", {}, "No plugins yet"), h("span", {}, "Install one from a folder or a marketplace with +.")) : null,
      section("mcp", "MCP servers", servers.length, [addServer, ...mcp]),
      section("skills", "Skills", skills.length, sk),
      section("rules", "Rules", rules.length, ru),
      tab === "rules" && !ru.length ? h("div", { class: "sp-empty" }, h("strong", {}, "No rules yet"), h("span", {}, "Kept notes in Memory act as standing rules for every chat.")) : null,
      q() && !featured.length && !inst.length && !mcp.length && !sk.length && !ru.length ? h("div", { class: "sp-empty" }, h("strong", {}, "Nothing matches"), h("span", {}, `No plugin, server, skill or rule matches “${search.value.trim()}”.`)) : null);
  }

  search.addEventListener("input", render);
  add.addEventListener("click", async () => {
    const { openMenu } = await import("./popover.js");
    openMenu(add, [
      { label: "Install from a folder…", description: "A plugin, a marketplace, or a folder of skills", icon: "folder", onSelect: () => void chooseFolder() },
      { label: "Add an MCP server…", icon: "plug", onSelect: () => nav.openSettings("mcp") },
      { label: "New skill…", icon: "file", onSelect: () => nav.openSettings("skills") },
      { label: "New rule…", icon: "shield", onSelect: () => nav.openSettings("memory") },
    ], { up: false, width: 300 });
  });
  return { el: root, show: () => { if (catalog === null) void loadCatalog(); else render(); }, render, refresh: loadCatalog };
}

// =====================================================================================
// Review: what changed in each project, with a way into its Changes tab.
// =====================================================================================
export function createReviewPage({ openChanges }) {
  const body = h("div", { class: "rv-body" });
  const root = h("div", { class: "rv-page pane-surface" }, h("div", { class: "pl-scroll" }, body));
  let seq = 0;
  async function show() {
    const my = ++seq;
    put(body, h("div", { class: "rv-intro" }, h("h1", {}, "Review"), h("p", {}, "Uncommitted changes in each project. Open one to read the diff beside its chat.")), h("div", { class: "sp-empty" }, h("span", {}, "Checking projects…")));
    const rows = await Promise.all(state.workspaces.map(async (w) => {
      try { return { w, ch: await state.client.call("changes.diff", { workspace_id: w.id }) }; } catch (e) { return { w, err: e.message }; }
    }));
    if (my !== seq) return;
    const changed = rows.filter((r) => r.ch?.files.length);
    const clean = rows.filter((r) => r.ch && r.ch.git && !r.ch.files.length);
    const nogit = rows.filter((r) => r.ch && !r.ch.git);
    const row = (r) => {
      const add = r.ch.files.reduce((n, f) => n + f.added, 0);
      const del = r.ch.files.reduce((n, f) => n + f.removed, 0);
      return h("button", { class: "rv-row", type: "button", dataset: { workspace: r.w.id }, onclick: () => openChanges(r.w.id) },
        icon("folder"), h("span", { class: "grow" }, h("span", { class: "sp-row-title" }, r.w.name), h("span", { class: "sp-row-sub" }, r.ch.branch ? `On ${r.ch.branch}` : "")),
        h("span", { class: "sp-note" }, `${r.ch.files.length} file${r.ch.files.length === 1 ? "" : "s"}`), h("span", { class: "sp-counts" }, h("span", { class: "add" }, `+${add}`), " ", h("span", { class: "del" }, `−${del}`)), icon("chevron-right"));
    };
    put(body,
      h("div", { class: "rv-intro" }, h("h1", {}, "Review"), h("p", {}, "Uncommitted changes in each project. Open one to read the diff beside its chat.")),
      state.workspaces.length === 0 ? h("div", { class: "sp-empty" }, h("strong", {}, "No projects yet"), h("span", {}, "Add a project to see its changes here.")) : null,
      changed.length ? h("div", {}, h("h4", { class: "sp-h" }, "Changed"), h("div", { class: "sp-list" }, ...changed.map(row))) : state.workspaces.length ? h("div", { class: "sp-empty" }, h("strong", {}, "Nothing to review"), h("span", {}, "No project has uncommitted changes.")) : null,
      clean.length ? h("div", {}, h("h4", { class: "sp-h" }, "Clean"), h("div", { class: "sp-list" }, ...clean.map((r) => h("div", { class: "rv-row rv-quiet" }, icon("folder"), h("span", { class: "grow sp-row-title" }, r.w.name), h("span", { class: "sp-note" }, r.ch.branch ? `On ${r.ch.branch}` : "Clean"))))) : null,
      nogit.length ? h("div", {}, h("h4", { class: "sp-h" }, "Not git repositories"), h("div", { class: "sp-list" }, ...nogit.map((r) => h("div", { class: "rv-row rv-quiet" }, icon("folder"), h("span", { class: "grow sp-row-title" }, r.w.name), h("span", { class: "sp-note" }, "No git"))))) : null);
  }
  return { el: root, show };
}

// =====================================================================================
// Automations: list on the left; the selected one (steps, runs) on the right.
// =====================================================================================
const RUN_STATUS = { running: "Running", waiting: "Waiting for you", succeeded: "Succeeded", failed: "Failed", cancelled: "Cancelled" };
const STEP_STATUS = { pending: "Pending", running: "Running", waiting_approval: "Waiting for you", succeeded: "Done", failed: "Failed", skipped: "Skipped", cancelled: "Cancelled" };
const ENGINE_LABEL = { "claude-code": "Claude Code", codex: "Codex", api: "API key" };
const pill = (text, kind = "") => h("span", { class: `pill ${kind}` }, text);
const statusPill = (s) => pill(RUN_STATUS[s] ?? STEP_STATUS[s] ?? s, s === "succeeded" ? "pill-ok" : s === "failed" ? "pill-warn" : s === "waiting" || s === "waiting_approval" ? "pill-wait" : "");
const when = (iso) => { if (!iso) return ""; const d = new Date(iso); const same = d.toDateString() === new Date().toDateString(); return same ? d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : d.toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }); };
const took = (a, b) => { if (!a) return ""; const s = Math.round(((b ? Date.parse(b) : Date.now()) - Date.parse(a)) / 1000); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`; };

/** The short format guide given to an agent asked to write an automation. */
const AUTOMATION_GUIDE = `Opscode automations are YAML files: project ones in .opscode/automations/<name>.yaml (shared through git).
Format:
version: 1
description: one line
on: { schedule: { at: "09:00", weekdays: [mon, tue, wed, thu, fri] } }   # or { schedule: { every: 6h } }; leave on: out to run by hand
inputs: { brief: { description: What to build, required: true } }        # used as {{inputs.brief}}
budget: { tokens: 2000000, turns: 40 }                                     # always set one
steps:                                                                      # run in order
  <step>:
    agent: planner | builder | designer | reviewer | writer | explorer      # or prompt: "...", or run: "a command", or wait: 30m
    prompt: the task (an agent step may have one)
    engine: claude-code | codex | api
    model: fast | base | frontier                                           # fast for small jobs, frontier only where it pays
    access: read | edit | full                                              # default read
    needs: [earlier-step]
    decides: [a, b]          # the agent ends with "decision: a"; later steps can use if: { <step>: a } (or failed)
    checks: ["npm test", { agent: reviewer }]
    retries: 2
    escalate: frontier       # or [{ model: frontier }, { engine: codex, model: frontier }]
    approve: true            # wait for the person after this step
Names: lowercase letters, digits, - and _, starting with a letter.`;

export function createAutomationsPage({ openChat }) {
  const wsSel = h("select", { class: "input select au-ws", "aria-label": "Project" });
  const listEl = h("div", { class: "au-list" });
  const detail = h("div", { class: "au-detail" });
  const root = h("div", { class: "au-page pane-surface" },
    h("aside", { class: "au-left" },
      h("div", { class: "au-left-head" }, h("span", { class: "au-tab" }, icon("zap"), "Automations"), h("span", { class: "au-tab au-tab-off", title: "Agents live in Settings → Sub-agents", role: "button", tabindex: 0, onclick: () => nav.openSettings("agents") }, "Agents")),
      wsSel,
      h("button", { class: "au-new", type: "button", onclick: () => openCreate() }, icon("plus"), "New automation"),
      listEl),
    detail);
  let items = [];
  let sel = null; // { scope, name }
  let runSel = null;
  let runs = [];
  let editing = null; // text being edited
  let creating = false;
  let diag = [];

  const wsId = () => wsSel.value || state.active;
  const current = () => items.find((a) => sel && a.scope === sel.scope && a.name === sel.name) ?? null;

  async function load() {
    const opts = state.workspaces.map((w) => h("option", { value: w.id, selected: w.id === (wsSel.value || state.active) }, w.name));
    put(wsSel, ...opts);
    if (!wsId()) { items = []; render(); return; }
    try { items = (await state.client.call("automation.list", { workspace_id: wsId() })).automations; } catch (e) { toast(e.message); items = []; }
    if (sel && !current()) sel = null;
    await loadRuns();
    render();
  }
  async function loadRuns() {
    const a = current();
    runs = a ? (await state.client.call("automation.runs", { workspace_id: wsId(), name: a.name }).catch(() => ({ runs: [] }))).runs.filter((r) => r.scope === a.scope) : [];
  }

  function renderList() {
    put(listEl, ...(items.length ? items.map((a) => h("button", { class: "au-item", type: "button", "aria-current": String(!!sel && sel.name === a.name && sel.scope === a.scope), dataset: { automation: a.name }, onclick: async () => { sel = { scope: a.scope, name: a.name }; runSel = null; editing = null; creating = false; await loadRuns(); render(); } },
      h("span", { class: "au-item-top" }, h("span", { class: "grow truncate" }, a.description || a.name), a.running ? h("span", { class: "spin" }) : !a.ok ? h("span", { class: "pl-dot", title: "Has problems" }) : a.enabled ? h("span", { class: "au-on", title: "On" }) : null),
      h("span", { class: "au-item-sub" }, `${a.scope === "me" ? "Just me" : "Project"} · ${a.trigger || "Has problems"}`))) : [h("div", { class: "sidebar-note" }, "No automations in this project yet.")]));
  }

  function createBox() {
    const title = h("input", { class: "au-title-input", placeholder: "Automation title", "aria-label": "Automation title", maxLength: 120 });
    const what = h("textarea", { class: "au-what", rows: 5, placeholder: "Tell it what to do, e.g. every morning, read new issues and label each one by area", "aria-label": "What it should do" });
    const choice = (label, options, value) => h("select", { class: "au-chip-select", "aria-label": label }, ...options.map(([v, t]) => h("option", { value: v, selected: v === value }, t)));
    const ws = state.workspaces.find((w) => w.id === wsId());
    const sched = choice("Schedule", [["manual", "By hand"], ["weekdays", "Weekdays at 9:00"], ["daily", "Every day at 9:00"], ["hourly", "Every hour"]], "manual");
    const engines = (state.engines ?? []).filter((e) => e.found);
    const eng = choice("Engine", [["", "Default engine"], ...engines.map((e) => [e.id, e.label]), ["api", "API key"]], "");
    const acc = choice("Access", [["read", "Read-only"], ["edit", "Can edit"], ["full", "Full access"]], "read");
    const scope = choice("Whose", [["me", "Just me"], ["project", "Project (in the repo)"]], "me");
    const msg = h("span", { class: "au-msg", role: "status" });
    const create = async () => {
      if (!title.value.trim() || !what.value.trim()) { msg.textContent = "Give it a title and say what to do."; return; }
      try {
        const r = await state.client.call("automation.create", { workspace_id: wsId(), scope: scope.value, title: title.value.trim(), prompt: what.value.trim(), schedule: sched.value, ...(eng.value ? { engine: eng.value } : {}), access: acc.value });
        creating = false; sel = { scope: scope.value, name: r.name }; await load();
        toast(sched.value === "manual" ? "Created. Run it with Run." : "Created. Turn it on to start the schedule.");
      } catch (e) { msg.textContent = e.message; }
    };
    const withAgent = () => {
      const brief = what.value.trim() || title.value.trim();
      if (!brief) { msg.textContent = "Say what it should do first."; return; }
      const name = (title.value.trim() || "automation").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 36) || "automation";
      creating = false;
      openChat(wsId(), `Write an Opscode automation for this project at .opscode/automations/${/^[a-z]/.test(name) ? name : `a-${name}`}.yaml.\n\nWhat it should do: ${brief}\nSchedule: ${sched.options[sched.selectedIndex].text}. Engine: ${eng.options[eng.selectedIndex].text}. Access: ${acc.options[acc.selectedIndex].text}.\n\nUse built-in agents where they fit, model fast for small steps, and always a budget. Then tell me what each step does.\n\n${AUTOMATION_GUIDE}`);
    };
    const useTemplate = async (anchor) => {
      const { openMenu } = await import("./popover.js");
      const { templates } = await state.client.call("automation.templates");
      openMenu(anchor, templates.map((tp) => ({ label: tp.title, description: tp.summary, icon: "zap", onSelect: async () => {
        try { const r = await state.client.call("automation.from_template", { workspace_id: wsId(), scope: scope.value, template: tp.id }); creating = false; sel = { scope: scope.value, name: r.name }; await load(); toast(`Added ${tp.title}`); }
        catch (e) { toast(e.message); }
      } })), { up: false, width: 380 });
    };
    queueMicrotask(() => title.focus());
    return h("div", { class: "au-create" },
      h("div", { class: "au-create-top" }, title, h("span", { class: "grow" }),
        h("button", { class: "btn btn-sm", type: "button", onclick: withAgent, title: "A chat writes the file with you" }, icon("mark"), "Build with agent"),
        h("button", { class: "btn btn-sm", type: "button", onclick: (e) => useTemplate(e.currentTarget) }, "Use template"),
        h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: () => { creating = false; render(); } }, icon("x"))),
      what,
      h("div", { class: "au-create-foot" }, h("span", { class: "au-chip" }, icon("folder"), ws?.name ?? ""), sched, eng, acc, scope, h("span", { class: "grow" }), msg,
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: create }, "Create")));
  }

  function stepCard(s, i) {
    return h("div", { class: "au-step", dataset: { step: s.name } },
      h("span", { class: "au-step-n" }, String(i + 1)),
      h("div", { class: "grow" },
        h("div", { class: "au-step-title" }, h("strong", {}, s.name), s.kind === "agent" ? h("span", { class: "sp-note" }, ` · ${s.agent}${s.missing_agent ? " (missing)" : ""}`) : s.kind === "run" ? h("code", { class: "au-code" }, s.run) : h("span", { class: "sp-note" }, ` · ${s.kind}`)),
        h("div", { class: "au-step-meta" },
          s.engine ? pill(ENGINE_LABEL[s.engine] ?? s.engine) : null,
          s.model ? pill(s.model) : s.engine ? pill("base") : null,
          s.engine ? pill(s.access === "full" ? "Full access" : s.access === "edit" ? "Can edit" : "Read-only") : null,
          s.needs.length ? h("span", { class: "sp-note" }, `after ${s.needs.join(", ")}`) : null,
          s.if ? h("span", { class: "sp-note" }, `if ${Object.entries(s.if).map(([k, v]) => `${k} = ${v}`).join(", ")}`) : null,
          s.checks.length ? h("span", { class: "sp-note" }, `checks: ${s.checks.join(" + ")}`) : null,
          s.retries ? h("span", { class: "sp-note" }, `${s.retries} retr${s.retries === 1 ? "y" : "ies"}`) : null,
          s.approve ? pill("You approve", "pill-wait") : null)));
  }

  async function runIt(a) {
    const keys = Object.entries(a.inputs ?? {});
    const go = async (inputs) => {
      try { const r = await state.client.call("automation.run", { workspace_id: wsId(), scope: a.scope, name: a.name, ...(inputs ? { inputs } : {}) }); closeDialog(); runSel = r.run.id; await load(); }
      catch (e) { toast(e.message); }
    };
    if (!keys.length) return go();
    const fields = keys.map(([k, def]) => ({ k, el: h(k === "brief" ? "textarea" : "input", { class: `input${k === "brief" ? " textarea" : ""}`, rows: k === "brief" ? 6 : undefined, value: def.default ?? "", placeholder: def.description, "aria-label": k }) }));
    showDialog(h("div", { class: "dialog au-run-dialog", role: "dialog", "aria-modal": "true", "aria-label": `Run ${a.name}` },
      h("div", { class: "dialog-head" }, h("h2", {}, `Run ${a.description || a.name}`)),
      h("div", { class: "dialog-body" }, ...fields.map(({ k, el }) => h("label", { class: "field" }, h("span", { class: "field-label" }, `${k}${a.inputs[k].required ? "" : " (optional)"}`), el, h("span", { class: "field-help" }, a.inputs[k].description)))),
      h("div", { class: "dialog-foot" }, h("span", { class: "grow" }, a.budget?.tokens ? `Budget: ${a.budget.tokens.toLocaleString()} tokens` : ""), h("button", { class: "btn btn-sm", type: "button", onclick: closeDialog }, "Cancel"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => go(Object.fromEntries(fields.map(({ k, el }) => [k, el.value]))) }, "Run"))));
    fields[0]?.el.focus();
  }

  function runView(r) {
    const waiting = r.steps.find((s) => s.status === "waiting_approval");
    return h("div", { class: "au-run", dataset: { run: r.id } },
      h("div", { class: "au-run-head" }, statusPill(r.status), h("span", { class: "sp-note" }, `${r.trigger === "schedule" ? "On schedule" : "By hand"} · ${when(r.started_at)} · ${took(r.started_at, r.ended_at)} · ${r.turns} turn${r.turns === 1 ? "" : "s"} · ${r.tokens.toLocaleString()} tokens`), h("span", { class: "grow" }),
        r.status === "running" || r.status === "waiting" ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => state.client.call("automation.run_cancel", { run_id: r.id }).catch((e) => toast(e.message)) }, "Cancel run") : null),
      r.error ? h("p", { class: "sp-alert", role: "alert" }, r.error) : null,
      Object.keys(r.inputs).length ? h("details", { class: "au-inputs" }, h("summary", {}, "Inputs"), ...Object.entries(r.inputs).map(([k, v]) => h("div", {}, h("strong", {}, `${k}: `), v || "—"))) : null,
      h("div", { class: "au-steps" }, ...r.steps.map((s) => h("div", { class: "au-srun", dataset: { status: s.status, step: s.name } },
        h("div", { class: "au-srun-head" }, s.status === "running" ? h("span", { class: "spin" }) : null, h("strong", {}, s.name), statusPill(s.status), s.decision ? pill(`decided ${s.decision}`) : null, h("span", { class: "grow" }),
          ...s.attempts.filter((x) => x.chat_id).slice(-1).map((x) => h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => openChat(r.workspace_id, null, x.chat_id) }, "Open chat"))),
        s.why ? h("div", { class: "sp-note au-why" }, s.why) : null,
        s.attempts.length ? h("div", { class: "au-attempts" }, ...s.attempts.map((x) => h("div", { class: "au-attempt" },
          h("span", { class: "sp-note" }, `Attempt ${x.n} · ${ENGINE_LABEL[x.engine] ?? x.engine}${x.model ? ` · ${x.model}` : ""}${x.effort ? ` · ${x.effort}` : ""}${x.tokens ? ` · ${x.tokens.toLocaleString()} tokens` : ""}`),
          ...x.checks.map((c) => h("span", { class: `au-check ${c.ok ? "ok" : "bad"}`, title: c.output }, c.ok ? icon("check") : icon("x"), c.name)),
          x.output && (s.kind === "run" || !x.ok) ? h("pre", { class: "tool-pre" }, x.output) : null))) : null,
        s.summary && s.kind !== "run" ? h("div", { class: "au-summary" }, s.summary) : null,
        s.status === "waiting_approval" ? h("div", { class: "tool-actions" },
          h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => state.client.call("automation.approve", { run_id: r.id, step: s.name, decision: "approve" }).catch((e) => toast(e.message)) }, "Approve and continue"),
          h("button", { class: "btn btn-sm", type: "button", onclick: () => state.client.call("automation.approve", { run_id: r.id, step: s.name, decision: "reject" }).catch((e) => toast(e.message)) }, "Reject")) : null))),
      waiting ? null : null);
  }

  let box = null;
  function renderDetail() {
    if (creating) {
      // Keep the same box while it is open, so a background refresh never wipes what was typed.
      box ??= createBox();
      if (!detail.contains(box)) put(detail, box);
      return;
    }
    box = null;
    const a = current();
    if (!wsId()) return put(detail, h("div", { class: "sp-empty au-empty" }, h("strong", {}, "Add a project first"), h("span", {}, "Automations belong to a project.")));
    if (!a) {
      return put(detail, h("div", { class: "sp-empty au-empty" },
        h("strong", {}, "Automations"),
        h("span", {}, "Pick one on the left to see its last run, or make one that runs on a schedule or by hand."),
        h("div", { class: "sp-empty-actions" }, h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => openCreate() }, "New automation"), h("button", { class: "btn btn-sm", type: "button", onclick: () => openCreate() }, "Use a template"))));
    }
    const run = runs.find((r) => r.id === runSel) ?? runs[0];
    put(detail, h("div", { class: "au-detail-inner" },
      h("div", { class: "au-head" },
        h("div", { class: "grow" }, h("h1", {}, a.description || a.name), h("div", { class: "sp-note" }, `${a.name} · ${a.scope === "me" ? "Just me" : "Project"} · ${a.trigger || "—"}${a.next_run ? ` · next ${when(a.next_run)}` : ""}${a.budget?.tokens ? ` · budget ${a.budget.tokens.toLocaleString()} tokens` : ""}`)),
        a.scheduled ? h("label", { class: "au-switch" }, h("span", { class: "sp-note" }, a.enabled ? "On" : "Off"), h("button", { class: "switch", type: "button", role: "switch", "aria-checked": String(a.enabled), "aria-label": "Turn the schedule on or off", onclick: () => state.client.call("automation.set_enabled", { workspace_id: wsId(), scope: a.scope, name: a.name, enabled: !a.enabled }).then(load).catch((e) => toast(e.message)) })) : null,
        h("button", { class: "btn btn-primary btn-sm", type: "button", disabled: !a.ok || a.running, onclick: () => runIt(a) }, icon("play"), a.running ? "Running…" : "Run"),
        h("button", { class: "icon-btn", type: "button", "aria-label": "More", onclick: async (e) => {
          const { openMenu } = await import("./popover.js");
          openMenu(e.currentTarget, [
            { label: "Edit file", icon: "file", onSelect: async () => { const r = await state.client.call("automation.get", { workspace_id: wsId(), scope: a.scope, name: a.name }); editing = r.text; diag = a.diagnostics; render(); } },
            { label: "Change with agent…", icon: "mark", onSelect: () => openChat(wsId(), `Change the Opscode automation in ${a.scope === "project" ? `.opscode/automations/${a.name}.yaml` : `my personal automation "${a.name}" (paste the new file back to me, it is not in the repo)`}: `) },
            { separator: true },
            { label: "Delete", icon: "trash", danger: true, onSelect: async () => { if (await confirmDialog({ title: `Delete ${a.name}?`, body: a.scope === "project" ? "This removes the file from the project's .opscode/automations folder." : "This removes your automation.", confirm: "Delete", danger: true })) { await state.client.call("automation.delete", { workspace_id: wsId(), scope: a.scope, name: a.name }).catch((err) => toast(err.message)); sel = null; await load(); } } },
          ], { up: false, width: 240 });
        } }, icon("more"))),
      a.diagnostics.length && editing === null ? h("div", { class: "sp-alert au-problems" }, h("strong", {}, "This file has problems:"), ...a.diagnostics.map((d) => h("div", {}, `Line ${d.line}: ${d.message}`)), h("button", { class: "link", type: "button", onclick: async () => { const r = await state.client.call("automation.get", { workspace_id: wsId(), scope: a.scope, name: a.name }); editing = r.text; diag = a.diagnostics; render(); } }, "Edit file")) : null,
      editing !== null ? editor(a) : null,
      h("h4", { class: "sp-h" }, "Steps"),
      h("div", { class: "au-pipeline" }, ...a.steps.map(stepCard)),
      h("h4", { class: "sp-h" }, "Runs"),
      runs.length ? h("div", { class: "au-runs" }, ...runs.slice(0, 12).map((r) => h("button", { class: "au-run-row", type: "button", "aria-current": String(r.id === run?.id), onclick: () => { runSel = r.id; render(); } }, statusPill(r.status), h("span", { class: "grow" }, when(r.started_at)), h("span", { class: "sp-note" }, `${r.tokens.toLocaleString()} tokens`)))) : h("div", { class: "sp-note" }, "No runs yet."),
      run ? runView(run) : null));
  }

  function editor(a) {
    const ta = h("textarea", { class: "input textarea mono au-editor", rows: 18, spellcheck: false, "aria-label": "Automation file" }, editing);
    const save = async () => {
      try {
        const r = await state.client.call("automation.file_write", { workspace_id: wsId(), scope: a.scope, name: a.name, text: ta.value });
        diag = r.diagnostics; editing = r.diagnostics.length ? ta.value : null; await load();
        toast(r.diagnostics.length ? "Saved, with problems to fix" : "Saved");
      } catch (e) { toast(e.message); }
    };
    return h("div", { class: "au-edit" }, ta, diag.length ? h("div", { class: "sp-alert" }, ...diag.map((d) => h("div", {}, `Line ${d.line}: ${d.message}`))) : null,
      h("div", { class: "row-actions" }, h("span", { class: "grow sp-note" }, a.scope === "project" ? `.opscode/automations/${a.name}.yaml` : "Your own copy, in Opscode's data folder"), h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { editing = null; render(); } }, "Cancel"), h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: save }, "Save")));
  }

  function openCreate() { creating = true; sel = null; render(); }
  function render() { renderList(); renderDetail(); }
  wsSel.addEventListener("change", () => { sel = null; void load(); });

  return {
    el: root,
    show: () => { if (!wsSel.value && state.active) wsSel.value = state.active; void load(); },
    changed: () => void load(),
    runUpdated: async ({ run }) => {
      const a = current();
      if (!a || run.automation !== a.name || run.scope !== a.scope || run.workspace_id !== wsId()) { if (run.status !== "running") void load(); return; }
      const i = runs.findIndex((r) => r.id === run.id);
      if (i >= 0) runs[i] = run; else runs.unshift(run);
      if (["succeeded", "failed", "cancelled"].includes(run.status)) await load(); else render();
    },
  };
}
