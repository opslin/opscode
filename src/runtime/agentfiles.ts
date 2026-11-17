// Agent files: named helpers the main agent can hand a task to (a "sub-agent").
// One markdown file each: frontmatter (name, description, access) + instructions.
// Personal ones live in the state dir (agents/), project ones in
// <project>/.opscode/agents/ (commit them to share). Opscode ships one built in.

import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { Workspace } from "../shared/protocol";
import { ensurePrivateDir } from "./jsonFile";
import { rootOf } from "./paths";
import { SKILL_NAME } from "./skills";

export type AgentAccess = "read" | "edit" | "full";
export type AgentScope = "builtin" | "user" | "project";
export const AGENT_NAME = SKILL_NAME;
export const AGENT_LIMITS = { DESCRIPTION: 300, BODY: 20_000 } as const;
export const ACCESS_LEVELS: readonly AgentAccess[] = ["read", "edit", "full"];

export interface AgentDef {
  name: string;
  description: string;
  /** The most it may do: read files; also edit files; also run commands. The chat's own mode still applies on top. */
  access: AgentAccess;
  body: string;
  /** Optional, for automations: which engine and model this agent prefers, and the words it may decide. */
  engine?: "api" | "claude-code" | "codex";
  model?: string;
  decides?: string[];
}
export interface AgentInfo {
  name: string;
  description: string;
  access: AgentAccess;
  scope: AgentScope;
}

const BUILTIN: AgentDef[] = [
  {
    name: "explorer",
    description: "Looks through the project and reports what it found. Reads only; never changes anything.",
    access: "read",
    body: "Find the answer to the task by reading files. Start with list_dir, then read only what you need. Report what you found as a short list with file paths, and say what you could not find.",
  },
  {
    name: "planner",
    description: "Turns a brief into a short, ordered build plan with files, components to reuse and checks.",
    access: "read",
    body: "Read the brief, any requirements file and the code. Write a plan a builder can follow: the parts in order, the files each part touches, existing components to reuse (with paths), and the check that proves each part works. Keep it under 60 lines. Do not write code.",
  },
  {
    name: "builder",
    description: "Implements a plan or task in the project and makes the checks pass.",
    access: "edit",
    body: "Do the task in small, focused changes. Reuse what the project already has before writing new code. Run the project's checks when you can. Report what you changed (files) and what is left, in a few lines.",
  },
  {
    name: "designer",
    description: "Builds UI: screens, components and styles that match the design brief.",
    access: "edit",
    body: "Build the UI the task describes, reusing the project's existing components and styles. Keep screens responsive and accessible. Report the screens and components you made, with paths.",
  },
  {
    name: "reviewer",
    description: "Reviews the latest work against the task and decides approve or request_changes.",
    access: "read",
    decides: ["approve", "request_changes"],
    body: "Review the work in the data blocks and the project's changes. Look for bugs, missing parts of the task and broken checks. List concrete problems, most severe first, each with a file and a fix. Approve only when nothing serious is left.",
  },
  {
    name: "writer",
    description: "Writes marketing copy: posts, pages and announcements from the project's real features.",
    access: "edit",
    body: "Read the project to learn what it really does. Write the requested copy in plain, specific language with no invented claims. Save it where the task says. Report the files you wrote.",
  },
];

export function parseAgent(text: string, fallbackName?: string): AgentDef | null {
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
  if (!AGENT_NAME.test(name)) return null;
  const access = ACCESS_LEVELS.includes(fm.access as AgentAccess) ? (fm.access as AgentAccess) : "read";
  const engine = ["api", "claude-code", "codex"].includes(fm.engine ?? "") ? (fm.engine as AgentDef["engine"]) : undefined;
  const decides = fm.decides ? fm.decides.replace(/^\[|\]$/g, "").split(",").map((x) => x.trim()).filter((x) => /^[a-z][a-z0-9_-]{0,39}$/.test(x)) : [];
  return { name, description: (fm.description ?? "").slice(0, AGENT_LIMITS.DESCRIPTION), access, body: body.trim().slice(0, AGENT_LIMITS.BODY), ...(engine ? { engine } : {}), ...(fm.model ? { model: fm.model.slice(0, 120) } : {}), ...(decides.length ? { decides } : {}) };
}

export const serializeAgent = (a: AgentDef): string =>
  `---\nname: ${a.name}\ndescription: ${JSON.stringify(a.description.replace(/\s*\n\s*/g, " ").trim())}\naccess: ${a.access}\n${a.engine ? `engine: ${a.engine}\n` : ""}${a.model ? `model: ${a.model}\n` : ""}${a.decides?.length ? `decides: [${a.decides.join(", ")}]\n` : ""}---\n\n${a.body.trim()}\n`;

