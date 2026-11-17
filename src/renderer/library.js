// The Library page: the person's existing apps, what features each already has and
// where, and a search that answers "do we already have X?". Plain on purpose.
// Nothing is indexed until an app is added; indexing is read-only and uses no model.

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { confirmDialog } from "./dialogs.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const ago = (iso) => { const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000); return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min ago` : s < 86400 ? `${Math.floor(s / 3600)} h ago` : `${Math.floor(s / 86400)} d ago`; };
const LAYER = { backend: "Backend", app: "App", web: "Web", db: "Database", other: "Other" };
const chip = (layer) => h("span", { class: `lb-chip lb-${layer}` }, LAYER[layer] ?? layer);
const short = (p) => p.replace(/^\/Users\/[^/]+/, "~");

export function createLibraryPage({ bridge }) {
  let apps = [];
  let suggestions = [];
  let sel = null; // { appId, featureId? }
  let detail = null;
  let feature = null;
  let query = "";
  let hits = null;
  let filter = "";
  const progress = new Map();

  const left = h("aside", { class: "lb-left" });
  const main = h("div", { class: "lb-main" });
  const root = h("div", { class: "lb-page pane-surface", hidden: true }, left, h("div", { class: "lb-scroll" }, main));

  async function load() {
    try { ({ apps, suggestions } = await state.client.call("library.list", {})); } catch (e) { toast(`Couldn't read the Library: ${e.message}`); }
    if (sel && !apps.some((a) => a.id === sel.appId)) { sel = null; detail = null; feature = null; }
    renderLeft();
    await renderMain();
  }

  async function addFolder(path) {
    try {
      const { app } = await state.client.call("library.add", { path });
      sel = { appId: app.id }; detail = null; feature = null; hits = null;
      await load();
    } catch (e) { toast(`Couldn't add: ${e.message}`); }
  }

  function renderLeft() {
    const apps_ = apps.map((a) => h("button", { class: "lb-app", type: "button", dataset: { app: a.id }, "aria-current": String(sel?.appId === a.id), onclick: () => { sel = { appId: a.id }; hits = null; feature = null; detail = null; renderLeft(); void renderMain(); } },
      h("span", { class: "lb-app-name" }, a.name),
      h("span", { class: "lb-app-sub" }, a.status === "indexing" ? `Reading… ${progress.get(a.id) ?? ""}` : a.status === "error" ? "Couldn't read it" : `${a.features ?? 0} features · ${(a.files ?? 0).toLocaleString()} files`)));
    put(left,
      h("div", { class: "lb-left-head" }, icon("layers"), h("span", { class: "grow" }, "Library"), h("button", { class: "btn btn-sm", type: "button", onclick: async () => { const p = await bridge?.pickFolder(); if (p) await addFolder(p); } }, icon("plus"), "Add app")),
      h("p", { class: "lb-left-note" }, "Your existing apps, read once so Opscode knows what you already have. Read-only; no model is used."),
      apps_.length ? h("div", { class: "lb-apps" }, ...apps_) : h("p", { class: "lb-empty-s" }, "No apps yet."),
      suggestions.length ? h("div", { class: "lb-sugg" }, h("div", { class: "lb-sugg-h" }, "Found in Documents"), ...suggestions.slice(0, 12).map((s) => h("div", { class: "lb-sugg-row" }, h("span", { class: "lb-sugg-n", title: short(s.path) }, s.name), h("button", { class: "btn btn-sm", type: "button", onclick: () => void addFolder(s.path) }, "Add")))) : null);
  }

  async function runSearch(q) {
    query = q;
    if (!q.trim()) { hits = null; return renderMain(); }
    try { hits = (await state.client.call("library.search", { query: q, limit: 15 })).hits; } catch (e) { toast(e.message); }
    sel = hits ? null : sel;
    await renderMain();
  }

  const searchBox = () => {
    const input = h("input", { class: "input lb-search", type: "search", placeholder: "Do we already have…  e.g. loyalty points, cart, vendor payouts", value: query, "aria-label": "Search your apps", autocomplete: "off", spellcheck: false });
    let t = 0;
    input.addEventListener("input", () => { clearTimeout(t); t = setTimeout(() => void runSearch(input.value), 200); });
    return h("div", { class: "lb-searchbar" }, icon("search"), input);
  };

  function hitRow(x) {
    return h("button", { class: "lb-hit", type: "button", dataset: { feature: x.feature }, onclick: async () => { sel = { appId: x.app_id, featureId: x.feature }; hits = null; query = ""; renderLeft(); await renderMain(); } },
      h("div", { class: "lb-hit-top" }, h("strong", {}, x.name), h("span", { class: "lb-hit-app" }, x.app), h("span", { class: "grow" }), ...x.layers.map((l) => chip(l.layer))),
      h("div", { class: "lb-hit-why" }, x.why.join(" · ")));
  }

  async function renderMain() {
    if (hits) {
      return put(main, searchBox(), h("h2", { class: "lb-h" }, hits.length ? `${hits.length} place${hits.length === 1 ? "" : "s"} in your apps` : "Nothing like that in your apps"),
        hits.length ? h("div", { class: "lb-hits" }, ...hits.map(hitRow)) : h("p", { class: "lb-empty-s" }, `No app has "${query}". That is a gap: it would be built new.`));
    }
    if (!sel) {
      return put(main, searchBox(), apps.length ? h("p", { class: "lb-empty" }, "Pick an app on the left, or search all of them.") : h("div", { class: "lb-hero" }, icon("layers"), h("h2", {}, "Teach Opscode what you already have"), h("p", {}, "Add your existing apps (grocery, meat, e-commerce, laundry…). Opscode reads their folders once, with no model, and then knows which features exist and where. New projects reuse them instead of starting from zero."), h("button", { class: "btn", type: "button", onclick: async () => { const p = await bridge?.pickFolder(); if (p) await addFolder(p); } }, icon("plus"), "Add an app")));
    }
    const app = apps.find((a) => a.id === sel.appId);
    if (!app) return;
    if (app.status === "indexing") return put(main, searchBox(), h("div", { class: "lb-hero" }, h("span", { class: "ut-pulse" }), h("h2", {}, `Reading ${app.name}…`), h("p", {}, "Files, imports, routes and tables are being read. Nothing leaves this computer.")));
    if (app.status === "error") return put(main, searchBox(), h("div", { class: "lb-hero" }, h("h2", {}, "Couldn't read this app"), h("p", {}, app.error ?? ""), h("button", { class: "btn", type: "button", onclick: () => void reindex(app) }, "Try again")));
    try { detail = (await state.client.call("library.get", { app_id: app.id })); } catch (e) { return toast(e.message); }
    feature = sel.featureId ? (await state.client.call("library.feature", { app_id: app.id, feature_id: sel.featureId }).catch(() => null)) : null;
    const fl = filter.trim().toLowerCase();
    const feats = detail.features.filter((f) => !fl || f.name.toLowerCase().includes(fl) || f.id.includes(fl));
    put(main, searchBox(),
      h("header", { class: "lb-head" },
        h("div", { class: "grow" }, h("h2", {}, app.name), h("div", { class: "lb-path", title: app.path }, short(app.path))),
        h("button", { class: "btn btn-sm", type: "button", onclick: () => void reindex(app) }, icon("reload"), "Read again"),
        h("button", { class: "btn btn-sm", type: "button", onclick: async () => { if (await confirmDialog({ title: `Remove ${app.name} from the Library?`, body: "Only Opscode's notes about it are deleted. The app's folder is not touched.", confirm: "Remove", danger: true })) { await state.client.call("library.remove", { app_id: app.id }); sel = null; await load(); } } }, "Remove")),
      h("div", { class: "lb-pkgs" }, ...detail.packages.map((p) => h("div", { class: "lb-pkg" }, chip(p.layer), h("span", { class: "lb-pkg-n" }, p.name), h("span", { class: "lb-pkg-s" }, p.stack.slice(0, 5).join(" · ") || p.kind), h("span", { class: "lb-pkg-f" }, `${p.files.toLocaleString()} files`)))),
      h("p", { class: "lb-meta" }, `Read ${app.indexed_at ? ago(app.indexed_at) : ""}. ${detail.coverage.resolved.toLocaleString()} of ${detail.coverage.relative.toLocaleString()} imports linked${detail.coverage.unresolved ? `, ${detail.coverage.unresolved} could not be (see the list below the features)` : ""}.${app.truncated ? " Very large: only the first 40,000 files were read." : ""}`),
      h("div", { class: "lb-cols" },
        h("section", { class: "lb-features" },
          h("div", { class: "lb-feat-head" }, h("h3", {}, `${detail.features.length} features`), h("input", { class: "input lb-filter", type: "search", placeholder: "Filter", "aria-label": "Filter features", value: filter, oninput: (e) => { filter = e.target.value; void renderMain(); } })),
          h("div", { class: "lb-flist" }, ...feats.map((f) => h("button", { class: "lb-frow", type: "button", dataset: { feature: f.id }, "aria-current": String(sel.featureId === f.id), onclick: () => { sel = { appId: app.id, featureId: f.id }; void renderMain(); } },
            h("span", { class: "lb-frow-n" }, f.name), h("span", { class: "grow" }), ...f.layers.map((l) => chip(l.layer)), h("span", { class: "lb-frow-c" }, `${f.file_count}`)))),
          detail.coverage.unresolved ? h("details", { class: "lb-unres" }, h("summary", {}, `${detail.coverage.unresolved} imports could not be linked`), h("ul", {}, ...detail.coverage.unresolved_sample.map((u) => h("li", {}, u)))) : null),
        feature ? featurePane(app, feature) : h("section", { class: "lb-fpane lb-fpane-empty" }, h("p", {}, "Pick a feature to see where it lives: its files by layer, routes and tables."))));
  }

  function featurePane(app, { feature: f, related }) {
    return h("section", { class: "lb-fpane", dataset: { open: f.id } },
      h("h3", {}, f.name),
      h("div", { class: "lb-layers" }, ...f.layers.map((l) => h("details", { class: "lb-layer", open: f.layers.length <= 2 },
        h("summary", {}, chip(l.layer), h("span", { class: "lb-layer-p" }, l.package), h("span", { class: "grow" }), h("span", { class: "lb-frow-c" }, `${l.file_count} files`)),
        h("p", { class: "lb-why" }, l.reason),
        h("ul", { class: "lb-files" }, ...l.files.slice(0, 40).map((p) => h("li", { title: p }, p)), l.file_count > 40 ? h("li", { class: "lb-more" }, `…and ${l.file_count - 40} more`) : null)))),
      f.routes.length ? h("div", { class: "lb-sec" }, h("h4", {}, "Routes"), ...f.routes.slice(0, 20).map((r) => h("div", { class: "lb-route", title: r.reason }, h("span", { class: "lb-method" }, r.method), h("span", { class: "lb-route-p" }, r.path)))) : null,
      f.tables.length ? h("div", { class: "lb-sec" }, h("h4", {}, "Database tables"), ...f.tables.slice(0, 20).map((t) => h("div", { class: "lb-route", title: t.reason }, h("span", { class: "lb-method" }, "TABLE"), h("span", { class: "lb-route-p" }, t.name), h("span", { class: "lb-tr" }, t.reason)))) : null,
      f.symbols.length ? h("div", { class: "lb-sec" }, h("h4", {}, "Names in it"), h("p", { class: "lb-syms" }, f.symbols.slice(0, 18).join(", "))) : null,
      related.length ? h("div", { class: "lb-sec" }, h("h4", {}, "Works closely with"), h("div", { class: "lb-rel" }, ...related.map((r) => h("button", { class: "lb-relbtn", type: "button", onclick: () => { sel = { appId: app.id, featureId: r.id }; void renderMain(); } }, r.name, h("span", {}, `${r.links}`))))) : null);
  }

  async function reindex(app) { try { await state.client.call("library.reindex", { app_id: app.id }); } catch (e) { toast(e.message); } await load(); }

  return {
    el: root,
    show() { void load(); },
    changed(list) { apps = list ?? apps; if (!root.hidden) { renderLeft(); if (!hits) void renderMain(); } },
    progress(p) { progress.set(p.app_id, p.files); if (!root.hidden) renderLeft(); },
  };
}
