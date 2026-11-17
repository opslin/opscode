// The Library: the person's existing apps, indexed so Opscode can answer "do we
// already have X, and where?" without spending model tokens. Nothing is indexed
// until the person adds an app. Read-only: it never writes into an app's folder.
//
// State: <state>/library/registry.json (the apps) and <state>/library/<id>.json
// (per-file facts, so a re-index reads only files that changed).

import { existsSync, mkdirSync, readdirSync, realpathSync, rmSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve, sep } from "node:path";
import { Worker } from "node:worker_threads";
import { randomBytes } from "node:crypto";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";
import { buildModel } from "./model";
import type { Feature, Model, Pkg } from "./model";
import { context, corpusOf, search } from "./search";
import type { Corpus, Hit } from "./search";
import type { FileFact } from "./scan";
import type { ScanResult } from "./scan";

const VERSION = 1;
const MAX_APPS = 20;

export interface AppRec {
  id: string; name: string; path: string; added_at: string; indexed_at?: string;
  status: "indexing" | "ready" | "error"; error?: string;
  files?: number; features?: number; truncated?: boolean;
  packages?: { name: string; root: string; layer: string; stack: string[]; files: number }[];
}
interface Loaded { facts: Map<string, FileFact>; model: Model; corpus: Corpus }

/** Folders that belong to other apps or to the system: never indexed. */
function blocked(path: string, stateDir: string): string | null {
  const home = homedir();
  const bad = [".caveman-code", ".claude", ".codex", ".ssh", ".aws", ".gnupg", "Library", ".Trash"].map((d) => join(home, d));
  if (path === "/" || path === home) return "That folder is too broad. Pick one app's folder.";
  for (const b of [...bad, resolve(stateDir)]) if (path === b || path.startsWith(b + sep)) return `${basename(b)} belongs to another app or to Opscode itself.`;
  for (const sys of ["/System", "/usr", "/bin", "/sbin", "/etc", "/private/etc", "/private/var/db"]) if (path === sys || path.startsWith(sys + "/")) return "That is a system folder.";
  return null;
}

export class LibraryService {
  private readonly dir: string;
  private apps: AppRec[] = [];
  private loaded = new Map<string, { at: number; v: Loaded }>();
  private running = new Map<string, Promise<void>>();
  progress = new Map<string, number>();

  constructor(private readonly stateDir: string, private readonly notify: (method: string, params: unknown) => void) {
    this.dir = join(stateDir, "library");
    ensurePrivateDir(stateDir);
    mkdirSync(this.dir, { recursive: true, mode: 0o700 });
    const raw = readJson(join(this.dir, "registry.json"));
    if (isRecord(raw) && raw.version === VERSION && Array.isArray(raw.apps)) this.apps = (raw.apps as AppRec[]).filter((a) => a && typeof a.id === "string" && typeof a.path === "string").map((a) => ({ ...a, status: a.status === "indexing" ? "error" : a.status, ...(a.status === "indexing" ? { error: "Opscode closed while indexing; read it again." } : {}) }));
  }

  private save(): void { writeJsonAtomic(join(this.dir, "registry.json"), { version: VERSION, apps: this.apps }); }
  private changed(): void { this.notify("library.changed", { apps: this.list() }); }
  list(): AppRec[] { return this.apps.map((a) => ({ ...a })); }
  app(id: string): AppRec { const a = this.apps.find((x) => x.id === id); if (!a) throw new Error("no such app in the Library"); return a; }

