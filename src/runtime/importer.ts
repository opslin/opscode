// Import: brings MCP servers, skills and instructions from other coding tools
// (Claude Code, Codex, Cursor) into Opscode. Read-only on their files; it never
// copies secrets (env values, headers, tokens), and imported MCP servers start
// switched off so nothing runs until you turn it on.

import { lstatSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { isRecord } from "./rpc";
import { parseSkill, SKILL_LIMITS, SKILL_NAME, type ParsedSkill } from "./skills";
import { NOTE_LIMITS } from "./memory";

export type ImportSource = "claude" | "codex" | "cursor";
export type ImportKind = "mcp" | "skill" | "note";

export interface McpSpec {
  name: string;
  command?: string;
  args?: string[];
  url?: string;
}
export interface NoteDraft {
  title: string;
  body: string;
}

export interface ImportItem {
  id: string;
  source: ImportSource;
  kind: ImportKind;
  title: string;
  /** What will be copied, in one line (a command, a description, a size). */
  detail: string;
  /** Shown when something is left behind (env values, extra files). */
  warn?: string;
  /** Set when it cannot be imported at all. */
  blocked?: string;
  mcp?: McpSpec;
  skill?: ParsedSkill;
  notes?: NoteDraft[];
}

export const SOURCE_LABEL: Record<ImportSource, string> = { claude: "Claude Code", codex: "Codex", cursor: "Cursor" };

const MAX_FILE = 256 * 1024;
const MAX_JSON = 16 * 1024 * 1024;
const MAX_NOTES_PER_FILE = 15;
const MAX_ARGS = 64;

export const importHome = (): string => process.env.OPSCODE_IMPORT_HOME || homedir();

function readText(file: string, max: number): string | null {
  try {
    const st = lstatSync(file);
    if (!st.isFile() || st.size > max) return null;
    return readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

// ---- MCP ----------------------------------------------------------------------------

const BAD_NAME = /[\u0000-\u001f]/;
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

function mcpItem(source: ImportSource, name: string, raw: unknown, envKeys: string[]): ImportItem | null {
  if (!isRecord(raw) || !name || BAD_NAME.test(name)) return null;
  const base = { id: `${source}:mcp:${name}`, source, kind: "mcp" as const, title: clip(name, 60) };
  const left = [...envKeys, ...(isRecord(raw.headers) ? Object.keys(raw.headers) : [])];
  const warn = left.length ? `Not copied: ${left.slice(0, 6).join(", ")}${left.length > 6 ? "…" : ""} (values stay in the other app). The server may need them.` : undefined;
  if (typeof raw.url === "string" && raw.url) {
    try {
      const u = new URL(raw.url);
      if (u.protocol !== "http:" && u.protocol !== "https:") throw new Error("scheme");
      if (u.username || u.password || u.search) return { ...base, detail: "remote server", blocked: "The URL carries credentials or a token; add it by hand instead." };
      return { ...base, detail: `${u.origin}${u.pathname}`, ...(warn ? { warn } : {}), mcp: { name: clip(name, 60), url: raw.url } };
    } catch {
      return { ...base, detail: "remote server", blocked: "Not a valid http(s) address." };
    }
  }
  if (typeof raw.command === "string" && raw.command.trim()) {
    const args = Array.isArray(raw.args) ? raw.args : [];
    if (args.length > MAX_ARGS || !args.every((a) => typeof a === "string")) return { ...base, detail: raw.command, blocked: "Its arguments are not plain text." };
    return { ...base, detail: clip([raw.command, ...(args as string[])].join(" "), 200), ...(warn ? { warn } : {}), mcp: { name: clip(name, 60), command: raw.command, args: args as string[] } };
  }
  return null;
}

function mcpFromJsonMap(source: ImportSource, map: unknown): ImportItem[] {
  if (!isRecord(map)) return [];
  const out: ImportItem[] = [];
  for (const [name, v] of Object.entries(map)) {
    const env = isRecord(v) && isRecord(v.env) ? Object.keys(v.env) : [];
    const it = mcpItem(source, name, v, env);
    if (it) out.push(it);
  }
  return out;
}

// ---- A small TOML reader (only what ~/.codex/config.toml uses) -------------------------

function tomlValue(text: string): unknown {
  const t = text.trim();
  if (t.startsWith('"')) {
    const m = /^"((?:[^"\\]|\\.)*)"/.exec(t);
    try {
      return m ? JSON.parse(`"${m[1]}"`) : undefined;
    } catch {
      return undefined;
    }
  }
  if (t.startsWith("'")) {
    const end = t.indexOf("'", 1);
    return end > 0 ? t.slice(1, end) : undefined;
  }
  if (t.startsWith("[")) {
    const items: unknown[] = [];
    const re = /"((?:[^"\\]|\\.)*)"|'([^']*)'/g;
    let m: RegExpExecArray | null;
    const body = t.replace(/#.*$/gm, (c) => (/["']/.test(c) ? c : ""));
    while ((m = re.exec(body))) {
      try {
        items.push(m[1] !== undefined ? JSON.parse(`"${m[1]}"`) : m[2]);
      } catch {
        return undefined;
      }
    }
    return items;
  }
  if (/^true\b/.test(t)) return true;
  if (/^false\b/.test(t)) return false;
  return undefined;
}

