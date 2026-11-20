// Settings page: left nav (in the sidebar) + one section at a time.
// Sections: General, Appearance, Models & keys, Memory, MCP servers, Keyboard.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast, activeWorkspace, nav } from "./store.js";
import { MODES } from "./modes.js";
import { confirmDialog, showDialog, closeDialog } from "./dialogs.js";
import { checking, engineCard, reloadAccounts } from "./accounts.js";

export const SECTIONS = [
  { id: "general", label: "General", icon: "sliders", keywords: "name awake sleep app version runtime voice microphone dictation speech language" },
  { id: "devices", label: "Devices", icon: "monitor", keywords: "android phone pair qr code internet relay connection disconnect" },
  { id: "appearance", label: "Appearance", icon: "sun", keywords: "theme light dark text size density font" },
  { id: "models", label: "Models & keys", icon: "chat", keywords: "api key provider anthropic openai model base url gateway openrouter ollama secret" },
  { id: "memory", label: "Memory", icon: "file", keywords: "notes remember brief draft pin scope" },
  { id: "mcp", label: "MCP servers", icon: "link", keywords: "mcp server tools plugin connector url command" },
  { id: "skills", label: "Skills", icon: "file", keywords: "skill steps slash command reusable instructions import" },
  { id: "agents", label: "Sub-agents", icon: "chat", keywords: "sub-agent subagent agent helper delegate task explorer reviewer files access" },
  { id: "plugins", label: "Plugins", icon: "link", keywords: "plugin marketplace install bundle extension import folder" },
  { id: "computer", label: "Computer use", icon: "monitor", keywords: "computer use screen screenshot click type apps accessibility screen recording allow never mac" },
  { id: "import", label: "Import", icon: "folder", keywords: "import claude code codex cursor migrate mcp servers skills instructions claude.md agents.md copy" },
  { id: "keyboard", label: "Keyboard", icon: "terminal", keywords: "shortcut keys hotkey" },
];

const isMac = /mac/i.test(navigator.platform);
const MOD = isMac ? "⌘" : "Ctrl+";
const patch = async (p) => { try { await state.client.call("settings.set", { patch: p }); } catch (e) { toast(`Couldn't save: ${e.message}`); } };
const call = async (method, params) => { try { return await state.client.call(method, params); } catch (e) { toast(e.message); throw e; } };

// ---- shared pieces -------------------------------------------------------------
const group = (title, ...rows) => h("section", { class: "set-group" }, title ? h("h3", { class: "set-group-title" }, title) : null, h("div", { class: "set-card" }, ...rows));
const row = (label, help, control) => h("div", { class: "set-row" }, h("div", { class: "set-row-text" }, h("div", { class: "set-row-label" }, label), help ? h("div", { class: "set-row-help" }, help) : null), h("div", { class: "set-row-control" }, control));
const toggle = (on, onChange, label) => h("button", { class: "switch", type: "button", role: "switch", "aria-checked": String(on), "aria-label": label, onclick: () => onChange(!on) });
const segmented = (value, options, onChange, label) =>
  h("div", { class: "segmented", role: "radiogroup", "aria-label": label }, ...options.map(([id, text, ic]) =>
    h("button", { type: "button", role: "radio", "aria-checked": String(value === id), onclick: () => onChange(id) }, ic ? icon(ic) : null, text)));
const header = (title, sub) => h("header", { class: "set-head" }, h("h1", {}, title), sub ? h("p", {}, sub) : null);

// ---- sections ---------------------------------------------------------------------
function general() {
  const s = state.settings;
  const rt = state.bridge?.runtime;
  const v = state.bridge?.versions ?? {};
  const name = h("input", { class: "input", maxLength: 64, value: s.display_name, placeholder: "Your name", autocomplete: "off", "aria-label": "Display name" });
  const commit = () => { if (name.value !== state.settings.display_name) void patch({ display_name: name.value }); };
  name.addEventListener("blur", commit);
  name.addEventListener("keydown", (e) => { if (e.key === "Enter") name.blur(); });
  const hello = state.hello;
  return [
    header("General", "How Opscode behaves on this computer."),
    group("You", row("Display name", "Shown in greetings.", name)),
    group("Chats",
      row("Permissions for new chats", "What an agent may do without asking. You can change it per chat.",
        h("select", { class: "input select", "aria-label": "Permissions for new chats", onchange: async (e) => {
          const next = e.target.value;
          if (next === "full" && !(await confirmDialog({ title: "Start new chats with full access?", body: "Agents will edit files and run commands without asking, in every new chat. They still cannot leave a project's folder.", confirm: "Use full access", danger: true }))) { e.target.value = state.settings.default_mode; return; }
          void patch({ default_mode: next });
        } }, ...MODES.map((m) => h("option", { value: m.id, selected: m.id === s.default_mode }, m.label))))),
    group("Voice", ...voiceRows(s)),
    group("This app",
      row("Keep this computer awake", "While agents are working.", toggle(s.keep_awake, (on) => patch({ keep_awake: on }), "Keep awake")),
      row("Version", null, h("code", {}, rt ? `${rt.appName} ${rt.appVersion}` : "—")),
      row("Runtime", state.conn === "ready" ? "Connected." : `Status: ${state.conn}.`, h("code", {}, hello ? `${hello.version} · protocol ${hello.protocol_revision}` : "—")),
      row("Electron / Chromium / Node", null, h("code", {}, `${v.electron ?? "—"} / ${v.chrome ?? "—"} / ${v.node ?? "—"}`))),
  ];
}

function appearance() {
  const s = state.settings;
  return [
    header("Appearance", "Theme and reading comfort."),
    group(null,
      row("Theme", "Light or dark. System follows macOS.", segmented(s.theme, [["system", "System", "monitor"], ["light", "Light", "sun"], ["dark", "Dark", "moon"]], (theme) => patch({ theme }), "Theme")),
      row("Text size", "Scales the whole interface.", segmented(s.text_size, [["small", "Small"], ["default", "Default"], ["large", "Large"]], (text_size) => patch({ text_size }), "Text size")),
      row("Density", "Compact fits more on screen.", segmented(s.density, [["comfortable", "Comfortable"], ["compact", "Compact"]], (density) => patch({ density }), "Density"))),
  ];
}

const MODEL_HINT = { anthropic: "e.g. claude-sonnet-5-5", openai: "e.g. gpt-4.1, or a local model name" };

