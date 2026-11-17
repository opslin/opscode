// Project helpers for the side panel: Actions (one-click commands), Changes
// (git diff of the working tree), file search for "@", local dev servers, and
// a short environment summary. Read-only except the personal actions file.

import { execFile } from "node:child_process";
import { existsSync, lstatSync, readdirSync, readFileSync, realpathSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { parseToml } from "./importer";
import { isRecord } from "./rpc";

// ---- running git and other tools safely ------------------------------------------------

/** Settings that stop a repository's own config from running programs during read-only git calls. */
export const GIT_SAFE = ["-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "diff.external=", "-c", "core.pager=cat", "-c", "color.ui=false"];

export function run(cmd: string, args: string[], cwd: string, opts: { timeout?: number; max?: number; okCodes?: number[] } = {}): Promise<{ code: number; out: string; err: string }> {
  return new Promise((resolve) => {
    execFile(cmd, args, { cwd, timeout: opts.timeout ?? 8000, maxBuffer: opts.max ?? 8 * 1024 * 1024, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0", GIT_TERMINAL_PROMPT: "0", LC_ALL: "C" } }, (error, stdout, stderr) => {
      const code = error ? (typeof (error as NodeJS.ErrnoException & { code?: unknown }).code === "number" ? ((error as unknown as { code: number }).code) : -1) : 0;
      resolve({ code, out: String(stdout), err: String(stderr) });
    });
  });
}
const git = (root: string, args: string[], max?: number) => run("git", [...GIT_SAFE, ...args], root, { max });

// ---- environment ----------------------------------------------------------------------------

export interface EnvInfo {
  path: string;
  git: boolean;
  branch: string | null;
  repo: string | null;
  /** origin as host/owner/repo, never with a user name, password or token. */
  remote?: string | null;
  /** This folder is a linked git worktree (not the main checkout). */
  worktree?: boolean;
  /** Commits ahead of / behind the branch's upstream, when it has one. */
  upstream?: string | null;
  ahead?: number;
  behind?: number;
}

/** "https://user:tok@github.com/o/r.git" or "git@github.com:o/r.git" -> "github.com/o/r". */
export function cleanRemote(url: string): string | null {
  const u = url.trim();
  if (!u) return null;
  const scp = /^[^@/\s]+@([^:/\s]+):(.+)$/.exec(u);
  if (scp) return `${scp[1]}/${scp[2].replace(/\.git$/, "")}`.slice(0, 200);
  try {
    const x = new URL(u);
    if (x.protocol === "file:") return "local folder";
    return `${x.hostname}${x.port ? `:${x.port}` : ""}${x.pathname.replace(/\.git$/, "")}`.slice(0, 200);
  } catch {
    return /^[./~]/.test(u) ? "local folder" : null;
  }
}

export async function envInfo(root: string): Promise<EnvInfo> {
  const inside = await git(root, ["rev-parse", "--is-inside-work-tree"]);
  if (inside.code !== 0 || inside.out.trim() !== "true") return { path: root, git: false, branch: null, repo: null };
  const br = await git(root, ["rev-parse", "--abbrev-ref", "HEAD"]);
  let branch = br.code === 0 ? br.out.trim() : null;
  if (branch === "HEAD") branch = "detached";
  if (!branch) {
    const sym = await git(root, ["symbolic-ref", "--short", "HEAD"]);
    branch = sym.code === 0 ? sym.out.trim() : null;
  }
  const [remote, dirs, up] = await Promise.all([
    git(root, ["config", "--get", "remote.origin.url"]),
    git(root, ["rev-parse", "--git-dir", "--git-common-dir"]),
    git(root, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]),
  ]);
  const url = remote.code === 0 ? remote.out.trim() : "";
  const repo = url ? (/([^/:]+?)(?:\.git)?$/.exec(url)?.[1] ?? null) : null;
  const [gd, cd] = dirs.code === 0 ? dirs.out.trim().split("\n") : [];
  const worktree = !!gd && !!cd && gd !== cd;
  const upstream = up.code === 0 ? up.out.trim() || null : null;
  let ahead: number | undefined;
  let behind: number | undefined;
  if (upstream) {
    const c = await git(root, ["rev-list", "--left-right", "--count", "@{u}...HEAD"]);
    const m = /^(\d+)\s+(\d+)/.exec(c.out.trim());
    if (c.code === 0 && m) { behind = Number(m[1]); ahead = Number(m[2]); }
  }
  return { path: root, git: true, branch, repo, remote: cleanRemote(url), worktree, upstream, ...(ahead !== undefined ? { ahead, behind } : {}) };
}

/** Can we reach origin? Runs `git ls-remote` with prompts off (no password or passphrase is ever asked). */
export async function remoteCheck(root: string): Promise<{ ok: boolean; remote: string | null; message: string }> {
  const remote = await git(root, ["config", "--get", "remote.origin.url"]);
  const name = remote.code === 0 ? cleanRemote(remote.out) : null;
  if (!name) return { ok: false, remote: null, message: "No remote named origin." };
  const started = Date.now();
  const r = await new Promise<{ code: number; err: string }>((resolve) => {
    execFile("git", [...GIT_SAFE, "ls-remote", "--heads", "--exit-code", "origin"], { cwd: root, timeout: 12_000, maxBuffer: 4 * 1024 * 1024, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0", GIT_TERMINAL_PROMPT: "0", GIT_ASKPASS: "echo", SSH_ASKPASS: "echo", GIT_SSH_COMMAND: "ssh -o BatchMode=yes -o ConnectTimeout=8", LC_ALL: "C" } }, (error, _o, stderr) => {
      resolve({ code: error ? (typeof (error as { code?: unknown }).code === "number" ? (error as { code: number }).code : -1) : 0, err: String(stderr) });
    });
  });
  const ms = Date.now() - started;
  // Exit 2 = reachable but no heads yet (an empty repository).
  if (r.code === 0 || r.code === 2) return { ok: true, remote: name, message: `Reachable (${ms < 1000 ? `${ms} ms` : `${(ms / 1000).toFixed(1)} s`})` };
  const line = r.err.split("\n").map((x) => x.trim()).find((x) => /fatal|error|denied|could not|timed out|resolve/i.test(x)) ?? "No answer";
  return { ok: false, remote: name, message: line.replace(/https?:\/\/[^@\s]+@/g, "https://").slice(0, 160) };
}

// ---- changes (git diff) ---------------------------------------------------------------------------

export interface ChangedFile {
  path: string;
  old_path?: string;
  status: "added" | "modified" | "deleted" | "renamed" | "untracked";
  added: number;
  removed: number;
  binary?: boolean;
}
export interface Changes {
  git: boolean;
  branch: string | null;
  files: ChangedFile[];
  /** Unified diff of everything (capped). */
  diff: string;
  truncated: boolean;
}

const MAX_DIFF = 1024 * 1024;
const MAX_UNTRACKED = 50;
const MAX_UNTRACKED_BYTES = 200 * 1024;

export async function changes(root: string): Promise<Changes> {
  const env = await envInfo(root);
  if (!env.git) return { git: false, branch: null, files: [], diff: "", truncated: false };
  const hasHead = (await git(root, ["rev-parse", "--verify", "-q", "HEAD"])).code === 0;
  const base = hasHead ? ["HEAD"] : ["--cached"];
  const numstat = await git(root, ["diff", "--no-color", "--no-ext-diff", "--no-textconv", "-M", "--numstat", "-z", ...base]);
  const status = await git(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"]);
  const files = new Map<string, ChangedFile>();

  // status: "XY path\0" (renames: "R  new\0old\0")
  const st = status.out.split("\0");
  for (let i = 0; i < st.length; i++) {
    const e = st[i];
    if (e.length < 4) continue;
    const xy = e.slice(0, 2);
    const path = e.slice(3);
    if (xy === "??") files.set(path, { path, status: "untracked", added: 0, removed: 0 });
    else if (xy.includes("R")) {
      const old = st[++i];
      files.set(path, { path, old_path: old, status: "renamed", added: 0, removed: 0 });
    } else if (xy.includes("D")) files.set(path, { path, status: "deleted", added: 0, removed: 0 });
    else if (xy.includes("A")) files.set(path, { path, status: "added", added: 0, removed: 0 });
    else files.set(path, { path, status: "modified", added: 0, removed: 0 });
  }
  // numstat -z: "a\tb\tpath\0" or for renames "a\tb\t\0old\0new\0"
  const ns = numstat.out.split("\0");
  for (let i = 0; i < ns.length; i++) {
    const m = /^(-|\d+)\t(-|\d+)\t(.*)$/.exec(ns[i]);
    if (!m) continue;
    let path = m[3];
    if (path === "") { i += 2; path = ns[i] ?? ""; }
    const f = files.get(path) ?? { path, status: "modified" as const, added: 0, removed: 0 };
    if (m[1] === "-") f.binary = true;
    else { f.added = Number(m[1]); f.removed = Number(m[2]); }
    files.set(path, f);
  }

  let diff = (await git(root, ["diff", "--no-color", "--no-ext-diff", "--no-textconv", "-M", ...base], MAX_DIFF * 2)).out;
  let truncated = diff.length > MAX_DIFF;
  let untracked = 0;
  for (const f of files.values()) {
    if (f.status !== "untracked") continue;
    const abs = join(root, f.path);
    try {
      const s = lstatSync(abs);
      if (!s.isFile()) continue;
      if (++untracked > MAX_UNTRACKED || s.size > MAX_UNTRACKED_BYTES || diff.length > MAX_DIFF) { truncated = true; continue; }
      const buf = readFileSync(abs);
      if (buf.includes(0)) { f.binary = true; diff += `diff --git a/${f.path} b/${f.path}\nnew file\nBinary file\n`; continue; }
      const lines = buf.toString("utf8").split("\n");
      if (lines.at(-1) === "") lines.pop();
      f.added = lines.length;
      diff += `diff --git a/${f.path} b/${f.path}\nnew file mode 100644\n--- /dev/null\n+++ b/${f.path}\n@@ -0,0 +1,${lines.length} @@\n${lines.map((l) => `+${l}`).join("\n")}\n`;
    } catch { /* vanished: skip */ }
  }
  if (diff.length > MAX_DIFF) { diff = diff.slice(0, MAX_DIFF); truncated = true; }
  return { git: true, branch: env.branch, files: [...files.values()].sort((a, b) => a.path.localeCompare(b.path)), diff, truncated };
}

// ---- file search ("@" in the composer, the New tab search) -----------------------------------

const SKIP = new Set([".git", "node_modules", "dist", "build", ".next", ".turbo", ".cache", "target", ".venv", "venv", "__pycache__", ".DS_Store"]);

export function searchFiles(root: string, query: string, limit = 20): { path: string; kind: "file" | "dir" }[] {
  const q = query.trim().toLowerCase();
  const hits: { path: string; kind: "file" | "dir"; score: number }[] = [];
  const queue = [""];
  let seen = 0;
  while (queue.length && seen < 20_000) {
    const dir = queue.shift() as string;
    let names: string[];
    try {
      names = readdirSync(join(root, dir)).sort();
    } catch {
      continue;
    }
    for (const name of names) {
      if (SKIP.has(name)) continue;
      seen++;
      const rel = dir ? `${dir}/${name}` : name;
      let kind: "file" | "dir";
      try {
        const st = lstatSync(join(root, rel));
        if (st.isSymbolicLink()) continue;
        kind = st.isDirectory() ? "dir" : "file";
      } catch {
        continue;
      }
      if (kind === "dir") queue.push(rel);
      const low = rel.toLowerCase();
      const base = name.toLowerCase();
      let score = -1;
      if (!q) score = kind === "file" ? 1 : 0;
      else if (base === q) score = 100;
      else if (base.startsWith(q)) score = 80;
      else if (base.includes(q)) score = 60;
      else if (low.includes(q)) score = 40;
      if (score >= 0) hits.push({ path: rel, kind, score: score - rel.split("/").length });
    }
  }
  return hits.sort((a, b) => b.score - a.score || a.path.localeCompare(b.path)).slice(0, limit).map(({ path, kind }) => ({ path, kind }));
}

// ---- local servers -------------------------------------------------------------------------------

export interface LocalServer {
  port: number;
  url: string;
  pid: number;
  process_name: string;
}

/** TCP servers listening on this computer whose process runs inside the project folder. */
export async function localServers(root: string): Promise<LocalServer[]> {
  if (process.platform === "win32") return [];
  const ls = await run("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"], root, { timeout: 4000 });
  const byPid = new Map<number, { name: string; ports: Set<number> }>();
  let pid = 0;
  for (const line of ls.out.split("\n")) {
    if (line.startsWith("p")) pid = Number(line.slice(1));
    else if (line.startsWith("c") && pid) byPid.set(pid, { name: line.slice(1), ports: byPid.get(pid)?.ports ?? new Set() });
    else if (line.startsWith("n") && pid) {
      const port = Number(/:(\d+)$/.exec(line)?.[1]);
      if (port) (byPid.get(pid) ?? byPid.set(pid, { name: "", ports: new Set() }).get(pid)!).ports.add(port);
    }
  }
  if (byPid.size === 0) return [];
  const cwd = await run("lsof", ["-a", "-p", [...byPid.keys()].join(","), "-d", "cwd", "-Fpn"], root, { timeout: 4000 });
  let real = root;
  try { real = realpathSync(root); } catch { /* keep */ }
  const inside = (p: string): boolean => {
    const r = relative(real, p);
    return r === "" || (!r.startsWith("..") && !r.startsWith(sep) && r !== "..");
  };
  const out: LocalServer[] = [];
  let cur = 0;
  for (const line of cwd.out.split("\n")) {
    if (line.startsWith("p")) cur = Number(line.slice(1));
    else if (line.startsWith("n") && cur && inside(line.slice(1))) {
      const info = byPid.get(cur);
      for (const port of info?.ports ?? []) out.push({ port, url: `http://localhost:${port}`, pid: cur, process_name: info?.name || "server" });
    }
  }
  return out.sort((a, b) => a.port - b.port);
}

// ---- actions ---------------------------------------------------------------------------------

export const ACTION_ICONS = ["play", "test", "lint", "configure", "build", "debug", "diff"] as const;
export interface Action {
  id: string;
  name: string;
  command: string;
  icon?: string;
  source: "project" | "personal";
}
export const PROJECT_ACTIONS_FILE = ".opscode/actions.toml";
const ACTION_ID = /^[a-z0-9][a-z0-9-]{0,23}$/;
const HIDDEN = /[\u0000-\u001f\u007f​-‏‪-‮⁠-⁩﻿]/;
const title = (id: string): string => id.charAt(0).toUpperCase() + id.slice(1).replace(/-/g, " ");

function checkAction(a: { id: string; name: string; command: string; icon?: string }, where: string): void {
  if (!ACTION_ID.test(a.id)) throw new Error(`${where}: an action id is up to 24 lowercase letters, digits and dashes`);
  if (!a.command.trim()) throw new Error(`${where}: it has no command`);
  if (a.command.length > 2000 || a.name.length > 60) throw new Error(`${where}: too long`);
  if (HIDDEN.test(a.command) || HIDDEN.test(a.name)) throw new Error(`${where}: one line only, with no invisible characters (chain commands with &&)`);
  if (a.icon !== undefined && !(ACTION_ICONS as readonly string[]).includes(a.icon)) throw new Error(`${where}: icon must be one of ${ACTION_ICONS.join(", ")}`);
}

/** `[id]` tables with command (required), name and icon. */
export function readProjectActions(root: string): Action[] {
  const file = join(root, PROJECT_ACTIONS_FILE);
  if (!existsSync(file)) return [];
  const st = lstatSync(file);
  if (!st.isFile()) throw new Error(`${PROJECT_ACTIONS_FILE} is not a regular file`);
  if (st.size > 64 * 1024) throw new Error(`${PROJECT_ACTIONS_FILE} is too large`);
  const tables = parseToml(readFileSync(file, "utf8"));
  const out: Action[] = [];
  for (const [key, vals] of Object.entries(tables)) {
    if (key === "") continue;
    if (key.includes("\u0001")) throw new Error(`${PROJECT_ACTIONS_FILE}: [${key.split("\u0001").join(".")}]: an action's table name is up to 24 lowercase letters, digits and dashes`);
    const a = { id: key, name: typeof vals.name === "string" && vals.name.trim() ? vals.name.trim() : title(key), command: typeof vals.command === "string" ? vals.command.trim() : "", ...(typeof vals.icon === "string" ? { icon: vals.icon } : {}) };
    checkAction(a, `${PROJECT_ACTIONS_FILE} [${key}]`);
    out.push({ ...a, source: "project" });
  }
  return out;
}

const LIFECYCLE = new Set(["preinstall", "install", "postinstall", "prepare", "preprepare", "postprepare", "prepublish", "prepublishOnly", "prepack", "postpack", "publish", "postpublish", "preversion", "version", "postversion"]);

export function packageManager(root: string, declared?: unknown): string {
  if (existsSync(join(root, "bun.lock")) || existsSync(join(root, "bun.lockb"))) return "bun";
  if (existsSync(join(root, "pnpm-lock.yaml"))) return "pnpm";
  if (existsSync(join(root, "yarn.lock"))) return "yarn";
  if (existsSync(join(root, "package-lock.json"))) return "npm";
  return (typeof declared === "string" ? /^(bun|pnpm|yarn|npm)@/.exec(declared)?.[1] : undefined) ?? "npm";
}

/** package.json scripts not already saved as actions (no install/publish hooks), at most 12. */
export function suggestActions(root: string, have: Set<string>): { name: string; command: string }[] {
  let pkg: Record<string, unknown>;
  try {
    pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8")) as Record<string, unknown>;
  } catch {
    return [];
  }
  if (!isRecord(pkg.scripts)) return [];
  const names = Object.entries(pkg.scripts).filter(([, v]) => typeof v === "string").map(([k]) => k);
  const all = new Set(names);
  const pm = packageManager(root, pkg.packageManager);
  const hook = (n: string): boolean => /^(pre|post)/.test(n) && all.has(n.replace(/^(pre|post)/, ""));
  return names
    .filter((n) => !LIFECYCLE.has(n) && !hook(n) && !HIDDEN.test(n))
    .map((n) => ({ name: n, command: `${pm} run ${n}` }))
    .filter((s) => !have.has(s.command))
    .slice(0, 12);
}

/** Personal actions: per project, only on this computer. */
export class ActionStore {
  private readonly file: string;
  private data: Record<string, { id: string; name: string; command: string; icon?: string }[]>;

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "actions.json");
    const raw = readJson(this.file);
    this.data = {};
    if (isRecord(raw)) {
      for (const [k, v] of Object.entries(raw)) {
        if (!Array.isArray(v)) continue;
        this.data[k] = v.filter((a): a is { id: string; name: string; command: string; icon?: string } => isRecord(a) && typeof a.id === "string" && typeof a.name === "string" && typeof a.command === "string");
      }
    }
  }

  list(workspaceId: string): Action[] {
    return (this.data[workspaceId] ?? []).map((a) => ({ ...a, source: "personal" as const }));
  }

  set(workspaceId: string, actions: { id?: string; name: string; command: string; icon?: string }[]): Action[] {
    if (actions.length > 50) throw new Error("at most 50 actions");
    const used = new Set<string>();
    const next = actions.map((a, i) => {
      let id = a.id ?? (a.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 20) || "action");
      for (let n = 2; used.has(id); n++) id = `${id.slice(0, 20)}-${n}`;
      used.add(id);
      const out = { id, name: a.name.trim() || title(id), command: a.command.trim(), ...(a.icon ? { icon: a.icon } : {}) };
      checkAction(out, `action ${i + 1}`);
      return out;
    });
    if (next.length) this.data[workspaceId] = next;
    else delete this.data[workspaceId];
    writeJsonAtomic(this.file, this.data);
    return this.list(workspaceId);
  }

  forget(workspaceId: string): void {
    if (this.data[workspaceId]) {
      delete this.data[workspaceId];
      writeJsonAtomic(this.file, this.data);
    }
  }
}
