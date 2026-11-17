// Walks one app folder and reads the facts of every source file that is new or
// changed. Safe by construction: never follows links, never opens a secret by
// name (see secrets.ts), skips hidden, dependency, build and Flutter platform
// folders, and keeps names, paths and routes only.

import { lstatSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import { extract, languageOf } from "./facts";
import type { Facts } from "./facts";
import { isSecretName } from "./secrets";

export const MAX_FILES = 40_000;
export const MAX_READ_BYTES = 512 * 1024;
const SKIP_DIRS = new Set(["node_modules", "dist", "build", "out", "coverage", "vendor", "target", "__pycache__", "Pods", "DerivedData", "bower_components", "site-packages", "venv", "env", "testdata", "fixtures", "__fixtures__", "__snapshots__", "__mocks__"]);
const FLUTTER_PLATFORM = new Set(["ios", "android", "macos", "windows", "linux", "web"]);
const MANIFESTS = new Set(["package.json", "pubspec.yaml", "go.mod", "requirements.txt", "pyproject.toml", "composer.json", "tsconfig.json"]);

export interface Manifest {
  kind: "node" | "flutter" | "go" | "python" | "php" | "tsconfig";
  name?: string;
  deps: string[];
  scripts?: string[];
  /** tsconfig: compilerOptions.paths and baseUrl. */
  paths?: Record<string, string[]>;
  baseUrl?: string;
}
export interface FileFact { p: string; l: string; s: number; m: number; f: Facts; k?: Manifest }

const stripJsonComments = (t: string): string => t.replace(/("(?:[^"\\]|\\.)*")|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (_m, str) => str ?? "").replace(/,(\s*[}\]])/g, "$1");

function manifestOf(name: string, text: string): Manifest | undefined {
  try {
    if (name === "package.json") {
      const j = JSON.parse(text) as { name?: string; dependencies?: object; devDependencies?: object; peerDependencies?: object; scripts?: object };
      return { kind: "node", ...(j.name ? { name: String(j.name) } : {}), deps: Object.keys({ ...j.dependencies, ...j.devDependencies, ...j.peerDependencies }).slice(0, 300), scripts: Object.keys(j.scripts ?? {}).slice(0, 30) };
    }
    if (name === "tsconfig.json") {
      const o = (JSON.parse(stripJsonComments(text)) as { compilerOptions?: { paths?: Record<string, string[]>; baseUrl?: string } }).compilerOptions ?? {};
      return { kind: "tsconfig", deps: [], ...(o.paths ? { paths: o.paths } : {}), ...(o.baseUrl ? { baseUrl: o.baseUrl } : {}) };
    }
    if (name === "pubspec.yaml") {
      const y = (parseYaml(text) ?? {}) as { name?: string; dependencies?: object; dev_dependencies?: object };
      return { kind: "flutter", ...(y.name ? { name: String(y.name) } : {}), deps: Object.keys({ ...y.dependencies, ...y.dev_dependencies }).slice(0, 300) };
    }
    if (name === "go.mod") {
      const module = /^module\s+(\S+)/m.exec(text)?.[1];
      const deps = [...text.matchAll(/^\s*(?:require\s+)?([\w.\-]+\.[\w.\-]+\/[\w.\-/]+)\s+v[\w.\-+]+/gm)].map((m) => m[1]);
      return { kind: "go", ...(module ? { name: module } : {}), deps: [...new Set(deps)].slice(0, 200) };
    }
    if (name === "requirements.txt") return { kind: "python", deps: text.split("\n").map((l) => l.trim().split(/[<>=~!\[; ]/)[0]).filter((x) => x && !x.startsWith("#")).slice(0, 200) };
    if (name === "pyproject.toml") return { kind: "python", ...(/^name\s*=\s*"([^"]+)"/m.exec(text) ? { name: /^name\s*=\s*"([^"]+)"/m.exec(text)![1] } : {}), deps: [...text.matchAll(/"([A-Za-z][\w.\-]+)(?:[<>=~!\[ ][^"]*)?"/g)].map((m) => m[1]).slice(0, 100) };
    if (name === "composer.json") {
      const j = JSON.parse(text) as { name?: string; require?: object };
      return { kind: "php", ...(j.name ? { name: j.name } : {}), deps: Object.keys(j.require ?? {}).slice(0, 100) };
    }
  } catch { /* a broken manifest is just not a package */ }
  return undefined;
}

export interface ScanResult { changed: FileFact[]; unchanged: string[]; removed: string[]; total: number; truncated: boolean }

/**
 * known: path -> [size, mtime] of files already indexed; those that have not changed are not read again.
 * onProgress is called every few hundred files so the caller can report progress.
 */
export function scanFolder(root: string, known: Map<string, [number, number]>, onProgress?: (seen: number) => void): ScanResult {
  const changed: FileFact[] = [];
  const unchanged: string[] = [];
  const seen = new Set<string>();
  let total = 0;
  let truncated = false;
  const stack: string[] = [""];
  while (stack.length && !truncated) {
    const rel = stack.pop() as string;
    let names: string[];
    try { names = readdirSync(join(root, rel)); } catch { continue; }
    const flutter = names.includes("pubspec.yaml");
    for (const name of names) {
      const p = rel ? `${rel}/${name}` : name;
      let st;
      try { st = lstatSync(join(root, p)); } catch { continue; }
      if (st.isSymbolicLink()) continue;
      if (st.isDirectory()) {
        if (name.startsWith(".") || SKIP_DIRS.has(name) || (flutter && FLUTTER_PLATFORM.has(name))) continue;
        stack.push(p);
        continue;
      }
      if (!st.isFile() || name.startsWith(".") || isSecretName(name)) continue;
      const lang = languageOf(name) ?? (MANIFESTS.has(name) ? "manifest" : null);
      if (!lang) continue;
      if (++total > MAX_FILES) { truncated = true; break; }
      if (total % 400 === 0) onProgress?.(total);
      seen.add(p);
      const m = Math.round(st.mtimeMs);
      const prev = known.get(p);
      if (prev && prev[0] === st.size && prev[1] === m) { unchanged.push(p); continue; }
      let f: Facts = { n: 0 };
      let k: Manifest | undefined;
      if (st.size <= MAX_READ_BYTES) {
        try {
          const text = readFileSync(join(root, p), "utf8");
          if (lang === "manifest") { k = manifestOf(name, text); f = { n: text.split("\n").length }; } else f = extract(lang, text, p);
        } catch { /* unreadable: indexed without facts */ }
      }
      changed.push({ p, l: lang, s: st.size, m, f, ...(k ? { k } : {}) });
    }
  }
  const removed = [...known.keys()].filter((p) => !seen.has(p));
  return { changed, unchanged, removed, total: Math.min(total, MAX_FILES), truncated };
}
