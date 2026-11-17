// Plugins and marketplaces, in the common layouts:
//   plugin       .claude-plugin/plugin.json {name, description, version}
//                skills/<name>/SKILL.md      .mcp.json {mcpServers: {name: {command,args} | {url}}}
//   marketplace  .claude-plugin/marketplace.json {name, plugins: [{name, source, description}]}
// A plugin is COPIED into the state dir on install, after you have seen what it
// brings (preview). Nothing from a folder runs or loads until then.

import { randomUUID } from "node:crypto";
import { chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, statSync } from "node:fs";
import { basename, isAbsolute, join, relative, resolve, sep } from "node:path";
import type { FolderPreview, MarketplaceInfo, PluginInfo } from "../shared/protocol";
import { validateBaseUrl } from "./agent/llm";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { splitCommand } from "./mcp";
import { isRecord } from "./rpc";
import { readSkillsDir, SKILL_NAME, writeSkill, type ParsedSkill } from "./skills";

const COPY_LIMITS = { FILES: 500, BYTES: 5 * 1024 * 1024 } as const;
const SKIP = new Set([".git", "node_modules", ".DS_Store"]);
const MAX_PLUGINS = 64;
const MAX_MARKETPLACES = 16;

interface McpDecl {
  name: string;
  transport: "stdio" | "http";
  command?: string;
  args?: string[];
  url?: string;
}

interface Installed {
  id: string;
  name: string;
  description: string;
  version: string;
  enabled: boolean;
  source: string;
  installed_at: string;
}
interface Market {
  id: string;
  name: string;
  path: string;
}

const readJsonFile = (file: string): Record<string, unknown> | null => {
  try {
    const v = JSON.parse(readFileSync(file, "utf8"));
    return isRecord(v) ? v : null;
  } catch {
    return null;
  }
};
const asString = (v: unknown, max = 500): string => (typeof v === "string" ? v.slice(0, max) : "");
const slugName = (s: string): string => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48);

/** An existing absolute directory, with symlinks resolved. */
export function realDir(p: string): string {
  if (typeof p !== "string" || !isAbsolute(p) || p.includes("\0")) throw new Error("choose a folder by its full path");
  let real: string;
  try {
    real = realpathSync(p);
  } catch {
    throw new Error("that folder does not exist");
  }
  if (!statSync(real).isDirectory()) throw new Error("that is not a folder");
  return real;
}

function readMcpDecls(dir: string): { servers: McpDecl[]; warnings: string[] } {
  const warnings: string[] = [];
  const servers: McpDecl[] = [];
  const file = join(dir, ".mcp.json");
  const j = existsSync(file) ? readJsonFile(file) : null;
  const map = j && isRecord(j.mcpServers) ? j.mcpServers : j && isRecord(j) && !("mcpServers" in j) ? null : null;
  if (!map) return { servers, warnings };
  for (const [name, raw] of Object.entries(map)) {
    if (!isRecord(raw)) continue;
    if (typeof raw.command === "string" && raw.command) {
      const args = Array.isArray(raw.args) ? raw.args.filter((a): a is string => typeof a === "string") : [];
      servers.push({ name: name.slice(0, 60), transport: "stdio", command: raw.command, args });
      if (isRecord(raw.env) && Object.keys(raw.env).length) warnings.push(`"${name}" sets environment variables; Opscode does not pass them on.`);
    } else if (typeof raw.url === "string") {
      try {
        servers.push({ name: name.slice(0, 60), transport: "http", url: validateBaseUrl(raw.url) });
      } catch (e) {
        warnings.push(`"${name}" skipped: ${e instanceof Error ? e.message : String(e)}`);
      }
      if (isRecord(raw.headers) && Object.keys(raw.headers).length) warnings.push(`"${name}" needs request headers (a sign-in); Opscode does not send them.`);
    }
  }
  return { servers, warnings };
}