function models() {
  const cards = state.providers.map((p) => {
    const key = h("input", { class: "input", type: "password", autocomplete: "off", spellcheck: false, placeholder: p.configured ? `Saved · ends in ${p.key_hint} (type to replace)` : "API key", "aria-label": `${p.label} API key` });
    const model = h("input", { class: "input", value: p.model, placeholder: MODEL_HINT[p.id], autocomplete: "off", spellcheck: false, "aria-label": `${p.label} model` });
    const base = h("input", { class: "input", value: p.base_url, placeholder: p.default_base_url, autocomplete: "off", spellcheck: false, "aria-label": `${p.label} base URL` });
    const msg = h("span", { class: "grow", role: "status" });
    const say = (text, good = false) => { msg.textContent = text; if (good) msg.setAttribute("data-ok", ""); else msg.removeAttribute("data-ok"); };
    const save = async () => {
      const params = { id: p.id, model: model.value };
      if (key.value) params.api_key = key.value;
      if (base.value.trim() !== p.base_url) params.base_url = base.value;
      say("Saving…");
      try { await state.client.call("provider.set", params); key.value = ""; say("Saved", true); } catch (err) { say(err.message); }
    };
    const act = (fn) => async () => { try { await fn(); } catch (err) { say(err.message); } };
    return h("details", { class: "prov", open: p.active || undefined, dataset: { provider: p.id } },
      h("summary", {}, h("span", { class: "grow" }, p.label), h("span", { class: "badge", dataset: { kind: p.active ? "active" : "" } }, p.active ? "In use" : p.configured ? "Ready" : "Not set up")),
      h("div", { class: "prov-body" },
        h("label", { class: "field" }, h("span", { class: "field-label" }, "API key"), key, h("span", { class: "field-help" }, "Stored only on this computer, in the app's private data folder. It is never shown again.")),
        h("label", { class: "field" }, h("span", { class: "field-label" }, "Model"), model),
        h("label", { class: "field" }, h("span", { class: "field-label" }, "Base URL"), base, h("span", { class: "field-help" }, p.id === "openai" ? "Any OpenAI-compatible server (OpenRouter, Ollama, vLLM…). https only; http is allowed for localhost." : "Leave as is unless you use a proxy. Changing it needs the key entered again.")),
        h("div", { class: "prov-actions" },
          h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: save }, "Save"),
          !p.active ? h("button", { class: "btn btn-sm", type: "button", disabled: !p.configured, onclick: act(() => state.client.call("provider.select", { id: p.id })) }, "Use this") : null,
          p.configured ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: act(() => state.client.call("provider.remove", { id: p.id })) }, "Remove") : null,
          msg)));
  });
  return [
    header("Models & keys", "Chats run on a coding agent you already use (with its own sign-in), or on a model through your API key."),
    ...codingAgents(),
    group("API keys", h("div", { class: "set-row-help pad" }, "Your own keys pay for each provider's models.")),
    h("div", { class: "set-stack", dataset: { providers: "" } }, ...cards),
  ];
}

let accountsAskedAt = 0;
function codingAgents() {
  const list = state.engines ?? [];
  const es = state.engineSettings ?? { claude_lean: true, default_engine: "api" };
  // Who is signed in is read when this page opens (the programs' own status commands; free and quick).
  if (Date.now() - accountsAskedAt > 20_000) { accountsAskedAt = Date.now(); void reloadAccounts(true); }
  const setE = async (patch) => {
    try { const r = await state.client.call("engines.set", patch); nav.setEngines?.(r.engines, r.settings); }
    catch (e) { toast(e.message); }
  };
  // Check: every program is asked again at the same time. The cards say "Checking…" and fill in as each one answers.
  const refresh = async () => {
    if (checking.on) return;
    checking.on = true;
    checking.since = Date.now();
    rerender(true);
    try {
      const [r] = await Promise.all([state.client.call("engines.list", { refresh: true }), reloadAccounts(true)]);
      nav.setEngines?.(r.engines, r.settings);
      checking.on = false;
      rerender(true);
      const parts = (state.engines ?? []).map((e) => {
        if (!e.found) return `${e.label}: not installed`;
        const a = (state.accounts ?? []).find((x) => x.engine === e.id && x.active) ?? (state.accounts ?? []).find((x) => x.engine === e.id);
        return `${e.label}: ${a?.status?.signed_in ? "signed in" : "not signed in"}${e.models.length ? `, ${e.models.length} models` : ""}`;
      });
      toast(`Checked. ${parts.join(" · ")}`, 7000);
    } catch (e) { toast(e.message); }
    finally { if (checking.on) { checking.on = false; rerender(true); } }
  };
  // The programs are found by themselves; there is nothing to point at. Only behaviour switches remain under each account.
  const extras = (e) => [
    e.id === "codex" ? row("When one runs out, continue in the other", "If Claude Code or Codex hits its plan limit during a chat, the chat moves to the other one and carries on with the task record (plan, changed files, your messages). Normal chats only; at most one switch per message.", toggle(!!es.auto_switch, (on) => setE({ auto_switch: on }), "When one runs out, continue in the other")) : null,
    e.id === "claude-code" ? row("Lean mode", "Leaves out your Claude Code MCP servers. They add tens of thousands of tokens to every message; turn this off only if chats need them.", toggle(es.claude_lean, (on) => setE({ claude_lean: on }), "Lean mode")) : null,
  ];
  return [
    group("Coding agents",
      row("New chats start on", "You can change it per chat from the model button.", h("select", { class: "input select", "aria-label": "New chats start on", onchange: (ev) => setE({ default_engine: ev.target.value, default_model: "", default_effort: "" }) },
        ...[["api", "API key (Models below)"], ...list.map((e) => [e.id, e.label])].map(([id, label]) => h("option", { value: id, selected: es.default_engine === id }, label)))),
      row("Check again", "After installing, or signing in somewhere else.", h("button", { class: "btn btn-sm", type: "button", disabled: checking.on, "aria-busy": String(checking.on), onclick: refresh }, icon("reload", checking.on ? "icon spinning" : "icon"), checking.on ? "Checking…" : "Check"))),
    h("div", { class: "set-stack ac-stack" }, ...list.map((e) => engineCard(e, extras(e).filter(Boolean)))),
  ];
}

// ---- memory ---------------------------------------------------------------------------
const memUi = { filter: "all", scope: "all", query: "", editing: null, composing: false };

