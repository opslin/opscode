// Workspace tools the agent can call. Every path goes through the same
// sandbox as the file RPCs (paths.ts), so the model cannot leave the project.
// Reads run freely; writes and shell commands need the user's approval.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { isAbsolute, join } from "node:path";
import { killTree } from "../proc";
import { listDir, readFile, writeFile } from "../files";
import type { PermissionMode } from "../../shared/protocol";
import type { ToolDef } from "./llm";

export interface ToolCtx {
  root: string;
  signal: AbortSignal;
  /** Saves a draft note for this project; throws if memory is off. */
  saveNote(title: string, body: string): void;
  /** The steps of a skill by name, or undefined. */
  readSkill(name: string): string | undefined;
  /** For computer tools: the app that was in front when the user approved the action. */
  approvedApp?: string;
  /** The id of the choice the person picked on the approval card (tools whose gate gave choices). */
  choice?: string;
  /** Shows a question card and waits for the person's answer (ask_user). Missing where nobody can answer. */
  ask?(questions: import("../../shared/protocol").AskQuestion[]): Promise<import("../ask").AskResult>;
}
export interface ToolResult {
  output: string;
  is_error: boolean;
  /** Shown to the model only (never stored in the transcript). */
  image?: { media_type: string; data: string };
}
export type ToolKind = "read" | "note" | "edit" | "command" | "mcp" | "computer" | "agent" | "chief" | "browser";

/** A tool's own decision about one call, made at run time (e.g. which app is in front). */
export interface GateResult {
  rule: "auto" | "ask" | "deny";
  summary: string;
  detail?: string;
  /** Why a call was denied; goes back to the model. */
  reason?: string;
  /** Identity of the target the user is approving; passed back to run() as ctx.approvedApp. */
  app?: string;
  /** Instead of Allow, the card shows one button per choice (2 or 3) plus Deny; the one picked comes back to run() as ctx.choice. */
  choices?: ToolChoice[];
}

/** One way to say yes: "All projects", "This project"... */
export interface ToolChoice {
  id: string;
  label: string;
  /** One short line under the card saying what this choice means. */
  hint?: string;
}

/** What a permission mode does with a kind of tool. "hide" tools are not offered to the model. */
export function policy(mode: PermissionMode, kind: ToolKind): "auto" | "ask" | "hide" {
  // "agent" (hand a task to a sub-agent) is free: what the helper then does is gated call by call.
  // "chief" tools only change Opscode's own board and chats; what the chats do is gated there.
  if (kind === "read" || kind === "note" || kind === "agent" || kind === "chief") return "auto";
  // Computer use is never "auto" from the mode alone (not even Full access): each action asks,
  // unless the app in front has an explicit "always" rule (see Tool.gate).
  if (kind === "computer") return mode === "read" ? "hide" : "ask";
  // Acting in Opscode's own browser tab (clicks, typing, page JavaScript): hidden when read-only,
  // asked when supervised, free once edits are. Opening and reading pages are "read" tools.
  if (kind === "browser") return mode === "read" ? "hide" : mode === "supervised" ? "ask" : "auto";
  switch (mode) {
    case "read":
      return "hide";
    case "supervised":
      return "ask";
    case "auto_edits":
      return kind === "edit" ? "auto" : "ask";
    case "auto":
      // Edits go ahead; commands and MCP tools are decided per call by their risk (agent.ts runTool, engines/safety.ts).
      return kind === "edit" ? "auto" : "ask";
    case "full":
      return "auto";
  }
}

export interface Tool {
  def: ToolDef;
  kind: ToolKind;
  /** One-line summary and optional longer preview, shown to the user. */
  describe(input: Record<string, unknown>): { summary: string; detail?: string };
  /** Optional run-time decision that replaces the mode's rule when it is not "hide". */
  gate?(input: Record<string, unknown>): Promise<GateResult>;
  run(input: Record<string, unknown>, ctx: ToolCtx): Promise<ToolResult>;
}

const MAX_OUT = 32 * 1024;
const READ_CAP = 128 * 1024;
const CMD_TIMEOUT_MS = 120_000;