/** Copies a plugin folder: regular files and directories only, bounded. */
function copyTree(src: string, dst: string): void {
  let files = 0;
  let bytes = 0;
  const walk = (from: string, to: string): void => {
    mkdirSync(to, { recursive: true, mode: 0o700 });
    for (const name of readdirSync(from)) {
      if (SKIP.has(name)) continue;
      const f = join(from, name);
      const st = lstatSync(f);
      if (st.isSymbolicLink()) continue;
      if (st.isDirectory()) walk(f, join(to, name));
      else if (st.isFile()) {
        files++;
        bytes += st.size;
        if (files > COPY_LIMITS.FILES || bytes > COPY_LIMITS.BYTES) throw new Error(`that folder is too large for a plugin (limit ${COPY_LIMITS.FILES} files, ${COPY_LIMITS.BYTES / 1024 / 1024} MB)`);
        const out = join(to, name);
        copyFileSync(f, out);
        chmodSync(out, (st.mode & 0o700) | 0o600); // owner-only; keeps an executable bit

      }
    }
  };
  walk(src, dst);
}

export class PluginStore {
  private readonly file: string;
  private readonly marketsFile: string;
  private readonly dir: string;
  private plugins: Installed[];
  private markets: Market[];

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.dir = join(stateDir, "plugins");
    ensurePrivateDir(this.dir);
    this.file = join(stateDir, "plugins.json");
    this.marketsFile = join(stateDir, "marketplaces.json");
    this.plugins = this.loadInstalled();
    this.markets = this.loadMarkets();
  }

  private loadInstalled(): Installed[] {
    const raw = readJson(this.file);
    if (!Array.isArray(raw)) return [];
    return raw.filter(
      (p): p is Installed => isRecord(p) && typeof p.id === "string" && /^[a-z0-9-]{1,80}$/.test(p.id) && typeof p.name === "string" && typeof p.enabled === "boolean" && typeof p.source === "string" && typeof p.installed_at === "string" && typeof p.description === "string" && typeof p.version === "string",
    );
  }
  private loadMarkets(): Market[] {
    const raw = readJson(this.marketsFile);
    if (!Array.isArray(raw)) return [];
    return raw.filter((m): m is Market => isRecord(m) && typeof m.id === "string" && typeof m.name === "string" && typeof m.path === "string");
  }
  private save(): void {
    writeJsonAtomic(this.file, this.plugins);
  }
  private saveMarkets(): void {
    writeJsonAtomic(this.marketsFile, this.markets);
  }

  private pluginDir(id: string): string {
    return join(this.dir, id);
  }

  // ---- reading folders --------------------------------------------------------

  private pluginMeta(dir: string): { name: string; description: string; version: string } {
    const j = readJsonFile(join(dir, ".claude-plugin", "plugin.json")) ?? {};
    return { name: asString(j.name, 80) || basename(dir), description: asString(j.description, 300), version: asString(j.version, 40) || "0.0.0" };
  }

  private marketplaceDoc(dir: string): { name: string; plugins: { name: string; description: string; source: string }[] } | null {
    const j = readJsonFile(join(dir, ".claude-plugin", "marketplace.json"));
    if (!j || !Array.isArray(j.plugins)) return null;
    const plugins: { name: string; description: string; source: string }[] = [];
    for (const p of j.plugins) {
      if (isRecord(p) && typeof p.name === "string" && typeof p.source === "string") plugins.push({ name: p.name.slice(0, 80), description: asString(p.description, 300), source: p.source });
    }
    return { name: asString(j.name, 80) || basename(dir), plugins };
  }

  /** A plugin's folder inside a marketplace; refuses anything that escapes it. */
  private marketPluginDir(marketDir: string, source: string): string | null {
    if (isAbsolute(source) || source.includes("\0")) return null;
    const p = resolve(marketDir, source);
    if (p !== marketDir && !p.startsWith(marketDir + sep)) return null;
    try {
      const real = realpathSync(p);
      return relative(marketDir, real).startsWith("..") ? null : real;
    } catch {
      return null;
    }
  }

  /** What a folder would bring in. Reads only; never runs or copies anything. */
  preview(path: string): FolderPreview {
    const dir = realDir(path);
    const mk = this.marketplaceDoc(dir);
    if (mk) {
      return { kind: "marketplace", name: mk.name, description: "", version: "", skills: [], mcp_servers: [], plugins: mk.plugins.map((p) => ({ name: p.name, description: p.description })), warnings: [] };
    }
    const hasPlugin = existsSync(join(dir, ".claude-plugin", "plugin.json")) || existsSync(join(dir, ".mcp.json")) || existsSync(join(dir, "skills"));
    if (hasPlugin) {
      const meta = this.pluginMeta(dir);
      const { servers, warnings } = readMcpDecls(dir);
      return {
        kind: "plugin",
        ...meta,
        skills: readSkillsDir(join(dir, "skills")).map((s) => ({ name: s.name, description: s.description })),
        mcp_servers: servers.map((s) => ({ name: s.name, transport: s.transport, target: s.transport === "stdio" ? [s.command, ...(s.args ?? [])].join(" ") : (s.url ?? "") })),
        plugins: [],
        warnings,
      };
    }
    const skills = readSkillsDir(dir);
    if (skills.length > 0) {
      return { kind: "skills", name: basename(dir), description: "", version: "", skills: skills.map((s) => ({ name: s.name, description: s.description })), mcp_servers: [], plugins: [], warnings: [] };
    }
    throw new Error("nothing to import in this folder: no plugin, marketplace or skills found");
  }

  // ---- installing ------------------------------------------------------------------

  install(path: string): PluginInfo {
    const dir = realDir(path);
    const pv = this.preview(dir);
    if (pv.kind !== "plugin") throw new Error(pv.kind === "marketplace" ? "this is a marketplace: add it, then install a plugin from it" : "this folder has skills but no plugin: import its skills instead");
    if (this.plugins.length >= MAX_PLUGINS) throw new Error(`at most ${MAX_PLUGINS} plugins`);
    const id = slugName(pv.name) || "plugin";
    if (this.plugins.some((p) => p.id === id)) throw new Error(`a plugin named “${pv.name}” is already installed; uninstall it first`);
    if (pv.skills.length === 0 && pv.mcp_servers.length === 0) throw new Error("this plugin has no skills or MCP servers");
    const dst = this.pluginDir(id);
    rmSync(dst, { recursive: true, force: true });
    try {
      copyTree(dir, dst);
    } catch (e) {
      rmSync(dst, { recursive: true, force: true });
      throw e;
    }
    const rec: Installed = { id, name: pv.name, description: pv.description, version: pv.version, enabled: true, source: dir, installed_at: new Date().toISOString() };
    this.plugins.push(rec);
    this.save();
    return this.info(rec);
  }

  /** Copies a folder's skills into `destDir` (a skills directory). */
  importSkills(path: string, destDir: string): string[] {
    const dir = realDir(path);
    const skills = readSkillsDir(dir);
    if (skills.length === 0) throw new Error("no skills found in that folder");
    const names: string[] = [];
    for (const s of skills) {
      writeSkill(destDir, s);
      names.push(s.name);
    }
    return names;
  }

  uninstall(id: string): boolean {
    const i = this.plugins.findIndex((p) => p.id === id);
    if (i < 0) return false;
    this.plugins.splice(i, 1);
    this.save();
    rmSync(this.pluginDir(id), { recursive: true, force: true });
    return true;
  }

  setEnabled(id: string, enabled: boolean): boolean {
    const p = this.plugins.find((x) => x.id === id);
    if (!p) return false;
    p.enabled = enabled;
    this.save();
    return true;
  }

  private info(p: Installed): PluginInfo {
    const dir = this.pluginDir(p.id);
    return {
      id: p.id, name: p.name, description: p.description, version: p.version, enabled: p.enabled, source: p.source,
      skills: readSkillsDir(join(dir, "skills")).map((s) => s.name),
      mcp_servers: readMcpDecls(dir).servers.map((s) => s.name),
    };
  }

  list(): PluginInfo[] {
    return this.plugins.map((p) => this.info(p));
  }

  /** Skills of enabled plugins. */
  skills(): { plugin: string; skill: ParsedSkill }[] {
    const out: { plugin: string; skill: ParsedSkill }[] = [];
    for (const p of this.plugins) {
      if (!p.enabled) continue;
      for (const skill of readSkillsDir(join(this.pluginDir(p.id), "skills"))) out.push({ plugin: p.name, skill });
    }
    return out;
  }

  /** MCP servers of enabled plugins; ${CLAUDE_PLUGIN_ROOT} / ${PLUGIN_ROOT} point at the installed copy. */
  mcpServers(): { plugin: string; id: string; name: string; transport: "stdio" | "http"; command?: string; args?: string[]; url?: string }[] {
    const out: { plugin: string; id: string; name: string; transport: "stdio" | "http"; command?: string; args?: string[]; url?: string }[] = [];
    for (const p of this.plugins) {
      if (!p.enabled) continue;
      const root = this.pluginDir(p.id);
      const sub = (v: string): string => v.replace(/\$\{(?:CLAUDE_)?PLUGIN_ROOT\}/g, root);
      for (const s of readMcpDecls(root).servers) {
        out.push({
          plugin: p.name, id: `plugin:${p.id}:${slugName(s.name)}`, name: s.name, transport: s.transport,
          ...(s.transport === "stdio" ? { command: sub(s.command ?? ""), args: (s.args ?? []).map(sub) } : { url: s.url }),
        });
      }
    }
    return out;
  }

  // ---- marketplaces ------------------------------------------------------------------------

  addMarketplace(path: string): MarketplaceInfo {
    const dir = realDir(path);
    const doc = this.marketplaceDoc(dir);
    if (!doc) throw new Error("that folder is not a marketplace (no .claude-plugin/marketplace.json)");
    if (this.markets.some((m) => m.path === dir)) throw new Error("that marketplace is already added");
    if (this.markets.length >= MAX_MARKETPLACES) throw new Error(`at most ${MAX_MARKETPLACES} marketplaces`);
    const m: Market = { id: randomUUID(), name: doc.name, path: dir };
    this.markets.push(m);
    this.saveMarkets();
    return this.marketInfo(m);
  }

  removeMarketplace(id: string): boolean {
    const i = this.markets.findIndex((m) => m.id === id);
    if (i < 0) return false;
    this.markets.splice(i, 1);
    this.saveMarkets();
    return true;
  }

  private marketInfo(m: Market): MarketplaceInfo {
    const doc = existsSync(m.path) ? this.marketplaceDoc(m.path) : null;
    if (!doc) return { id: m.id, name: m.name, path: m.path, plugins: [], error: "the folder or its marketplace.json is gone" };
    const plugins: MarketplaceInfo["plugins"] = [];
    for (const p of doc.plugins) {
      const pd = this.marketPluginDir(m.path, p.source);
      if (!pd) continue;
      const meta = this.pluginMeta(pd);
      plugins.push({ name: meta.name || p.name, description: p.description || meta.description, installed: this.plugins.some((x) => x.id === slugName(meta.name || p.name)), path: pd });
    }
    return { id: m.id, name: m.name, path: m.path, plugins };
  }

  marketplaces(): MarketplaceInfo[] {
    return this.markets.map((m) => this.marketInfo(m));
  }

  /** Only a plugin that a marketplace lists can be installed by marketplace id + name. */
  marketplacePluginPath(marketId: string, pluginName: string): string {
    const m = this.markets.find((x) => x.id === marketId);
    if (!m) throw new Error("no such marketplace");
    const p = this.marketInfo(m).plugins.find((x) => x.name === pluginName);
    if (!p) throw new Error("that marketplace does not list this plugin");
    return p.path;
  }
}

export { SKILL_NAME, splitCommand };
