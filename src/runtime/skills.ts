// Skills: a folder with a SKILL.md (frontmatter: name, description; body: the
// steps). Personal skills live in the state dir, project skills in
// <project>/.opscode/skills/ (commit them to share), plugin skills come from
// installed plugins. The agent sees names + descriptions and loads a body on demand.

import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { SkillInfo } from "../shared/protocol";

export const SKILL_LIMITS = { NAME: 64, DESCRIPTION: 300, BODY: 20_000 } as const;
export const SKILL_NAME = /^[a-z0-9][a-z0-9-]{0,63}$/;

export interface ParsedSkill {
  name: string;
  description: string;
  body: string;
}

/** Reads `---\nkey: value\n---\nbody`. Values may be quoted. Returns null if there is no name. */
export function parseSkill(text: string, fallbackName?: string): ParsedSkill | null {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(text);
  const fm: Record<string, string> = {};
  let body = text;
  if (m) {
    body = m[2];
    for (const line of m[1].split(/\r?\n/)) {
      const kv = /^([A-Za-z_-]+):\s*(.*)$/.exec(line);
      if (kv) fm[kv[1].toLowerCase()] = kv[2].trim().replace(/^(["'])([\s\S]*)\1$/, "$2");
    }
  }
  const name = (fm.name ?? fallbackName ?? "").trim();
  if (!SKILL_NAME.test(name)) return null;
  return { name, description: (fm.description ?? "").slice(0, SKILL_LIMITS.DESCRIPTION), body: body.trim().slice(0, SKILL_LIMITS.BODY) };
}

export function serializeSkill(s: ParsedSkill): string {
  const one = (v: string): string => v.replace(/\s*\n\s*/g, " ").trim();
  return `---\nname: ${s.name}\ndescription: ${JSON.stringify(one(s.description))}\n---\n\n${s.body.trim()}\n`;
}

/** Skills in a directory: each child folder with a SKILL.md. Never follows symlinks. */
export function readSkillsDir(dir: string): ParsedSkill[] {
  const out: ParsedSkill[] = [];
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return out;
  }
  for (const name of entries.sort()) {
    const d = join(dir, name);
    const f = join(d, "SKILL.md");
    try {
      if (!lstatSync(d).isDirectory() || !lstatSync(f).isFile()) continue;
      const sk = parseSkill(readFileSync(f, "utf8"), name);
      if (sk) out.push(sk);
    } catch { /* unreadable: skip */ }
  }
  return out;
}

export function writeSkill(dir: string, s: ParsedSkill): void {
  if (!SKILL_NAME.test(s.name)) throw new Error("a skill name is lowercase letters, digits and dashes, like release-notes");
  if (!s.description.trim()) throw new Error("say when to use it, in one line");
  if (!s.body.trim()) throw new Error("write the steps");
  if (s.description.length > SKILL_LIMITS.DESCRIPTION) throw new Error(`the description can be at most ${SKILL_LIMITS.DESCRIPTION} characters`);
  if (s.body.length > SKILL_LIMITS.BODY) throw new Error(`the steps can be at most ${SKILL_LIMITS.BODY} characters`);
  const skillDir = join(dir, s.name);
  mkdirSync(skillDir, { recursive: true, mode: 0o700 });
  const tmp = join(skillDir, `.SKILL.md.${process.pid}.tmp`);
  writeFileSync(tmp, serializeSkill(s), { mode: 0o600 });
  renameSync(tmp, join(skillDir, "SKILL.md"));
}

export function deleteSkill(dir: string, name: string): boolean {
  if (!SKILL_NAME.test(name)) return false;
  const d = join(dir, name);
  if (!existsSync(join(d, "SKILL.md"))) return false;
  rmSync(d, { recursive: true, force: true });
  return true;
}

export const toInfo = (s: ParsedSkill, scope: SkillInfo["scope"], plugin?: string): SkillInfo => ({ name: s.name, description: s.description, scope, ...(plugin ? { plugin } : {}) });