const str = (v: unknown, name: string): string => {
  if (typeof v !== "string") throw new Error(`${name} must be a string`);
  return v;
};
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}\n… (${s.length - n} more characters)` : s);

export const TOOLS: Tool[] = [
  {
    def: {
      name: "use_skill",
      description: "Load a skill's full steps by name, from the list of available skills. Do this when a skill's description matches the task, then follow it.",
      schema: { type: "object", properties: { name: { type: "string", description: "The skill name" } }, required: ["name"] },
    },
    kind: "read",
    describe: (i) => ({ summary: `Skill ${String(i.name ?? "")}` }),
    async run(i, ctx) {
      const body = ctx.readSkill(str(i.name, "name"));
      return body === undefined ? { output: "No skill with that name.", is_error: true } : { output: body, is_error: false };
    },
  },
  {
    def: {
      name: "save_note",
      description: "Remember something for future chats in this project: a lasting preference, a correction, or a gotcha. One fact per note. The user reviews notes before they load automatically.",
      schema: { type: "object", properties: { title: { type: "string", description: "Optional short title" }, note: { type: "string", description: "The fact, in one or two sentences" } }, required: ["note"] },
    },
    kind: "note",
    describe: (i) => ({ summary: `Remember: ${clip(String(i.note ?? ""), 70).split("\n")[0]}` }),
    async run(i, ctx) {
      ctx.saveNote(typeof i.title === "string" ? i.title : "", str(i.note, "note"));
      return { output: "Saved as a draft note. The user will review it.", is_error: false };
    },
  },
  {
    def: {
      name: "list_dir",
      description: "List a directory inside the project. Use \"\" for the project root.",
      schema: { type: "object", properties: { path: { type: "string", description: "Project-relative directory" } }, required: ["path"] },
    },
    kind: "read",
    describe: (i) => ({ summary: `List ${typeof i.path === "string" && i.path ? i.path : "."}` }),
    async run(i, { root }) {
      const res = listDir(root, str(i.path ?? "", "path"));
      const lines = res.entries.slice(0, 300).map((e) => `${e.kind === "dir" ? "dir " : "file"} ${e.name}${e.kind === "file" ? ` (${e.size} B)` : ""}`);
      if (res.entries.length > 300) lines.push(`… ${res.entries.length - 300} more`);
      return { output: lines.join("\n") || "(empty directory)", is_error: false };
    },
  },
  {
    def: {
      name: "read_file",
      description: "Read a text file inside the project (up to 128 KB).",
      schema: { type: "object", properties: { path: { type: "string", description: "Project-relative file path" } }, required: ["path"] },
    },
    kind: "read",
    describe: (i) => ({ summary: `Read ${String(i.path ?? "")}` }),
    async run(i, { root }) {
      const r = readFile(root, str(i.path, "path"), READ_CAP);
      if (r.encoding !== "utf8") return { output: `Binary file (${r.size} bytes); not shown.`, is_error: true };
      return { output: r.truncated ? `${r.content}\n… (file truncated at ${READ_CAP} bytes of ${r.size})` : r.content, is_error: false };
    },
  },
  {
    def: {
      name: "write_file",
      description: "Create or overwrite a text file inside the project. Requires the user's approval.",
      schema: {
        type: "object",
        properties: { path: { type: "string", description: "Project-relative file path" }, content: { type: "string", description: "Full new file content" } },
        required: ["path", "content"],
      },
    },
    kind: "edit",
    describe: (i) => ({ summary: `Write ${String(i.path ?? "")}`, detail: clip(String(i.content ?? ""), 2000) }),
    async run(i, { root }) {
      const content = str(i.content, "content");
      const r = writeFile(root, str(i.path, "path"), Buffer.from(content, "utf8"), true);
      return { output: `Wrote ${r.size} bytes to ${r.path}`, is_error: false };
    },
  },
  {
    def: {
      name: "run_command",
      description: "Run a shell command in the project root (120 s limit). Requires the user's approval.",
      schema: { type: "object", properties: { command: { type: "string", description: "Shell command" } }, required: ["command"] },
    },
    kind: "command",
    describe: (i) => ({ summary: `Run ${clip(String(i.command ?? ""), 80).split("\n")[0]}`, detail: clip(String(i.command ?? ""), 2000) }),
    run: (i, ctx) => runCommand(str(i.command, "command"), ctx),
  },
];

export const toolByName = (name: string): Tool | undefined => TOOLS.find((t) => t.def.name === name);

/** The shell the built-in agent's run_command uses, and how it is told the command (Windows: PowerShell, whose ls/cat/rm/cp work like the usual ones). */
function shell(): { file: string; args: (command: string) => string[] } {
  if (process.platform === "win32") {
    const ps = join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    return { file: existsSync(ps) ? ps : process.env.ComSpec || "cmd.exe", args: (c) => (existsSync(ps) ? ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", c] : ["/d", "/s", "/c", c]) };
  }
  const s = process.env.SHELL;
  return { file: s && isAbsolute(s) ? s : "/bin/sh", args: (c) => ["-c", c] };
}

/** Small, explicit environment: no tokens or Electron flags leak into agent commands. */
function commandEnv(): Record<string, string> {
  const keep = ["PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR", "SHELL"];
  if (process.platform === "win32") keep.push("SystemRoot", "windir", "ComSpec", "PATHEXT", "USERPROFILE", "USERNAME", "APPDATA", "LOCALAPPDATA", "ProgramData", "ProgramFiles", "ProgramFiles(x86)", "TEMP", "TMP", "HOMEDRIVE", "HOMEPATH", "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE");
  const env: Record<string, string> = {};
  for (const k of keep) if (process.env[k] !== undefined) env[k] = process.env[k] as string;
  env.TERM = "dumb";
  env.CI = "1";
  return env;
}

function runCommand(command: string, { root, signal }: ToolCtx): Promise<ToolResult> {
  return new Promise((resolve) => {
    const sh = shell();
    const child = spawn(sh.file, sh.args(command), { cwd: root, env: commandEnv(), detached: process.platform !== "win32", windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let dropped = 0;
    const take = (d: Buffer): void => {
      out += d.toString("utf8");
      if (out.length > MAX_OUT * 2) {
        dropped += out.length - MAX_OUT;
        out = out.slice(-MAX_OUT);
      }
    };
    child.stdout.on("data", take);
    child.stderr.on("data", take);
    const killGroup = (): void => {
      killTree(child.pid);
    };
    const timer = setTimeout(() => { timedOut = true; killGroup(); }, CMD_TIMEOUT_MS);
    let timedOut = false;
    const onAbort = (): void => killGroup();
    signal.addEventListener("abort", onAbort, { once: true });
    const done = (code: number | null, why: string): void => {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
      const tail = clip(out, MAX_OUT);
      const head = dropped ? `… (${dropped} earlier characters dropped)\n` : "";
      resolve({ output: `${why}\n${head}${tail}`.trimEnd(), is_error: code !== 0 });
    };
    child.on("error", (e) => done(1, `could not start: ${e.message}`));
    child.on("close", (code, sig) => done(timedOut ? 124 : code, timedOut ? "timed out after 120 s" : sig ? `killed by ${sig}` : `exit code ${code}`));
  });
}