function memory() {
  const s = state.settings;
  const projects = state.workspaces;
  const scopeName = (id) => (id === "global" ? "Every project" : (projects.find((w) => w.id === id)?.name ?? "Removed project"));
  const q = memUi.query.trim().toLowerCase();
  const notes = state.notes.filter((n) =>
    (memUi.filter === "all" || (memUi.filter === "draft" ? n.state === "draft" : n.state === "kept")) &&
    (memUi.scope === "all" || n.scope === memUi.scope) &&
    (!q || `${n.title} ${n.body}`.toLowerCase().includes(q)));

  const scopeSelect = (value, onChange, withAll) => {
    const sel = h("select", { class: "input select", "aria-label": "Scope", onchange: () => onChange(sel.value) },
      withAll ? h("option", { value: "all" }, "All scopes") : null,
      h("option", { value: "global" }, "Every project"),
      ...projects.map((w) => h("option", { value: w.id }, w.name)));
    sel.value = value;
    return sel;
  };

  const form = (note) => {
    const title = h("input", { class: "input", placeholder: "Title (optional)", maxLength: 120, value: note?.title ?? "", "aria-label": "Note title" });
    const body = h("textarea", { class: "input textarea", rows: 3, maxLength: 2000, placeholder: "One fact, preference or gotcha, in a line", "aria-label": "Note text" }, note?.body ?? "");
    let scope = note?.scope ?? activeWorkspace()?.id ?? "global";
    const sel = scopeSelect(scope, (v) => (scope = v), false);
    const done = () => { memUi.editing = null; memUi.composing = false; rerender(); };
    const save = async () => {
      try {
        if (note) await state.client.call("memory.update", { id: note.id, title: title.value, body: body.value, scope });
        else await state.client.call("memory.add", { title: title.value || undefined, body: body.value, scope });
        done();
      } catch (e) { toast(e.message); }
    };
    return h("div", { class: "note note-form" }, title, body, h("div", { class: "note-actions" }, sel, h("span", { class: "grow" }),
      h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: done }, "Cancel"),
      h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: save }, note ? "Save" : "Add note")));
  };

  const card = (n) => {
    if (memUi.editing === n.id) return form(n);
    return h("div", { class: "note", dataset: { state: n.state, pinned: String(n.pinned) } },
      h("div", { class: "note-top" },
        n.title ? h("span", { class: "note-title" }, n.title) : null,
        h("span", { class: "badge", dataset: { kind: n.state === "draft" ? "warn" : "" } }, n.state === "draft" ? "Draft" : "Kept"),
        n.pinned ? h("span", { class: "badge" }, "Pinned") : null,
        h("span", { class: "grow" }),
        h("span", { class: "note-scope" }, scopeName(n.scope))),
      h("div", { class: "note-body" }, n.body),
      n.state === "draft" ? h("div", { class: "note-help" }, "Saved by an agent. It loads in chats only if you keep or pin it.") : null,
      h("div", { class: "note-actions" },
        n.state === "draft" ? h("button", { class: "btn btn-sm", type: "button", onclick: () => call("memory.update", { id: n.id, state: "kept" }) }, "Keep") : null,
        h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => call("memory.update", { id: n.id, pinned: !n.pinned }) }, n.pinned ? "Unpin" : "Pin"),
        h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { memUi.editing = n.id; rerender(); } }, "Edit"),
        h("span", { class: "grow" }),
        h("button", { class: "btn btn-ghost btn-sm danger", type: "button", onclick: () => call("memory.delete", { id: n.id }) }, "Forget")));
  };

  const search = h("input", { class: "input", placeholder: "Search notes", value: memUi.query, "aria-label": "Search notes" });
  search.addEventListener("input", () => { memUi.query = search.value; const pos = search.selectionStart; rerender(); const el = document.querySelector('[aria-label="Search notes"]'); el?.focus(); el?.setSelectionRange(pos, pos); });

  return [
    header("Memory", "Short notes agents read at the start of every chat."),
    group(null, row("Remember between chats", "When off, no notes are read and agents cannot save new ones.", toggle(s.memory_enabled, (on) => patch({ memory_enabled: on }), "Remember between chats"))),
    h("div", { class: s.memory_enabled ? "" : "dim" },
      h("div", { class: "set-toolbar" },
        segmented(memUi.filter, [["all", "All"], ["kept", "Kept"], ["draft", "Drafts"]], (f) => { memUi.filter = f; rerender(); }, "Note state"),
        scopeSelect(memUi.scope, (v) => { memUi.scope = v; rerender(); }, true),
        search,
        h("button", { class: "btn btn-sm", type: "button", onclick: () => { memUi.composing = true; memUi.editing = null; rerender(); } }, icon("plus"), "New note")),
      h("div", { class: "set-stack" },
        memUi.composing ? form(null) : null,
        ...notes.map(card),
        notes.length === 0 && !memUi.composing
          ? h("div", { class: "set-empty" }, h("strong", {}, state.notes.length ? "No notes match" : "Nothing remembered yet"), h("span", {}, state.notes.length ? "Try another filter." : "Tell an agent a preference, or add a note here."))
          : null)),
  ];
}

// ---- MCP ------------------------------------------------------------------------------------
const mcpUi = { open: new Set() };

function mcp() {
  const input = h("input", { class: "input mono", placeholder: "https://mcp.example.com/mcp  or  npx -y @acme/mcp-server", autocomplete: "off", spellcheck: false, "aria-label": "MCP server URL or command" });
  const name = h("input", { class: "input", placeholder: "Name (optional)", maxLength: 60, autocomplete: "off", "aria-label": "MCP server name" });
  const add = async () => {
    if (!input.value.trim()) return;
    try { await state.client.call("mcp.add", { input: input.value, ...(name.value.trim() ? { name: name.value.trim() } : {}) }); input.value = ""; name.value = ""; } catch (e) { toast(e.message); }
  };
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") void add(); });

  const STATE = { off: "Off", connecting: "Connecting…", ready: "Connected", error: "Failed" };
  const servers = state.mcp.map((sv) => {
    const open = mcpUi.open.has(sv.id);
    return h("div", { class: "srv", dataset: { state: sv.state } },
      h("div", { class: "srv-top" },
        h("span", { class: "dot", dataset: { state: sv.state === "ready" ? "ready" : sv.state === "error" ? "offline" : sv.state === "connecting" ? "connecting" : "" } }),
        h("button", { class: "srv-name", type: "button", "aria-expanded": String(open), onclick: () => { open ? mcpUi.open.delete(sv.id) : mcpUi.open.add(sv.id); rerender(); } }, sv.name, h("span", { class: "srv-count" }, sv.state === "ready" ? `${sv.tools.length} tool${sv.tools.length === 1 ? "" : "s"}` : STATE[sv.state])),
        h("span", { class: "grow" }),
        sv.enabled ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => call("mcp.refresh", { id: sv.id }) }, "Refresh") : null,
        toggle(sv.enabled, (on) => call("mcp.set_enabled", { id: sv.id, enabled: on }), `Enable ${sv.name}`),
        h("button", { class: "icon-btn", type: "button", title: `Remove ${sv.name}`, "aria-label": `Remove ${sv.name}`, onclick: () => call("mcp.remove", { id: sv.id }) }, icon("x"))),
      h("div", { class: "srv-target" }, sv.transport === "stdio" ? "Command · " : "URL · ", h("code", {}, sv.target)),
      sv.error ? h("div", { class: "srv-error" }, sv.error) : null,
      open ? h("div", { class: "srv-tools" }, ...(sv.tools.length ? sv.tools.map((t) => h("div", { class: "srv-tool" }, h("code", {}, t.name), h("span", {}, t.description))) : [h("div", { class: "note-help" }, "No tools listed.")])) : null);
  });

  return [
    header("MCP servers", "Give agents more tools. Every call asks for your approval first."),
    group("Add an MCP server",
      h("div", { class: "set-form" }, input, name, h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: add }, icon("plus"), "Add")),
      h("div", { class: "set-row-help pad" }, "Paste a URL, or the command that starts a local server. A command runs on this computer with your permissions — only add servers you trust.")),
    h("div", { class: "set-stack" }, ...servers, servers.length === 0 ? h("div", { class: "set-empty" }, h("strong", {}, "No MCP servers yet"), h("span", {}, "Added servers show here with the tools they offer.")) : null),
  ];
}

// ---- computer use -----------------------------------------------------------------------
const compUi = { apps: null, name: "", rule: "always" };

// While Accessibility is not on yet, check again every 2 s (the page flips to Granted as soon as the person turns it on).
let accessTimer = 0;
function watchAccess(on) {
  if (!on) { clearInterval(accessTimer); accessTimer = 0; return; }
  if (accessTimer) return;
  let n = 0;
  accessTimer = setInterval(async () => {
    if (++n > 90 || document.hidden) { if (n > 90) { clearInterval(accessTimer); accessTimer = 0; } return; }
    try {
      const { status } = await state.client.call("computer.status");
      if (status?.permissions?.accessibility === true && status?.permissions?.screen_recording !== false) { clearInterval(accessTimer); accessTimer = 0; state.computer = status; rerender(true); }
      else if (status && JSON.stringify(status.permissions) !== JSON.stringify(state.computer?.permissions)) { state.computer = status; rerender(true); }
    } catch { /* runtime busy */ }
  }, 2000);
}

