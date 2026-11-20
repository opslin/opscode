// Renderer entry. Builds the shell once, then wires state -> views.
// Talks to main through window.opscode (IPC) and to the runtime over the
// WebSocket session (RPC).

import { connectRuntime } from "./rpc.js";
import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, subscribe, notify, activeWorkspace, writePref, toast, nav } from "./store.js";
import { createSettingsPage, rerender as rerenderSettings, SECTIONS } from "./settings.js";
import { createChat } from "./chat.js";
import { createPanel, SURFACES as TOOLS } from "./panel.js";
import { createReviewPage, createAutomationsPage } from "./pages.js";
import { createPluginsPage } from "./plugins.js";
import { createUsagePage, lowestLeft } from "./usage.js";
import { createLibraryPage } from "./library.js";
import { MODE_INFO, MODE_ORDER, modeEmblem, openModePicker } from "./conductor.js";
import { createChiefPage, mascot, mascotOf } from "./chief.js";
import { CHIEF_NAME, chiefLabel } from "./names.js";
import { chiefViews, createProjects, noteActive, revealMode, setAllOpen, setProjectOpen } from "./sidebar.js";
import { openPalette, closeDialog, confirmDialog } from "./dialogs.js";
import { openMenu } from "./popover.js";
import { installFileLinks } from "./filelinks.js";
import * as accountsUi from "./accounts.js";

const bridge = state.bridge;
const isMac = (bridge?.runtime?.platform ?? navigator.platform).toLowerCase().includes("darwin") || /mac/i.test(navigator.platform);
if (isMac) document.documentElement.classList.add("mac");

// ---- shell skeleton ---------------------------------------------------------
const sidebar = h("aside", { class: "sidebar", "aria-label": "Sidebar" });
const paneHeader = h("div", { class: "pane-header drag" });
const paneBody = h("div", { class: "pane-body" });
const paneRow = h("div", { class: "pane-row" }, paneBody);
const card = h("div", { class: "panel-card", "data-focus-area": "page" }, paneHeader, paneRow);
const frame = h("main", { class: "panel-frame" }, card);
document.getElementById("root").replaceChildren(h("div", { class: "window-shell" }, sidebar, frame));

const settingsPage = createSettingsPage();
settingsPage.hidden = true;
paneBody.append(settingsPage);
const pluginsPage = createPluginsPage();
const reviewPage = createReviewPage({ openChanges: (wid) => { state.active = wid; state.page = "app"; notify(); viewsFor(activeWorkspace()).panel.open("diff"); } });
/** Opens a chat: an existing one by id, or a new one in a project with a message ready to send. */
function openChat(wid, draft, chatId) {
  if (chatId) {
    const c = state.chats.find((x) => x.id === chatId);
    if (!c) { toast("That chat is gone."); return; }
    state.page = "app";
    selectChat(chatId);
    return;
  }
  state.active = wid;
  state.page = "app";
  state.chatSel[wid] = "new";
  notify();
  const view = selectedChat(activeWorkspace());
  if (draft) view.setDraft(draft);
}
const automationsPage = createAutomationsPage({ openChat });
const usagePage = createUsagePage();
const libraryPage = createLibraryPage({ bridge });
const sidebarToggle = () => h("button", { class: "pane-toggle no-drag", type: "button", title: "Show sidebar (⌘B)", "aria-label": "Show sidebar", hidden: !state.collapsed, onclick: toggleSidebar }, icon("panel-left"));
const chiefPage = createChiefPage({ openChat, onHeader: (nodes) => { if (state.page === "chief") paneHeader.replaceChildren(sidebarToggle(), ...nodes); } });
for (const p of [pluginsPage, reviewPage, automationsPage, libraryPage, usagePage, chiefPage]) { p.el.hidden = true; paneBody.append(p.el); }
const PAGES = { plugins: { label: "Plugins", icon: "grid", view: pluginsPage }, review: { label: "Review", icon: "diff", view: reviewPage }, automations: { label: "Automations", icon: "zap", view: automationsPage }, library: { label: "Library", icon: "layers", view: libraryPage }, usage: { label: "Usage", icon: "gauge", view: usagePage }, chief: { label: CHIEF_NAME.one, icon: "users", view: chiefPage } };
// Managers (internally Chiefs) and mode chats: profiles and how many items need you, per one.
state.chiefs = [];
const chiefNeeds = new Map();
function openChief(id) {
  closeDialog();
  state.page = "chief";
  state.chiefSel = id;
  notify();
  void chiefPage.show(id);
}
async function newChief() {
  try {
    const n = state.chiefs.filter((c) => !c.mode).length;
    const { chief } = await state.client.call("chief.create", { name: n ? `${CHIEF_NAME.one} ${n + 1}` : CHIEF_NAME.one });
    state.chiefs = [...state.chiefs.filter((c) => c.id !== chief.id), chief];
    openChief(chief.id);
  } catch (e) { toast(e.message); }
}
/** Start a Conductor (GODMODE / WARLORD / SHINOBI) for the active project. Normal chat does not come through here. */
async function startConductor(mode) {
  const ws = activeWorkspace();
  if (!ws) return void addProject();
  try {
    const { chief } = await state.client.call("chief.create", { mode, project_id: ws.id });
    state.chiefs = [...state.chiefs.filter((c) => c.id !== chief.id), chief];
    setProjectOpen(ws.id, true);
    openChief(chief.id);
  } catch (e) { toast(e.message); }
}
/** The new-chat box was in a mode: start that Conductor in `ws`, open it, and send it the first message. Throws on failure. */
async function startModeChat(ws, mode, text, files = []) {
  const { chief } = await state.client.call("chief.create", { mode, project_id: ws.id });
  state.chiefs = [...state.chiefs.filter((c) => c.id !== chief.id), chief];
  setProjectOpen(ws.id, true);
  closeDialog();
  state.page = "chief";
  state.chiefSel = chief.id;
  notify();
  await chiefPage.show(chief.id);
  await chiefPage.sendFirst(text, files);
}
function chooseHowToWork() {
  const ws = activeWorkspace();
  if (!ws) return void addProject();
  openModePicker({ project: ws.name, onPick: (m) => (m ? void startConductor(m) : newChat()) });
}
async function loadChiefs() {
  try {
    state.chiefs = (await state.client.call("chief.list")).chiefs;
    for (const c of state.chiefs) {
      const v = await state.client.call("chief.get", { chief_id: c.id }).catch(() => null);
      if (v) { chiefViews.set(c.id, v); chiefNeeds.set(c.id, v.items.filter((i) => i.state === "needs_you" || i.state === "proposed").length); }
    }
    renderSidebar();
  } catch { /* older runtime */ }
}
const waitingRuns = new Set();
function openPage(page) {
  closeDialog();
  state.page = page;
  notify();
  PAGES[page]?.view.show();
}
nav.openPage = openPage;
let settingsQuery = "";

