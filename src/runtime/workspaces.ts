// The user's project folders. Paths are stored fully resolved (realpath) so
// every later check compares against a canonical root.

import { randomUUID } from "node:crypto";
import { realpathSync, statSync } from "node:fs";
import { basename, isAbsolute, join, parse } from "node:path";
import type { Workspace } from "../shared/protocol";
import { readJson, writeJsonAtomic } from "./jsonFile";
import { fail, isRecord } from "./rpc";

const isWorkspace = (v: unknown): v is Workspace =>
  isRecord(v) &&
  typeof v.id === "string" &&
  typeof v.name === "string" &&
  typeof v.path === "string" &&
  isAbsolute(v.path) &&
  typeof v.added_at === "string";

export class WorkspaceStore {
  private readonly file: string;
  private items: Workspace[];

  /** stateDir must already exist (SettingsStore creates it 0700). */
  constructor(stateDir: string) {
    this.file = join(stateDir, "workspaces.json");
    const raw = readJson(this.file);
    this.items = Array.isArray(raw) ? raw.filter(isWorkspace) : [];
  }

  list(): Workspace[] {
    return this.items.map((w) => ({ ...w }));
  }

  get(id: string): Workspace | undefined {
    const w = this.items.find((x) => x.id === id);
    return w && { ...w };
  }

  /** Adds a directory (deduplicated by real path). Throws RpcFailure. */
  add(rawPath: string): { workspace: Workspace; created: boolean } {
    if (!isAbsolute(rawPath)) throw fail.invalid("path must be absolute");
    let real: string;
    try {
      real = realpathSync(rawPath);
    } catch {
      throw fail.notFound("no such directory");
    }
    if (!statSync(real).isDirectory()) throw fail.invalid("path is not a directory");
    if (real === parse(real).root) throw fail.invalid("the filesystem root cannot be a project");

    const existing = this.items.find((w) => w.path === real);
    if (existing) return { workspace: { ...existing }, created: false };

    const workspace: Workspace = {
      id: randomUUID(),
      name: basename(real),
      path: real,
      added_at: new Date().toISOString(),
    };
    this.items.push(workspace);
    writeJsonAtomic(this.file, this.items);
    return { workspace: { ...workspace }, created: true };
  }

  remove(id: string): boolean {
    const before = this.items.length;
    this.items = this.items.filter((w) => w.id !== id);
    if (this.items.length === before) return false;
    writeJsonAtomic(this.file, this.items);
    return true;
  }
}
