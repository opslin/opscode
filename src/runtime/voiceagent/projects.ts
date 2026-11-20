// What the voice agent can learn about the person's projects and folders, read-only:
//   describeProject(root)        a few facts for a spoken answer (package name, README start, top folder)
//   findProjects(list, query)    the projects that best match spoken words, tolerant of speech-recognition mistakes
//                                ("deal car app" -> "dealker-app")
//   lookFolder(path, home)       one folder anywhere inside the home folder: entries, README, package facts
//   findFolders(name, home)      folders with a matching name in the usual places code lives (bounded walk)
// Never inside private places (keys, keychains, browser profiles, mail) and never outside the home folder.

import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, isAbsolute, join, relative, resolve, sep } from "node:path";

/** Folders (by name, anywhere) the agent never reads or lists. */
const PRIVATE = new Set([".ssh", ".gnupg", ".aws", ".azure", ".kube", ".docker", ".password-store", ".netrc", "Keychains", "Cookies", "Mail", "Messages", ".Trash", "Library"]);
/** Folders not worth walking into when searching. */
const SKIP = new Set(["node_modules", ".git", ".hg", ".svn", "dist", "build", "out", ".next", ".cache", "target", "vendor", "Pods", "DerivedData", ".venv", "venv", "__pycache__", "Applications", "Movies", "Music", "Pictures", "Public"]);

export interface ProjectFacts { name: string; path: string; what: string; kind: string[]; git: boolean; top: string[] }
export interface FolderLook extends ProjectFacts { entries: { name: string; dir: boolean }[]; readme: string; truncated: boolean }

const clip = (t: string, n: number): string => (t.length > n ? `${t.slice(0, n).trimEnd()}…` : t);
const readSmall = (p: string, max = 4000): string => { try { const st = statSync(p); if (!st.isFile() || st.size > 2_000_000) return ""; return readFileSync(p, "utf8").slice(0, max); } catch { return ""; } };

/** Words for matching: lower case, letters and digits, camelCase and separators split. */
export function words(text: string): string[] {
  return text.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
}

/** Letter-pair similarity of two strings with spaces removed, 0..1 (speech splits and merges words). */
export function similar(a: string, b: string): number {
  const sq = (s: string): string => words(s).join("");
  const x = sq(a), y = sq(b);
  if (!x || !y) return 0;
  if (x === y) return 1;
  const pairs = (s: string): Map<string, number> => { const m = new Map<string, number>(); for (let i = 0; i < s.length - 1; i++) { const k = s.slice(i, i + 2); m.set(k, (m.get(k) ?? 0) + 1); } return m; };
  const px = pairs(x), py = pairs(y);
  let both = 0;
  for (const [k, n] of px) both += Math.min(n, py.get(k) ?? 0);
  const total = Math.max(1, x.length - 1 + y.length - 1);
  let score = (2 * both) / total;
  // One contained in the other ("dealker" in "dealker-app-server") counts strongly.
  if (y.includes(x) || x.includes(y)) score = Math.max(score, 0.75 + 0.25 * (Math.min(x.length, y.length) / Math.max(x.length, y.length)));
  return score;
}

/** The kind of project from the files at its top ("node", "react", "flutter", …). */
function kinds(top: string[], pkg: Record<string, unknown> | null): string[] {
  const k = new Set<string>();
  const has = (n: string): boolean => top.includes(n);
  if (pkg) {
    k.add("node");
    const deps = { ...(pkg.dependencies as object ?? {}), ...(pkg.devDependencies as object ?? {}) } as Record<string, unknown>;
    for (const [dep, name] of [["next", "next.js"], ["react", "react"], ["vue", "vue"], ["svelte", "svelte"], ["electron", "electron"], ["express", "express"], ["@nestjs/core", "nestjs"], ["react-native", "react-native"], ["expo", "expo"], ["vite", "vite"]] as const) if (dep in deps) k.add(name);
  }
  if (has("pubspec.yaml")) k.add("flutter");
  if (has("Cargo.toml")) k.add("rust");
  if (has("go.mod")) k.add("go");
  if (has("pyproject.toml") || has("requirements.txt")) k.add("python");
  if (has("Package.swift") || top.some((n) => n.endsWith(".xcodeproj"))) k.add("swift");
  if (has("build.gradle") || has("build.gradle.kts")) k.add("android/gradle");
  if (has("composer.json")) k.add("php");
  if (has("docker-compose.yml") || has("Dockerfile")) k.add("docker");
  return [...k];
}

