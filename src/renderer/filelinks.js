// File links in replies (a.op-file from markdown.js), in every chat (normal, modes, Conductor, workers)
// and the side panel. Installed once for the whole window.
//   click        - text files inside the open project: Opscode's File tab; anything else: the Mac's default
//                  app (Excel, Preview, …); folders: Finder. Programs and scripts are only shown in Finder.
//   right-click  - Open, Open in Opscode, Show in Finder, Copy path, Copy name, Attach to message.

import { openMenu } from "./popover.js";
import { activeWorkspace, nav, toast } from "./store.js";

/** Files Opscode's File tab shows as text. */
const TEXT = /\.(md|markdown|txt|json|jsonc|js|mjs|cjs|ts|tsx|jsx|css|scss|html?|ya?ml|toml|ini|cfg|conf|py|go|rs|java|kt|kts|swift|dart|rb|php|c|h|cc|cpp|hpp|m|mm|sh|zsh|bash|sql|csv|tsv|log|xml|svg|graphql|gql|prisma|vue|svelte|gradle|properties|lock|gitignore|dockerfile)$/i;

const bridge = () => window.opscode?.fileAction;
const nameOf = (p) => p.replace(/\/+$/, "").split("/").pop() || p;
const noLine = (p) => p.replace(/:\d+(:\d+)?$/, "").replace(/#L?\d+(-L?\d+)?$/, "");

/** The path relative to the open project, when the file is inside it. */
function inProject(abs) {
  const ws = activeWorkspace();
  const root = ws?.path?.replace(/\/+$/, "");
  return root && abs.startsWith(`${root}/`) ? abs.slice(root.length + 1) : null;
}

async function info(path) {
  const f = bridge();
  if (!f) { toast("Opening files needs the Opscode app"); return null; }
  try { return await f("info", path); } catch (e) { toast(String(e?.message ?? e)); return null; }
}

async function act(op, path) {
  const r = await bridge()?.("open" === op ? "open" : "reveal", path).catch((e) => ({ ok: false, error: String(e?.message ?? e) }));
  if (!r?.ok) toast(r?.error ? `Couldn't ${op === "open" ? "open" : "show"} ${nameOf(path)}: ${r.error}` : "Couldn't do that");
  else if (op === "open" && r.revealed) toast(`${nameOf(path)} is a program or script, so Opscode shows it in Finder instead of running it.`);
}

function openInOpscode(abs) {
  const rel = inProject(noLine(abs));
  if (!rel || !nav.openFile) return false;
  nav.openFile(rel);
  return true;
}

async function open(path) {
  const i = await info(path);
  if (!i) return;
  if (!i.exists) { toast(`Can't find ${nameOf(path)} (${i.path || path})`); return; }
  if (!i.dir && !i.runnable && TEXT.test(noLine(i.path)) && openInOpscode(i.path)) return;
  await act("open", i.path);
}

async function menu(a, path) {
  const i = await info(path);
  if (!i) return;
  const abs = i.path || path;
  if (!i.exists) {
    openMenu(a, [{ heading: "Not found" }, { label: "Copy path", icon: "copy", onSelect: () => copy(abs) }], { up: false, width: 260 });
    return;
  }
  const canPanel = !i.dir && !i.runnable && TEXT.test(noLine(abs)) && !!inProject(noLine(abs)) && !!nav.openFile;
  openMenu(a, [
    { heading: nameOf(abs) },
    i.runnable ? null : { label: i.dir ? "Open folder" : "Open", description: i.dir ? "In Finder" : "With its default app", icon: i.dir ? "folder" : "external", onSelect: () => void act("open", abs) },
    canPanel ? { label: "Open in Opscode", description: "File tab in the side panel", icon: "file", onSelect: () => openInOpscode(abs) } : null,
    { label: "Show in Finder", icon: "folder", onSelect: () => void act("reveal", abs) },
    { separator: true },
    { label: "Copy path", icon: "copy", onSelect: () => copy(abs) },
    { label: "Copy name", icon: "copy", onSelect: () => copy(nameOf(abs)) },
    { separator: true },
    { label: "Attach to message", icon: "paperclip", description: "Add it to the message you are writing", onSelect: () => window.dispatchEvent(new CustomEvent("opscode:attach-paths", { detail: { paths: [abs] } })) },
  ].filter(Boolean), { up: false, width: 260 });
}

async function copy(text) {
  try { await navigator.clipboard.writeText(text); toast("Copied"); } catch { toast("Couldn't copy"); }
}

let installed = false;
export function installFileLinks() {
  if (installed) return;
  installed = true;
  document.addEventListener("click", (e) => {
    const a = e.target instanceof Element ? e.target.closest("a.op-file") : null;
    if (!a) return;
    e.preventDefault();
    void open(a.dataset.path ?? "");
  });
  document.addEventListener("contextmenu", (e) => {
    const a = e.target instanceof Element ? e.target.closest("a.op-file") : null;
    if (!a) return;
    e.preventDefault();
    void menu(a, a.dataset.path ?? "");
  });
}
