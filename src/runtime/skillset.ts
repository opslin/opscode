// The skills a chat can see: project (<project>/.opscode/skills) over personal
// (state dir) over plugin skills. Same name -> the narrower scope wins.

import { existsSync, lstatSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import type { SkillInfo, SkillScope, Workspace } from "../shared/protocol";
import { ensurePrivateDir } from "./jsonFile";
import { rootOf } from "./paths";
import type { PluginStore } from "./plugins";
import { deleteSkill, readSkillsDir, toInfo, writeSkill, type ParsedSkill } from "./skills";

export class SkillSet {
  readonly userDir: string;

  constructor(stateDir: string, private readonly plugins: PluginStore, private readonly workspace: (id: string) => Workspace | undefined) {
    ensurePrivateDir(stateDir);
    this.userDir = join(stateDir, "skills");
    ensurePrivateDir(this.userDir);
  }

  /** <project>/.opscode/skills; refuses when .opscode is a symlink (it could point outside). */
  projectDir(workspaceId: string, create: boolean): string | null {
    const ws = this.workspace(workspaceId);
    if (!ws) throw new Error("no such project");
    const root = rootOf(ws);
    const od = join(root, ".opscode");
    if (existsSync(od) && lstatSync(od).isSymbolicLink()) throw new Error(".opscode in this project is a link; refusing to use it");
    const dir = join(od, "skills");
    if (existsSync(dir) && lstatSync(dir).isSymbolicLink()) throw new Error(".opscode/skills in this project is a link; refusing to use it");
    if (create) mkdirSync(dir, { recursive: true });
    return existsSync(dir) ? dir : null;
  }

  private all(workspaceId?: string): { info: SkillInfo; skill: ParsedSkill }[] {
    const seen = new Set<string>();
    const out: { info: SkillInfo; skill: ParsedSkill }[] = [];
    const add = (skill: ParsedSkill, scope: SkillScope, plugin?: string): void => {
      if (seen.has(skill.name)) return;
      seen.add(skill.name);
      out.push({ info: toInfo(skill, scope, plugin), skill });
    };
    if (workspaceId && this.workspace(workspaceId)) {
      try {
        const d = this.projectDir(workspaceId, false);
        if (d) for (const s of readSkillsDir(d)) add(s, "project");
      } catch { /* a missing or linked project folder simply has no project skills */ }
    }
    for (const s of readSkillsDir(this.userDir)) add(s, "user");
    for (const { plugin, skill } of this.plugins.skills()) add(skill, "plugin", plugin);
    return out;
  }

  /** Without a workspace: personal + plugin skills only. */
  list(workspaceId?: string): SkillInfo[] {
    return this.all(workspaceId).map((x) => x.info);
  }

  get(workspaceId: string | undefined, name: string): { info: SkillInfo; body: string } | undefined {
    const hit = this.all(workspaceId).find((x) => x.info.name === name);
    return hit ? { info: hit.info, body: hit.skill.body } : undefined;
  }

  /** Project and personal skills with the path of their SKILL.md, for engines that read files themselves (Claude Code, Codex). */
  files(workspaceId?: string): { name: string; description: string; path: string }[] {
    const out: { name: string; description: string; path: string }[] = [];
    const seen = new Set<string>();
    const add = (dir: string | null): void => {
      if (!dir) return;
      for (const s of readSkillsDir(dir)) if (!seen.has(s.name)) { seen.add(s.name); out.push({ name: s.name, description: s.description, path: join(dir, s.name, "SKILL.md") }); }
    };
    if (workspaceId && this.workspace(workspaceId)) { try { add(this.projectDir(workspaceId, false)); } catch { /* none */ } }
    add(this.userDir);
    return out.slice(0, 40);
  }

  has(name: string): boolean {
    return readSkillsDir(this.userDir).some((s) => s.name === name);
  }

  save(scope: "user" | "project", workspaceId: string | undefined, skill: ParsedSkill): void {
    if (scope === "user") return writeSkill(this.userDir, skill);
    if (!workspaceId) throw new Error("choose a project for a project skill");
    writeSkill(this.projectDir(workspaceId, true) as string, skill);
  }

  remove(scope: "user" | "project", workspaceId: string | undefined, name: string): boolean {
    if (scope === "user") return deleteSkill(this.userDir, name);
    if (!workspaceId) throw new Error("choose a project");
    const d = this.projectDir(workspaceId, false);
    return d ? deleteSkill(d, name) : false;
  }
}
