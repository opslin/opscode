// A small anchored menu: items [{label, description?, icon?, checked?, danger?, disabled?, onSelect}]
// or {separator: true} / {heading: "text"}. Closes on outside click, Esc, or selection.

import { h } from "./dom.js";
import { icon } from "./icons.js";

let current = null;

export function closeMenu() {
  if (!current) return;
  current.el.remove();
  document.removeEventListener("mousedown", current.onDown, true);
  document.removeEventListener("keydown", current.onKey, true);
  window.removeEventListener("resize", closeMenu);
  const { restore } = current;
  current = null;
  restore?.focus?.();
}

export function openMenu(anchor, items, { up = true, width = 280 } = {}) {
  const same = current?.anchor === anchor;
  closeMenu();
  if (same) return; // clicking the anchor again toggles it closed

  const entries = items.filter((i) => !i.separator && !i.heading);
  let index = Math.max(0, entries.findIndex((i) => i.checked));
  const nodes = [];
  const rows = items.map((it) => {
    if (it.separator) return h("div", { class: "menu-sep", role: "separator" });
    if (it.heading) return h("div", { class: "menu-heading" }, it.heading);
    const row = h("button", { class: "menu-item", type: "button", role: "menuitemradio", "aria-checked": String(!!it.checked), disabled: it.disabled, dataset: it.danger ? { danger: "" } : {}, onclick: () => { closeMenu(); it.onSelect?.(); } },
      it.icon ? icon(it.icon) : null,
      h("span", { class: "menu-text" }, h("span", { class: "menu-label" }, it.label), it.description ? h("span", { class: "menu-desc" }, it.description) : null),
      it.shortcut ? h("span", { class: "menu-shortcut" }, it.shortcut) : null,
      it.checked ? icon("check", "icon menu-check") : null);
    nodes.push(row);
    return row;
  });
  const el = h("div", { class: "menu", role: "menu" }, ...rows);
  el.style.width = `${width}px`;
  document.body.append(el);

  const r = anchor.getBoundingClientRect();
  const w = el.offsetWidth;
  const hgt = el.offsetHeight;
  let left = Math.min(Math.max(8, r.left), window.innerWidth - w - 8);
  let top = up ? r.top - hgt - 6 : r.bottom + 6;
  if (top < 8) top = r.bottom + 6;
  if (top + hgt > window.innerHeight - 8) top = Math.max(8, r.top - hgt - 6);
  el.style.left = `${left}px`;
  el.style.top = `${top}px`;

  const focusRow = () => nodes.forEach((n, i) => n.toggleAttribute("data-active", i === index));
  focusRow();
  const onDown = (e) => { if (!el.contains(e.target) && !anchor.contains(e.target)) closeMenu(); };
  const onKey = (e) => {
    if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); closeMenu(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); e.stopPropagation(); index = (index + 1) % nodes.length; focusRow(); }
    else if (e.key === "ArrowUp") { e.preventDefault(); e.stopPropagation(); index = (index - 1 + nodes.length) % nodes.length; focusRow(); }
    else if (e.key === "Enter" || (e.key === "Tab" && !e.shiftKey)) { e.preventDefault(); e.stopPropagation(); nodes[index]?.click(); }
  };
  document.addEventListener("mousedown", onDown, true);
  document.addEventListener("keydown", onKey, true);
  window.addEventListener("resize", closeMenu);
  current = { el, anchor, onDown, onKey, restore: anchor };
}