// ---- per-project views (kept alive so chats keep streaming, shells keep running)
const views = new Map(); // workspace id -> { chats: Map(chat id -> view), draft, panel }
let emptyEl = null;

function viewsFor(ws) {
  let v = views.get(ws.id);
  if (!v) {
    v = { chats: new Map(), draft: null };
    views.set(ws.id, v);
    v.panel = createPanel(ws, { chat: () => (state.active === ws.id ? selectedChat(ws).snapshot() : null), onChange: () => syncPanelButton(), visible: () => state.active === ws.id && state.page === "app" });
    v.panel.el.hidden = true;
    paneRow.append(v.panel.el);
  }
  return v;
}

function makeChatView(ws, v, meta) {
  const view = createChat(ws, {
    chatId: meta?.id ?? null,
    mode: meta?.mode,
    meta,
    // The draft just became a real chat on its first message.
    onBind: (id) => {
      v.chats.set(id, view);
      if (v.draft === view) v.draft = null;
      view.loadedOnce = true;
      state.chatSel[ws.id] = id;
      notify();
    },
    onSelectProject: (id) => selectProject(id),
    onStartMode: (mode, text, files) => startModeChat(ws, mode, text, files),
    onActivity: (ev) => { if (selectedChat(ws) === view) v.panel?.chatChanged(ev); },
  });
  view.el.hidden = true;
  paneBody.append(view.el);
  return view;
}

/** The chat view for the project's current selection ("new" = the draft). */
function selectedChat(ws) {
  const v = viewsFor(ws);
  let sel = state.chatSel[ws.id];
  if (sel === undefined || (sel !== "new" && !state.chats.some((c) => c.id === sel))) {
    sel = state.chats.find((c) => c.workspace_id === ws.id)?.id ?? "new";
    state.chatSel[ws.id] = sel;
  }
  if (sel === "new") return (v.draft ??= makeChatView(ws, v, null));
  let view = v.chats.get(sel);
  if (!view) {
    view = makeChatView(ws, v, state.chats.find((c) => c.id === sel));
    v.chats.set(sel, view);
  }
  return view;
}

// ---- the agent's browser: main asks for a project's Browser tab (src/main/browserHost.ts) ----
async function browserOp(op, a) {
  const ws = state.workspaces.find((w) => w.id === a.workspace_id);
  if (!ws) throw new Error("that project is not open in the window");
  const panel = viewsFor(ws).panel;
  switch (op) {
    case "ensure": return panel.agentBrowser(a);
    case "list": return panel.browserList();
    case "select": panel.selectTab(a.tab_id); return true;
    case "close": panel.closeTabById(a.tab_id); return true;
    case "activity": panel.agentActivity(a.tab_id, a.label); return true;
    default: throw new Error(`unknown op ${op}`);
  }
}
window.opscode?.browserHost?.onRequest(({ rid, op, args }) => {
  browserOp(op, args ?? {}).then(
    (result) => window.opscode.browserHost.reply({ rid, result }),
    (e) => window.opscode.browserHost.reply({ rid, error: e instanceof Error ? e.message : String(e) }),
  );
});

function ensureLoaded(chatView) {
  if (chatView && !chatView.loadedOnce) { chatView.loadedOnce = true; void chatView.loadHistory(); }
}

