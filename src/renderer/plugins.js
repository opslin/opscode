// The Plugins page: recommended servers, everything installed (plugins, MCP servers, skills, rules), a detail page for each
// server and skill, and the sign-in for servers behind a login (the browser opens, the person signs in, Opscode keeps the token).
// Layout is modelled on the way Caveman Code lays out its Plugins page; the code, the pattern background and the wording are Opscode's own.

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast, nav } from "./store.js";
import { showDialog, closeDialog, confirmDialog } from "./dialogs.js";
import { chooseFolder } from "./settings.js";
import { renderMarkdown } from "./markdown.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const toggle = (on, onChange, label) => h("button", { class: "switch", type: "button", role: "switch", "aria-checked": String(on), "aria-label": label, onclick: (e) => { e.stopPropagation(); onChange(!on); } });
// A tile shows the service's own logo when there is one (a white plate, so dark logos stay readable in both themes); letters are the fallback.
const tile = (mark, kind = "", logo = "") => {
  if (!logo) return h("span", { class: `pl-tile ${kind}` }, mark);
  const img = h("img", { src: `brand/integrations/${logo}`, alt: "", draggable: false });
  const el = h("span", { class: `pl-tile pl-tile-logo ${kind}` }, img);
  img.addEventListener("error", () => { el.classList.remove("pl-tile-logo"); el.replaceChildren(mark); });
  return el;
};
const tokens = (chars) => Math.max(1, Math.ceil(chars / 4));
const ENGINES = [["engine-claude", "Claude Code"], ["engine-codex", "Codex"], ["engine-antigravity", "Antigravity"], ["engine-qoder", "Qoder"], ["mark", "Opscode agent"]];
const CATEGORY_ORDER = ["Developer tools", "Productivity", "Data and analytics", "Payments and cloud", "Web", "Communication", "Email and marketing"];
const CATEGORY_LABEL = { "Data and analytics": "Data & analytics", "Payments and cloud": "Payments & cloud", "Email and marketing": "Email & marketing" };

