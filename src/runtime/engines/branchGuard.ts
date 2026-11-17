// New git branches are the person's call. When an agent runs a command that creates a branch (checkout -b,
// switch -c, branch <name>, worktree add -b), Opscode asks with a card of its own: create it, or keep working on the
// current branch, and optionally remember the answer for the project (a branch rule: ask / current / allow).

import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { readJson, writeJsonAtomic } from "../jsonFile";

export type BranchRule = "ask" | "current" | "allow";
export const BRANCH_RULES: readonly BranchRule[] = ["ask", "current", "allow"];

const TAIL = String.raw`[^;&|\n]*?`;
const NAME = String.raw`['"]?([^\s;&|'"]+)['"]?`;
const CREATE: RegExp[] = [
  // git checkout -b x / git switch -c x (also -B / -C and the long forms)
  new RegExp(String.raw`\bgit\s+(?:-C\s+\S+\s+)?(?:checkout|switch)\s+${TAIL}(?:-b|-B|-c|-C|--create|--force-create)\s+${NAME}`, "g"),
  new RegExp(String.raw`\bgit\s+(?:-C\s+\S+\s+)?checkout\s+--orphan\s+${NAME}`, "g"),
  new RegExp(String.raw`\bgit\s+(?:-C\s+\S+\s+)?worktree\s+add\s+${TAIL}-b\s+${NAME}`, "g"),
];
// git branch <name> [start] creates one; listing, deleting, renaming and querying do not.
const BRANCH = /\bgit\s+(?:-C\s+\S+\s+)?branch\s+([^;&|\n]*)/g;
const BRANCH_OTHER = /^-(?:d|D|m|M|c|C|a|r|v|vv|l|u|-)|--(?:delete|move|copy|list|show-current|contains|merged|no-merged|set-upstream-to|unset-upstream|edit-description|all|remotes|verbose|sort|format)/;

/** Names of the branches a shell command would create ([] for none). Remote shells (ssh, docker exec) are another repository: ignored. */
export function branchCreations(command: string): string[] {
  if (/^\s*(?:ssh|docker\s+exec|kubectl\s+exec)\b/.test(command)) return [];
  const out = new Set<string>();
  for (const re of CREATE) for (const m of command.matchAll(re)) if (m[1]) out.add(m[1]);
  for (const m of command.matchAll(BRANCH)) {
    const args = (m[1] ?? "").trim();
    if (!args || BRANCH_OTHER.test(args)) continue;
    const name = args.split(/\s+/)[0]?.replace(/^['"]|['"]$/g, "");
    if (name && !name.startsWith("-")) out.add(name);
  }
  return [...out];
}

export function currentBranch(root: string): string {
  try { return execFileSync("git", ["-C", root, "rev-parse", "--abbrev-ref", "HEAD"], { encoding: "utf8", timeout: 4000, stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch { return ""; }
}

/** The project's branch rule, kept across restarts. */
export class BranchRules {
  private readonly file: string;
  private rules: Record<string, BranchRule>;
  constructor(stateDir: string) {
    mkdirSync(stateDir, { recursive: true, mode: 0o700 });
    this.file = join(stateDir, "branch-rules.json");
    const raw = readJson(this.file);
    this.rules = {};
    if (raw && typeof raw === "object") for (const [k, v] of Object.entries(raw as Record<string, unknown>)) if (v === "current" || v === "allow") this.rules[k] = v;
  }
  get(workspaceId: string): BranchRule { return this.rules[workspaceId] ?? "ask"; }
  set(workspaceId: string, rule: BranchRule): void {
    if (rule === "ask") delete this.rules[workspaceId]; else this.rules[workspaceId] = rule;
    writeJsonAtomic(this.file, this.rules);
  }
}

/** What an engine needs from its turn to guard branch creation. */
export interface BranchHost {
  policy(): BranchRule;
  current(): string;
  remember(rule: BranchRule): void;
}

export interface BranchVerdict { allow: boolean; message?: string }

const stay = (cur: string): string => `The person wants to keep working on the current branch${cur ? ` (${cur})` : ""} in this project, so do not create a new branch. Make the change and commit on it if asked, or say what you would have named a branch.`;

/** null when the command creates no branch; otherwise the verdict (asking the person when the project's rule says ask). */
export async function guardBranch(
  host: { branch?: BranchHost; askBranch?(callId: string, info: { names: string[]; current: string }): Promise<{ allow: boolean; remember?: "allow" | "current" }> },
  callId: string,
  command: string,
): Promise<BranchVerdict | null> {
  const names = branchCreations(command);
  if (!names.length || !host.branch) return null;
  const cur = host.branch.current();
  const rule = host.branch.policy();
  if (rule === "allow") return { allow: true };
  if (rule === "current") return { allow: false, message: stay(cur) };
  if (!host.askBranch) return null;
  const a = await host.askBranch(callId, { names, current: cur });
  if (a.remember) host.branch.remember(a.remember);
  return a.allow ? { allow: true } : { allow: false, message: stay(cur) };
}