/** Tables as { "a.b": { key: value } }. Quoted table-name parts keep dots inside. */
export function parseToml(text: string): Record<string, Record<string, unknown>> {
  const tables: Record<string, Record<string, unknown>> = { "": {} };
  let cur = "";
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith("#")) continue;
    const head = /^\[([^\[\]]+)\]\s*(#.*)?$/.exec(line);
    if (head) {
      const parts: string[] = [];
      const re = /"((?:[^"\\]|\\.)*)"|'([^']*)'|([A-Za-z0-9_-]+)/g;
      let m: RegExpExecArray | null;
      while ((m = re.exec(head[1]))) parts.push(m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]);
      cur = parts.join("\u0001");
      tables[cur] ??= {};
      continue;
    }
    const kv = /^("[^"]+"|[A-Za-z0-9_.-]+)\s*=\s*(.*)$/.exec(line);
    if (!kv) continue;
    let value = kv[2];
    if (value.startsWith("[")) {
      let depth = 0;
      const count = (s: string): void => {
        for (const ch of s.replace(/"(?:[^"\\]|\\.)*"|'[^']*'/g, "")) {
          if (ch === "[") depth++;
          else if (ch === "]") depth--;
        }
      };
      count(value);
      while (depth > 0 && i + 1 < lines.length) {
        value += `\n${lines[++i]}`;
        count(lines[i]);
      }
    }
    tables[cur][kv[1].replace(/^"|"$/g, "")] = tomlValue(value);
  }
  return tables;
}

function codexMcp(text: string): ImportItem[] {
  const t = parseToml(text);
  const out: ImportItem[] = [];
  for (const [key, vals] of Object.entries(t)) {
    const parts = key.split("\u0001");
    if (parts[0] !== "mcp_servers" || parts.length !== 2) continue;
    const name = parts[1];
    const env = t[`mcp_servers\u0001${name}\u0001env`];
    const headers = t[`mcp_servers\u0001${name}\u0001http_headers`] ?? t[`mcp_servers\u0001${name}\u0001env_http_headers`];
    const raw: Record<string, unknown> = { command: vals.command, args: vals.args, url: vals.url };
    if (headers) raw.headers = headers;
    const it = mcpItem("codex", name, raw, env ? Object.keys(env) : []);
    if (it) out.push(it);
  }
  return out;
}

// ---- Skills --------------------------------------------------------------------------