function computer() {
  const c = state.computer;
  if (!c) return [header("Computer use", "Loading…")];
  if (!c.supported) return [header("Computer use", "Let agents use apps on this computer."), h("div", { class: "set-empty" }, h("strong", {}, "Not available here"), h("span", {}, "Computer use works on macOS only."))];

  const pill = (v, yes, no, unknown) => h("span", { class: `pill ${v === true ? "pill-ok" : v === false ? "pill-warn" : ""}` }, v === true ? yes : v === false ? no : unknown);
  const open = (pane) => call("computer.open_settings", { pane });
  // Accessibility: macOS's own prompt adds Opscode to the list; this page then checks every 2 s until it is on.
  const allow = async (pane = "accessibility") => { try { await state.client.call("computer.request_access", { pane }); toast(`Opscode was added fresh: turn it on in the ${pane === "screen" ? "Screen Recording" : "Accessibility"} list that opened.`); } catch (e) { toast(e.message); } };
  watchAccess(c.permissions.accessibility !== true || c.permissions.screen_recording === false);
  const name = h("input", { class: "input", placeholder: "App name, e.g. Notes", maxLength: 120, autocomplete: "off", spellcheck: false, value: compUi.name, "aria-label": "App name", oninput: (e) => { compUi.name = e.target.value; } });
  const add = async () => {
    const n = compUi.name.trim();
    if (!n) return;
    const known = (compUi.apps ?? []).find((a) => a.name.toLowerCase() === n.toLowerCase());
    try { await state.client.call("computer.rule.set", { name: n, bundle_id: known?.bundle_id ?? "", rule: compUi.rule }); compUi.name = ""; rerender(true); } catch (e) { toast(e.message); }
  };
  name.addEventListener("keydown", (e) => { if (e.key === "Enter") void add(); });
  const loadApps = async () => { try { compUi.apps = (await state.client.call("computer.apps")).apps; rerender(true); } catch (e) { toast(e.message); } };

  const rules = c.rules.map((r) =>
    h("div", { class: "srv", dataset: { rule: r.rule } },
      h("div", { class: "srv-top" },
        h("span", { class: "srv-name-static" }, r.name),
        h("span", { class: "grow" }),
        segmented(r.rule, [["always", "Always allow"], ["never", "Never"]], (v) => call("computer.rule.set", { name: r.name, bundle_id: r.bundle_id, rule: v }), `Rule for ${r.name}`),
        h("button", { class: "icon-btn", type: "button", title: `Remove rule for ${r.name}`, "aria-label": `Remove rule for ${r.name}`, onclick: () => call("computer.rule.remove", { id: r.id }) }, icon("x")))));

  return [
    header("Computer use", "Let agents see your screen and use apps on this Mac."),
    group(null,
      row("Let agents use apps on this Mac", "Off by default. Agents (chats, voice mode and the notch's On my Mac) read apps, click, type and press keys. Only risky steps ask you first: buying, paying, sending, deleting, submitting, quitting apps, or typing card numbers. Terminals, password managers and system prompts are never used. Hidden in read-only chats.", toggle(c.enabled, (on) => call("computer.set_enabled", { enabled: on }), "Let agents use apps on this Mac"))),
    group("Permissions",
      row("Accessibility", "Needed to read apps, click and type. Click Allow…: macOS adds Opscode to Privacy & Security → Accessibility and you turn it on there. If Opscode already shows as on there but this says Not granted, Allow… replaces that old entry with a fresh one. While developing it appears as “Electron”.", h("div", { class: "row-actions" }, pill(c.permissions.accessibility, "Granted", "Not granted", "Unknown"), c.permissions.accessibility === true ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => open("accessibility") }, "Open settings") : h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: allow }, "Allow…"))),
      row("Screen Recording", "Only needed when an agent takes a screenshot to see how something looks (reading and clicking apps does not need it). Click Allow…: macOS adds Opscode to the list and you turn it on there. If Opscode already shows as on but this says Not granted, Allow… replaces that old entry.", h("div", { class: "row-actions" }, pill(c.permissions.screen_recording, "Granted", "Not granted", "Unknown"), c.permissions.screen_recording === true ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => open("screen") }, "Open settings") : h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => allow("screen") }, "Allow…")))),
    group("Apps",
      h("div", { class: "set-form" }, name,
        segmented(compUi.rule, [["always", "Always allow"], ["never", "Never"]], (v) => { compUi.rule = v; rerender(true); }, "Rule"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: add }, icon("plus"), "Add")),
      h("div", { class: "set-row-help pad" }, "“Never” blocks an app completely. “Always allow” also skips the question for risky steps in that app, so use it only for apps you trust an agent with."),
      h("div", { class: "pad chips" },
        h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: loadApps }, compUi.apps ? "Refresh running apps" : "Pick from running apps"),
        ...(compUi.apps ?? []).map((a) => a.denied
          ? h("span", { class: "chip chip-off", title: "Off limits" }, a.name)
          : h("button", { class: "chip", type: "button", title: a.rule ? `Rule: ${a.rule}` : "Add a rule", onclick: () => { compUi.name = a.name; rerender(true); } }, a.name, a.rule ? ` · ${a.rule === "always" ? "allowed" : "blocked"}` : "")))),
    h("div", { class: "set-stack" }, ...rules, rules.length === 0 ? h("div", { class: "set-empty" }, h("strong", {}, "No app rules yet"), h("span", {}, "Every action will ask first.")) : null),
    group("Always off limits",
      h("div", { class: "set-row-help pad" }, "These can never be controlled, and cannot be allowed:"),
      h("ul", { class: "pad plain-list" }, ...c.denied.map((d) => h("li", {}, d))),
      h("div", { class: "set-row-help pad" }, "Screenshots capture the whole main display, not just the app in front, so close anything private first.")),
  ];
}

function keyboard() {
  const rows = [
    ["Command palette", `${MOD}K`], ["Hide or show sidebar", `${MOD}B`], ["Settings", `${MOD},`], ["New chat", `${MOD}N`],
    ["Chat view", `${MOD}1`], ["Files view", `${MOD}2`], ["Terminal view", `${MOD}3`], ["Send message", "Enter"], ["New line in message", "Shift Enter"], ["Close a dialog or the palette", "Esc"],
  ];
  return [header("Keyboard", "Shortcuts you can use anywhere in the app."), group(null, ...rows.map(([l, k]) => row(l, null, h("kbd", {}, k))))];
}


// ---- skills ---------------------------------------------------------------------------
const skillUi = { form: null }; // null | { name?: string, scope, description, body }

