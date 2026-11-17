// Memory: short notes that agents read at the start of every chat.
// Notes you write or keep are loaded; an agent's own notes stay drafts until
// you keep, edit or pin them. Stored in the private state dir.

import { randomUUID } from "node:crypto";
import { join } from "node:path";
import type { Note, NoteState } from "../shared/protocol";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { isRecord } from "./rpc";

export const NOTE_LIMITS = { TITLE: 120, BODY: 2000, COUNT: 500, PROMPT_CHARS: 6000 } as const;

export class MemoryStore {
  private readonly file: string;
  private notes: Note[];

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "memory.json");
    this.notes = this.load();
  }

  private load(): Note[] {
    const raw = readJson(this.file);
    if (!Array.isArray(raw)) return [];
    const out: Note[] = [];
    for (const n of raw) {
      if (
        isRecord(n) && typeof n.id === "string" && typeof n.title === "string" && typeof n.body === "string" && typeof n.scope === "string" &&
        (n.state === "kept" || n.state === "draft") && typeof n.pinned === "boolean" && typeof n.created_at === "string" && typeof n.updated_at === "string"
      ) out.push(n as unknown as Note);
    }
    return out;
  }
  private save(): void {
    writeJsonAtomic(this.file, this.notes);
  }

  list(): Note[] {
    return this.notes.map((n) => ({ ...n })).sort((a, b) => b.updated_at.localeCompare(a.updated_at));
  }

  add(o: { title?: string; body: string; scope: string; state?: NoteState; pinned?: boolean }): Note {
    const body = o.body.trim();
    if (!body) throw new Error("a note needs some text");
    if (body.length > NOTE_LIMITS.BODY) throw new Error(`a note can be at most ${NOTE_LIMITS.BODY} characters`);
    if ((o.title ?? "").length > NOTE_LIMITS.TITLE) throw new Error(`a title can be at most ${NOTE_LIMITS.TITLE} characters`);
    if (this.notes.length >= NOTE_LIMITS.COUNT) throw new Error(`at most ${NOTE_LIMITS.COUNT} notes; forget some first`);
    const now = new Date().toISOString();
    const note: Note = { id: randomUUID(), title: (o.title ?? "").trim(), body, scope: o.scope, state: o.state ?? "kept", pinned: o.pinned ?? false, created_at: now, updated_at: now };
    this.notes.push(note);
    this.save();
    return { ...note };
  }

  /** Editing a draft counts as keeping it. */
  update(id: string, patch: { title?: string; body?: string; scope?: string; state?: NoteState; pinned?: boolean }): Note | undefined {
    const n = this.notes.find((x) => x.id === id);
    if (!n) return undefined;
    if (patch.body !== undefined) {
      const b = patch.body.trim();
      if (!b) throw new Error("a note needs some text");
      if (b.length > NOTE_LIMITS.BODY) throw new Error(`a note can be at most ${NOTE_LIMITS.BODY} characters`);
      n.body = b;
    }
    if (patch.title !== undefined) {
      if (patch.title.length > NOTE_LIMITS.TITLE) throw new Error(`a title can be at most ${NOTE_LIMITS.TITLE} characters`);
      n.title = patch.title.trim();
    }
    if (patch.scope !== undefined) n.scope = patch.scope;
    if (patch.pinned !== undefined) n.pinned = patch.pinned;
    if (patch.state !== undefined) n.state = patch.state;
    else if (patch.body !== undefined || patch.title !== undefined) n.state = "kept";
    n.updated_at = new Date().toISOString();
    this.save();
    return { ...n };
  }

  remove(id: string): boolean {
    const i = this.notes.findIndex((n) => n.id === id);
    if (i < 0) return false;
    this.notes.splice(i, 1);
    this.save();
    return true;
  }

  /** Notes about a project that is no longer added. */
  forgetScope(scope: string): number {
    const before = this.notes.length;
    this.notes = this.notes.filter((n) => n.scope !== scope);
    if (this.notes.length !== before) this.save();
    return before - this.notes.length;
  }

  /** Text for the system prompt: kept or pinned notes for "global" and this project. */
  promptFor(workspaceId: string): string {
    const rows = this.notes
      .filter((n) => (n.scope === "global" || n.scope === workspaceId) && (n.state === "kept" || n.pinned))
      .sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.updated_at.localeCompare(a.updated_at));
    const lines: string[] = [];
    let used = 0;
    for (const n of rows) {
      const line = `- ${n.title ? `${n.title}: ` : ""}${n.body.replace(/\s*\n\s*/g, " ")}`;
      if (used + line.length > NOTE_LIMITS.PROMPT_CHARS) break;
      lines.push(line);
      used += line.length;
    }
    return lines.join("\n");
  }
}