// ---- actions ----------------------------------------------------------------
/** Side panel: show/hide, or open one tool in it. */
function togglePanel() {
  const ws = activeWorkspace();
  if (ws) viewsFor(ws).panel.toggle();
}
function openTool(kind, params) {
  const ws = activeWorkspace();
  if (!ws) return;
  state.page = "app";
  notify();
  if (params) viewsFor(ws).panel.open(kind, params);
  else viewsFor(ws).panel.toggleKind(kind);
}
let panelBtn = null;
function syncPanelButton() {
  const ws = activeWorkspace();
  if (!panelBtn || !ws) return;
  const open = views.get(ws.id)?.panel?.isOpen ?? false;
  panelBtn.setAttribute("aria-pressed", String(open));
  panelBtn.title = open ? "Hide side panel (⌘\\)" : "Show side panel (⌘\\)";
}
function selectChat(id) {
  const c = state.chats.find((x) => x.id === id);
  if (!c) return;
  state.active = c.workspace_id;
  state.chatSel[c.workspace_id] = id;
  state.page = "app";
  state.surface = "chat";
  if (c.chief && c.chief.role !== "home") revealMode(c.chief.id);
  notify();
  selectedChat(activeWorkspace()).focus();
}
function newChat() {
  const ws = activeWorkspace();
  if (!ws) return void addProject();
  state.page = "app";
  state.chatSel[ws.id] = "new";
  state.surface = "chat";
  notify();
  const v = selectedChat(ws);
  v.focus();
  requestAnimationFrame(() => v.reveal?.());
}
async function deleteChat(chat) {
  const worker = chat.chief && chat.chief.role !== "home";
  const parent = worker ? state.chiefs.find((c) => c.id === chat.chief.id) : null;
  const body = `“${chat.title || "New chat"}” and its transcript will be removed from this computer. Files it changed stay as they are.${parent ? ` It also leaves ${chiefLabel(parent)}.` : ""}`;
  const ok = await confirmDialog({ title: "Delete this chat?", body: state.running.has(chat.id) ? `${body} It is working now, so it stops.` : body, confirm: "Delete chat", danger: true });
  if (!ok) return;
  try { await state.client.call("chat.delete", { chat_id: chat.id }); } catch (err) { toast(`Couldn't delete: ${err.message}`); }
}
/** A mode chat (GODMODE / WARLORD / SHINOBI): it goes with the worker chats nested under it. */
async function deleteMode(c, workers) {
  const n = workers.length;
  const working = workers.filter((w) => state.running.has(w.id)).length;
  const body = n
    ? `“${chiefLabel(c)}” and its ${n} nested ${n === 1 ? "chat" : "chats"} will be deleted, with their transcripts.${working ? ` ${working} ${working === 1 ? "is" : "are"} working now and stop${working === 1 ? "s" : ""}.` : ""} Files they changed stay as they are.`
    : `“${chiefLabel(c)}” and its transcript will be removed from this computer. Files it changed stay as they are.`;
  const ok = await confirmDialog({ title: n ? `Delete this chat and ${n} nested?` : "Delete this chat?", body, confirm: n ? `Delete ${n + 1} chats` : "Delete chat", danger: true });
  if (!ok) return;
  try { await state.client.call("chief.remove", { chief_id: c.id, delete_workers: true }); } catch (err) { toast(`Couldn't delete: ${err.message}`); }
}
function selectProject(id) {
  state.active = id;
  state.page = "app";
  if (state.chatSel[id] === undefined) state.chatSel[id] = "new";
  notify();
}

async function addProject() {
  const path = await bridge?.pickFolder();
  if (!path) return;
  try {
    const { workspace, created } = await state.client.call("workspace.add", { path });
    if (!created) toast(`${workspace.name} is already added.`);
    selectProject(workspace.id);
  } catch (err) {
    toast(`Couldn't add: ${err.message}`);
  }
}
/** Unlink, not delete: the folder and its files stay on disk; only Opscode forgets the project and its chats. */
async function unlinkProject(ws) {
  const chats = state.chats.filter((c) => c.workspace_id === ws.id).length + state.chiefs.filter((c) => c.mode && c.project_ids[0] === ws.id).length;
  const ok = await confirmDialog({
    title: `Unlink “${ws.name}”?`,
    body: `This only removes the link in Opscode. Your folder and files stay exactly where they are on this computer; nothing on disk is touched.${chats ? ` The ${chats} ${chats === 1 ? "chat" : "chats"} you had here in Opscode are removed from it.` : ""} You can add the folder again any time.`,
    confirm: "Unlink project",
  });
  if (!ok) return;
  try { await state.client.call("workspace.remove", { workspace_id: ws.id }); } catch (err) { toast(`Couldn't unlink: ${err.message}`); }
}
function openSettingsPage(section) {
  closeDialog();
  if (section) state.section = section;
  state.page = "settings";
  notify();
}
function closeSettingsPage() {
  state.page = "app";
  notify();
}
nav.openSettings = openSettingsPage;
nav.closeSettings = closeSettingsPage;
nav.setEngines = (list, settings) => setEngines(list, settings);
nav.openOverview = () => openTool("overview", { focus: "context" });
// A file link in a reply opens a project file in the side panel's File tab (path relative to the project).
nav.openFile = (rel) => openTool("file", { path: rel });
// Voice mode's mini screen: the WebContents id of the project's Browser tab the agent works in (null if none is open).
nav.browserWcId = async (workspaceId) => { const v = views.get(workspaceId); return v?.panel?.browserWcId ? v.panel.browserWcId() : null; };
installFileLinks();

function toggleSidebar() {
  state.collapsed = !state.collapsed;
  writePref("sidebar-collapsed", state.collapsed ? "1" : "0");
  notify();
}
function setTheme(theme) {
  void state.client?.call("settings.set", { patch: { theme } }).catch((e) => toast(e.message));
}

// ---- sidebar ----------------------------------------------------------------
function renderSettingsSidebar() {
  sidebar.dataset.collapsed = String(state.collapsed);
  const q = settingsQuery.trim().toLowerCase();
  const shown = SECTIONS.filter((x) => !q || `${x.label} ${x.keywords}`.toLowerCase().includes(q));
  const search = h("input", { placeholder: "Search settings…", "aria-label": "Search settings", value: settingsQuery, autocomplete: "off", spellcheck: false });
  search.addEventListener("input", () => {
    settingsQuery = search.value;
    const pos = search.selectionStart;
    renderSettingsSidebar();
    const el = sidebar.querySelector("input");
    el?.focus();
    el?.setSelectionRange(pos, pos);
  });
  search.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && shown[0]) { state.section = shown[0].id; notify(); }
  });
  sidebar.replaceChildren(
    h("div", { class: "sidebar-inner" },
      h("div", { class: "sidebar-header drag" },
        h("span", { class: "brand-mark", title: "Opscode" }, h("img", { src: "brand/opscode-mark-128.png", alt: "", width: 20, height: 20, draggable: false }), h("span", { class: "brand-name" }, "Opscode")),
        h("span", { class: "sidebar-spacer" }),
        h("button", { class: "sidebar-icon-button no-drag", type: "button", title: "Hide sidebar (⌘B)", "aria-label": "Hide sidebar", onclick: toggleSidebar }, icon("panel-left"))),
      h("nav", { class: "sidebar-navigation" },
        h("button", { class: "sidebar-back", type: "button", onclick: closeSettingsPage }, icon("chevron-down"), "Back to app"),
        h("label", { class: "sidebar-search" }, icon("search"), search),
        h("div", { class: "sidebar-group" },
          ...shown.map((x) => h("button", { class: "sidebar-item", type: "button", "aria-current": String(state.section === x.id), onclick: () => { state.section = x.id; notify(); } }, icon(x.icon), h("span", { class: "sidebar-label" }, x.label))),
          shown.length === 0 ? h("div", { class: "sidebar-note" }, "No matching settings.") : null))));
}