async function openFolderPreview(path) {
  let preview;
  try { ({ preview } = await state.client.call("plugin.preview", { path })); } catch (e) { toast(e.message); return; }
  const hasProject = !!activeWorkspace();
  let scope = "user";
  const list = (title, rows) => rows.length ? h("div", { class: "pv-block" }, h("div", { class: "pv-title" }, title), ...rows) : null;
  const sel = h("select", { class: "input select", "aria-label": "Import skills into", onchange: (e) => (scope = e.target.value) },
    h("option", { value: "user" }, "Personal (just me)"), hasProject ? h("option", { value: "project" }, `Project: ${activeWorkspace().name}`) : null);
  const run = async (fn, okText) => {
    try { await fn(); closeDialog(); toast(okText); } catch (e) { toast(e.message); }
  };
  const actions = {
    plugin: () => h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => run(() => state.client.call("plugin.install", { path }), `Installed ${preview.name}`) }, "Install plugin"),
    marketplace: () => h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => run(() => state.client.call("marketplace.add", { path }), `Added ${preview.name}`) }, "Add marketplace"),
    skills: () => h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => run(() => state.client.call("skill.import", { path, scope, ...(scope === "project" ? { workspace_id: state.active } : {}) }), "Skills imported") }, "Import skills"),
  };
  const kindText = { plugin: "Plugin", marketplace: "Marketplace", skills: "Folder of skills" };
  showDialog(h("div", { class: "dialog dialog-wide", role: "dialog", "aria-modal": "true", "aria-label": "What this brings" },
    h("div", { class: "dialog-head" }, h("h2", {}, `${kindText[preview.kind]}: ${preview.name}`), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: closeDialog }, icon("x"))),
    h("div", { class: "dialog-body" },
      preview.description ? h("p", { class: "field-help", style: "margin:0;font-size:13px" }, preview.description + (preview.version ? ` · v${preview.version}` : "")) : null,
      h("p", { class: "field-help", style: "margin:0" }, "This is everything it would bring in. Nothing is installed until you confirm."),
      list(`Skills (${preview.skills.length})`, preview.skills.map((x) => h("div", { class: "pv-row" }, h("code", {}, x.name), h("span", {}, x.description)))),
      list(`MCP servers (${preview.mcp_servers.length})`, preview.mcp_servers.map((x) => h("div", { class: "pv-row" }, h("code", {}, x.name), h("span", { class: x.transport === "stdio" ? "pv-warn" : "" }, x.transport === "stdio" ? `Runs a program on this computer: ${x.target}` : x.target)))),
      list(`Plugins (${preview.plugins.length})`, preview.plugins.map((x) => h("div", { class: "pv-row" }, h("code", {}, x.name), h("span", {}, x.description)))),
      preview.warnings.length ? h("div", { class: "pv-block" }, h("div", { class: "pv-title" }, "Notes"), ...preview.warnings.map((w) => h("div", { class: "pv-row" }, h("span", {}, w)))) : null,
      preview.mcp_servers.some((x) => x.transport === "stdio") ? h("p", { class: "pv-warn", style: "margin:0;font-size:12.5px" }, "Programs run with your permissions. Only install plugins you trust.") : null,
      h("div", { class: "dialog-foot" }, preview.kind === "skills" ? sel : null, h("span", { class: "grow" }), h("button", { class: "btn btn-sm", type: "button", onclick: closeDialog }, "Cancel"), actions[preview.kind]()))));
}

export async function chooseFolder() {
  const path = await state.bridge?.pickFolder();
  if (path) await openFolderPreview(path);
}

function skills() {
  const ws = activeWorkspace();
  const f = skillUi.form;
  const mine = state.skills.filter((x) => x.scope === "user");
  const proj = state.skills.filter((x) => x.scope === "project");
  const plug = state.skills.filter((x) => x.scope === "plugin");

  const form = () => {
    const name = h("input", { class: "input mono", placeholder: "release-notes", value: f.name ?? "", disabled: f.editing || undefined, maxLength: 64, autocomplete: "off", spellcheck: false, "aria-label": "Skill name" });
    const desc = h("input", { class: "input", placeholder: "When to use it, in one line", value: f.description, maxLength: 300, "aria-label": "When to use it" });
    const body = h("textarea", { class: "input textarea", rows: 8, placeholder: "The steps, as you would tell a new teammate", "aria-label": "Skill steps" }, f.body);
    const scope = h("select", { class: "input select", "aria-label": "Skill scope", disabled: f.editing || undefined, onchange: (e) => (f.scope = e.target.value) },
      h("option", { value: "user", selected: f.scope === "user" }, "Personal (just me)"),
      ws ? h("option", { value: "project", selected: f.scope === "project" }, `Project: ${ws.name} (saved in .opscode/skills)`) : null);
    const save = async () => {
      try {
        await state.client.call("skill.save", { scope: f.scope, ...(f.scope === "project" ? { workspace_id: ws?.id } : {}), name: name.value.trim(), description: desc.value, body: body.value });
        skillUi.form = null;
        rerender(true);
      } catch (e) { toast(e.message); }
    };
    return h("div", { class: "note note-form" },
      h("label", { class: "field" }, h("span", { class: "field-label" }, "Name"), name, h("span", { class: "field-help" }, "Lowercase letters, digits and dashes. Run it in a chat by typing / and the name.")),
      h("label", { class: "field" }, h("span", { class: "field-label" }, "When to use it"), desc),
      h("label", { class: "field" }, h("span", { class: "field-label" }, "Steps"), body),
      h("div", { class: "note-actions" }, scope, h("span", { class: "grow" }),
        h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { skillUi.form = null; rerender(true); } }, "Cancel"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: save }, "Save skill")));
  };

  const edit = async (sk) => {
    try {
      const { body } = await state.client.call("skill.read", { name: sk.name, ...(ws ? { workspace_id: ws.id } : {}) });
      skillUi.form = { editing: true, name: sk.name, scope: sk.scope, description: sk.description, body };
      rerender(true);
    } catch (e) { toast(e.message); }
  };
  const del = async (sk) => {
    if (!(await confirmDialog({ title: `Delete “${sk.name}”?`, body: sk.scope === "project" ? "This removes the SKILL.md from the project's .opscode/skills folder." : "This removes the skill from this computer.", confirm: "Delete skill", danger: true }))) return;
    try { await state.client.call("skill.delete", { scope: sk.scope, ...(sk.scope === "project" ? { workspace_id: ws?.id } : {}), name: sk.name }); } catch (e) { toast(e.message); }
  };
  const row = (sk, editable) => h("div", { class: "note", dataset: { skill: sk.name } },
    h("div", { class: "note-top" }, h("code", { class: "note-title" }, sk.name), sk.plugin ? h("span", { class: "badge" }, sk.plugin) : null, h("span", { class: "grow" })),
    h("div", { class: "note-body" }, sk.description || "No description."),
    editable ? h("div", { class: "note-actions" },
      h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => edit(sk) }, "Edit"), h("span", { class: "grow" }),
      h("button", { class: "btn btn-ghost btn-sm danger", type: "button", onclick: () => del(sk) }, "Delete")) : null);
  const section = (title, items, editable, empty) => h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, title),
    h("div", { class: "set-stack" }, ...(items.length ? items.map((x) => row(x, editable)) : [h("div", { class: "set-empty" }, h("span", {}, empty))])));

  return [
    header("Skills", "Reusable steps an agent follows when a task matches. Type / in a chat to run one."),
    h("div", { class: "set-toolbar" },
      h("button", { class: "btn btn-sm", type: "button", onclick: () => { skillUi.form = { scope: ws ? "project" : "user", description: "", body: "" }; rerender(true); } }, icon("plus"), "New skill"),
      h("button", { class: "btn btn-sm", type: "button", onclick: chooseFolder }, "Import a folder…")),
    f ? form() : null,
    section("Personal", mine, true, "No personal skills yet."),
    ws ? section(`Project: ${ws.name}`, proj, true, "No project skills. Add one and it is saved in the project, ready to commit.") : null,
    plug.length ? section("From plugins", plug, false, "") : null,
  ];
}