function skillItems(source: ImportSource, dir: string): ImportItem[] {
  const out: ImportItem[] = [];
  let names: string[];
  try {
    names = readdirSync(dir).sort();
  } catch {
    return out;
  }
  for (const folder of names) {
    const d = join(dir, folder);
    let extra = 0;
    try {
      if (!lstatSync(d).isDirectory()) continue;
      extra = readdirSync(d).filter((f) => f !== "SKILL.md").length;
    } catch {
      continue;
    }
    const text = readText(join(d, "SKILL.md"), 2 * SKILL_LIMITS.BODY);
    if (text === null) continue;
    const base = { id: `${source}:skill:${folder}`, source, kind: "skill" as const, title: folder };
    const sk = parseSkill(text, folder);
    if (!sk) {
      out.push({ ...base, detail: "SKILL.md", blocked: "The name is not lowercase letters, digits and dashes." });
      continue;
    }
    if (!sk.description.trim() || !sk.body.trim()) {
      out.push({ ...base, title: sk.name, detail: "SKILL.md", blocked: "It has no description or no steps." });
      continue;
    }
    out.push({
      ...base,
      title: sk.name,
      detail: clip(sk.description, 140),
      ...(extra > 0 ? { warn: `Only SKILL.md is copied; ${extra} other file${extra === 1 ? "" : "s"} in the folder stay behind.` } : {}),
      skill: sk,
    });
  }
  return out;
}

// ---- Instructions -> notes -------------------------------------------------------------

