// Terminal surface: tabs over real PTYs (term.*), rendered with xterm.js
// (vendored as classic scripts: window.Terminal / window.FitAddon).

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";

const cssVar = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

export function createTerminals(workspace) {
  const tabs = h("div", { class: "term-bar" });
  const host = h("div", { class: "term-host" });
  const root = h("div", { class: "term pane-surface" }, tabs, host);
  const items = new Map(); // terminal_id -> { info, term, fit, el, attached, exited }
  let current = null;
  let fitTimer = null;

  const theme = () => ({ background: cssVar("--term-bg") || "#19191b", foreground: cssVar("--term-fg") || "#e1e3e8", cursor: cssVar("--term-fg") || "#e1e3e8" });

  function renderTabs() {
    const els = [...items.values()].map((it, i) =>
      h(
        "div",
        { class: "term-tab", role: "tab", "aria-selected": String(it.info.terminal_id === current), onclick: () => select(it.info.terminal_id) },
        icon("terminal"),
        `Shell ${i + 1}`,
        h("button", { class: "x", type: "button", title: "Close terminal", "aria-label": "Close terminal", onclick: (e) => { e.stopPropagation(); void close(it.info.terminal_id); } }, icon("x")),
      ),
    );
    els.push(h("button", { class: "icon-btn", type: "button", title: "New terminal", "aria-label": "New terminal", onclick: () => void create() }, icon("plus")));
    tabs.replaceChildren(...els);
  }

  function mount(info) {
    const el = h("div", { style: "height:100%;display:none" });
    host.append(el);
    const term = new window.Terminal({ fontFamily: cssVar("--font-mono"), fontSize: 12.5, cursorBlink: true, scrollback: 5000, theme: theme(), allowProposedApi: false });
    const fit = new window.FitAddon.FitAddon();
    term.loadAddon(fit);
    term.open(el);
    const it = { info, term, fit, el, exited: !info.running };
    term.onData((data) => {
      if (!it.exited) state.client.call("term.write", { terminal_id: info.terminal_id, data }).catch(() => {});
    });
    items.set(info.terminal_id, it);
    return it;
  }

  async function adopt(info) {
    const it = mount(info);
    try {
      const res = await state.client.call("term.attach", { terminal_id: info.terminal_id });
      if (res.scrollback) it.term.write(res.scrollback);
    } catch (err) {
      it.exited = true;
      it.term.write(`\r\n[cannot attach: ${err.message}]\r\n`);
    }
    return it;
  }

  async function create() {
    try {
      const info = await state.client.call("term.open", { workspace_id: workspace.id, cols: 80, rows: 24 });
      await adopt(info);
      select(info.terminal_id);
    } catch (err) {
      toast(err.message);
    }
  }

  async function close(id) {
    try { await state.client.call("term.close", { terminal_id: id }); } catch { /* already gone */ }
    remove(id);
  }

  function remove(id) {
    const it = items.get(id);
    if (!it) return;
    it.term.dispose();
    it.el.remove();
    items.delete(id);
    if (current === id) current = items.keys().next().value ?? null;
    if (current) select(current);
    else renderTabs();
    if (items.size === 0 && root.isConnected && !root.hidden) void create();
  }

  function select(id) {
    current = id;
    for (const [k, it] of items) it.el.style.display = k === id ? "block" : "none";
    renderTabs();
    queueMicrotask(refit);
    items.get(id)?.term.focus();
  }

  function refit() {
    clearTimeout(fitTimer);
    fitTimer = setTimeout(() => {
      const it = items.get(current);
      if (!it || root.closest("[hidden]") || !host.clientWidth) return;
      try { it.fit.fit(); } catch { return; }
      const { cols, rows } = it.term;
      if (cols !== it.info.cols || rows !== it.info.rows) {
        it.info.cols = cols;
        it.info.rows = rows;
        state.client.call("term.resize", { terminal_id: it.info.terminal_id, cols, rows }).catch(() => {});
      }
    }, 40);
  }
  new ResizeObserver(refit).observe(host);

  new MutationObserver(() => { for (const it of items.values()) it.term.options.theme = theme(); }).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

  return {
    el: root,
    async load() {
      if (items.size > 0) return;
      try {
        const { terminals } = await state.client.call("term.list", { workspace_id: workspace.id });
        for (const info of terminals) await adopt(info);
        if (items.size > 0) select(items.keys().next().value);
        else await create();
      } catch (err) {
        toast(err.message);
      }
    },
    show() { refit(); items.get(current)?.term.focus(); },
    onOutput({ terminal_id, data }) { items.get(terminal_id)?.term.write(data); },
    onExit({ terminal_id, exit_code }) {
      const it = items.get(terminal_id);
      if (!it) return;
      it.exited = true;
      it.term.write(`\r\n\x1b[2m[process exited${exit_code === null ? "" : ` with code ${exit_code}`}]\x1b[0m\r\n`);
    },
    owns: (id) => items.has(id),
    reset() { for (const id of [...items.keys()]) { const it = items.get(id); it.term.dispose(); it.el.remove(); items.delete(id); } current = null; },
  };
}