// ---- sub-agents -------------------------------------------------------------------------
const agentUi = { form: null }; // null | { editing?, name?, scope, description, access, body }
const ACCESS = [["read", "Read files"], ["edit", "Read and edit"], ["full", "Edit and run commands"]];

function agents() {
  const ws = activeWorkspace();
  const f = agentUi.form;
  const by = (scope) => state.agents.filter((x) => x.scope === scope);

  const form = () => {
    const name = h("input", { class: "input mono", placeholder: "code-reviewer", value: f.name ?? "", disabled: f.editing || undefined, maxLength: 64, autocomplete: "off", spellcheck: false, "aria-label": "Agent name" });
    const desc = h("input", { class: "input", placeholder: "When to hand it a task, in one line", value: f.description, maxLength: 300, "aria-label": "When to use it" });
    const body = h("textarea", { class: "input textarea", rows: 8, placeholder: "Its instructions, as you would brief a new teammate", "aria-label": "Agent instructions" }, f.body);
    const scope = h("select", { class: "input select", "aria-label": "Agent scope", disabled: f.editing || undefined, onchange: (e) => (f.scope = e.target.value) },
      h("option", { value: "user", selected: f.scope === "user" }, "Personal (just me)"),
      ws ? h("option", { value: "project", selected: f.scope === "project" }, `Project: ${ws.name} (saved in .opscode/agents)`) : null);
    const save = async () => {
      try {
        await state.client.call("subagent.save", { scope: f.scope, ...(f.scope === "project" ? { workspace_id: ws?.id } : {}), name: name.value.trim(), description: desc.value, access: f.access, body: body.value });
        agentUi.form = null;
        rerender(true);
      } catch (e) { toast(e.message); }
    };
    return h("div", { class: "note note-form" },
      h("label", { class: "field" }, h("span", { class: "field-label" }, "Name"), name, h("span", { class: "field-help" }, "Lowercase letters, digits and dashes. The main agent hands it tasks by this name.")),
      h("label", { class: "field" }, h("span", { class: "field-label" }, "When to use it"), desc),
      h("div", { class: "field" }, h("span", { class: "field-label" }, "The most it may do"), segmented(f.access, ACCESS, (v) => { f.access = v; rerender(true); }, "Access"),
        h("span", { class: "field-help" }, "Anything it edits or runs still asks you first, and the chat's own permission mode still applies: a read-only chat never lets it change anything.")),
      h("label", { class: "field" }, h("span", { class: "field-label" }, "Instructions"), body),
      h("div", { class: "note-actions" }, scope, h("span", { class: "grow" }),
        h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { agentUi.form = null; rerender(true); } }, "Cancel"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: save }, "Save agent")));
  };

  const edit = async (a) => {
    try {
      const { body } = await state.client.call("subagent.read", { name: a.name, ...(ws ? { workspace_id: ws.id } : {}) });
      agentUi.form = { editing: true, name: a.name, scope: a.scope, description: a.description, access: a.access, body };
      rerender(true);
    } catch (e) { toast(e.message); }
  };
  const del = async (a) => {
    if (!(await confirmDialog({ title: `Delete “${a.name}”?`, body: a.scope === "project" ? "This removes the file from the project's .opscode/agents folder." : "This removes the agent from this computer.", confirm: "Delete agent", danger: true }))) return;
    try { await state.client.call("subagent.delete", { scope: a.scope, ...(a.scope === "project" ? { workspace_id: ws?.id } : {}), name: a.name }); } catch (e) { toast(e.message); }
  };
  const label = (acc) => ACCESS.find((x) => x[0] === acc)?.[1] ?? acc;
  const rowOf = (a, editable) => h("div", { class: "note", dataset: { agent: a.name } },
    h("div", { class: "note-top" }, h("code", { class: "note-title" }, a.name), h("span", { class: "pill" }, label(a.access)), h("span", { class: "grow" })),
    h("div", { class: "note-body" }, a.description),
    editable ? h("div", { class: "note-actions" },
      h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => edit(a) }, "Edit"), h("span", { class: "grow" }),
      h("button", { class: "btn btn-ghost btn-sm danger", type: "button", onclick: () => del(a) }, "Delete")) : null);
  const section = (title, items, editable, empty) => h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, title),
    h("div", { class: "set-stack" }, ...(items.length ? items.map((x) => rowOf(x, editable)) : [h("div", { class: "set-empty" }, h("span", {}, empty))])));

  return [
    header("Sub-agents", "Named helpers the main agent can hand a task to. Each works on its own and reports back, so the chat stays focused."),
    h("div", { class: "set-toolbar" },
      h("button", { class: "btn btn-sm", type: "button", onclick: () => { agentUi.form = { scope: ws ? "project" : "user", description: "", access: "read", body: "" }; rerender(true); } }, icon("plus"), "New agent")),
    f ? form() : null,
    section("Personal", by("user"), true, "No personal agents yet."),
    ws ? section(`Project: ${ws.name}`, by("project"), true, "No project agents. Add one and it is saved in the project, ready to commit.") : null,
    section("Built in", by("builtin"), false, ""),
  ];
}

// ---- plugins ----------------------------------------------------------------------------
function plugins() {
  const installed = state.plugins.map((p) => h("div", { class: "srv", dataset: { plugin: p.id } },
    h("div", { class: "srv-top" },
      h("span", { class: "srv-name" }, p.name, h("span", { class: "srv-count" }, `v${p.version}`)),
      h("span", { class: "grow" }),
      h("button", { class: "btn btn-ghost btn-sm danger", type: "button", onclick: async () => {
        if (!(await confirmDialog({ title: `Uninstall ${p.name}?`, body: "Its skills and MCP servers stop loading, and its files are removed from this computer.", confirm: "Uninstall", danger: true }))) return;
        try { await state.client.call("plugin.uninstall", { id: p.id }); } catch (e) { toast(e.message); }
      } }, "Uninstall"),
      toggle(p.enabled, (on) => call("plugin.set_enabled", { id: p.id, enabled: on }), `Enable ${p.name}`)),
    p.description ? h("div", { class: "srv-target" }, p.description) : null,
    h("div", { class: "srv-target" }, `${p.skills.length} skill${p.skills.length === 1 ? "" : "s"} · ${p.mcp_servers.length} MCP server${p.mcp_servers.length === 1 ? "" : "s"}`, p.skills.length ? ` · ${p.skills.join(", ")}` : "")));

  const markets = state.marketplaces.map((m) => h("div", { class: "srv", dataset: { market: m.id } },
    h("div", { class: "srv-top" }, h("span", { class: "srv-name" }, m.name), h("span", { class: "grow" }),
      h("button", { class: "icon-btn", type: "button", title: `Remove ${m.name}`, "aria-label": `Remove ${m.name}`, onclick: () => call("marketplace.remove", { id: m.id }) }, icon("x"))),
    h("div", { class: "srv-target" }, h("code", {}, m.path)),
    m.error ? h("div", { class: "srv-error" }, m.error) : null,
    h("div", { class: "srv-tools" }, ...m.plugins.map((p) => h("div", { class: "srv-tool" }, h("code", {}, p.name), h("span", {}, p.description),
      p.installed ? h("span", { class: "badge" }, "Installed") : h("button", { class: "btn btn-sm", type: "button", onclick: () => openFolderPreview(p.path) }, "Install…"))))));

  return [
    header("Plugins", "Bundles of skills and MCP servers. You see what a plugin brings before anything is installed."),
    h("div", { class: "set-toolbar" },
      h("button", { class: "btn btn-sm", type: "button", onclick: chooseFolder }, icon("plus"), "Import a folder…"),
      h("span", { class: "field-help" }, "A plugin, a marketplace, or a folder of skills.")),
    h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, "Installed"),
      h("div", { class: "set-stack" }, ...installed, installed.length === 0 ? h("div", { class: "set-empty" }, h("strong", {}, "No plugins yet"), h("span", {}, "Install one from a marketplace, or import a folder.")) : null)),
    h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, "Marketplaces"),
      h("div", { class: "set-stack" }, ...markets, markets.length === 0 ? h("div", { class: "set-empty" }, h("span", {}, "No marketplaces. Import a folder that has a .claude-plugin/marketplace.json.")) : null)),
  ];
}

