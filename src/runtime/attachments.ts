// Things the person attaches to a message: photos, files, whole folders. They are copied into the project
// (.opscode/attachments/<id>/…, never committed) so every engine and every Conductor worker can open them
// the same way; something already inside the project is used where it is. Images are also handed to the
// model directly (Claude Code gets them inline, Codex as local images), so it sees them, not just a path.

import { randomBytes } from "node:crypto";
import { copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, extname, isAbsolute, join, normalize, relative, sep } from "node:path";

export const ATTACH_DIR = ".opscode/attachments";
export const IMAGE_TYPES: Record<string, string> = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", webp: "image/webp" };
export const LIMITS = { FILES: 1000, TOTAL: 500 * 1024 * 1024, FILE: 300 * 1024 * 1024, BLOB: 1_000_000, PER_MESSAGE: 12, INLINE_IMAGE: 3_500_000 } as const;

const SKIP_DIRS = new Set(["node_modules", ".git", ".next", ".dart_tool", "Pods", ".gradle", "venv", ".venv", "__pycache__", ".idea", "build", "dist", ".cache", "DerivedData"]);
const SECRET_FILE = /^(\.env(\..*)?|id_(rsa|ed25519|ecdsa|dsa)(\.pub)?|.*\.(pem|key|p12|pfx|keystore|jks)|\.npmrc|\.netrc|credentials(\.json)?)$/i;
const SECRET_DIRS = [".ssh", ".aws", ".gnupg", ".kube", join(".config", "gcloud")];

/** Keys and credentials are attached by reference: never copied (so the key stays where its owner keeps it, with its permissions),
 *  and the agent is told the path. Only paths the person attached in this session count. */
const refs = new Set<string>();
export const isRef = (abs: string): boolean => refs.has(abs);

export interface Attached { path: string; name: string; kind: "image" | "file" | "folder"; files?: number; bytes: number; skipped?: number; ref?: boolean }

export const isImagePath = (p: string): boolean => extname(p).slice(1).toLowerCase() in IMAGE_TYPES;
const kindOfFile = (p: string): "image" | "file" => (isImagePath(p) ? "image" : "file");

function inside(root: string, p: string): boolean { return p === root || p.startsWith(root + sep); }

/** <project>/.opscode/attachments, created with a .gitignore so nothing in it is committed. Refuses links. */
function attachRoot(root: string): string {
  const od = join(root, ".opscode");
  if (existsSync(od) && lstatSync(od).isSymbolicLink()) throw new Error(".opscode in this project is a link; refusing to use it");
  const dir = join(root, ATTACH_DIR);
  if (existsSync(dir) && lstatSync(dir).isSymbolicLink()) throw new Error(".opscode/attachments is a link; refusing to use it");
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const ig = join(dir, ".gitignore");
  if (!existsSync(ig)) writeFileSync(ig, "*\n");
  return dir;
}

const newId = (): string => `${new Date().toISOString().slice(0, 10).replace(/-/g, "")}-${randomBytes(3).toString("hex")}`;
const cleanName = (n: string): string => basename(n).replace(/[^A-Za-z0-9._ -]+/g, "_").replace(/^\.+/, "").slice(0, 100) || "file";

function secretReason(real: string): string | undefined {
  const home = homedir();
  for (const d of SECRET_DIRS) if (inside(join(home, d), real)) return `${d} holds secrets`;
  if (SECRET_FILE.test(basename(real))) return "it looks like a key or credentials";
  return undefined;
}

/** Files of a folder worth sending: no build output, no links, no secrets; with the caps applied. */
function walk(dir: string, out: { abs: string; rel: string; size: number }[], base: string, state: { total: number; skipped: number }): void {
  let names: string[];
  try { names = readdirSync(dir).sort(); } catch { return; }
  for (const n of names) {
    if (n === ".DS_Store") continue;
    const abs = join(dir, n);
    let st;
    try { st = lstatSync(abs); } catch { continue; }
    if (st.isSymbolicLink()) { state.skipped++; continue; }
    if (st.isDirectory()) { if (SKIP_DIRS.has(n)) { state.skipped++; continue; } walk(abs, out, base, state); continue; }
    if (!st.isFile() || SECRET_FILE.test(n) || st.size > LIMITS.FILE || out.length >= LIMITS.FILES || state.total + st.size > LIMITS.TOTAL) { state.skipped++; continue; }
    state.total += st.size;
    out.push({ abs, rel: relative(base, abs), size: st.size });
  }
}

function count(dir: string): { files: number; bytes: number; skipped: number } {
  const out: { abs: string; rel: string; size: number }[] = [];
  const st = { total: 0, skipped: 0 };
  walk(dir, out, dir, st);
  return { files: out.length, bytes: st.total, skipped: st.skipped };
}