/** Opens a sign-in address in the person's own browser (the app's window handler sends https links to the OS browser). */
function openInBrowser(url) { if (/^https?:\/\//i.test(url)) window.open(url, "_blank", "noopener"); }

export function createPluginsPage() {
  const search = h("input", { class: "pl-search-input", placeholder: "Search plugins, MCP servers and skills", "aria-label": "Search plugins, MCP servers and skills", autocomplete: "off", spellcheck: false });
  const tabs = h("div", { class: "pl-tabs", role: "tablist" });
  const warn = h("div", { class: "pl-warn" });
  const body = h("div", { class: "pl-body" });
  const add = h("button", { class: "icon-btn", type: "button", title: "Add", "aria-label": "Add" }, icon("plus"));
  const listHead = h("div", { class: "pl-head" }, h("label", { class: "pl-search" }, icon("search"), search), h("span", { class: "grow" }), add);
  const listSub = h("div", { class: "pl-subhead" }, tabs, h("span", { class: "grow" }), warn);
  const scroll = h("div", { class: "pl-scroll" }, body);
  const root = h("div", { class: "pl-page pane-surface" }, listHead, listSub, scroll);

  let tab = "all";
  let catalog = null;
  let showAllInstalled = false;
  /** null (the list), or { kind: "server", id } / { kind: "skill", name } */
  let view = null;
  /** Errors from a sign-in that did not start or did not finish, by server id (shown on its detail page). */
  const signinNote = new Map();
  /** Tool lists shown on a detail page (the list is asked for, not loaded for every server). */
  let setupBody = null;

  const q = () => search.value.trim().toLowerCase();
  const match = (...parts) => !q() || parts.join(" ").toLowerCase().includes(q());
  const entryOf = (s) => (s.catalog ? catalog?.find((c) => c.id === s.catalog) : undefined);

  async function loadCatalog() {
    try { catalog = (await state.client.call("mcp.catalog")).catalog; } catch { catalog = []; }
    render();
  }

  // ---- what to say about a server ----------------------------------------------------------------------------------------------
  function statusOf(s) {
    if (s.signing_in) return { text: "Waiting for the browser…", warn: false };
    if (s.needs_signin) return { text: "Needs a sign-in", warn: true };
    if (s.needs_key) return { text: "Needs a key", warn: true };
    if (s.state === "error") return { text: s.error ?? "Can't start", warn: true };
    if (s.state === "connecting") return { text: "Starting…", warn: false };
    if (!s.enabled) return { text: "Off", warn: false };
    if (s.state === "ready") return { text: `${s.auth === "oauth" ? "Signed in · " : ""}${s.tools.length} tool${s.tools.length === 1 ? "" : "s"}`, warn: false };
    return { text: s.enabled ? "Off" : "Off", warn: false };
  }
  const needsSetup = (s) => s.enabled && (s.needs_signin || s.needs_key);

  // ---- sign-in ---------------------------------------------------------------------------------------------------------------
  async function signIn(s) {
    signinNote.delete(s.id);
    try {
      const { url } = await state.client.call("mcp.oauth.start", { id: s.id });
      openInBrowser(url);
      toast(`Opening your browser to sign in to ${s.name}…`);
    } catch (err) { signinNote.set(s.id, err.message); toast(err.message); }
    render();
  }
  const signInCancel = async (s) => { try { await state.client.call("mcp.oauth.cancel", { id: s.id }); } catch (err) { toast(err.message); } };
  async function signOut(s) {
    const ok = await confirmDialog({ title: `Sign out of ${s.name}?`, body: "Opscode forgets the sign-in on this computer. You can sign in again at any time.", confirm: "Sign out", danger: true });
    if (!ok) return;
    try { await state.client.call("mcp.oauth.sign_out", { id: s.id }); toast(`Signed out of ${s.name}`); } catch (err) { toast(err.message); }
  }
  /** Called by the app when a sign-in ends (event mcp.oauth.done). */
  function signInDone({ id, ok, error }) {
    const s = (state.mcp ?? []).find((x) => x.id === id);
    const name = s?.name ?? "the server";
    if (ok) { signinNote.delete(id); toast(`Signed in to ${name}`); }
    else if (!/cancel/i.test(error ?? "")) { signinNote.set(id, error ?? "Sign-in did not finish."); toast(error ?? "Sign-in did not finish."); }
    render();
  }

  // ---- dialogs ---------------------------------------------------------------------------------------------------------------
  function addCatalog(e) {
    const oauth = e.auth === "oauth";
    const fields = [...e.inputs, ...(e.url_input ? [{ ...e.url_input, optional: false }] : [])];
    const inputs = fields.map((i) => ({ i, el: h("input", { class: "input", type: "password", autocomplete: "off", spellcheck: false, placeholder: i.placeholder ?? i.label, "aria-label": `${e.name} ${i.label}` }) }));
    const msg = h("p", { class: "field-help", role: "status" });
    const go = async () => {
      const values = Object.fromEntries(inputs.filter(({ el }) => el.value.trim() !== "").map(({ i, el }) => [i.key, el.value]));
      try {
        const { server } = await state.client.call("mcp.catalog.add", { id: e.id, ...(Object.keys(values).length ? { values } : {}) });
        closeDialog();
        toast(`Added ${e.name}`);
        void loadCatalog();
        if (oauth) await signIn(server);
      } catch (err) { msg.textContent = err.message; }
    };
    showDialog(h("div", { class: "dialog", role: "dialog", "aria-modal": "true", "aria-label": `Add ${e.name}` },
      h("div", { class: "dialog-head" }, tile(e.mark, "", e.logo), h("h2", {}, `Add ${e.name}`)),
      h("div", { class: "dialog-body" },
        h("p", { class: "field-help" }, e.description),
        h("div", { class: "pl-runs" }, h("span", { class: "field-label" }, e.transport === "stdio" ? "Runs on this computer" : "Connects to"), h("code", {}, e.target)),
        e.needs ? h("p", { class: "field-help" }, `Needs: ${e.needs}.`) : null,
        oauth && !e.unavailable ? h("p", { class: "field-help pl-note-box" }, `Opscode adds the server, then opens your browser so you can sign in to ${e.name}. Nothing is typed here, and Opscode never sees your password.`) : null,
        e.unavailable ? h("p", { class: "field-help pl-note-box" }, e.unavailable) : null,
        e.note ? h("p", { class: "field-help pl-note-box" }, e.note) : null,
        ...inputs.map(({ i, el }) => h("label", { class: "field" }, h("span", { class: "field-label" }, i.label, i.optional ? h("span", { class: "pl-optional" }, " · optional") : null), el, h("span", { class: "field-help" }, i.help))),
        inputs.length ? h("p", { class: "field-help" }, "Keys stay on this computer, in Opscode's private data folder. Agents see the server's tools, never the key.") : null,
        msg),
      h("div", { class: "dialog-foot" },
        h("a", { class: "link", href: e.docs, target: "_blank", rel: "noreferrer" }, "About this server"),
        h("span", { class: "grow" }),
        h("button", { class: "btn btn-sm", type: "button", onclick: closeDialog }, "Cancel"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", disabled: !!e.unavailable, onclick: go }, oauth ? "Add and sign in" : "Add"))));
    inputs[0]?.el.focus();
  }

  function editKeys(s) {
    const entry = entryOf(s);
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

  /** "Set up": every server that waits for a sign-in or a key, each with its button. Stays in step with the list while open. */
  function openSetup() {
    setupBody = h("div", { class: "dialog-body pl-setup" });
    paintSetup();
    showDialog(h("div", { class: "dialog", role: "dialog", "aria-modal": "true", "aria-label": "Set up servers" },
      h("div", { class: "dialog-head" }, h("h2", {}, "Set up your servers")),
      setupBody,
      h("div", { class: "dialog-foot" }, h("span", { class: "grow" }), h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: closeDialog }, "Done"))), { onClose: () => { setupBody = null; } });
  }
  function paintSetup() {
    if (!setupBody) return;
    const todo = (state.mcp ?? []).filter(needsSetup);
    put(setupBody,
      todo.length ? h("p", { class: "field-help" }, "These servers are on but cannot be used yet.") : h("p", { class: "field-help" }, "Everything is set up."),
      ...todo.map((s) => {
        const e = entryOf(s);
        const act = s.signing_in
          ? h("button", { class: "btn btn-sm", type: "button", onclick: () => signInCancel(s) }, "Waiting… Cancel")
          : s.needs_signin ? h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => signIn(s) }, "Sign in")
          : h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => editKeys(s) }, "Add key");
        return h("div", { class: "pl-setup-row", dataset: { server: s.id } }, tile(e?.mark ?? "", "", e?.logo ?? "mcp.svg"), h("div", { class: "pl-card-text" }, h("div", { class: "pl-card-title" }, s.name), h("div", { class: "pl-card-sub" }, statusOf(s).text)), act);
      }));
  }

  // ---- list ------------------------------------------------------------------------------------------------------------------
  const card = ({ mark, logo, kind, title, sub, dot, action, onclick, data }) =>
    h("div", { class: "pl-card", dataset: data ?? {}, onclick, onkeydown: onclick ? (e) => { if (e.key === "Enter") onclick(); } : undefined, role: onclick ? "button" : undefined, tabindex: onclick ? 0 : undefined },
      tile(mark, kind, logo), h("div", { class: "pl-card-text" }, h("div", { class: "pl-card-title" }, title), h("div", { class: "pl-card-sub" }, dot ? h("span", { class: "pl-dot" }) : null, sub)), action ?? null);
  const section = (id, title, count, items, more, sub) => (tab === "all" || tab === id) && items.length
    ? h("section", { class: "pl-section", dataset: { section: id } }, h("h3", {}, title, count !== null && count !== undefined ? h("span", { class: "pl-count" }, String(count)) : null), sub ? h("p", { class: "pl-section-sub" }, sub) : null, h("div", { class: "pl-grid" }, ...items), more ?? null)
    : null;

  function serverRow(s) {
    const ce = entryOf(s);
    const st = statusOf(s);
    const action = s.plugin ? h("span", { class: "pl-note" }, "Plugin")
      : s.needs_signin && !s.signing_in ? h("button", { class: "btn btn-sm", type: "button", dataset: { signin: s.id }, onclick: (ev) => { ev.stopPropagation(); void signIn(s); } }, "Sign in")
      : toggle(s.enabled, (on) => state.client.call("mcp.set_enabled", { id: s.id, enabled: on }).catch((e) => toast(e.message)), `Turn ${s.name} ${s.enabled ? "off" : "on"}`);
    return card({ mark: ce?.mark ?? "", logo: ce?.logo ?? "mcp.svg", kind: s.catalog ? "" : "pl-tile-mcp", title: s.name, sub: s.plugin ? `From ${s.plugin}` : s.source && st.text === "Off" ? `From ${s.source}` : st.text, dot: st.warn, data: { server: s.id }, onclick: () => open({ kind: "server", id: s.id }), action });
  }

  /** A catalog entry as a row: + to add it, or its state when it is already added. */
  function catalogRow(e) {
    const s = (state.mcp ?? []).find((x) => x.catalog === e.id);
    if (s) return serverRow(s);
    return card({ mark: e.mark, logo: e.logo, title: e.name, sub: e.unavailable ? "Not available yet" : e.description, data: { catalog: e.id }, onclick: () => addCatalog(e),
      action: h("button", { class: "pl-plus", type: "button", "aria-label": `Add ${e.name}`, title: e.unavailable ?? `Add ${e.name}`, onclick: (ev) => { ev.stopPropagation(); addCatalog(e); } }, icon("plus")) });
  }

  /** The big card in the Recommended row. */
  function recoCard(e) {
    const s = (state.mcp ?? []).find((x) => x.catalog === e.id);
    const foot = s
      ? h("span", { class: "pl-reco-state" }, icon("check"), statusOf(s).warn ? statusOf(s).text : "Installed")
      : h("button", { class: "pl-reco-add", type: "button", onclick: (ev) => { ev.stopPropagation(); addCatalog(e); } }, icon("plus"), "Install");
    return h("div", { class: "pl-rcard", dataset: { reco: e.id }, role: "button", tabindex: 0, onclick: () => (s ? open({ kind: "server", id: s.id }) : addCatalog(e)), onkeydown: (ev) => { if (ev.key === "Enter") ev.currentTarget.click(); } },
      h("div", { class: "pl-banner" }, h("span", { class: "pl-banner-logo" }, tile(e.mark, "", e.logo))),
      h("div", { class: "pl-rcard-body" },
        h("div", { class: "pl-rcard-title" }, e.name),
        h("div", { class: "pl-rcard-desc" }, e.description),
        h("div", { class: "pl-rcard-foot" }, foot, h("span", { class: "pl-note" }, CATEGORY_LABEL[e.category] ?? e.category))));
  }

  function recommended(cat) {
    const picks = cat.filter((e) => e.featured && !e.unavailable);
    if (!picks.length || (tab !== "all" && tab !== "featured") || q()) return null;
    const row = h("div", { class: "pl-reco-row" }, ...picks.map(recoCard));
    const arrow = (dir) => h("button", { class: `pl-arrow pl-arrow-${dir}`, type: "button", "aria-label": dir === "left" ? "Previous" : "Next", onclick: () => row.scrollBy({ left: (dir === "left" ? -1 : 1) * row.clientWidth * 0.8, behavior: "smooth" }) }, icon("chevron-right"));
    return h("section", { class: "pl-section pl-reco", dataset: { section: "recommended" } },
      h("div", { class: "pl-reco-head" }, h("div", {}, h("h2", { class: "pl-h2" }, "Recommended"), h("p", { class: "pl-section-sub" }, "Good first servers for your agents.")), h("span", { class: "grow" }), picks.length > 3 ? h("span", { class: "pl-arrows" }, arrow("left"), arrow("right")) : null),
      row);
  }

  function skillRow(s) {
    const where = s.scope === "project" ? "This project" : s.scope === "plugin" ? `From ${s.plugin}` : "All projects";
    return card({ mark: "/", kind: "pl-tile-soft", title: s.name, sub: `${where} · ${s.description}`, data: { skill: s.name }, onclick: () => open({ kind: "skill", name: s.name }) });
  }

  function renderList() {
    const servers = state.mcp ?? [];
    const plugins = state.plugins ?? [];
    const skills = state.skills ?? [];
    const rules = (state.notes ?? []).filter((n) => n.state === "kept" || n.pinned);
    const cat = (catalog ?? []).filter((e) => match(e.name, e.description, e.category));
    const setup = servers.filter(needsSetup);
    const counts = { featured: catalog?.length ?? 0, installed: plugins.length + servers.length, mcp: servers.length, skills: skills.length, rules: rules.length };
    put(tabs, ...[["featured", "Featured"], ["installed", "Installed"], ["mcp", "MCP servers"], ["skills", "Skills"], ["rules", "Rules"]].map(([id, label]) =>
      h("button", { class: "pl-tab", type: "button", role: "tab", "aria-selected": String(tab === id), onclick: () => { tab = tab === id ? "all" : id; render(); } }, label, h("span", { class: "pl-count" }, String(counts[id])))));
    put(warn, setup.length ? h("span", {}, h("span", { class: "pl-dot" }), `${setup.length} need${setup.length === 1 ? "s" : ""} a sign-in or a key`, h("button", { class: "btn btn-sm", type: "button", dataset: { act: "setup" }, onclick: openSetup }, "Set up")) : null);

    const mine = servers.filter((s) => match(s.name, s.target)).map(serverRow);
    // Servers from the list show their state in their category below; only the ones that are not in it (imported, typed in) get their own section.
    const others = servers.filter((s) => !s.catalog && match(s.name, s.target)).map(serverRow);
    const inst = plugins.filter((p) => match(p.name, p.description)).map((p) => card({ mark: p.name.slice(0, 1).toUpperCase(), kind: "pl-tile-soft", title: p.name, sub: p.description || `${p.skills.length} skills · ${p.mcp_servers.length} servers`, data: { plugin: p.id },
      action: toggle(p.enabled, (on) => state.client.call("plugin.set_enabled", { id: p.id, enabled: on }).catch((e) => toast(e.message)), `Turn ${p.name} ${p.enabled ? "off" : "on"}`) }));
    const shownInst = tab === "installed" || showAllInstalled ? inst : inst.slice(0, 8);
    const addServer = card({ mark: "+", kind: "pl-tile-ghost", title: "Add an MCP server", sub: "Paste its URL, or the command that starts it", onclick: () => nav.openSettings("mcp") });
    const sk = skills.filter((s) => match(s.name, s.description)).map(skillRow);
    const ru = rules.filter((n) => match(n.title, n.body)).map((n) => card({ mark: "R", kind: "pl-tile-soft", title: n.title || n.body.slice(0, 40), sub: n.body, onclick: () => nav.openSettings("memory") }));

    // Catalog by category (a server already added shows its state in place of the + button).
    const byCat = new Map();
    for (const e of cat) { const k = e.category ?? "Other"; (byCat.get(k) ?? byCat.set(k, []).get(k)).push(e); }
    const cats = [...byCat.entries()].sort((a, b) => (CATEGORY_ORDER.indexOf(a[0]) + 1 || 99) - (CATEGORY_ORDER.indexOf(b[0]) + 1 || 99));
    const catSections = (tab === "all" || tab === "featured") ? cats.map(([name, list]) => section("featured", CATEGORY_LABEL[name] ?? name, null, list.map(catalogRow))) : [];

    put(body,
      catalog === null ? h("div", { class: "sp-empty" }, h("span", {}, "Loading…")) : null,
      recommended(cat),
      tab === "all" && others.length ? section("mcp", "Your servers", others.length, others, null, "Added by you or imported from another app.") : null,
      tab === "mcp" ? section("mcp", "MCP servers", servers.length, [addServer, ...mine]) : null,
      tab === "installed" && mine.length ? section("installed", "MCP servers", mine.length, mine) : null,
      section("installed", "Installed plugins", inst.length, shownInst, inst.length > 8 && tab === "all" ? h("button", { class: "link pl-more", type: "button", onclick: () => { showAllInstalled = !showAllInstalled; render(); } }, showAllInstalled ? "Show fewer" : `Show all ${inst.length}`) : null),
      tab === "installed" && !inst.length && !mine.length ? h("div", { class: "sp-empty" }, h("strong", {}, "Nothing installed yet"), h("span", {}, "Install a server from Featured, or a plugin from a folder with +.")) : null,
      ...catSections,
      section("skills", "Skills", skills.length, sk, null, "Ask in any chat, for example “install the GitHub skill”. Opscode asks whether it is for all projects or only this one."),
      tab === "skills" && !sk.length ? h("div", { class: "sp-empty" }, h("strong", {}, "No skills yet"), h("span", {}, "Ask in a chat to install one, or make one with +.")) : null,
      section("rules", "Rules", rules.length, ru),
      tab === "rules" && !ru.length ? h("div", { class: "sp-empty" }, h("strong", {}, "No rules yet"), h("span", {}, "Kept notes in Memory act as standing rules for every chat.")) : null,
      q() && !cat.length && !inst.length && !mine.length && !sk.length && !ru.length ? h("div", { class: "sp-empty" }, h("strong", {}, "Nothing matches"), h("span", {}, `No plugin, server, skill or rule matches “${search.value.trim()}”.`)) : null);
  }

  // ---- detail pages -------------------------------------------------------------------------------------------------------------
  const crumb = (name) => h("div", { class: "pl-crumb" }, h("button", { class: "pl-crumb-back", type: "button", onclick: () => open(null) }, "Plugins"), icon("chevron-right"), h("span", {}, name));
  const fact = (label, value) => h("div", { class: "pl-fact" }, h("span", { class: "pl-fact-k" }, label), h("span", { class: "pl-fact-v" }, value));
  const engineIcons = () => h("span", { class: "pl-engines" }, ...ENGINES.map(([ic, name]) => h("span", { class: "pl-engine", title: name }, icon(ic))));
  const factsPanel = (...rows) => h("aside", { class: "pl-facts" }, ...rows);

  function renderServer(s) {
    const e = entryOf(s);
    const st = statusOf(s);
    const note = signinNote.get(s.id);
    const target = h("code", { class: "pl-url" }, s.target);
    const more = h("button", { class: "icon-btn", type: "button", "aria-label": "More", title: "More" }, icon("more"));
    more.addEventListener("click", async () => {
      const { openMenu } = await import("./popover.js");
      openMenu(more, [
        { label: "Copy address", icon: "copy", onSelect: () => { void navigator.clipboard?.writeText(s.target).then(() => toast("Copied")).catch(() => {}); } },
        ...(s.plugin ? [] : [{ label: "Remove…", icon: "trash", danger: true, onSelect: async () => {
          const ok = await confirmDialog({ title: `Remove ${s.name}?`, body: s.auth === "oauth" ? "The server and its sign-in are removed from this computer." : "The server and its keys are removed from this computer.", confirm: "Remove", danger: true });
          if (!ok) return;
          try { await state.client.call("mcp.remove", { id: s.id }); toast(`Removed ${s.name}`); open(null); void loadCatalog(); } catch (err) { toast(err.message); }
        } }]),
      ], { up: false, width: 220 });
    });

    // Sign-in
    let signin = null;
    if (s.auth === "oauth") {
      const button = s.signing_in ? h("div", { class: "pl-row-actions" }, h("button", { class: "btn btn-sm", type: "button", disabled: true }, "Waiting for the browser…"), h("button", { class: "btn btn-sm", type: "button", onclick: () => signInCancel(s) }, "Cancel"))
        : s.signed_in ? h("div", { class: "pl-row-actions" }, h("span", { class: "pl-signed" }, icon("check"), "Signed in"), h("button", { class: "btn btn-sm", type: "button", onclick: () => signOut(s) }, "Sign out"))
        : h("button", { class: "btn btn-primary btn-sm", type: "button", dataset: { act: "signin" }, onclick: () => signIn(s) }, "Sign in");
      signin = h("section", { class: "pl-block", dataset: { block: "signin" } }, h("h3", {}, "Sign-in"), button,
        h("p", { class: "field-help" }, s.signed_in ? "Opscode keeps this sign-in on this computer and renews it by itself when the service allows." : "Opens your browser so you can sign in to the service. Opscode keeps the sign-in on this computer. Agents see the tools, never your login."),
        e?.note ? h("p", { class: "field-help pl-note-box" }, e.note) : null,
        note ? h("p", { class: "field-help pl-error", role: "alert" }, note) : null);
    }
    const keys = s.secrets?.length && !s.plugin
      ? h("section", { class: "pl-block", dataset: { block: "keys" } }, h("h3", {}, "Keys"), h("div", { class: "pl-row-actions" }, h("span", { class: "pl-keys" }, s.secrets.join(", ")), h("button", { class: "btn btn-sm", type: "button", onclick: () => editKeys(s) }, "Change…")), s.needs_key ? h("p", { class: "field-help pl-error" }, "The server refused the key. Change it, then try again.") : null)
      : s.needs_key ? h("section", { class: "pl-block", dataset: { block: "keys" } }, h("h3", {}, "Key"), h("p", { class: "field-help" }, "This server wants a key. Add it as an Authorization header from Settings → MCP servers.")) : null;

    // Tools
    const toolsEl = h("div", { class: "pl-tools" });
    const paintTools = () => put(toolsEl,
      s.tools.length ? h("ul", { class: "pl-tool-list" }, ...s.tools.map((t) => h("li", {}, h("code", {}, t.name), t.description ? h("span", {}, t.description.split("\n")[0].slice(0, 160)) : null)))
        : h("p", { class: "field-help" }, s.state === "ready" ? "This server offers no tools." : s.needs_signin ? "Sign in first. Listing starts the server and shows what each tool does." : "Not listed yet. Listing starts the server once and shows what each tool does."));
    paintTools();
    const listBtn = h("button", { class: "link", type: "button", onclick: async () => { listBtn.textContent = "Listing…"; try { await state.client.call("mcp.refresh", { id: s.id }); } catch (err) { toast(err.message); } listBtn.textContent = "List its tools"; } }, "List its tools");
    const idle = s.tools.length ? `~${tokens(s.tools.reduce((n, t) => n + t.name.length + t.description.length + 40, 0)).toLocaleString("en-US")} tokens` : "Once listed";

    const main = h("div", { class: "pl-detail-main" },
      h("div", { class: "pl-detail-title" }, tile(e?.mark ?? "", "", e?.logo ?? "mcp.svg"), h("div", {}, h("h1", {}, s.name), target)),
      e?.description ? h("p", { class: "pl-lead" }, e.description) : null,
      signin, keys,
      h("section", { class: "pl-block", dataset: { block: "tools" } }, h("div", { class: "pl-block-head" }, h("h3", {}, "Tools"), h("span", { class: "grow" }), listBtn), toolsEl));
    const facts = factsPanel(
      h("div", { class: "pl-facts-h" }, "Status"),
      fact("Status", h("span", { class: st.warn ? "pl-warn-text" : "" }, st.text)),
      fact("From", s.plugin ? s.plugin : s.source ?? (s.catalog ? "Opscode's list" : "Added by you")),
      fact("Whose", "Just me"),
      fact("Sign-in", s.auth === "oauth" ? "Browser sign-in" : s.secrets?.length ? "A key" : "None"),
      h("div", { class: "pl-facts-h" }, "Reach"),
      fact("Engines", engineIcons()),
      fact("Idle cost", idle),
      fact("Where it runs", s.transport === "stdio" ? "This computer" : "The service"));
    const head = h("div", { class: "pl-detail-head" }, crumb(s.name), h("span", { class: "grow" }),
      s.plugin ? null : h("label", { class: "pl-onoff" }, h("span", {}, s.enabled ? "On" : "Off"), toggle(s.enabled, (on) => state.client.call("mcp.set_enabled", { id: s.id, enabled: on }).catch((err) => toast(err.message)), `Turn ${s.name} ${s.enabled ? "off" : "on"}`)),
      more);
    return h("div", { class: "pl-detail", dataset: { detail: "server" } }, head, h("div", { class: "pl-detail-cols" }, h("div", { class: "pl-detail-scroll" }, main), facts));
  }

  let skillCache = null;
  function renderSkill(name) {
    const s = (state.skills ?? []).find((x) => x.name === name);
    const crumbEl = crumb(name);
    if (!s) return h("div", { class: "pl-detail", dataset: { detail: "skill" } }, h("div", { class: "pl-detail-head" }, crumbEl), h("div", { class: "sp-empty" }, h("strong", {}, "That skill is gone"), h("span", {}, "It was removed, or it belongs to another project.")));
    const bodyEl = h("div", { class: "pl-instr" });
    const facts = h("div", {});
    const paint = (full) => {
      put(bodyEl, full ? renderMarkdown(full.body, {}) : h("p", { class: "field-help" }, "Loading…"));
      const chars = s.name.length + s.description.length;
      const file = s.scope === "project" ? `.opscode/skills/${s.name}/SKILL.md` : s.scope === "plugin" ? `${s.plugin}/skills/${s.name}/SKILL.md` : `skills/${s.name}/SKILL.md`;
      put(facts, factsPanel(
        h("div", { class: "pl-facts-h" }, "Status"),
        fact("Status", "Always on"),
        fact("Whose", s.scope === "project" ? "This project" : s.scope === "plugin" ? `Plugin: ${s.plugin}` : "Just me, in every project"),
        h("div", { class: "pl-facts-h" }, "Reach"),
        fact("Engines", engineIcons()),
        fact("Idle cost", `~${tokens(chars + 12)} tokens`),
        fact("Command", h("code", {}, `/${s.name}`)),
        h("div", { class: "pl-facts-h" }, "File"),
        h("code", { class: "pl-file" }, file)));
    };
    paint(skillCache?.name === name ? skillCache : null);
    state.client.call("skill.read", { name, ...(state.active ? { workspace_id: state.active } : {}) }).then((r) => { skillCache = { name, body: r.body }; if (view?.kind === "skill" && view.name === name) paint(skillCache); }).catch(() => paint({ body: "(could not read this skill)" }));
    const more = h("button", { class: "icon-btn", type: "button", "aria-label": "More", title: "More" }, icon("more"));
    more.addEventListener("click", async () => {
      if (s.scope === "plugin") return toast("This skill comes from a plugin. Turn the plugin off to stop using it.");
      const { openMenu } = await import("./popover.js");
      const other = s.scope === "project" ? "user" : "project";
      openMenu(more, [
        { label: other === "user" ? "Move to all projects" : "Move to this project", icon: "folder", onSelect: async () => {
          if (other === "project" && !state.active) return toast("Open a project first.");
          try {
            const full = skillCache?.name === name ? skillCache : await state.client.call("skill.read", { name, ...(state.active ? { workspace_id: state.active } : {}) });
            await state.client.call("skill.save", { scope: other, ...(state.active ? { workspace_id: state.active } : {}), name, description: s.description, body: full.body });
            await state.client.call("skill.delete", { scope: s.scope, ...(state.active ? { workspace_id: state.active } : {}), name });
            toast(other === "user" ? `${name} now works in every project` : `${name} is now only in this project`);
          } catch (err) { toast(err.message); }
        } },
        { label: "Remove…", icon: "trash", danger: true, onSelect: async () => {
          const ok = await confirmDialog({ title: `Remove ${name}?`, body: s.scope === "project" ? "The skill is deleted from this project's .opscode/skills folder." : "The skill is deleted from your own skills, for every project.", confirm: "Remove", danger: true });
          if (!ok) return;
          try { await state.client.call("skill.delete", { scope: s.scope, ...(state.active ? { workspace_id: state.active } : {}), name }); toast(`Removed ${name}`); open(null); } catch (err) { toast(err.message); }
        } },
      ], { up: false, width: 240 });
    });
    return h("div", { class: "pl-detail", dataset: { detail: "skill" } },
      h("div", { class: "pl-detail-head" }, crumbEl, h("span", { class: "grow" }), s.scope === "plugin" ? null : more),
      h("div", { class: "pl-detail-cols" },
        h("div", { class: "pl-detail-scroll" }, h("div", { class: "pl-detail-main" }, h("h1", {}, name), h("p", { class: "pl-lead" }, s.description), h("p", { class: "pl-note" }, "The engines read this file themselves, so it is on while it is there."), h("h3", { class: "pl-instr-h" }, "Instructions"), bodyEl)),
        facts));
  }

  // ---- page --------------------------------------------------------------------------------------------------------------------
  const detailHost = h("div", { class: "pl-detail-host" });
  root.append(detailHost);
  function open(next) { view = next; if (!next) skillCache = null; render(); }

  function render() {
    paintSetup();
    const detail = view?.kind === "server" ? (state.mcp ?? []).find((x) => x.id === view.id) : null;
    if (view?.kind === "server" && !detail) view = null;
    const showDetail = !!view;
    listHead.hidden = listSub.hidden = scroll.hidden = showDetail;
    detailHost.hidden = !showDetail;
    if (showDetail) put(detailHost, view.kind === "server" ? renderServer(detail) : renderSkill(view.name));
    else { put(detailHost); renderList(); }
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
  return { el: root, show: () => { if (catalog === null) void loadCatalog(); else render(); }, render, refresh: loadCatalog, signInDone, openServer: (id) => open({ kind: "server", id }) };
}