// ---- import ---------------------------------------------------------------------------------
const impUi = { data: null, picked: new Set(), result: null, loading: false, busy: false };
const KIND = { mcp: "MCP server", skill: "Skill", note: "Instructions" };

async function impScan() {
  impUi.loading = true;
  try { impUi.data = await state.client.call("import.scan"); impUi.picked = new Set([...impUi.picked].filter((id) => impUi.data.items.some((i) => i.id === id && !i.exists && !i.blocked))); }
  catch (e) { toast(e.message); impUi.data = { sources: [], items: [] }; }
  impUi.loading = false;
  rerender(true);
}

function importPage() {
  const d = impUi.data;
  if (!d) { if (!impUi.loading) void impScan(); return [header("Import", "Bring your setup from other coding tools."), h("div", { class: "set-empty" }, h("span", {}, "Looking…"))]; }
  const canPick = (i) => !i.exists && !i.blocked;
  const rows = (src) => d.items.filter((i) => i.source === src.id).map((i) =>
    h("label", { class: `imp-row${canPick(i) ? "" : " imp-off"}`, dataset: { id: i.id } },
      h("input", { type: "checkbox", disabled: !canPick(i), checked: impUi.picked.has(i.id), "aria-label": `Import ${i.title}`, onchange: (e) => { if (e.target.checked) impUi.picked.add(i.id); else impUi.picked.delete(i.id); rerender(true); } }),
      h("div", { class: "imp-main" },
        h("div", { class: "imp-top" }, h("span", { class: "imp-title" }, i.title), h("span", { class: "pill" }, KIND[i.kind]), i.exists ? h("span", { class: "pill pill-ok" }, "Already here") : null),
        h("div", { class: "set-row-help" }, i.detail),
        i.warn ? h("div", { class: "pv-warn" }, i.warn) : null,
        i.blocked ? h("div", { class: "pv-warn" }, `Can't import: ${i.blocked}`) : null)));
  const groups = d.sources.map((src) => {
    const r = rows(src);
    return group(src.label,
      r.length ? h("div", { class: "imp-list" }, ...r)
        : h("div", { class: "set-row-help pad" }, src.found ? `Nothing to import from ${src.path}.` : `${src.label} was not found (${src.path}).`));
  });
  const newIds = d.items.filter(canPick).map((i) => i.id);
  const run = async () => {
    impUi.busy = true; rerender(true);
    try {
      const r = await state.client.call("import.run", { ids: [...impUi.picked] });
      impUi.result = r; impUi.data = { ...impUi.data, items: r.items }; impUi.picked = new Set();
    } catch (e) { toast(e.message); }
    impUi.busy = false; rerender(true);
  };
  const res = impUi.result;
  return [
    header("Import", "Bring MCP servers, skills and instructions from Claude Code, Codex and Cursor."),
    h("div", { class: "set-row-help pad" }, "Nothing is changed in the other apps. Secrets (environment values, headers, tokens) are never copied, and imported MCP servers start switched off until you turn them on."),
    ...groups,
    h("div", { class: "set-form" },
      h("button", { class: "btn btn-ghost btn-sm", type: "button", disabled: newIds.length === 0, onclick: () => { impUi.picked = new Set(newIds); rerender(true); } }, "Select all new"),
      h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => { impUi.result = null; void impScan(); } }, "Rescan"),
      h("span", { class: "grow" }),
      h("button", { class: "btn btn-primary btn-sm", type: "button", disabled: impUi.picked.size === 0 || impUi.busy, onclick: run }, impUi.busy ? "Importing…" : `Import ${impUi.picked.size || ""}`.trim())),
    res ? group("Result", ...res.imported.map((x) => h("div", { class: "set-row-help pad" }, `✓ ${x.id.split(":").slice(2).join(":")} — ${x.detail}`)), ...res.skipped.map((x) => h("div", { class: "pv-warn pad" }, `Skipped ${x.id.split(":").slice(2).join(":")} — ${x.reason}`))) : null,
  ];
}

function devices() {
  const api = state.bridge?.mobile;
  const list = h("div", { class: "set-card" });
  const relay = h("div", { class: "set-card" });
  const error = h("p", { class: "set-row-help mobile-devices-error", role: "status" });
  let snapshot;
  let busy = false;
  const button = (label, action, primary = false) => h("button", {
    type: "button", class: `btn ${primary ? "btn-primary" : "btn-ghost"} btn-sm`, disabled: busy, onclick: action,
  }, label);
  const run = async (action, pending = "") => {
    if (busy) return;
    busy = true;
    error.textContent = pending;
    draw();
    try { snapshot = await action(); error.textContent = ""; }
    catch (e) { error.textContent = e.message.replace(/^Error invoking remote method '[^']+': Error: /, ""); }
    finally { busy = false; draw(); }
  };
  function draw() {
    if (!snapshot) {
      list.replaceChildren(row("No devices connected", api ? "Pairing is available in the macOS app while Opscode is running." : "", null));
      return;
    }
    const devices = snapshot.devices;
    list.replaceChildren(...(devices.length ? devices.map((device) => {
      const when = device.pairedAt ? new Date(device.pairedAt).toLocaleDateString() : "";
      return row(device.name, `Android${when ? " · Paired " + when : ""}`,
        h("div", { class: "row-actions mobile-device-actions" },
          h("span", { class: `pill ${device.connected ? "pill-ok" : "mobile-device-offline"}` },
            device.connected ? "✓ Connected" : "Offline"),
          button("Remove", async () => {
            if (await confirmDialog({ title: `Remove ${device.name}?`, body: "This phone will need a new QR to reconnect.", confirm: "Remove device", danger: true })) {
              await run(() => api.revoke(device.id));
            }
          })));
    }) : [row("No paired devices", "Scan the QR on Android to pair this Mac.", null)]));
    const relayStatus = snapshot.relay === "online" ? "relay.shotlin.in · Online"
      : snapshot.relay === "connecting" ? "Connecting to relay.shotlin.in…"
        : "The Mac’s relay credential is unavailable.";
    relay.replaceChildren(row("Opscode relay", relayStatus,
      button("Show pairing QR", () => run(api.pair, "Creating pairing QR…"), true)));
  }
  let signature;
  const refresh = async () => {
    if (!list.isConnected || !api) return;
    try {
      if (!busy) {
        const next = await api.status();
        const key = JSON.stringify(next);
        if (!busy && key !== signature) { snapshot = next; signature = key; draw(); }
      }
    } catch { /* A subsequent refresh can reconnect. */ }
    setTimeout(refresh, 2500);
  };
  draw();
  setTimeout(refresh, 0);
  return [
    header("Devices", "Pair Android phones to review Mac activity and approve tasks."),
    h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, "Pair a device"), relay),
    h("section", { class: "set-group" }, h("h3", { class: "set-group-title" }, "Paired devices"), list),
    error,
  ];
}

