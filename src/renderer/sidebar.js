// The Projects part of the sidebar: each project with its chats, a mode chat (GODMODE / WARLORD / SHINOBI)
// as one named row with its worker chats nested under it, delete, unlink, and showing or hiding the history.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, readPref, writePref } from "./store.js";
import { MODE_INFO, modeEmblem } from "./conductor.js";
import { openMenu } from "./popover.js";
import { chiefLabel } from "./names.js";

/** chief id -> its latest board view ({ items }); the workers' states come from it. */
export const chiefViews = new Map();

const SHOWN = 8; // chats listed per project before "Show more"
const load = (key) => { try { return new Set(JSON.parse(readPref(key) ?? "[]")); } catch { return new Set(); } };
const closed = load("sb-closed"); // projects whose chat list is hidden
const openMode = new Set(); // mode chats whose workers are listed
const allShown = new Set(); // projects showing every chat, not only the latest few
let filter = readPref("sb-filter") === "active" ? "active" : "all";
let lastActive = null;

const save = () => writePref("sb-closed", JSON.stringify([...closed]));
export const isProjectOpen = (id) => !closed.has(id);
export function setProjectOpen(id, open) { if (open) closed.delete(id); else closed.add(id); save(); }
export function setAllOpen(open) { closed.clear(); if (!open) for (const w of state.workspaces) closed.add(w.id); save(); }
export const getFilter = () => filter;
export function setFilter(f) { filter = f; writePref("sb-filter", f); }
/** Lists a mode chat's workers (when its worker is opened from somewhere else). */
export function revealMode(id) { openMode.add(id); }
/** The active project opens by itself when it changes, but can then be hidden. */
export function noteActive(id) { if (id && id !== lastActive) { closed.delete(id); save(); } lastActive = id; }

// ---- workers ----------------------------------------------------------------------------------------------
const WORKER = { running: "Working", needs: "Needs you", done: "Done", failed: "Failed", stopped: "Stopped" };
/** running | needs | done | failed | stopped */
export function workerState(c) {
  if (state.running.has(c.id)) return "running";
  const view = chiefViews.get(c.chief?.id);
  const it = view?.items.find((i) => i.id === c.chief.item_id);
  const ic = it?.chats.find((x) => x.chat_id === c.id);
  if (ic?.state === "needs_you") return "needs";
  if (ic?.state === "failed") return "failed";
  if (ic?.state === "running") return "running";
  if (ic?.state === "stopped") return "stopped";
  return "done";
}
export const workersOf = (chiefId) => state.chats.filter((c) => c.chief?.id === chiefId && c.chief.role !== "home").sort((a, b) => a.created_at.localeCompare(b.created_at));

/** "2 nested · 1 working · 1 needs you" */
function summary(workers) {
  const st = workers.map(workerState);
  const n = (k) => st.filter((x) => x === k).length;
  return [`${workers.length} nested`, n("running") ? `${n("running")} working` : "", n("needs") ? `${n("needs")} ${n("needs") === 1 ? "needs" : "need"} you` : "", n("failed") ? `${n("failed")} failed` : ""].filter(Boolean).join(" · ");
}

/**
 * ctx: { selectChat, openChief, newChat, selectProject, deleteChat, deleteMode, unlink, needs(chiefId), rerender }
 * Returns the project rows and the menus the section header uses.
 */
