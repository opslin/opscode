// Runs inside the agent's page in an isolated world (page scripts cannot see
// it; it shares the DOM). Tags elements with ref_N and reads the page as a
// short outline: role "name" [ref] (state). Written for Opscode.

export const PAGE_SCRIPT = String.raw`
(() => {
  if (globalThis.__ops) return true;
  const refs = new Map();      // "ref_N" -> WeakRef(element)
  const byEl = new WeakMap();  // element -> "ref_N"
  let counter = 0;
  const refOf = (el) => {
    let r = byEl.get(el);
    if (!r) { r = "ref_" + (++counter); byEl.set(el, r); refs.set(r, new WeakRef(el)); }
    return r;
  };
  const get = (ref) => {
    const el = refs.get(String(ref))?.deref();
    if (!el) throw new Error("No element " + ref + " on this page any more (the page changed). Read the page again with browser_read.");
    if (!el.isConnected) throw new Error("Element " + ref + " was removed from the page. Read the page again with browser_read.");
    return el;
  };
  const clean = (s, n = 80) => { s = String(s ?? "").replace(/\s+/g, " ").trim(); return s.length > n ? s.slice(0, n - 1) + "…" : s; };
  const INPUT_ROLE = { checkbox: "checkbox", radio: "radio", button: "button", submit: "button", reset: "button", image: "button", range: "slider", search: "searchbox", number: "spinbutton", file: "button" };
  const TAG_ROLE = { BUTTON: "button", SELECT: "combobox", TEXTAREA: "textbox", IMG: "img", H1: "heading", H2: "heading", H3: "heading", H4: "heading", H5: "heading", H6: "heading", NAV: "navigation", MAIN: "main", HEADER: "banner", FOOTER: "contentinfo", FORM: "form", UL: "list", OL: "list", LI: "listitem", TABLE: "table", TR: "row", TD: "cell", TH: "columnheader", DIALOG: "dialog", SUMMARY: "button", DETAILS: "group", P: "paragraph", ASIDE: "complementary", OPTION: "option", IFRAME: "iframe", LABEL: "label", ARTICLE: "article", SECTION: "region" };
  const role = (el) => {
    const r = el.getAttribute("role");
    if (r) return r.split(" ")[0];
    if (el.tagName === "A") return el.hasAttribute("href") ? "link" : "";
    if (el.tagName === "INPUT") return INPUT_ROLE[(el.type || "text").toLowerCase()] || "textbox";
    if (el.tagName === "SELECT" && el.multiple) return "listbox";
    if (el.isContentEditable && el.getAttribute("contenteditable") !== null) return "textbox";
    return TAG_ROLE[el.tagName] || "";
  };
  const INTERACTIVE = new Set(["button", "link", "checkbox", "radio", "tab", "menuitem", "menuitemcheckbox", "menuitemradio", "option", "switch", "textbox", "combobox", "listbox", "slider", "searchbox", "spinbutton", "treeitem"]);
  const interactive = (el, r) => INTERACTIVE.has(r) || el.tagName === "INPUT" || el.tagName === "SELECT" || el.tagName === "TEXTAREA" || el.hasAttribute("onclick") || (el.hasAttribute("tabindex") && el.getAttribute("tabindex") !== "-1" && el.tabIndex >= 0 && r !== "");
  const byIds = (ids) => ids.split(/\s+/).map((id) => document.getElementById(id)?.textContent || "").join(" ");
  const name = (el, r) => {
    const a = el.getAttribute("aria-label"); if (a) return clean(a);
    const lb = el.getAttribute("aria-labelledby"); if (lb) { const t = clean(byIds(lb)); if (t) return t; }
    if (el.tagName === "INPUT" || el.tagName === "SELECT" || el.tagName === "TEXTAREA") {
      if (el.id) { const l = document.querySelector('label[for="' + CSS.escape(el.id) + '"]'); if (l) return clean(l.textContent); }
      const wrap = el.closest("label"); if (wrap) { const t = clean(wrap.textContent); if (t) return t; }
      if (["submit", "button", "reset"].includes(el.type) && el.value) return clean(el.value);
      return clean(el.getAttribute("placeholder") || el.getAttribute("title") || el.getAttribute("name") || "");
    }
    if (el.tagName === "IMG") return clean(el.getAttribute("alt") || el.getAttribute("title") || "");
    if (["button", "link", "heading", "tab", "menuitem", "option", "listitem", "cell", "columnheader", "label", "paragraph", "switch", "treeitem", "checkbox", "radio"].includes(r) || interactive(el, r)) {
      const t = clean(el.innerText ?? el.textContent, r === "paragraph" ? 160 : 80); if (t) return t;
      const img = el.querySelector("img[alt],svg[aria-label]"); if (img) return clean(img.getAttribute("alt") || img.getAttribute("aria-label"));
    }
    return clean(el.getAttribute("title") || "");
  };
  const shown = (el) => {
    if (el.getAttribute("aria-hidden") === "true") return false;
    if (el.checkVisibility && !el.checkVisibility({ checkVisibilityCSS: true })) return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 || el.tagName === "OPTION";
  };
  const states = (el, r) => {
    const s = [];
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
      const t = (el.type || "text").toLowerCase();
      if (!["checkbox", "radio", "button", "submit", "reset", "text", "textarea"].includes(t)) s.push("type=" + t);
      if (t === "password") s.push(el.value ? "value=(hidden)" : "empty");
      else if (!["checkbox", "radio", "button", "submit", "reset", "file"].includes(t)) s.push(el.value ? "value=" + JSON.stringify(clean(el.value, 60)) : "empty");
    }
    if (el.tagName === "SELECT") s.push("selected=" + JSON.stringify(clean([...el.selectedOptions].map((o) => o.textContent).join(", "), 60)));
    if (el.isContentEditable && r === "textbox") s.push(el.textContent ? "value=" + JSON.stringify(clean(el.textContent, 60)) : "empty");
    if ("checked" in el && (el.type === "checkbox" || el.type === "radio")) s.push(el.checked ? "checked" : "unchecked");
    const ac = el.getAttribute("aria-checked"); if (ac) s.push(ac === "true" ? "checked" : "unchecked");
    const ae = el.getAttribute("aria-expanded"); if (ae) s.push(ae === "true" ? "expanded" : "collapsed");
    if (el.getAttribute("aria-selected") === "true") s.push("selected");
    if (el.disabled || el.getAttribute("aria-disabled") === "true") s.push("disabled");
    if (el.required) s.push("required");
    if (r === "link") { const h = el.getAttribute("href") || ""; if (h && !h.startsWith("javascript:")) s.push("href=" + clean(h.startsWith(location.origin) ? h.slice(location.origin.length) : h, 80)); }
    if (r === "heading") s.push("level=" + (el.getAttribute("aria-level") || el.tagName.slice(1)));
    if (document.activeElement === el) s.push("focused");
    return s;
  };
  const kids = (el) => {
    const out = [...el.children];
    if (el.shadowRoot) out.unshift(...el.shadowRoot.children);
    return out;
  };
  const SKIP = new Set(["SCRIPT", "STYLE", "NOSCRIPT", "TEMPLATE", "META", "LINK", "HEAD", "SVG", "PATH"]);
  // Every visible element worth naming, with depth. mode: interactive | all
  const walk = (root, mode, budget) => {
    const lines = [];
    let used = 0, cut = false;
    const visit = (el, depth) => {
      if (cut || SKIP.has(el.tagName.toUpperCase())) return;
      if (!shown(el)) return;
      const r = role(el);
      const isI = interactive(el, r);
      const own = [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim().length > 1);
      const named = mode === "all" ? (r !== "" || own) && !(["list", "row", "form", "group", "region", "article"].includes(r) && !el.getAttribute("aria-label")) : isI || r === "heading" || r === "dialog";
      let d = depth;
      if (named) {
        const n = name(el, r) || (own ? clean([...el.childNodes].filter((x) => x.nodeType === 3).map((x) => x.textContent).join(" "), 120) : "");
        if (isI || n || r === "img" || r === "dialog" || r === "iframe") {
          const st = states(el, r);
          const line = "  ".repeat(mode === "all" ? depth : 0) + "- " + (r || "text") + (n ? " " + JSON.stringify(n) : "") + (isI || r === "img" || r === "dialog" || r === "heading" ? " [" + refOf(el) + "]" : "") + (st.length ? " (" + st.join(", ") + ")" : "");
          used += line.length + 1;
          if (used > budget) { cut = true; return; }
          lines.push(line);
          d = depth + 1;
          if (isI && ["button", "link", "option", "checkbox", "radio", "tab", "menuitem"].includes(r)) return; // its text is its name
        }
      }
      for (const k of kids(el)) visit(k, d);
    };
    visit(root, 0);
    return { lines, cut };
  };
  const center = (el) => {
    const r = el.getBoundingClientRect();
    const x = Math.max(0, Math.min(innerWidth - 1, r.left + Math.min(r.width, innerWidth) / 2));
    const y = Math.max(0, Math.min(innerHeight - 1, r.top + Math.min(r.height, innerHeight) / 2));
    return { x, y, r };
  };
  globalThis.__ops = {
    tree(mode, refId, budget) {
      const root = refId ? get(refId) : (document.body || document.documentElement);
      const { lines, cut } = walk(root, mode, budget);
      const head = "Page: " + JSON.stringify(document.title) + " — " + location.href + "\nViewport " + innerWidth + "x" + innerHeight + ", scrolled to " + Math.round(scrollY) + " of " + Math.max(0, document.documentElement.scrollHeight - innerHeight);
      return head + "\n" + (lines.length ? lines.join("\n") : "(nothing " + (mode === "interactive" ? "interactive " : "") + "visible)") + (cut ? "\n… (cut; use ref_id to focus on part of the page, or browser_find)" : "");
    },
    find(q) {
      const want = String(q).toLowerCase();
      const { lines } = walk(document.body || document.documentElement, "all", 400000);
      const hits = lines.map((l) => l.trim()).filter((l) => l.toLowerCase().includes(want) && l.includes("[ref_"));
      const plain = lines.map((l) => l.trim()).filter((l) => l.toLowerCase().includes(want) && !l.includes("[ref_"));
      const out = [...hits, ...plain].slice(0, 20);
      return out.length ? out.join("\n") : "No element matches " + JSON.stringify(String(q)) + ".";
    },
    point(ref) {
      const el = get(ref);
      const label = (role(el) || el.tagName.toLowerCase()) + " " + JSON.stringify(name(el, role(el)));
      if (el.tagName === "OPTION") throw new Error(ref + " is an option of a native select: use browser_act fill on the select (ref of the combobox) with the option's label.");
      // Never click blind: a hidden element has no box, and its "centre" would be the page's corner.
      if (!shown(el)) throw new Error(ref + " (" + label + ") is not visible right now: it may be in a closed menu, a hidden section or another step. Open or show it first (the last result says what appeared), or read the page again.");
      el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
      const { x, y, r } = center(el);
      if (r.width < 1 || r.height < 1) throw new Error(ref + " (" + label + ") has no size on screen, so it cannot be clicked. Read the page again.");
      const top = document.elementFromPoint(x, y);
      const covered = top && top !== el && !el.contains(top) && !top.contains(el) ? clean(role(top) + " " + JSON.stringify(name(top, role(top)))) : "";
      return { x, y, w: r.width, h: r.height, label, covered };
    },
    rect(ref) {
      const el = get(ref);
      el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
      const r = el.getBoundingClientRect();
      return { x: Math.max(0, r.left), y: Math.max(0, r.top), w: Math.min(r.width, innerWidth), h: Math.min(r.height, innerHeight) };
    },
    scrollTo(ref) { const el = get(ref); el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" }); return (role(el) || el.tagName.toLowerCase()) + " " + JSON.stringify(name(el, role(el))); },
    // Prepares a fill: selects and checkboxes are set here; text fields are focused and selected so the host types over them.
    fill(ref, value) {
      const el = get(ref);
      el.scrollIntoView({ block: "center", behavior: "instant" });
      const fire = () => { el.dispatchEvent(new Event("input", { bubbles: true })); el.dispatchEvent(new Event("change", { bubbles: true })); };
      if (el.tagName === "SELECT") {
        const want = String(value);
        const opt = [...el.options].find((o) => o.value === want) || [...el.options].find((o) => clean(o.textContent).toLowerCase() === want.toLowerCase()) || [...el.options].find((o) => clean(o.textContent).toLowerCase().includes(want.toLowerCase()));
        if (!opt) return { done: true, error: "No option " + JSON.stringify(want) + ". Options: " + [...el.options].slice(0, 30).map((o) => JSON.stringify(clean(o.textContent, 40))).join(", ") };
        el.value = opt.value; fire();
        return { done: true, text: "Selected " + JSON.stringify(clean(opt.textContent)) };
      }
      if (el.type === "checkbox" || el.type === "radio" || el.getAttribute("role") === "checkbox" || el.getAttribute("role") === "switch") {
        const want = value === true || value === "true" || value === "on" || value === 1 || value === "1";
        const now = "checked" in el && (el.type === "checkbox" || el.type === "radio") ? el.checked : el.getAttribute("aria-checked") === "true";
        if (now !== want) el.click();
        return { done: true, text: (want ? "Checked " : "Unchecked ") + JSON.stringify(name(el, role(el))) };
      }
      if (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable) {
        el.focus();
        if (el.isContentEditable) { const s = getSelection(); const rg = document.createRange(); rg.selectNodeContents(el); s.removeAllRanges(); s.addRange(rg); }
        else { try { el.select(); } catch { el.setSelectionRange?.(0, el.value.length); } }
        return { done: false, label: (role(el) || "field") + " " + JSON.stringify(name(el, role(el))) };
      }
      return { done: true, error: "That element is not a field (" + (role(el) || el.tagName.toLowerCase()) + "). Click it or use type." };
    },
    focus(ref) { const el = get(ref); el.focus(); return true; },
    text(budget) {
      const root = document.querySelector("main") || document.body || document.documentElement;
      const t = (root.innerText || "").replace(/\n{3,}/g, "\n\n").trim();
      return "Page: " + JSON.stringify(document.title) + " — " + location.href + "\n\n" + (t.length > budget ? t.slice(0, budget) + "\n… (cut)" : t);
    },
    // What the agent can see right now, to tell it what an action changed: interactive elements by ref,
    // and the visible text lines.
    state() {
      const { lines } = walk(document.body || document.documentElement, "interactive", 300000);
      const byRef = {};
      for (const l of lines) { const m = /\[(ref_\d+)\]/.exec(l); if (m) byRef[m[1]] = l.trim(); }
      const text = (document.body?.innerText || "").split("\n").map((s) => s.trim()).filter((s) => s.length > 1).slice(0, 600);
      return { url: location.href, byRef, text };
    },
    hasText(t) { return (document.body?.innerText || "").toLowerCase().includes(String(t).toLowerCase()); },
  };
  return true;
})()
`;
