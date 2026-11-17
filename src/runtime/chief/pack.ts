// What a Conductor adds to every worker's brief so the worker does not have to
// explore the repository: a short project map, and the working rules that keep a
// worker's chat small. These are instructions and a map, not a filter: Opscode
// cannot rewrite what Claude Code's own tools return inside a running turn.

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const SKIP = new Set(["node_modules", "dist", "build", "out", "coverage", "vendor", "target", "__pycache__", ".next", ".nuxt", ".turbo", ".gradle", "Pods", "DerivedData"]);
const KEY_FILES = ["README.md", "package.json", "pubspec.yaml", "pyproject.toml", "go.mod", "Cargo.toml", "composer.json", "build.gradle", "docker-compose.yml", "Dockerfile", "CLAUDE.md", "AGENTS.md"];
const cache = new Map<string, { at: number; text: string }>();

const list = (dir: string): { dirs: string[]; files: string[] } => {
  const dirs: string[] = [];
  const files: string[] = [];
  let names: string[] = [];
  try { names = readdirSync(dir).sort(); } catch { return { dirs, files }; }
  for (const n of names) {
    if (n.startsWith(".") || SKIP.has(n)) continue;
    try { (statSync(join(dir, n)).isDirectory() ? dirs : files).push(n); } catch { /* unreadable */ }
  }
  return { dirs, files };
};

/** A short map of the project: top-level folders with a few of their entries, key files, and the package scripts. Under 2 KB. */
export function projectMap(root: string): string {
  const hit = cache.get(root);
  if (hit && Date.now() - hit.at < 60_000) return hit.text;
  const top = list(root);
  const lines: string[] = [];
  for (const d of top.dirs.slice(0, 24)) {
    const inner = list(join(root, d));
    const shown = [...inner.dirs.map((x) => `${x}/`), ...inner.files].slice(0, 8);
    lines.push(`- ${d}/${shown.length ? `  ${shown.join(", ")}${inner.dirs.length + inner.files.length > shown.length ? ", …" : ""}` : ""}`);
  }
  const key = KEY_FILES.filter((f) => top.files.includes(f));
  let scripts = "";
  try {
    const pj = join(root, "package.json");
    if (existsSync(pj)) {
      const s = (JSON.parse(readFileSync(pj, "utf8")) as { scripts?: Record<string, string> }).scripts;
      if (s) scripts = Object.keys(s).slice(0, 14).join(", ");
    }
  } catch { /* not JSON */ }
  const text = [
    "Project map (folders, with some of what is inside; hidden, build and dependency folders left out):",
    ...(lines.length ? lines : ["- (no sub-folders)"]),
    ...(key.length ? [`Key files: ${key.join(", ")}`] : []),
    ...(top.files.length > key.length ? [`Other top-level files: ${top.files.filter((f) => !key.includes(f)).slice(0, 12).join(", ")}`] : []),
    ...(scripts ? [`npm scripts: ${scripts}`] : []),
  ].join("\n").slice(0, 2400);
  cache.set(root, { at: Date.now(), text });
  return text;
}

/** The working rules every Conductor worker gets. */
export const WORKER_RULES = [
  "Working rules (they keep this chat small and cheap):",
  "- Do only this task. Do not explore the whole repository: use the project map below and open only the files you need, in line ranges, not whole large files.",
  "- Never read build output, lock files, node_modules, dist or generated folders.",
  "- For long command output (tests, builds, servers, logs), pipe it so only what matters comes back, for example `… 2>&1 | tail -n 60` or `| grep -iE \"error|fail\"`.",
  "- Take screenshots only for visual work, and keep them small.",
  "- When editing, change only what the task needs; never reformat or rewrite a file around a small change.",
  "- Decide small things yourself instead of waiting; finish with the report.",
  "- Before you say done: run the check that proves the goal itself (the stated requirement, not a proxy like \"it compiles\"), and put what you ran and its result in the Check line.",
].join("\n");

/** Added after the person's brief and before the report format. */
export function workerExtras(root: string): string {
  return `\n\n${WORKER_RULES}\n\n${projectMap(root)}`;
}