/** Attaches files or folders by absolute path (the person picked them). Inside the project: used in place. */
export function importPaths(root: string, sources: string[]): Attached[] {
  const realRoot = realpathSync(root);
  const items: Attached[] = [];
  for (const src of sources.slice(0, LIMITS.PER_MESSAGE)) {
    let real: string;
    try { real = realpathSync(src); } catch { throw new Error(`could not find ${basename(src)}`); }
    const st = statSync(real);
    const name = cleanName(real);
    // A key or credentials file: attach it by its path, do not copy it anywhere.
    if (secretReason(real)) {
      refs.add(real);
      items.push({ path: real, name, kind: "file", bytes: st.isFile() ? st.size : 0, ref: true });
      continue;
    }
    if (inside(realRoot, real)) {
      const rel = relative(realRoot, real);
      if (st.isDirectory()) { const c = count(real); items.push({ path: rel, name, kind: "folder", files: c.files, bytes: c.bytes, ...(c.skipped ? { skipped: c.skipped } : {}) }); }
      else items.push({ path: rel, name, kind: kindOfFile(real), bytes: st.size });
      continue;
    }
    const dest = join(attachRoot(root), newId());
    if (st.isFile()) {
      if (st.size > LIMITS.FILE) throw new Error(`${name} is larger than ${LIMITS.FILE / 1024 / 1024} MB`);
      mkdirSync(dest, { recursive: true, mode: 0o700 });
      copyFileSync(real, join(dest, name));
      items.push({ path: relative(realRoot, join(dest, name)), name, kind: kindOfFile(name), bytes: st.size });
    } else if (st.isDirectory()) {
      const files: { abs: string; rel: string; size: number }[] = [];
      const state = { total: 0, skipped: 0 };
      walk(real, files, real, state);
      if (!files.length) throw new Error(`${name} has nothing to attach (empty, or only build output and secrets)`);
      const to = join(dest, name);
      for (const f of files) {
        const target = join(to, f.rel);
        mkdirSync(join(target, ".."), { recursive: true, mode: 0o700 });
        copyFileSync(f.abs, target);
      }
      items.push({ path: relative(realRoot, to), name, kind: "folder", files: files.length, bytes: state.total, ...(state.skipped ? { skipped: state.skipped } : {}) });
    } else throw new Error(`${name} is not a file or folder`);
  }
  return items;
}

/** Where a voice note's recording goes: <project>/.opscode/attachments/<id>/voice-note-<date time>.m4a (the folder is made; git-ignored). */
export function voiceNotePath(root: string): string {
  const dir = join(attachRoot(root), newId());
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const d = new Date();
  const p = (n: number): string => String(n).padStart(2, "0");
  return join(realpathSync(dir), `voice-note-${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}.m4a`);
}

/** A pasted or dropped picture (no path on disk). */
export function saveBlob(root: string, name: string, data: Buffer): Attached {
  if (data.length > LIMITS.BLOB) throw new Error("that picture is too large to paste; attach it as a file instead");
  const dir = join(attachRoot(root), newId());
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const n = cleanName(name);
  writeFileSync(join(dir, n), data, { mode: 0o600 });
  return { path: relative(realpathSync(root), join(dir, n)), name: n, kind: kindOfFile(n), bytes: data.length };
}

/** Attachments named by relative path (what the UI sends back): checked to be real and inside the project. */
export function resolveAttached(root: string, rels: string[]): (Attached & { abs: string })[] {
  const realRoot = realpathSync(root);
  const out: (Attached & { abs: string })[] = [];
  for (const rel of rels.slice(0, LIMITS.PER_MESSAGE)) {
    const n = normalize(rel);
    if (!n || n.startsWith("..") || (n.startsWith(sep) && !refs.has(n) && !refs.has(rel))) continue;
    let real: string;
    try { real = realpathSync(isAbsolute(n) ? n : join(realRoot, n)); } catch { continue; }
    const ref = isAbsolute(n) && refs.has(real);
    if (!ref && (!inside(realRoot, real) || secretReason(real))) continue;
    const st = statSync(real);
    const name = basename(real);
    if (ref) out.push({ path: real, abs: real, name, kind: "file", bytes: st.isFile() ? st.size : 0, ref: true });
    else if (st.isDirectory()) { const c = count(real); out.push({ path: n, abs: real, name, kind: "folder", files: c.files, bytes: c.bytes }); }
    else out.push({ path: n, abs: real, name, kind: kindOfFile(real), bytes: st.size });
  }
  return out;
}

/** Lines for the model: where each attachment is and what it is. */
export function attachedNote(items: { path: string; kind: string; files?: number; ref?: boolean }[]): string {
  if (!items.length) return "";
  const line = (a: { path: string; kind: string; files?: number; ref?: boolean }): string => a.ref ? `- key or credentials file, left where it is (not copied): ${a.path}. Use it by this path (for example ssh -i); never print, copy or commit its contents.` : `- ${a.kind}: ${a.path}${a.kind === "folder" ? `/ (${a.files ?? "?"} files)` : ""}`;
  return `\n\nAttached by the person (open them as needed):\n${items.map(line).join("\n")}`;
}

/** A small image as a data URL for the chat's thumbnails; only from the attachments folder or the project. */
export function thumbnail(root: string, rel: string): string | undefined {
  const [item] = resolveAttached(root, [rel]);
  if (!item || item.kind !== "image" || item.bytes > 2_500_000) return undefined;
  return `data:${IMAGE_TYPES[extname(item.abs).slice(1).toLowerCase()]};base64,${readFileSync(item.abs).toString("base64")}`;
}

/** Image bytes for Claude Code's inline image blocks (skips ones too big for the API). */
export function inlineImage(abs: string): { media_type: string; data: string } | undefined {
  try {
    const st = statSync(abs);
    const type = IMAGE_TYPES[extname(abs).slice(1).toLowerCase()];
    if (!type || st.size > LIMITS.INLINE_IMAGE) return undefined;
    return { media_type: type, data: readFileSync(abs).toString("base64") };
  } catch { return undefined; }
}