let chiefsFolded = false;
const projectsList = createProjects({
  selectChat, openChief, selectProject, deleteChat, deleteMode, unlink: unlinkProject,
  newChatIn: (w) => { state.active = w.id; newChat(); },
  needs: (id) => chiefNeeds.get(id) ?? 0,
  rerender: () => renderSidebar(),
});

function renderSidebar() {
  if (state.page === "settings") return renderSettingsSidebar();
  sidebar.dataset.collapsed = String(state.collapsed);
  const ws = activeWorkspace();
  noteActive(ws?.id ?? null);
  // Usage: shows the lowest "% left" when it's getting low.
  const usageNav = () => {
    const low = lowestLeft(state.limits);
    const b = navItem("usage", "Usage", "gauge");
    if (low !== null && low < 25) b.append(h("span", { class: `sb-badge sb-usage${low < 5 ? " bad" : ""}`, title: `${Math.round(low)}% left on a plan limit` }, `${Math.round(low)}%`));
    return b;
  };
  const navItem = (page, label, ic, badge = 0) => h("button", { class: "sidebar-item sb-nav", type: "button", "aria-current": String(state.page === page), dataset: { page }, onclick: () => openPage(page) }, icon(ic), h("span", { class: "sidebar-label" }, label), badge ? h("span", { class: "sb-badge", title: `${badge} waiting for you` }, String(badge)) : null);
  const projects = projectsList.rows();

  const name = state.settings?.display_name?.trim() || "You";
  sidebar.replaceChildren(
    h("div", { class: "sidebar-inner" },
      h("div", { class: "sidebar-header drag" },
        h("span", { class: "brand-mark", title: "Opscode" }, h("img", { src: "brand/opscode-mark-128.png", alt: "", width: 20, height: 20, draggable: false }), h("span", { class: "brand-name" }, "Opscode")),
        h("span", { class: "sidebar-spacer" }),
        h("button", { class: "sidebar-icon-button no-drag", type: "button", title: "Hide sidebar (⌘B)", "aria-label": "Hide sidebar", onclick: toggleSidebar }, icon("panel-left"))),
      h("div", { class: "sb-new-row" },
        h("button", { class: "sb-new no-drag", type: "button", onclick: newChat, title: "New chat (⌘N)" }, icon("plus"), h("span", { class: "grow" }, "New chat")),
        h("button", { class: "sb-modes no-drag", type: "button", onclick: chooseHowToWork, title: "Start a mode chat: GODMODE, WARLORD or SHINOBI", "aria-label": "Start a mode chat" }, modeEmblem("shinobi", 22))),
      h("nav", { class: "sidebar-navigation" },
        h("div", { class: "sb-navs" }, navItem("review", "Review", "diff"), navItem("plugins", "Plugins", "grid"), navItem("automations", "Automations", "zap", waitingRuns.size), navItem("library", "Library", "layers"), usageNav()),
        h("div", { class: "sb-section-head", dataset: { section: "managers" } }, h("button", { class: "sb-fold", type: "button", "aria-expanded": String(!chiefsFolded), onclick: () => { chiefsFolded = !chiefsFolded; renderSidebar(); } }, CHIEF_NAME.many, icon(chiefsFolded ? "chevron-right" : "chevron-down")), h("span", { class: "grow" }),
          h("button", { class: "sb-head-btn", type: "button", title: `New ${CHIEF_NAME.one}: a chat that runs other chats for you`, "aria-label": `New ${CHIEF_NAME.one}`, onclick: () => void newChief() }, icon("plus"))),
        chiefsFolded ? null : h("div", { class: "sb-chiefs" }, ...(state.chiefs.some((c) => !c.mode) ? state.chiefs.filter((c) => !c.mode).map((c, i) => h("button", { class: "sidebar-item sb-chief", type: "button", dataset: { chief: c.id }, "aria-current": String(state.page === "chief" && state.chiefSel === c.id), onclick: () => openChief(c.id) },
          mascot(mascotOf(c, i), "mascot mascot-sm"), h("span", { class: "sidebar-label" }, chiefLabel(c)), state.running.has(c.chat_id) ? h("span", { class: "spin", title: "Thinking…" }) : null, chiefNeeds.get(c.id) ? h("span", { class: "sb-badge", title: "Needs you" }, String(chiefNeeds.get(c.id))) : null))
          : [h("button", { class: "sidebar-item sb-chief sb-chief-empty", type: "button", title: `A ${CHIEF_NAME.one} is a chat that runs other chats for you`, onclick: () => void newChief() }, icon("users"), h("span", { class: "sidebar-label" }, `Make ${CHIEF_NAME.article}`))])),
        h("div", { class: "sb-section-head", dataset: { section: "projects" } }, h("span", { class: "grow" }, "Projects"),
          h("button", { class: "sb-head-btn", type: "button", title: "Show or hide chats", "aria-label": "Show or hide chats", dataset: { act: "filter" }, onclick: (e) => projectsList.filterMenu(e.currentTarget) }, icon("filter")),
          h("button", { class: "sb-head-btn", type: "button", title: "Add project", "aria-label": "Add project", onclick: addProject }, icon("plus")),
          h("button", { class: "sb-head-btn", type: "button", title: "More", "aria-label": "Projects menu", onclick: (e) => openMenu(e.currentTarget, [
            { label: "Add project…", icon: "plus", onSelect: addProject },
            { label: "Hide all chats", icon: "chevron-right", onSelect: () => { setAllOpen(false); renderSidebar(); } },
            { label: "Show all chats", icon: "chevron-down", onSelect: () => { setAllOpen(true); renderSidebar(); } }], { up: false, width: 220 }) }, icon("more"))),
        h("div", { class: "sb-projects" }, ...(projects.length ? projects : [h("div", { class: "sidebar-note" }, "No projects yet. Add a folder to start.")]))),
      h("div", { class: "sidebar-foot sb-foot" },
        h("span", { class: "sb-avatar", "aria-hidden": "true" }, name.slice(0, 1).toUpperCase()),
        h("span", { class: "sidebar-label grow", title: state.conn === "ready" ? "Runtime ready" : `Runtime ${state.conn}` }, name, state.conn === "ready" ? null : h("span", { class: "dot", dataset: { state: state.conn } })),
        h("button", { class: "sb-head-btn", type: "button", title: "Settings (⌘,)", "aria-label": "Settings", onclick: () => openSettingsPage("general") }, icon("sliders")))),
  );
}