function readDir(dir: string): AgentDef[] {
  const out: AgentDef[] = [];
  let names: string[];
  try {
    names = readdirSync(dir).sort();
  } catch {
    return out;
  }
  for (const f of names) {
    if (!f.endsWith(".md")) continue;
    try {
      const p = join(dir, f);
      if (!lstatSync(p).isFile()) continue;
      const a = parseAgent(readFileSync(p, "utf8"), f.slice(0, -3));
      if (a && a.description.trim() && a.body.trim()) out.push(a);
    } catch { /* unreadable: skip */ }
  }
  return out;
}

function validate(a: AgentDef): void {
  if (!AGENT_NAME.test(a.name)) throw new Error("an agent name is lowercase letters, digits and dashes, like code-reviewer");
  if (!a.description.trim()) throw new Error("say when to use it, in one line");
  if (!a.body.trim()) throw new Error("write its instructions");
  if (a.description.length > AGENT_LIMITS.DESCRIPTION) throw new Error(`the description can be at most ${AGENT_LIMITS.DESCRIPTION} characters`);
  if (a.body.length > AGENT_LIMITS.BODY) throw new Error(`the instructions can be at most ${AGENT_LIMITS.BODY} characters`);
  if (!ACCESS_LEVELS.includes(a.access)) throw new Error("access is read, edit or full");
}

export class AgentSet {
  readonly userDir: string;

  constructor(stateDir: string, private readonly workspace: (id: string) => Workspace | undefined) {
    ensurePrivateDir(stateDir);
    this.userDir = join(stateDir, "agents");
    ensurePrivateDir(this.userDir);
  }

  /** <project>/.opscode/agents; refuses when a link is in the way (it could point outside). */
  projectDir(workspaceId: string, create: boolean): string | null {
    const ws = this.workspace(workspaceId);
    if (!ws) throw new Error("no such project");
    const od = join(rootOf(ws), ".opscode");
    if (existsSync(od) && lstatSync(od).isSymbolicLink()) throw new Error(".opscode in this project is a link; refusing to use it");
    const dir = join(od, "agents");
    if (existsSync(dir) && lstatSync(dir).isSymbolicLink()) throw new Error(".opscode/agents in this project is a link; refusing to use it");
    if (create) mkdirSync(dir, { recursive: true });
    return existsSync(dir) ? dir : null;
  }

  /** Project over personal over built-in; the narrower scope wins a name. */
  private all(workspaceId?: string): { info: AgentInfo; def: AgentDef }[] {
    const seen = new Set<string>();
    const out: { info: AgentInfo; def: AgentDef }[] = [];
    const add = (def: AgentDef, scope: AgentScope): void => {
      if (seen.has(def.name)) return;
      seen.add(def.name);
      out.push({ info: { name: def.name, description: def.description, access: def.access, scope }, def });
    };
    if (workspaceId && this.workspace(workspaceId)) {
      try {
        const d = this.projectDir(workspaceId, false);
        if (d) for (const a of readDir(d)) add(a, "project");
      } catch { /* missing or linked project folder: no project agents */ }
    }
    for (const a of readDir(this.userDir)) add(a, "user");
    for (const a of BUILTIN) add(a, "builtin");
    return out;
  }

  list(workspaceId?: string): AgentInfo[] {
    return this.all(workspaceId).map((x) => x.info);
  }

  get(workspaceId: string | undefined, name: string): { info: AgentInfo; def: AgentDef } | undefined {
    return this.all(workspaceId).find((x) => x.info.name === name);
  }

  save(scope: "user" | "project", workspaceId: string | undefined, a: AgentDef): void {
    validate(a);
    let dir: string;
    if (scope === "user") dir = this.userDir;
    else {
      if (!workspaceId) throw new Error("choose a project for a project agent");
      dir = this.projectDir(workspaceId, true) as string;
    }
    const tmp = join(dir, `.${a.name}.${process.pid}.tmp`);
    writeFileSync(tmp, serializeAgent(a), { mode: 0o600 });
    renameSync(tmp, join(dir, `${a.name}.md`));
  }

  remove(scope: "user" | "project", workspaceId: string | undefined, name: string): boolean {
    if (!AGENT_NAME.test(name)) return false;
    let dir: string | null;
    if (scope === "user") dir = this.userDir;
    else {
      if (!workspaceId) throw new Error("choose a project");
      dir = this.projectDir(workspaceId, false);
    }
    const f = dir ? join(dir, `${name}.md`) : "";
    if (!f || !existsSync(f) || !lstatSync(f).isFile()) return false;
    rmSync(f);
    return true;
  }
}