const BUILDERS = { general, devices, appearance, models, memory, mcp, skills, agents, plugins, computer, import: importPage, keyboard };

// ---- page -----------------------------------------------------------------------------------
let host = null;
let deferred = false;

export function createSettingsPage() {
  host = h("div", { class: "settings pane-surface" });
  host.addEventListener("focusout", () => { if (deferred) setTimeout(() => { if (!host.contains(document.activeElement)) rerender(); }, 0); });
  return host;
}

export function rerender(force = false) {
  if (!host || host.hidden) return;
  const active = document.activeElement;
  const typing = host.contains(active) && (active.tagName === "INPUT" || active.tagName === "TEXTAREA") && (active.value ?? "") !== "" && !force;
  if (typing && active.getAttribute("aria-label") !== "Search notes") { deferred = true; return; }
  deferred = false;
  const scroller = host.querySelector(".settings-scroll");
  const top = scroller?.scrollTop ?? 0;
  const open = new Set([...host.querySelectorAll("details[open]")].map((d) => d.dataset.provider));
  const build = BUILDERS[state.section] ?? general;
  const content = state.settings ? build() : [h("p", { class: "set-row-help", role: "status" }, "Loading settings…")];
  host.replaceChildren(h("div", { class: "settings-scroll" }, h("div", { class: "settings-col", dataset: { section: state.section } }, ...content)));
  for (const d of host.querySelectorAll("details")) if (open.has(d.dataset.provider)) d.open = true;
  host.querySelector(".settings-scroll").scrollTop = top;
}

// =====================================================================================
// Skills + Plugins
// =====================================================================================

const voiceLanguageNames = new Intl.DisplayNames(["en"], { type: "language" });
const voiceLanguageName = (id) => { try { return voiceLanguageNames.of(id) ?? id; } catch { return id; } };

function languageOptions(ids, current, autoLabel) {
  const list = [...new Set([...ids, ...(current === "auto" ? [] : [current])])];
  list.sort((a, b) => voiceLanguageName(a).localeCompare(voiceLanguageName(b)));
  return [
    h("option", { value: "auto", selected: current === "auto" }, autoLabel),
    ...list.map((id) => h("option", { value: id, selected: id === current }, voiceLanguageName(id))),
  ];
}

function modelControl(key, label) {
  const status = h("div", { class: "set-row-help", dataset: { [key]: "status" } }, "Checking…");
  const action = h("button", { class: "btn btn-sm", type: "button", dataset: { [key]: "action" }, disabled: true }, "…");
  const refresh = async () => {
    try {
      const st = await state.client.call(`${key}.status`, {});
      const mb = Math.round((st.download_bytes ?? 0) / 1e6);
      action.disabled = true;
      if (st.available === false) {
        status.textContent = st.error || "The local voice runtime is unavailable.";
        action.textContent = "Unavailable";
        return;
      }
      if (st.installing) {
        status.textContent = `Downloading… ${Math.round(st.installing.progress * 100)}%`;
        action.textContent = "Downloading…";
        return;
      }
      status.textContent = st.installed ? `Installed · ${mb} MB · runs on this computer`
        : st.install_error ? `Download failed. ${st.install_error}` : `One-time download · ${mb} MB · runs on this computer`;
      action.textContent = st.installed ? "Remove model" : `Download ${mb} MB`;
      action.disabled = false;
      action.onclick = async () => {
        action.disabled = true;
        try { await state.client.call(`${key}.${st.installed ? "remove" : "install"}`, {}); }
        catch (e) { toast(e.message); }
        void refresh();
      };
    } catch (e) {
      status.textContent = e.message;
      action.textContent = "Unavailable";
      action.disabled = true;
    }
  };
  const listener = (e) => {
    if (!status.isConnected) { window.removeEventListener(`opscode:${key}`, listener); return; }
    if (e.detail?.ev === "install") void refresh();
  };
  window.addEventListener(`opscode:${key}`, listener);
  void refresh();
  return row(label, status, action);
}

function voiceRows(s) {
  const inputLanguage = s.voice_locale ?? "auto";
  const input = h("select", { class: "input select", "aria-label": "Microphone language", onchange: (e) => void patch({ voice_locale: e.target.value }) },
    ...languageOptions(["en", "hi"], inputLanguage, "Auto detect"));
  void state.client.call("voice.locales", {}).then((r) => {
    const base = inputLanguage.split("-")[0];
    const current = r.speech.includes(base) ? base : inputLanguage;
    input.replaceChildren(...languageOptions(r.speech, current, "Auto detect"));
  }).catch(() => {});

  const outputLanguage = s.tts_locale ?? "auto";
  const output = h("select", { class: "input select", "aria-label": "Spoken reply language", onchange: (e) => void patch({ tts_locale: e.target.value }) },
    ...languageOptions(["en", "hi"], outputLanguage, "Auto · follow the reply"));
  const voice = h("select", { class: "input select", "aria-label": "Speaking voice", onchange: (e) => void patch({ tts_voice: e.target.value }) },
    h("option", { value: "auto" }, "Automatic"));
  const speed = h("select", { class: "input select", "aria-label": "Read-aloud speed", onchange: (e) => void patch({ tts_speed: Number(e.target.value) }) },
    ...[1, 1.25, 1.5, 1.75].map((v) => h("option", { value: String(v), selected: v === (s.tts_speed ?? 1) }, `${v}×`)));
  void state.client.call("tts.status", {}).then((st) => {
    output.replaceChildren(...languageOptions(st.languages, outputLanguage, "Auto · follow the reply"));
    const languages = outputLanguage === "auto" ? st.languages : [outputLanguage];
    voice.append(...languages.map((language) => h("optgroup", { label: voiceLanguageName(language) },
      ...st.voices.filter((v) => v.language === language).map((v) => h("option", { value: v.id, selected: v.id === s.tts_voice }, v.name)))));
  }).catch(() => {});

  return [
    modelControl("voice", "Whisper Large-v3 Turbo Q5"),
    row("Microphone language", "Used for dictation, voice notes, and Voice Mode. Auto detects the spoken language.", input),
    modelControl("tts", "Kitten TTS 2 Mini"),
    row("Spoken reply language", "Voice Mode answers in this language. Auto follows what you speak.", output),
    row("Speaking voice", "Default voice for each language. The Agent voice picker can set a separate voice for Voice Mode.", voice),
    row("Read-aloud speed", "Playback speed for chat replies.", speed),
  ];
}