  /** Git repos and package folders in the Documents folder that are not in the Library yet (a shortcut for "Add app"). */
  suggestions(): { path: string; name: string }[] {
    const root = process.env.OPSCODE_LIBRARY_SUGGEST_ROOT || join(homedir(), "Documents");
    const have = new Set(this.apps.map((a) => a.path));
    const out: { path: string; name: string }[] = [];
    let names: string[] = [];
    try { names = readdirSync(root).sort(); } catch { return out; }
    for (const n of names) {
      if (n.startsWith(".")) continue;
      const p = join(root, n);
      try {
        if (!statSync(p).isDirectory() || have.has(realpathSync(p))) continue;
        const kids = readdirSync(p);
        const marks = [".git", "package.json", "pubspec.yaml", "go.mod", "pyproject.toml", "composer.json"];
        if (kids.some((k) => marks.includes(k)) || kids.some((k) => { try { return statSync(join(p, k)).isDirectory() && marks.some((m) => existsSync(join(p, k, m))); } catch { return false; } })) out.push({ path: realpathSync(p), name: n });
      } catch { /* unreadable */ }
    }
    return out.slice(0, 40);
  }

  add(path: string, name?: string): AppRec {
    if (this.apps.length >= MAX_APPS) throw new Error(`The Library holds at most ${MAX_APPS} apps`);
    let real: string;
    try { real = realpathSync(resolve(path)); } catch { throw new Error("That folder does not exist"); }
    if (!statSync(real).isDirectory()) throw new Error("That is not a folder");
    const why = blocked(real, this.stateDir);
    if (why) throw new Error(why);
    const have = this.apps.find((a) => a.path === real);
    if (have) return have;
    const app: AppRec = { id: randomBytes(5).toString("hex"), name: (name ?? "").trim().slice(0, 60) || basename(real), path: real, added_at: new Date().toISOString(), status: "indexing" };
    this.apps.push(app);
    this.save();
    void this.reindex(app.id);
    this.changed();
    return app;
  }

  remove(id: string): boolean {
    const i = this.apps.findIndex((a) => a.id === id);
    if (i < 0) return false;
    this.apps.splice(i, 1);
    this.loaded.delete(id);
    rmSync(join(this.dir, `${id}.json`), { force: true });
    this.save();
    this.changed();
    return true;
  }

  private factsFile(id: string): string { return join(this.dir, `${id}.json`); }
  private readFacts(id: string): FileFact[] {
    const raw = readJson(this.factsFile(id));
    return isRecord(raw) && raw.version === VERSION && Array.isArray(raw.files) ? (raw.files as FileFact[]) : [];
  }

  /** Reads what is new or changed in the app's folder (in a worker thread) and rebuilds its model. */
  reindex(id: string): Promise<void> {
    const have = this.running.get(id);
    if (have) return have;
    const app = this.app(id);
    const p = (async () => {
      app.status = "indexing"; delete app.error;
      this.changed();
      try {
        const old = this.loaded.get(id)?.v.facts ?? new Map(this.readFacts(id).map((f) => [f.p, f]));
        const result = await this.scanInWorker(app.path, [...old.values()].map((f) => [f.p, f.s, f.m] as [string, number, number]), id);
        const facts = new Map<string, FileFact>();
        for (const path of result.unchanged) { const f = old.get(path); if (f) facts.set(path, f); }
        for (const f of result.changed) facts.set(f.p, f);
        const list = [...facts.values()];
        writeJsonAtomic(this.factsFile(id), { version: VERSION, root: app.path, files: list });
        const model = buildModel(list);
        this.loaded.set(id, { at: Date.now(), v: { facts, model, corpus: corpusOf(id, app.name, model) } });
        app.status = "ready"; app.indexed_at = new Date().toISOString(); app.files = list.length; app.features = model.features.length; app.truncated = result.truncated;
        app.packages = model.packages.map((k: Pkg) => ({ name: k.name, root: k.root, layer: k.layer, stack: k.stack, files: k.files }));
      } catch (e) {
        app.status = "error"; app.error = e instanceof Error ? e.message : String(e);
      }
      this.progress.delete(id);
      this.save();
      this.changed();
    })().finally(() => this.running.delete(id));
    this.running.set(id, p);
    return p;
  }