/** Splits a long instruction file into note-sized chunks at paragraph boundaries. */
export function chunkNotes(file: string, text: string): NoteDraft[] {
  const out: NoteDraft[] = [];
  let title = file;
  let buf = "";
  const flush = (): void => {
    const body = buf.trim();
    if (body) out.push({ title: clip(title, NOTE_LIMITS.TITLE), body });
    buf = "";
  };
  for (const para of text.replace(/\r\n/g, "\n").split(/\n{2,}/)) {
    const p = para.trim();
    if (!p) continue;
    const h = /^#{1,6}\s+(.+)$/m.exec(p.split("\n")[0]);
    if (h) {
      flush();
      title = `${file}: ${h[1].trim()}`;
    }
    const pieces = p.length > NOTE_LIMITS.BODY - 200 ? p.match(new RegExp(`[\\s\\S]{1,${NOTE_LIMITS.BODY - 200}}`, "g")) ?? [] : [p];
    for (const piece of pieces) {
      if (buf && !(buf.length < 150 && /^#{1,6}\s/.test(buf)) && buf.length + piece.length + 2 > NOTE_LIMITS.BODY - 200) flush();
      buf += `${buf ? "\n\n" : ""}${piece}`;
    }
  }
  flush();
  return out;
}

function noteItem(source: ImportSource, file: string, path: string): ImportItem[] {
  const text = readText(path, MAX_FILE);
  if (text === null || !text.trim()) return [];
  const all = chunkNotes(file, text);
  const notes = all.slice(0, MAX_NOTES_PER_FILE);
  return [
    {
      id: `${source}:note:${file}`,
      source,
      kind: "note",
      title: file,
      detail: `${notes.length} note${notes.length === 1 ? "" : "s"} for every project`,
      ...(all.length > notes.length ? { warn: `Only the first ${notes.length} of ${all.length} parts are copied.` } : {}),
      notes,
    },
  ];
}

// ---- Scan ----------------------------------------------------------------------------

export interface SourceInfo {
  id: ImportSource;
  label: string;
  found: boolean;
  path: string;
}

export function scan(home = importHome()): { sources: SourceInfo[]; items: ImportItem[] } {
  const items: ImportItem[] = [];
  const sources: SourceInfo[] = [];
  const exists = (p: string): boolean => {
    try {
      return statSync(p).isDirectory();
    } catch {
      return false;
    }
  };

  const claudeDir = join(home, ".claude");
  const claudeJson = readText(join(home, ".claude.json"), MAX_JSON);
  sources.push({ id: "claude", label: SOURCE_LABEL.claude, found: exists(claudeDir) || claudeJson !== null, path: "~/.claude" });
  if (claudeJson !== null) {
    try {
      items.push(...mcpFromJsonMap("claude", (JSON.parse(claudeJson) as Record<string, unknown>).mcpServers));
    } catch { /* not JSON: nothing to import */ }
  }
  items.push(...skillItems("claude", join(claudeDir, "skills")), ...noteItem("claude", "CLAUDE.md", join(claudeDir, "CLAUDE.md")));

  const codexDir = join(home, ".codex");
  sources.push({ id: "codex", label: SOURCE_LABEL.codex, found: exists(codexDir), path: "~/.codex" });
  const toml = readText(join(codexDir, "config.toml"), MAX_FILE);
  if (toml !== null) items.push(...codexMcp(toml));
  items.push(...skillItems("codex", join(codexDir, "skills")), ...noteItem("codex", "AGENTS.md", join(codexDir, "AGENTS.md")));

  const cursorDir = join(home, ".cursor");
  sources.push({ id: "cursor", label: SOURCE_LABEL.cursor, found: exists(cursorDir), path: "~/.cursor" });
  const cj = readText(join(cursorDir, "mcp.json"), MAX_FILE);
  if (cj !== null) {
    try {
      items.push(...mcpFromJsonMap("cursor", (JSON.parse(cj) as Record<string, unknown>).mcpServers));
    } catch { /* ignore */ }
  }
  items.push(...skillItems("cursor", join(cursorDir, "skills")));

  // Same id twice (odd config): keep the first.
  const seen = new Set<string>();
  return { sources, items: items.filter((i) => (seen.has(i.id) ? false : (seen.add(i.id), true))) };
}

// ---- Apply ---------------------------------------------------------------------------

export interface ImportDeps {
  mcp: { list(): { target: string }[]; addServer(spec: McpSpec & { enabled: boolean; source?: string }): void };
  skills: { has(name: string): boolean; saveUser(skill: ParsedSkill): void };
  memory: { list(): { scope: string; body: string }[]; add(o: { title: string; body: string; scope: string }): unknown };
}

const targetOf = (m: McpSpec): string => (m.url ? m.url : [m.command, ...(m.args ?? [])].join(" "));

/** True when everything the item would add is already in Opscode. */
export function alreadyHere(it: ImportItem, d: ImportDeps): boolean {
  if (it.mcp) return d.mcp.list().some((s) => s.target === targetOf(it.mcp as McpSpec));
  if (it.skill) return d.skills.has(it.skill.name);
  if (it.notes) {
    const have = new Set(d.memory.list().filter((n) => n.scope === "global").map((n) => n.body));
    return it.notes.every((n) => have.has(n.body));
  }
  return false;
}

export interface ImportResult {
  imported: { id: string; detail: string }[];
  skipped: { id: string; reason: string }[];
}

/** Applies the chosen items. `items` come from a fresh scan, never from the caller. */
export function apply(items: ImportItem[], d: ImportDeps): ImportResult {
  const res: ImportResult = { imported: [], skipped: [] };
  for (const it of items) {
    if (it.blocked) {
      res.skipped.push({ id: it.id, reason: it.blocked });
      continue;
    }
    if (alreadyHere(it, d)) {
      res.skipped.push({ id: it.id, reason: "Already in Opscode." });
      continue;
    }
    try {
      if (it.mcp) {
        d.mcp.addServer({ ...it.mcp, enabled: false, source: SOURCE_LABEL[it.source] });
        res.imported.push({ id: it.id, detail: "Added, switched off. Turn it on in MCP servers." });
      } else if (it.skill) {
        d.skills.saveUser(it.skill);
        res.imported.push({ id: it.id, detail: "Added to your skills." });
      } else if (it.notes) {
        const have = new Set(d.memory.list().filter((n) => n.scope === "global").map((n) => n.body));
        let n = 0;
        for (const note of it.notes) {
          if (have.has(note.body)) continue;
          d.memory.add({ title: note.title, body: note.body, scope: "global" });
          n++;
        }
        res.imported.push({ id: it.id, detail: `Added ${n} note${n === 1 ? "" : "s"} to Memory.` });
      }
    } catch (e) {
      res.skipped.push({ id: it.id, reason: e instanceof Error ? e.message : String(e) });
    }
  }
  return res;
}

export { SKILL_NAME };