// ---- pane header + body -----------------------------------------------------
function renderPane() {
  const ws = activeWorkspace();
  frame.dataset.sidebar = state.collapsed ? "closed" : "open";
  for (const p of Object.values(PAGES)) p.view.el.hidden = true;
  if (state.page === "settings") {
    const sec = SECTIONS.find((x) => x.id === state.section) ?? SECTIONS[0];
    paneHeader.replaceChildren(
      h("button", { class: "pane-toggle no-drag", type: "button", title: "Show sidebar (⌘B)", "aria-label": "Show sidebar", hidden: !state.collapsed, onclick: toggleSidebar }, icon("panel-left")),
      h("span", { class: "pane-tab", "aria-selected": "true" }, icon(sec.icon), sec.label),
      h("span", { class: "pane-grow" }),
      h("button", { class: "btn btn-ghost btn-sm no-drag", type: "button", onclick: closeSettingsPage }, "Done"));
    hideAllViews();
    emptyEl?.remove();
    emptyEl = null;
    settingsPage.hidden = false;
    rerenderSettings(true);
    return;
  }
  settingsPage.hidden = true;
  for (const [id, p] of Object.entries(PAGES)) p.view.el.hidden = state.page !== id;
  const toggle = h("button", { class: "pane-toggle no-drag", type: "button", title: "Show sidebar (⌘B)", "aria-label": "Show sidebar", hidden: !state.collapsed, onclick: toggleSidebar }, icon("panel-left"));
  if (state.page === "chief") {
    paneHeader.replaceChildren(toggle, ...chiefPage.header());
    hideAllViews();
    emptyEl?.remove();
    emptyEl = null;
    return;
  }
  if (PAGES[state.page]) {
    const pg = PAGES[state.page];
    paneHeader.replaceChildren(toggle, h("span", { class: "pane-crumbs" }, icon(pg.icon), h("span", { class: "pane-crumb-here" }, pg.label)), h("span", { class: "pane-grow" }));
    hideAllViews();
    emptyEl?.remove();
    emptyEl = null;
    return;
  }
  const sel = ws ? state.chatSel[ws.id] : undefined;
  const meta = ws && sel && sel !== "new" ? state.chats.find((c) => c.id === sel) : null;
  const title = !ws ? null : meta
    ? h("button", { class: "pane-title no-drag", type: "button", title: meta.title || "New chat", onclick: (e) => openMenu(e.currentTarget, [
        { label: "New chat", icon: "compose", onSelect: newChat },
        { label: "Delete chat…", icon: "trash", danger: true, onSelect: () => void deleteChat(meta) }], { up: false, width: 220 }) },
        state.running.has(meta.id) ? h("span", { class: "spin" }) : icon("mark"), h("span", { class: "pane-title-text" }, meta.title || "New chat"), icon("chevron-down", "icon chip-caret"))
    : h("div", { class: "pane-crumbs" }, icon("folder"), h("span", {}, ws.name), h("span", { class: "crumb-sep" }, "/"), h("span", { class: "pane-crumb-here" }, "New chat"));
  panelBtn = ws ? h("button", { class: "pane-panel-btn no-drag", type: "button", "aria-label": "Side panel", onclick: togglePanel }, icon("panel-right")) : null;
  paneHeader.replaceChildren(toggle, title, h("span", { class: "pane-grow" }), panelBtn);
  syncPanelButton();

  hideAllViews();
  emptyEl?.remove();
  emptyEl = null;
  if (!ws) {
    emptyEl = h("div", { class: "empty pane-surface" },
      h("div", { class: "empty-mark" }, icon("mark")),
      h("h1", {}, "Open a project to begin"),
      h("p", {}, "Projects are folders on this computer. Chat, files and terminals all stay inside the project you pick."),
      h("button", { class: "btn btn-primary", type: "button", onclick: addProject }, icon("plus"), "Add project…"));
    paneBody.append(emptyEl);
    return;
  }
  const v = viewsFor(ws);
  const chat = selectedChat(ws);
  chat.el.hidden = false;
  v.panel.el.hidden = !v.panel.isOpen;
  chat.syncChips();
  if (state.client && state.conn === "ready") ensureLoaded(chat);
  if (v.shownChat !== chat) { v.shownChat = chat; v.panel.chatChanged(null); }
  syncPanelButton();
}

function hideAllViews() {
  for (const v of views.values()) {
    for (const c of v.chats.values()) c.el.hidden = true;
    if (v.draft) v.draft.el.hidden = true;
    if (v.panel) v.panel.el.hidden = true;
  }
}

