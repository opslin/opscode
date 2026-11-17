// Minimal, safe markdown -> DOM: fenced code, headings, lists, paragraphs,
// inline code / bold / italic / links. Built from nodes only.
// Links: http(s) open in the browser; local files ([name](</abs/path>), [name](/abs/path), file://,
// project-relative paths, `/abs/path` in inline code, bare /abs/path.ext in text) become file links
// (a.op-file, handled in filelinks.js: open, Show in Finder, copy, attach). Anything else stays text.

import { h } from "./dom.js";

/** A file link; the path is absolute (or "~/…"), checked by main when clicked. */
function fileLink(label, path, code = false) {
  return h("a", { class: `op-file${code ? " op-file-code" : ""}`, href: "#", title: path, dataset: { path } }, code ? h("code", {}, label) : label);
}

/** Where a link points: { web } for http(s), { file } for a local path, null for anything else. */
export function linkTarget(raw, root) {
  let href = raw.trim();
  if (href.startsWith("<") && href.endsWith(">")) href = href.slice(1, -1).trim();
  if (/^https?:\/\//i.test(href)) return { web: href };
  if (/^file:\/\//i.test(href)) { try { return { file: decodeURI(href.slice(7)) }; } catch { return { file: href.slice(7) }; } }
  if (href.startsWith("/") || href.startsWith("~/") || /^[A-Za-z]:[\\/]/.test(href)) return { file: href };
  // A project-relative path (src/a.ts, ./docs/x.md:12); never a scheme, an anchor or a mail address.
  if (root && !/^[a-z][a-z0-9+.-]*:/i.test(href) && !href.startsWith("#") && !href.startsWith("../") && /[\w)]/.test(href)) return { file: `${root.replace(/[\\/]$/, "")}/${href.replace(/^\.\//, "")}` };
  return null;
}

/** Inline code that is a path: "/a/b.txt", "~/x/", "/Users/me/My Folder/file.xlsx". */
const CODE_PATH = /^(?:~?\/|[A-Za-z]:[\\/])[^\n`]*[^\s`/\\]\/?$/;
const looksLikePath = (t) => CODE_PATH.test(t) && (t.slice(1).includes("/") || t.slice(1).includes("\\") || /\.[a-z0-9]{1,8}$/i.test(t));

function inline(text, ctx = {}) {
  const out = [];
  const re = /(`[^`\n]+`)|(\*\*[^*\n]+\*\*)|(\*[^*\n]+\*)|(\[[^\]\n]+\]\((?:<[^>\n]+>|[^)\s]+)\))|((?<![\w/:.~@\\-])(?:~?\/(?:[\w.@+-]+\/)*|[A-Za-z]:[\\/](?:[\w.@+-]+[\\/])*)[\w@+-][\w.@+-]*\.[A-Za-z0-9]{1,8}(?::\d+)?(?![\w/\\]))/g;
  let last = 0;
  for (let m; (m = re.exec(text)); ) {
    if (m.index > last) out.push(text.slice(last, m.index));
    const t = m[0];
    if (m[1]) {
      const code = t.slice(1, -1);
      out.push(looksLikePath(code.trim()) ? fileLink(code, code.trim(), true) : h("code", {}, code));
    } else if (m[2]) out.push(h("strong", {}, t.slice(2, -2)));
    else if (m[3]) out.push(h("em", {}, t.slice(1, -1)));
    else if (m[4]) {
      const [, label, href] = /^\[([^\]]+)\]\((.+)\)$/.exec(t);
      const to = linkTarget(href, ctx.root);
      if (to?.web) out.push(h("a", { href: to.web, target: "_blank", rel: "noreferrer noopener" }, label));
      else if (to?.file) out.push(fileLink(label, to.file));
      else out.push(label);
    } else out.push(fileLink(t, t));
    last = m.index + t.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

/** ctx.root: the project folder, for links written relative to it. */
export function renderMarkdown(src, ctx = {}) {
  const root = h("div", { class: "body" });
  const lines = src.replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const fence = /^```(.*)$/.exec(line);
    if (fence) {
      const code = [];
      i++;
      while (i < lines.length && !/^```\s*$/.test(lines[i])) code.push(lines[i++]);
      i++;
      root.append(h("pre", {}, h("code", {}, code.join("\n"))));
      continue;
    }
    const head = /^(#{1,3})\s+(.*)$/.exec(line);
    if (head) {
      root.append(h(`h${head[1].length}`, {}, ...inline(head[2], ctx)));
      i++;
      continue;
    }
    if (/^\s*([-*]|\d+\.)\s+/.test(line)) {
      const ordered = /^\s*\d+\./.test(line);
      const list = h(ordered ? "ol" : "ul");
      while (i < lines.length && /^\s*([-*]|\d+\.)\s+/.test(lines[i])) {
        list.append(h("li", {}, ...inline(lines[i].replace(/^\s*([-*]|\d+\.)\s+/, ""), ctx)));
        i++;
      }
      root.append(list);
      continue;
    }
    if (!line.trim()) {
      i++;
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^```/.test(lines[i]) && !/^#{1,3}\s/.test(lines[i]) && !/^\s*([-*]|\d+\.)\s+/.test(lines[i])) para.push(lines[i++]);
    root.append(h("p", {}, ...inline(para.join("\n"), ctx)));
  }
  return root;
}