function readmeOf(root: string, top: string[]): string {
  const name = top.find((n) => /^readme(\.(md|txt|rst))?$/i.test(n));
  if (!name) return "";
  return readSmall(join(root, name), 6000).replace(/<[^>]+>/g, " ").replace(/!\[[^\]]*\]\([^)]*\)/g, "").replace(/[#*_`>|]/g, "").replace(/\n{2,}/g, "\n").trim();
}

/** A few facts about a folder, for describing it aloud. */
export function describeProject(root: string, name?: string): ProjectFacts {
  let top: string[] = [];
  try { top = readdirSync(root).filter((n) => !n.startsWith(".") || n === ".git").sort(); } catch { /* unreadable */ }
  let pkg: Record<string, unknown> | null = null;
  try { pkg = top.includes("package.json") ? JSON.parse(readSmall(join(root, "package.json"), 200_000)) as Record<string, unknown> : null; } catch { pkg = null; }
  const readme = readmeOf(root, top);
  const firstLine = readme.split("\n").map((l) => l.trim()).find((l) => l.length > 20) ?? "";
  const what = clip(String(pkg?.description ?? "") || firstLine || "", 220);
  return { name: name ?? String(pkg?.name ?? basename(root)), path: root, what, kind: kinds(top, pkg), git: top.includes(".git"), top: top.filter((n) => n !== ".git").slice(0, 30) };
}

export interface ProjectRef { id: string; name: string; path: string }
export interface Match { id: string; name: string; path: string; score: number; why: string }

/** Projects matching spoken words, best first (score 0..1). Looks at the name, the folder, the package name and the README start. */
export function findProjects(list: ProjectRef[], query: string, facts: (p: ProjectRef) => ProjectFacts = (p) => describeProject(p.path, p.name)): Match[] {
  const q = query.trim();
  if (!q) return [];
  const qWords = words(q).filter((w) => w.length > 1 && !["app", "the", "project", "folder", "my", "one", "in", "of"].includes(w));
  const out: Match[] = [];
  for (const p of list) {
    const f = facts(p);
    const byName = Math.max(similar(q, p.name), similar(q, basename(p.path)), qWords.length ? Math.max(...qWords.map((w) => similar(w, p.name))) * 0.92 : 0);
    const text = `${f.what} ${f.kind.join(" ")} ${f.top.join(" ")}`.toLowerCase();
    const hits = qWords.filter((w) => w.length > 2 && text.includes(w)).length;
    const byText = qWords.length ? (hits / qWords.length) * 0.7 : 0;
    const score = Math.max(byName, byText);
    if (score >= 0.35) out.push({ id: p.id, name: p.name, path: p.path, score: Math.round(score * 100) / 100, why: byName >= byText ? "name" : "what it contains" });
  }
  return out.sort((a, b) => b.score - a.score).slice(0, 5);
}

/** Where the walk for folders starts (the usual places code lives). */
export function codeRoots(home = homedir()): string[] {
  return [home, ...["Documents", "Desktop", "Developer", "dev", "code", "Code", "projects", "Projects", "src", "work", "repos", "github", "GitHub", "Sites"].map((d) => join(home, d))].filter((d, i, a) => a.indexOf(d) === i && existsSync(d));
}

/** Resolves a spoken or typed path ("~/Documents/shop", "Documents/shop", "/Users/x/shop") inside the home folder, or throws. */
export function insideHome(path: string, home = homedir()): string {
  const raw = path.trim().replace(/^~(?=$|\/)/, home);
  const abs = isAbsolute(raw) ? resolve(raw) : resolve(home, raw);
  let real: string;
  try { real = realpathSync(abs); } catch { throw new Error(`There is no folder at ${abs}.`); }
  const homeReal = realpathSync(home);
  const rel = relative(homeReal, real);
  if (rel.startsWith("..") || isAbsolute(rel)) throw new Error("Only folders inside the home folder can be read.");
  if (rel.split(sep).some((part) => PRIVATE.has(part))) throw new Error("That is a private folder; it is not read.");
  return real;
}

/** Looks inside one folder (read-only): what is there, the README start, and what kind of project it looks like. */
export function lookFolder(path: string, home = homedir()): FolderLook {
  const root = insideHome(path, home);
  const st = statSync(root);
  if (!st.isDirectory()) throw new Error("That is a file, not a folder.");
  const all = readdirSync(root, { withFileTypes: true }).filter((e) => !PRIVATE.has(e.name));
  const entries = all
    .map((e) => ({ name: e.name, dir: e.isDirectory() }))
    .sort((a, b) => Number(b.dir) - Number(a.dir) || a.name.localeCompare(b.name));
  const facts = describeProject(root);
  const readme = readmeOf(root, entries.map((e) => e.name));
  return { ...facts, entries: entries.slice(0, 60), readme: clip(readme, 1500), truncated: entries.length > 60 };
}

/** Folders whose name matches the spoken words, in the usual code places, best first. Bounded: depth 3, 6000 folders. */
export function findFolders(name: string, home = homedir(), limit = 6): Match[] {
  const out: Match[] = [];
  const seen = new Set<string>();
  let budget = 6000;
  const walk = (dir: string, depth: number): void => {
    if (budget <= 0 || depth > 3) return;
    let list: import("node:fs").Dirent[];
    try { list = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of list) {
      if (!e.isDirectory() || e.name.startsWith(".") || SKIP.has(e.name) || PRIVATE.has(e.name)) continue;
      if (--budget <= 0) return;
      const p = join(dir, e.name);
      if (seen.has(p)) continue;
      seen.add(p);
      const score = similar(name, e.name);
      if (score >= 0.55) out.push({ id: "", name: e.name, path: p, score: Math.round(score * 100) / 100, why: "folder name" });
      walk(p, depth + 1);
    }
  };
  for (const r of codeRoots(home)) walk(r, r === home ? 1 : 0);
  return out.sort((a, b) => b.score - a.score || a.path.length - b.path.length).slice(0, limit);
}