function render() {
  if (state.client && state.conn === "ready" && skillsFor !== state.active) { skillsFor = state.active; void refreshSkills(); }
  renderSidebar();
  renderPane();
  document.title = activeWorkspace() ? `${activeWorkspace().name} — Opscode` : "Opscode";
}
subscribe(render);

// The notch: tell main which chat is on screen (a finished chat there counts as seen), and open what the notch asks.
let notchSeen;
subscribe(() => {
  const ws = activeWorkspace();
  const sel = state.page === "app" && ws ? state.chatSel[ws.id] : undefined;
  const id = typeof sel === "string" && sel !== "new" ? sel : null;
  if (id !== notchSeen) { notchSeen = id; window.opscode?.notch?.viewing(id); }
});
window.opscode?.notch?.onOpen((t) => {
  if (t?.chat_id && state.chats.some((c) => c.id === t.chat_id)) return openChat(undefined, undefined, t.chat_id);
  if (t?.newchat || t?.workspace_id) {
    const wid = t.workspace_id && state.workspaces?.some?.((w) => w.id === t.workspace_id) ? t.workspace_id : activeWorkspace()?.id;
    if (wid) return openChat(wid, t.draft);
    return newChat();
  }
});

// ---- theme + settings -------------------------------------------------------
function applySettings(next) {
  state.settings = next;
  if (next.theme === "system") document.documentElement.removeAttribute("data-theme");
  else document.documentElement.setAttribute("data-theme", next.theme);
  document.documentElement.dataset.text = next.text_size;
  document.documentElement.dataset.density = next.density;
  bridge?.setTheme(next.theme);
  if (state.page === "settings") rerenderSettings();
}

// ---- palette + shortcuts ----------------------------------------------------
function commands() {
  const ws = activeWorkspace();
  const out = [];
  if (ws) out.push({ group: "Chats", label: "New chat", icon: "compose", hint: "⌘N", run: newChat });
  for (const c of state.chats.slice(0, 20)) out.push({ group: "Chats", label: c.title || "New chat", icon: "chat", hint: state.workspaces.find((w) => w.id === c.workspace_id)?.name, run: () => selectChat(c.id) });
  if (ws) out.push({ group: "Side panel", label: "Show or hide the side panel", icon: "panel-right", hint: "⌘\\", run: togglePanel });
  if (ws) for (const t of TOOLS) out.push({ group: "Side panel", label: t.label, icon: t.icon, hint: t.chord ?? t.description, run: () => openTool(t.kind) });
  for (const w of state.workspaces) out.push({ group: "Projects", label: `Open ${w.name}`, icon: "folder", hint: w.path.replace(/^\/Users\/[^/]+/, "~"), run: () => selectProject(w.id) });
  out.push({ group: "Actions", label: "Plugins", icon: "grid", run: () => openPage("plugins") });
  out.push({ group: "Actions", label: "Automations", icon: "zap", run: () => openPage("automations") });
  out.push({ group: "Actions", label: "Usage limits", icon: "gauge", run: () => openPage("usage") });
  out.push({ group: "Actions", label: "Library: what my apps already have", icon: "layers", run: () => openPage("library") });
  out.push({ group: "Actions", label: "Start a mode chat…", icon: "users", run: chooseHowToWork });
  for (const m of MODE_ORDER) out.push({ group: "Actions", label: `Start ${MODE_INFO[m].name} in this project`, icon: "users", run: () => void startConductor(m) });
  for (const c of state.chiefs ?? []) out.push({ group: c.mode ? "Mode chats" : CHIEF_NAME.many, label: c.mode ? `${chiefLabel(c)} · ${MODE_INFO[c.mode]?.name} · ${state.workspaces.find((w) => w.id === c.project_ids[0])?.name ?? ""}` : chiefLabel(c), icon: "users", run: () => openChief(c.id) });
  out.push({ group: CHIEF_NAME.many, label: `New ${CHIEF_NAME.one}`, icon: "plus", run: () => void newChief() });
  out.push({ group: "Actions", label: "Review changes", icon: "diff", run: () => openPage("review") });
  out.push({ group: "Actions", label: "Add project…", icon: "plus", run: addProject });
  out.push({ group: "Actions", label: state.collapsed ? "Show sidebar" : "Hide sidebar", icon: "panel-left", hint: "⌘B", run: toggleSidebar });
  out.push({ group: "Actions", label: "Settings", icon: "sliders", hint: "⌘,", run: () => openSettingsPage("general") });
  for (const x of SECTIONS.filter((y) => y.id !== "general")) out.push({ group: "Settings", label: x.label, icon: x.icon, run: () => openSettingsPage(x.id) });
  for (const [id, ic, label] of [["system", "monitor", "System"], ["light", "sun", "Light"], ["dark", "moon", "Dark"]]) out.push({ group: "Theme", label: `${label} theme`, icon: ic, run: () => setTheme(id) });
  return out;
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && state.page === "settings" && !document.querySelector(".overlay") && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName ?? "")) { closeSettingsPage(); return; }
  // Side panel chords: ⇧⌘B browser, ⌃` terminal, ⌘P files, ⌃⇧G changes, ⌘\ show/hide.
  if (e.ctrlKey && !e.metaKey && !e.altKey && (e.key === "`" || e.code === "Backquote") && activeWorkspace()) { e.preventDefault(); openTool("terminal"); return; }
  if (e.ctrlKey && e.shiftKey && !e.metaKey && e.key.toLowerCase() === "g" && activeWorkspace()) { e.preventDefault(); openTool("diff"); return; }
  const mod = isMac ? e.metaKey : e.ctrlKey;
  if (!mod || e.altKey) return;
  const key = e.key.toLowerCase();
  if (key === "b" && e.shiftKey && activeWorkspace()) { e.preventDefault(); openTool("browser"); return; }
  if (key === "p" && !e.shiftKey && activeWorkspace()) { e.preventDefault(); openTool("files"); return; }
  if (key === "\\" && activeWorkspace()) { e.preventDefault(); togglePanel(); return; }
  if (key === "k") { e.preventDefault(); openPalette(commands()); }
  else if (key === "b") { e.preventDefault(); toggleSidebar(); }
  else if (key === ",") { e.preventDefault(); openSettingsPage("general"); }
  else if (key === "n" && activeWorkspace()) { e.preventDefault(); newChat(); }
});

