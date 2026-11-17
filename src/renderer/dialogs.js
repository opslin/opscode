// Modal dialogs: Settings and the command palette.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";

let openLayer = null;
let onCloseHook = null;

export function closeDialog() {
  const hook = onCloseHook;
  onCloseHook = null;
  openLayer?.remove();
  openLayer = null;
  hook?.();
}

/** `onClose` runs when this dialog goes away any way (Esc, backdrop, a button, another dialog replacing it). */
export function showDialog(content, { onClose } = {}) {
  const el = layer(content, { center: true });
  onCloseHook = onClose ?? null;
  return el;
}

function layer(content, { center = false, top = false } = {}) {
  closeDialog();
  const el = h("div", { class: "overlay", dataset: top ? { top: "" } : center ? { center: "" } : {}, onmousedown: (e) => { if (e.target === el) closeDialog(); } }, content);
  el.addEventListener("keydown", (e) => { if (e.key === "Escape") { e.stopPropagation(); closeDialog(); } });
  document.body.append(el);
  openLayer = el;
  return el;
}

/**
 * Asks before something that can't be undone. A small card drops in at the top middle of the window (like the Claude and Codex
 * apps), over a light veil. Resolves true on the confirm button or Enter, false on Cancel, Esc or a click outside.
 * `danger` paints the confirm button red; `cancel` renames the other button.
 */
export function confirmDialog({ title, body, confirm = "Confirm", cancel = "Cancel", danger = false }) {
  return new Promise((resolve) => {
    let settled = false;
    const done = (v) => { if (settled) return; settled = true; closeDialog(); resolve(v); };
    const ok = h("button", { class: `btn btn-sm ${danger ? "btn-danger" : "btn-primary"}`, type: "button", dataset: { act: "confirm" }, onclick: () => done(true) }, confirm);
    const no = h("button", { class: "btn btn-sm", type: "button", dataset: { act: "cancel" }, onclick: () => done(false) }, cancel);
    const el = layer(h("div", { class: "dialog confirm-top", role: "alertdialog", "aria-modal": "true", "aria-label": title },
      h("div", { class: "dialog-head" }, h("h2", {}, title)),
      h("div", { class: "dialog-body" }, h("p", { class: "field-help", style: "margin:0;font-size:13px;line-height:20px" }, body),
        h("div", { class: "dialog-foot" }, h("span", { class: "grow" }), no, ok))), { top: true }, );
    el.addEventListener("keydown", (e) => { if (e.key === "Escape") done(false); });
    el.addEventListener("mousedown", (e) => { if (e.target === el) done(false); });
    // Anything that closes it another way (another dialog opening) counts as "no".
    onCloseHook = () => done(false);
    ok.focus();
  });
}

/** commands: [{group, label, hint?, icon, run}] */
export function openPalette(commands) {
  let query = "";
  let index = 0;
  const input = h("input", { placeholder: "Search projects, views and actions…", "aria-label": "Command search", autocomplete: "off", spellcheck: false });
  const listEl = h("div", { class: "palette-list", role: "listbox" });
  let shown = [];

  function render() {
    const q = query.trim().toLowerCase();
    shown = commands.filter((c) => !q || c.label.toLowerCase().includes(q) || c.group.toLowerCase().includes(q));
    index = Math.min(index, Math.max(0, shown.length - 1));
    const nodes = [];
    let group = null;
    shown.forEach((c, i) => {
      if (c.group !== group) { group = c.group; nodes.push(h("div", { class: "palette-group" }, group)); }
      nodes.push(h("button", { class: "palette-item", type: "button", role: "option", "aria-selected": String(i === index), onmousemove: () => { if (index !== i) { index = i; render(); } }, onclick: () => run(c) },
        icon(c.icon), h("span", { class: "grow" }, c.label), c.hint ? h("span", { class: "hint" }, c.hint) : null));
    });
    if (nodes.length === 0) nodes.push(h("div", { class: "palette-empty" }, "No matches"));
    listEl.replaceChildren(...nodes);
    listEl.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest" });
  }
  function run(c) { closeDialog(); c.run(); }

  input.addEventListener("input", () => { query = input.value; index = 0; render(); });
  input.addEventListener("keydown", (e) => {
    if (e.key === "ArrowDown") { e.preventDefault(); index = Math.min(index + 1, shown.length - 1); render(); }
    else if (e.key === "ArrowUp") { e.preventDefault(); index = Math.max(index - 1, 0); render(); }
    else if (e.key === "Enter" && shown[index]) { e.preventDefault(); run(shown[index]); }
  });

  layer(h("div", { class: "palette", role: "dialog", "aria-label": "Command palette" }, h("div", { class: "palette-input" }, icon("search"), input), listEl));
  render();
  input.focus();
}
