// Tiny DOM helpers. Everything is built from nodes (never innerHTML), so file
// names, chat text and terminal titles can't inject markup.

const SVG_NS = "http://www.w3.org/2000/svg";

/** Windows and Linux get "this PC", "Ctrl+", "File Explorer" in the words the app shows (the text is written once, for a Mac). */
export function makeWords(isMac, windows) {
  return function words(s) {
    if (isMac || typeof s !== "string" || !s) return s;
    return s
      .replace(/⌥\s?Space/g, windows ? "Ctrl+Shift+Space" : "Alt+Space")
      .replace(/\bThis Mac\b/g, "This PC").replace(/\bthis Mac\b/g, "this PC").replace(/\byour Mac\b/g, "your PC").replace(/\bYour Mac\b/g, "Your PC")
      .replace(/\bthe Mac's\b/g, "the PC's").replace(/\bthis Mac's\b/g, "this PC's").replace(/\bthe Mac\b/g, "the PC").replace(/\bon a Mac\b/g, "on a PC")
      .replace(/\bFinder\b/g, windows ? "File Explorer" : "the file manager").replace(/\bSystem Settings\b/g, "Settings")
      .replace(/⌘\s?/g, "Ctrl+").replace(/⌥\s?/g, "Alt+").replace(/⌃\s?/g, "Ctrl+").replace(/⇧\s?/g, "Shift+");
  };
}
const ua = globalThis.navigator?.userAgent ?? "";
const plat = globalThis.navigator?.platform ?? "";
const IS_MAC = /mac/i.test(plat) || (/mac/i.test(ua) && !/windows|linux/i.test(ua));
export const IS_WINDOWS = !IS_MAC && /win/i.test(plat || ua);
export const words = makeWords(IS_MAC, IS_WINDOWS);
/** The microphone shortcut: ⌥Space on a Mac; Ctrl+Shift+Space elsewhere (Alt+Space opens the window menu on Windows). */
export const isMicChord = (e) => e.code === "Space" && (IS_WINDOWS ? e.ctrlKey && e.shiftKey && !e.altKey && !e.metaKey : e.altKey && !e.metaKey && !e.ctrlKey);

/** h("div", {class: "x", onclick, dataset, aria-*}, ...children) */
export function h(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(props ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else if (k === "class") node.className = v;
    else if (k === "dataset") Object.assign(node.dataset, v);
    else if (k === "text") node.textContent = words(v);
    else if (k === "title" || k === "placeholder" || k === "aria-label") node.setAttribute(k, words(String(v)));
    else if (k in node && !k.includes("-")) node[k] = v;
    else node.setAttribute(k, v === true ? "" : String(v));
  }
  append(node, children);
  return node;
}

export function append(node, children) {
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : words(String(c)));
  }
  return node;
}

export function svg(inner, cls = "icon") {
  const s = document.createElementNS(SVG_NS, "svg");
  s.setAttribute("viewBox", "0 0 24 24");
  s.setAttribute("aria-hidden", "true");
  s.setAttribute("class", cls);
  for (const spec of inner) {
    const el = document.createElementNS(SVG_NS, spec[0]);
    for (const [k, v] of Object.entries(spec[1])) el.setAttribute(k, v);
    s.append(el);
  }
  return s;
}

export const formatSize = (n) =>
  n < 1024 ? `${n} B` : n < 1048576 ? `${(n / 1024).toFixed(1)} KB` : `${(n / 1048576).toFixed(1)} MB`;