// ---- runtime session --------------------------------------------------------
function setProviders(next) {
  state.providers = next;
  for (const v of views.values()) { v.draft?.refreshEngine(); for (const c of v.chats.values()) c.refreshEngine(); }
  if (state.page === "settings") rerenderSettings();
  notify();
}

function setPlugins(plugins, marketplaces) {
  state.plugins = plugins;
  state.marketplaces = marketplaces;
  if (state.page === "plugins") pluginsPage.render();
  if (state.page === "settings") rerenderSettings();
}

/** Skills depend on the active project (project skills), so refetch on change. */
let skillsFor;
async function refreshSkills() {
  if (!state.client || state.conn !== "ready") return;
  try {
    const { skills } = await state.client.call("skill.list", state.active ? { workspace_id: state.active } : {});
    state.skills = skills;
    state.agents = (await state.client.call("subagent.list", state.active ? { workspace_id: state.active } : {})).agents;
    skillsFor = state.active;
    if (state.page === "settings") rerenderSettings();
    if (state.page === "plugins") pluginsPage.render();
  } catch { /* the project may have just been removed */ }
}

function setNotes(next) {
  state.notes = next;
  if (state.page === "plugins") pluginsPage.render();
  if (state.page === "settings") rerenderSettings();
}
function setComputer(next) {
  state.computer = next;
  for (const v of views.values()) v.panel?.computerChanged();
  if (state.page === "settings") rerenderSettings();
}
/** Who is signed in to Claude Code and Codex (accounts.list / accounts.changed). `login` is the open sign-in, when the runtime sent it. */
let accountsSig = "";
function setAccounts(list, login) {
  state.accounts = list;
  if (login !== undefined) accountsUi.loginChanged(login);
  // Re-reading who is signed in often finds nothing new; then nothing is redrawn (a page being typed into stays as it is).
  const sig = JSON.stringify(list.map((a) => [a.engine, a.id, a.active, a.last_used_at, a.status && [a.status.signed_in, a.status.email, a.status.plan, a.status.org, a.status.method, a.status.error, accountsUi.checking.on ? a.status.checked_at : 0]]));
  if (sig === accountsSig) return;
  accountsSig = sig;
  accountsUi.accountsChanged();
  for (const v of views.values()) { v.draft?.refreshEngine(); for (const c of v.chats.values()) c.refreshEngine(); }
  if (state.page === "chief") chiefPage.accountsChanged?.();
  if (state.page === "settings") rerenderSettings();
}
accountsUi.bindAccounts(setAccounts);

function setEngines(list, settings) {
  state.engines = list;
  state.engineSettings = settings;
  for (const v of views.values()) { v.draft?.refreshEngine(); for (const c of v.chats.values()) c.refreshEngine(); }
  if (state.page === "settings") rerenderSettings();
}
function setMcp(next) {
  state.mcp = next;
  if (state.page === "plugins") pluginsPage.render();
  if (state.page === "settings") rerenderSettings();
}

function setChats(list, running) {
  state.chats = list;
  if (running) state.running = new Set(running);
  for (const v of views.values()) {
    for (const [id, view] of v.chats) {
      if (!list.some((c) => c.id === id)) { view.el.remove(); v.chats.delete(id); }
    }
  }
  for (const c of list) views.get(c.workspace_id)?.chats.get(c.id)?.setMeta(c);
  notify();
}

function setWorkspaces(next) {
  state.workspaces = next;
  for (const [id, v] of views) {
    if (!next.some((w) => w.id === id)) {
      for (const c of v.chats.values()) c.el.remove();
      v.draft?.el.remove();
      v.panel?.dispose();
      views.delete(id);
    }
  }
  if (!next.some((w) => w.id === state.active)) state.active = next[0]?.id ?? null;
  notify();
}