/**
 * One PTY in a side-panel tab. params: { terminalId?, command? }.
 * Attaches to terminalId when it is still alive; otherwise opens a new one
 * (a command tab whose process is gone shows a Run again button instead).
 */
export function createTerminalView(workspace, params, { onStarted, onTitle } = {}) {
  const host = h("div", { class: "term-host" });
  const bar = h("div", { class: "term-status", hidden: true });
  const root = h("div", { class: "term pane-surface" }, bar, host);
  let term = null;
  let fit = null;
  let info = null;
  let exited = false;
  let fitTimer = null;
  const theme = () => ({ background: cssVar("--term-bg") || "#19191b", foreground: cssVar("--term-fg") || "#e1e3e8", cursor: cssVar("--term-fg") || "#e1e3e8" });

  function ensureTerm() {
    if (term) { term.reset(); return; }
    term = new window.Terminal({ fontFamily: cssVar("--font-mono"), fontSize: 12.5, cursorBlink: true, scrollback: 5000, theme: theme(), allowProposedApi: false });
    fit = new window.FitAddon.FitAddon();
    term.loadAddon(fit);
    term.open(host);
    term.onData((data) => { if (info && !exited) state.client.call("term.write", { terminal_id: info.terminal_id, data }).catch(() => {}); });
  }

  function showExit(code) {
    exited = true;
    bar.hidden = false;
    bar.replaceChildren(h("span", { class: "grow" }, code === null || code === undefined ? "Process exited." : `Exited with code ${code}.`),
      params.command ? h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => void start(true) }, icon("reload"), "Run again") : h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => void start(true) }, "New shell"));
  }

  async function start(fresh = false) {
    ensureTerm();
    exited = false;
    bar.hidden = true;
    if (!fresh && params.terminalId) {
      try {
        const res = await state.client.call("term.attach", { terminal_id: params.terminalId });
        info = res;
        if (res.scrollback) term.write(res.scrollback);
        if (!res.running) showExit(res.exit_code);
        queueMicrotask(refit);
        return;
      } catch { /* gone (runtime restarted): start a new one */ }
    }
    try {
      info = await state.client.call("term.open", { workspace_id: workspace.id, cols: 80, rows: 24, ...(params.command ? { command: params.command } : {}) });
      params.terminalId = info.terminal_id;
      onStarted?.(info.terminal_id);
      onTitle?.(params.command ?? "Terminal");
      queueMicrotask(refit);
    } catch (err) {
      term.write(`\r\n[could not start: ${err.message}]\r\n`);
    }
  }

  function refit() {
    clearTimeout(fitTimer);
    fitTimer = setTimeout(() => {
      if (!term || !fit || root.closest("[hidden]") || !host.clientWidth) return;
      try { fit.fit(); } catch { return; }
      if (info && !exited && (term.cols !== info.cols || term.rows !== info.rows)) {
        info.cols = term.cols;
        info.rows = term.rows;
        state.client.call("term.resize", { terminal_id: info.terminal_id, cols: term.cols, rows: term.rows }).catch(() => {});
      }
    }, 40);
  }
  new ResizeObserver(refit).observe(host);
  new MutationObserver(() => { if (term) term.options.theme = theme(); }).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

  void start();
  return {
    el: root,
    show() { refit(); term?.focus(); },
    owns: (id) => info?.terminal_id === id,
    onOutput({ data }) { term?.write(data); },
    onExit({ exit_code }) { showExit(exit_code); },
    reconnect() { if (info && !exited) void start(); },
    dispose(closeProcess) {
      if (closeProcess && info && !exited) state.client.call("term.close", { terminal_id: info.terminal_id }).catch(() => {});
      term?.dispose();
    },
  };
}