export function createProjects(ctx) {
  const key = (e, fn) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); fn(); } };
  const moreBtn = (label, items) => h("button", { class: "remove sb-more", type: "button", title: label, "aria-label": label, onclick: (e) => { e.stopPropagation(); openMenu(e.currentTarget, items(), { up: false, width: 230 }); } }, icon("more"));
  const current = (c) => state.page === "app" && state.active === c.workspace_id && state.chatSel[c.workspace_id] === c.id;

  const chatRow = (c, nested = false) => {
    const worker = !!c.chief && c.chief.role !== "home";
    const st = worker ? workerState(c) : state.waiting.has(c.id) ? "needs" : state.running.has(c.id) ? "running" : "";
    const label = c.title || "New chat";
    return h("div", { class: `sidebar-item sb-chat${nested ? " sb-nested" : ""}`, role: "button", tabindex: 0, title: worker || st === "needs" ? `${label} · ${WORKER[st]}` : label, dataset: { chat: c.id, ...(worker || st === "needs" ? { state: st } : {}) }, "aria-current": String(current(c)),
      onclick: () => ctx.selectChat(c.id), onkeydown: (e) => key(e, () => ctx.selectChat(c.id)) },
      st === "running" ? h("span", { class: "spin", title: "Working…" }) : st ? h("span", { class: "sb-state", dataset: { s: st }, title: WORKER[st] }) : null,
      h("span", { class: "sidebar-label" }, label),
      c.mode === "full" ? h("span", { class: "mode-dot", title: "Full access" }) : null,
      moreBtn(`More for ${label}`, () => [{ label: "Delete chat…", icon: "trash", danger: true, onSelect: () => void ctx.deleteChat(c) }]));
  };

  /** A mode chat: its emblem and name; its workers nest under it. */
  const modeRow = (c) => {
    const workers = workersOf(c.id);
    const label = chiefLabel(c);
    const here = state.page === "chief" && state.chiefSel === c.id;
    const inside = workers.some((w) => current(w));
    const open = workers.length > 0 && (openMode.has(c.id) || inside);
    const needs = ctx.needs(c.id);
    const toggle = () => { if (open) openMode.delete(c.id); else openMode.add(c.id); ctx.rerender(); };
    const row = h("div", { class: "sidebar-item sb-chat sb-conductor", role: "button", tabindex: 0, title: `${MODE_INFO[c.mode]?.name ?? c.name}: ${label}`, dataset: { chief: c.id, mode: c.mode }, "aria-current": String(here), "aria-expanded": workers.length ? String(open) : undefined,
      onclick: () => ctx.openChief(c.id), onkeydown: (e) => key(e, () => ctx.openChief(c.id)) },
      modeEmblem(c.mode, 18, "mode-emblem mode-emblem-sm"),
      h("span", { class: "sidebar-label" }, label),
      state.running.has(c.chat_id) ? h("span", { class: "spin", title: "Working…" }) : null,
      needs ? h("span", { class: "sb-badge", title: `${needs} waiting for you` }, String(needs)) : null,
      moreBtn(`More for ${label}`, () => [{ label: workers.length ? `Delete chat and ${workers.length} nested…` : "Delete chat…", icon: "trash", danger: true, onSelect: () => void ctx.deleteMode(c, workers) }]),
      workers.length ? h("button", { class: "sb-expand", type: "button", title: open ? "Hide nested chats" : "Show nested chats", "aria-label": `${open ? "Hide" : "Show"} nested chats of ${label}`, "aria-expanded": String(open), onclick: (e) => { e.stopPropagation(); toggle(); } }, icon("chevron-right")) : null);
    const nest = !workers.length ? null : open
      ? h("div", { class: "sb-nest", dataset: { open: "true" } }, ...workers.filter((w) => filter === "all" || workerState(w) !== "done" || current(w)).map((w) => chatRow(w, true)))
      : h("button", { class: "sb-nest sb-nest-sum", type: "button", dataset: { open: "false" }, title: "Show nested chats", onclick: toggle }, h("span", { class: "sb-nested-text" }, summary(workers)));
    return h("div", { class: "sb-group", dataset: { group: c.id } }, row, nest);
  };

  /** What the project lists, newest first: plain chats and mode chats (a mode chat's age includes its workers'). */
  const entries = (w) => {
    const plain = state.chats.filter((c) => c.workspace_id === w.id && !c.origin && !(c.chief && state.chiefs.some((x) => x.id === c.chief.id && x.mode))).map((c) => ({ at: c.updated_at, active: state.running.has(c.id), chat: c }));
    const modes = state.chiefs.filter((c) => c.mode && c.project_ids[0] === w.id).map((c) => {
      const workers = workersOf(c.id);
      const home = state.chats.find((x) => x.id === c.chat_id);
      const at = [home?.updated_at ?? c.created_at, ...workers.map((x) => x.updated_at)].sort().at(-1);
      const active = state.running.has(c.chat_id) || ctx.needs(c.id) > 0 || workers.some((x) => workerState(x) === "running" || workerState(x) === "needs");
      return { at, active, mode: c };
    });
    return [...plain, ...modes].sort((a, b) => b.at.localeCompare(a.at)).filter((e) => filter === "all" || e.active || (e.chat && current(e.chat)) || (e.mode && state.chiefSel === e.mode.id && state.page === "chief"));
  };

  const projectRow = (w) => {
    const open = isProjectOpen(w.id);
    const all = entries(w);
    const total = state.chats.filter((c) => c.workspace_id === w.id && !c.origin).length + state.chiefs.filter((c) => c.mode && c.project_ids[0] === w.id).length;
    const more = allShown.has(w.id) ? all : all.slice(0, SHOWN);
    const list = open ? h("div", { class: "sb-chats" },
      ...(more.map((e) => (e.mode ? modeRow(e.mode) : chatRow(e.chat)))),
      all.length > SHOWN ? h("button", { class: "sb-showmore", type: "button", onclick: () => { if (allShown.has(w.id)) allShown.delete(w.id); else allShown.add(w.id); ctx.rerender(); } }, allShown.has(w.id) ? "Show less" : `Show ${all.length - SHOWN} more`) : null,
      all.length === 0 ? h("div", { class: "sidebar-note" }, total === 0 ? "No chats yet." : "Nothing active right now.") : null) : null;
    return h("div", { class: "sb-project", dataset: { open: String(open), workspace: w.id } },
      h("div", { class: "sidebar-item sb-project-row", role: "button", tabindex: 0, title: w.path, "aria-current": String(state.page === "app" && w.id === state.active && (state.chatSel[w.id] ?? "new") === "new"), "aria-expanded": String(open),
        onclick: () => {
          // The open project's row shows or hides its chats; another project's row opens it and goes there.
          if (w.id === state.active && state.page === "app") { setProjectOpen(w.id, !open); ctx.rerender(); }
          else { setProjectOpen(w.id, true); ctx.selectProject(w.id); }
        },
        onkeydown: (e) => key(e, () => e.currentTarget.click()) },
        icon("folder"), h("span", { class: "sidebar-label sb-project-name" }, w.name), h("button", { class: "sb-caret", type: "button", title: open ? "Hide chats" : "Show chats", "aria-label": `${open ? "Hide" : "Show"} chats of ${w.name}`, "aria-expanded": String(open), onclick: (e) => { e.stopPropagation(); setProjectOpen(w.id, !open); ctx.rerender(); } }, icon("chevron-down")), h("span", { class: "grow" }),
        !open && total ? h("span", { class: "sb-count", title: `${total} hidden chat${total === 1 ? "" : "s"}` }, String(total)) : null,
        h("button", { class: "remove sb-project-new", type: "button", title: `New chat in ${w.name}`, "aria-label": `New chat in ${w.name}`, onclick: (e) => { e.stopPropagation(); ctx.newChatIn(w); } }, icon("plus")),
        moreBtn(`More for ${w.name}`, () => [
          { label: "New chat", icon: "plus", onSelect: () => ctx.newChatIn(w) },
          { label: open ? "Hide chats" : "Show chats", icon: open ? "chevron-up" : "chevron-down", onSelect: () => { setProjectOpen(w.id, !open); ctx.rerender(); } },
          { separator: true },
          { label: "Unlink project…", icon: "x", danger: true, onSelect: () => void ctx.unlink(w) },
        ])),
      list);
  };

  return {
    rows: () => state.workspaces.map(projectRow),
    /** The filter button in the Projects header. */
    filterMenu: (anchor) => openMenu(anchor, [
      { heading: "Show chats" },
      { label: "All chats", checked: filter === "all", onSelect: () => { setFilter("all"); ctx.rerender(); } },
      { label: "Only working or needing you", checked: filter === "active", onSelect: () => { setFilter("active"); ctx.rerender(); } },
      { separator: true },
      { label: "Hide every project's chats", icon: "chevron-right", onSelect: () => { setAllOpen(false); ctx.rerender(); } },
      { label: "Show every project's chats", icon: "chevron-down", onSelect: () => { setAllOpen(true); ctx.rerender(); } },
    ], { up: false, width: 250 }),
  };
}