/** How many workspace.changed / chat.changed pushes arrived (newer than a list fetched before them). */
const pushed = { workspaces: 0, chats: 0 };
const endpoint = bridge?.runtime?.endpoint ?? null;
if (endpoint) {
  let everReady = false;
  const client = connectRuntime(endpoint, {
    onState: async (conn, hello) => {
      state.conn = conn;
      state.hello = hello;
      if (conn === "ready") {
        // After a runtime restart, shells and in-flight turns are gone: reload every view.
        if (everReady) for (const v of views.values()) { v.panel?.reset(); for (const c of v.chats.values()) c.loadedOnce = false; }
        everReady = true;
        void client.call("settings.get", {}).then(({ settings }) => applySettings(settings))
          .catch((err) => toast(`Couldn't load settings: ${err.message}`));
        try {
          // Everything is asked at the same time. Projects and chats come first so the sidebar is there at once; the models and who is
          // signed in answer from what the runtime remembers (and are read again in the background, arriving as engines.changed / accounts.changed).
          // A push that arrives while these are in flight is newer than their answers: keep it (a project added during a
          // reconnect used to vanish when the slower calls finished and the older, empty list was put back).
          const seen = { ...pushed };
          const [chatList, ws, providers, notes, pl, mcp, computer] = await Promise.all([
            client.call("chat.list", {}), client.call("workspace.list"), client.call("provider.list"),
            client.call("memory.list"), client.call("plugin.list"), client.call("mcp.list"), client.call("computer.status"),
            client.call("engines.list", {}).then((r) => setEngines(r.engines, r.settings)).catch(() => {}),
            accountsUi.reloadAccounts(false),
          ]);
          if (pushed.chats === seen.chats) state.chats = chatList.chats;
          state.running = new Set(chatList.running);
          skillsFor = undefined; // refetch skills for the active project
          if (pushed.workspaces === seen.workspaces) setWorkspaces(ws.workspaces);
          setProviders(providers.providers);
          setNotes(notes.notes);
          setPlugins(pl.plugins, pl.marketplaces);
          setMcp(mcp.servers);
          setComputer(computer.status);
          // Plan limits for the sidebar badge, a little after start (the check runs no model).
          setTimeout(() => void client.call("limits.get", {}).then((r) => { state.limits = r.limits; renderSidebar(); }).catch(() => {}), 8000);
          void loadChiefs();
        } catch (err) {
          toast(`Runtime error: ${err.message}`);
        }
      }
      notify();
    },
  });
  state.client = client;
  window.__opscodeRpc = client; // read by the smoke check
  client.on("settings.changed", ({ settings }) => applySettings(settings));
  client.on("plugin.changed", ({ plugins, marketplaces }) => setPlugins(plugins, marketplaces));
  client.on("skill.changed", () => void refreshSkills());
  client.on("subagent.changed", () => void refreshSkills());
  client.on("memory.changed", ({ notes }) => setNotes(notes));
  client.on("chief.changed", (p) => {
    if (p.chiefs) state.chiefs = p.chiefs;
    if (p.removed) { chiefNeeds.delete(p.chief_id); chiefViews.delete(p.chief_id); if (state.chiefSel === p.chief_id) { state.page = "app"; state.chiefSel = null; } notify(); return; }
    if (p.items) chiefViews.set(p.chief_id, { items: p.items });
    if (p.items) chiefNeeds.set(p.chief_id, p.items.filter((i) => i.state === "needs_you" || i.state === "proposed").length);
    chiefPage.onChanged(p);
    renderSidebar();
  });
  client.on("chief.problem", ({ message }) => toast(message, 6000));
  client.on("automation.changed", () => { if (state.page === "automations") automationsPage.changed(); });
  client.on("automation.run_updated", (p) => {
    const was = waitingRuns.size;
    if (p.run.status === "waiting") waitingRuns.add(p.run.id); else waitingRuns.delete(p.run.id);
    if (waitingRuns.size !== was) { renderSidebar(); if (waitingRuns.size > was) toast(`${p.run.automation} is waiting for you in Automations`); }
    if (state.page === "automations") void automationsPage.runUpdated(p);
  });
  client.on("engines.changed", ({ engines, settings }) => setEngines(engines, settings));
  client.on("accounts.changed", ({ accounts, login }) => setAccounts(accounts, login));
  client.on("accounts.login", ({ login }) => accountsUi.loginChanged(login));
  client.on("usage.progress", (p) => usagePage.tokens.progress(p));
  client.on("library.changed", ({ apps }) => libraryPage.changed(apps));
  client.on("library.progress", (p) => libraryPage.progress(p));
  client.on("limits.changed", ({ limits, by_account }) => { const was = lowestLeft(state.limits); state.limitsByAccount = by_account ?? []; usagePage.changed(limits); state.limits = limits; if ((was ?? 100) >= 25 !== ((lowestLeft(limits) ?? 100) >= 25)) renderSidebar(); });
  client.on("mcp.changed", ({ servers }) => setMcp(servers));
  client.on("mcp.oauth.done", (p) => pluginsPage.signInDone(p));
  client.on("computer.changed", ({ status }) => setComputer(status));
  client.on("tts.event", (p) => window.dispatchEvent(new CustomEvent("opscode:tts", { detail: p })));
  client.on("voice.event", (p) => window.dispatchEvent(new CustomEvent("opscode:voice", { detail: p })));
  client.on("voiceagent.event", (p) => window.dispatchEvent(new CustomEvent("opscode:voiceagent", { detail: p })));
  client.on("ios.activity", (p) => { for (const v of views.values()) v.panel?.iosActivity(p); });
  client.on("provider.changed", ({ providers }) => setProviders(providers));
  client.on("workspace.changed", ({ workspaces }) => { pushed.workspaces++; setWorkspaces(workspaces); });
  client.on("chat.changed", ({ chats }) => { pushed.chats++; setChats(chats); });
  client.on("turn.event", (ev) => {
    views.get(ev.workspace_id)?.chats.get(ev.chat_id)?.onEvent(ev);
    if (chiefPage.owns(ev.chat_id)) chiefPage.onEvent(ev);
    else chiefPage.onWorkerEvent(ev);
    if (ev.type === "started") { state.running.add(ev.chat_id); notify(); }
    else if (ev.type === "completed" || ev.type === "failed" || ev.type === "interrupted") { state.running.delete(ev.chat_id); state.waiting.delete(ev.chat_id); notify(); }
    // Questions and approvals that wait for the person: the sidebar shows the chat as "Needs you". A question from a
    // reply that ended comes after "completed" and stays until it is answered.
    if (ev.type === "question" || ev.type === "approval_request") {
      const open = state.waiting.get(ev.chat_id) ?? new Set();
      open.add(ev.call_id);
      state.waiting.set(ev.chat_id, open);
      notify();
    } else if (ev.type === "question_answered" || ev.type === "approval_resolved") {
      const open = state.waiting.get(ev.chat_id);
      if (open) { open.delete(ev.call_id); if (!open.size) state.waiting.delete(ev.chat_id); notify(); }
    }
  });
  client.on("term.output", (p) => { for (const v of views.values()) v.panel?.termOutput(p); });
  client.on("term.exit", (p) => { for (const v of views.values()) v.panel?.termExit(p); });
  client.on("actions.changed", ({ workspace_id }) => views.get(workspace_id)?.panel?.actionsChanged());
}

render();