  private scanInWorker(root: string, known: [string, number, number][], id: string): Promise<ScanResult> {
    return new Promise((resolveP, reject) => {
      const w = new Worker(join(__dirname, "worker.js"), { workerData: { root, known } });
      let settled = false;
      const end = (fn: () => void): void => { if (!settled) { settled = true; fn(); } };
      w.on("message", (m: { type: string; seen?: number; result?: ScanResult; message?: string }) => {
        if (m.type === "progress") { this.progress.set(id, m.seen ?? 0); this.notify("library.progress", { app_id: id, files: m.seen ?? 0 }); }
        else if (m.type === "done" && m.result) { void w.terminate(); end(() => resolveP(m.result as ScanResult)); }
        else if (m.type === "error") { void w.terminate(); end(() => reject(new Error(m.message ?? "indexing failed"))); }
      });
      w.on("error", (e) => end(() => reject(e)));
      w.on("exit", () => end(() => reject(new Error("the indexer stopped"))));
    });
  }

  /** The model of an app, loaded from its saved facts when needed (and freed after 5 idle minutes). */
  private get(id: string): Loaded {
    const app = this.app(id);
    const hit = this.loaded.get(id);
    if (hit) { hit.at = Date.now(); return hit.v; }
    if (app.status === "indexing" && !this.readFacts(id).length) throw new Error("This app is still being indexed");
    const list = this.readFacts(id);
    const model = buildModel(list);
    const v: Loaded = { facts: new Map(list.map((f) => [f.p, f])), model, corpus: corpusOf(id, app.name, model) };
    this.loaded.set(id, { at: Date.now(), v });
    const t = setTimeout(() => { const l = this.loaded.get(id); if (l && Date.now() - l.at >= 5 * 60_000 && !this.running.has(id)) this.loaded.delete(id); }, 5 * 60_000 + 500);
    t.unref();
    return v;
  }

  detail(id: string): { app: AppRec; packages: Pkg[]; features: { id: string; name: string; layers: { layer: string; package: string; files: number }[]; file_count: number; routes: number; tables: number }[]; coverage: Model["coverage"]; orphans: Model["orphans"] } {
    const app = this.app(id);
    const { model } = this.get(id);
    return { app: { ...app }, packages: model.packages, features: model.features.map((f) => ({ id: f.id, name: f.name, layers: f.layers.map((l) => ({ layer: l.layer, package: l.package, files: l.file_count })), file_count: f.file_count, routes: f.routes.length, tables: f.tables.length })), coverage: model.coverage, orphans: model.orphans };
  }

  feature(id: string, featureId: string): { feature: Feature; related: { id: string; name: string; links: number }[] } {
    const { model } = this.get(id);
    const f = model.features.find((x) => x.id === featureId);
    if (!f) throw new Error("no such feature");
    const mine = new Set(f.layers.flatMap((l) => l.files));
    const links = new Map<string, number>();
    for (const p of mine) {
      for (const n of [...(model.out.get(p) ?? []), ...(model.rev.get(p) ?? [])]) {
        const other = model.fileFeature.get(n);
        if (other && other !== f.id) links.set(other, (links.get(other) ?? 0) + 1);
      }
    }
    const related = [...links].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([fid, n]) => ({ id: fid, name: model.features.find((x) => x.id === fid)?.name ?? fid, links: n }));
    return { feature: f, related };
  }

  search(query: string, appIds?: string[], limit = 12): Hit[] {
    const ready = this.apps.filter((a) => a.status === "ready" && (!appIds?.length || appIds.includes(a.id)));
    return search(ready.map((a) => this.get(a.id).corpus), query, limit);
  }

  context(id: string, query: string, maxFiles = 15): { app: string; features: string[]; files: { path: string; why: string; lines: number; score: number }[] } {
    const { corpus } = this.get(id);
    return { app: this.app(id).name, ...context(corpus, query, maxFiles) };
  }
}
