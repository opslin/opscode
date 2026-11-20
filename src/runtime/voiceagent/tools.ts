// The voice agent's tools. They are the only way it touches the worker: start it with a brief, add to it, ask how it is
// doing, stop it, answer an approval the worker is waiting on, and take a quick look at the project to write a better
// brief. None of them can edit files or run commands; the worker does that, under the chat's own permission mode.

import type { Tool, ToolResult } from "../agent/tools";
import { listDir, readFile } from "../files";

/** What the tools need from the service (kept narrow so the tools can be tested alone). */
/** How a new worker is set up: which project it works in and what it runs on (all optional: the defaults). */
export interface WorkerSpec { project?: string; engine?: string; model?: string; effort?: string }

export interface WorkerApi {
  root: string;
  workStart(brief: string, title: string | undefined, spec?: WorkerSpec): string;
  /** The folder of a project named in spoken words (its name or id), or throws with the closest names. */
  projectRoot?(project: string): string;
  /** Every project: one line each. */
  projectsList?(): string;
  /** The projects (and, if none fits, folders not added yet) that match spoken words. */
  projectFind?(query: string): string;
  /** One folder inside the home folder, read-only. */
  folderLook?(path: string): string;
  /** Folders with a matching name in the usual code places. */
  folderFind?(name: string): string;
  /** Adds a folder as a project (only after folderLook showed it and the person said yes). */
  projectAdd?(path: string): string;
  /** The engines, models and effort levels a worker can run on. */
  modelsList?(): string;
  workTell(worker: string | undefined, message: string, interrupt: boolean): Promise<string>;
  workStatus(worker: string | undefined): string;
  workStop(worker: string | undefined): string;
  workApprove(callId: string, allow: boolean): string;
  /** Self-approval on/off: on = workers' routine requests are answered by Opscode; only high-risk ones reach the person. */
  workTrust(on: boolean): string;
  /** For the window's animation: the agent looked at a file / used the browser. */
  peeked?(path: string): void;
  browsed?(tool: string): void;
}

const s = (description: string): Record<string, unknown> => ({ type: "string", description });
const WORKER = s("Which worker: w1, w2, … (see <workers>). Leave out for the latest one.");
const wid = (v: unknown): string | undefined => (typeof v === "string" && v.trim() ? v.trim().slice(0, 10) : undefined);
const clip = (t: string, n: number): string => (t.length > n ? `${t.slice(0, n)}…` : t);
const need = (v: unknown, name: string, max: number): string => {
  if (typeof v !== "string" || !v.trim()) throw new Error(`${name} is required`);
  return v.trim().slice(0, max);
};

const BRIEF_MIN = 40;
const BRIEF_MAX = 12_000;

export function voiceTools(api: WorkerApi): Tool[] {
  const tool = (name: string, description: string, properties: Record<string, unknown>, required: string[], summary: (i: Record<string, unknown>) => string, run: (i: Record<string, unknown>) => ToolResult | Promise<ToolResult>): Tool => ({
    def: { name, description, schema: { type: "object", properties, required } },
    kind: "chief",
    describe: (i) => ({ summary: summary(i) }),
    run: async (i) => {
      try { return await run(i); } catch (e) { return { output: e instanceof Error ? e.message : String(e), is_error: true }; }
    },
  });
  const ok = (output: string): ToolResult => ({ output, is_error: false });

  return [
    tool("work_start",
      "Start a NEW worker on a new piece of work, in its own fresh chat, with a complete brief. The worker cannot hear the conversation: the brief is everything it knows (sections Goal, Context, Where to start, Constraints, Done when, Report). Several workers can run at once (up to 4) for independent pieces. For more on work a worker already has, use work_tell instead.",
      {
        brief: s("The whole brief, written for a colleague who was not in the conversation."), title: s("Two to five words naming the work."),
        project: s("Which project it works in (a name or id from projects_list). Leave out for the current project."),
        engine: s("What it runs on when the person chose: claude-code, codex, antigravity, qoder or api (see models_list). Leave out for the default."),
        model: s("A model id from models_list for that engine, when the person chose one."),
        effort: s("low, medium, high, xhigh or max, when the person chose one."),
      },
      ["brief"],
      (i) => `Brief the worker: ${clip(String(i.title ?? i.brief ?? ""), 60)}${typeof i.project === "string" && i.project ? ` in ${clip(i.project, 30)}` : ""}`,
      (i) => {
        const brief = need(i.brief, "brief", BRIEF_MAX);
        if (brief.length < BRIEF_MIN) throw new Error("That brief is too short for a worker that cannot hear the conversation. Say what to do, where, and how to check it is done.");
        const opt = (v: unknown, n: number): string | undefined => (typeof v === "string" && v.trim() ? v.trim().slice(0, n) : undefined);
        const spec: WorkerSpec = {};
        for (const [k, n] of [["project", 200], ["engine", 40], ["model", 120], ["effort", 20]] as const) { const v = opt(i[k], n); if (v) spec[k] = v; }
        return ok(api.workStart(brief, typeof i.title === "string" ? i.title : undefined, spec));
      }),

    tool("work_tell",
      "Add to or change what a worker already has (a follow-up on the same work), in one or two sentences it can act on. If the worker is running the message waits until its turn ends, unless interrupt is true (use that only when the old direction is now wrong).",
      { worker: WORKER, message: s("What to tell the worker, self-contained."), interrupt: { type: "boolean", description: "Stop what it is doing now and continue with this message." } },
      ["message"],
      (i) => `Tell the worker: ${clip(String(i.message ?? ""), 60)}`,
      async (i) => ok(await api.workTell(wid(i.worker), need(i.message, "message", 4000), i.interrupt === true))),

    tool("work_status",
      "How a worker is doing right now: running, waiting for approval, finished or failed; what it is doing, files changed, plan steps, commands that failed, and the end of its last reply. Leave worker out to see every running worker (and the latest). Call this when the person asks what is happening.",
      { worker: WORKER }, [],
      (i) => `Check on ${wid(i.worker) ?? "the workers"}`,
      (i) => ok(api.workStatus(wid(i.worker)))),

    tool("work_stop",
      "Stop a worker's current turn now (the person said stop, or its work is no longer wanted).",
      { worker: WORKER }, [],
      (i) => `Stop ${wid(i.worker) ?? "the worker"}`,
      (i) => ok(api.workStop(wid(i.worker)))),

    tool("work_approve",
      "Answer an approval the worker is waiting on: after the person said yes or no, or told you to decide yourself (then also call work_trust). Use the call_id shown in <workers> or work_status.",
      { call_id: s("The approval's call id."), allow: { type: "boolean", description: "true = the person said yes, false = they said no." } },
      ["call_id", "allow"],
      (i) => `${i.allow === true ? "Approve" : "Refuse"} a worker request`,
      (i) => {
        if (typeof i.allow !== "boolean") throw new Error("allow must be true or false");
        return ok(api.workApprove(need(i.call_id, "call_id", 200), i.allow));
      }),

    tool("work_trust",
      "Self-approval. on=true when the person tells you to handle approvals yourself (\"allow it yourself\", \"you decide\", \"don't ask me\"): what is waiting is approved, and from then on Opscode answers routine requests without you; only deleting, migrations, database writes, push and deploy still reach the person. on=false when they want to be asked again.",
      { on: { type: "boolean", description: "true = decide yourself, false = ask the person again." } },
      ["on"],
      (i) => (i.on === false ? "Ask the person about approvals again" : "Approve routine worker requests myself"),
      (i) => {
        if (typeof i.on !== "boolean") throw new Error("on must be true or false");
        return ok(api.workTrust(i.on));
      }),

    tool("peek",
      "A quick look at a project, read-only: a folder (its entries) or the start of a file (about 3000 characters). For writing a better brief, not for investigating.",
      { path: s("A path inside the project, relative to its root. Empty = the root."), project: s("Which project (a name or id from projects_list). Leave out for the current project.") },
      [],
      (i) => `Peek: ${typeof i.project === "string" && i.project ? `${clip(i.project, 30)}/` : ""}${String(i.path ?? "") || "."}`,
      (i) => {
        const rel = typeof i.path === "string" ? i.path.trim().replace(/^\/+/, "") : "";
        const root = typeof i.project === "string" && i.project.trim() && api.projectRoot ? api.projectRoot(i.project.trim()) : api.root;
        api.peeked?.(rel);
        let isDir = true;
        try { listDir(root, rel); } catch { isDir = false; }
        if (isDir) {
          const d = listDir(root, rel);
          return ok(d.entries.slice(0, 80).map((e) => `${e.kind === "dir" ? "dir " : "file"} ${e.name}`).join("\n") + (d.truncated || d.entries.length > 80 ? "\n…more" : ""));
        }
        const f = readFile(root, rel, 3000);
        if (f.encoding !== "utf8") return ok("A binary file; nothing to read.");
        return ok(f.content + (f.truncated ? "\n…(file continues)" : ""));
      }),

    // ---- projects, folders and models (only when the service offers them) ----
    ...(api.projectsList ? [tool("projects_list",
      "Every project the person has in Opscode: name, folder, what it is, when it was last worked on. Use it when they name a project you are not sure about, or ask what projects they have.",
      {}, [], () => "List the projects", () => ok(api.projectsList!()))] : []),
    ...(api.projectFind ? [tool("project_find",
      "Find the project the person means from their words (speech recognition may have mangled the name: \"deal car\" can be \"dealker\"). Searches names, folders, package names and READMEs; when no project fits it also suggests folders on this Mac that are not projects yet. Then ask the person which one, if more than one fits.",
      { query: s("Their words for the project.") }, ["query"],
      (i) => `Find the project: ${clip(String(i.query ?? ""), 40)}`, (i) => ok(api.projectFind!(need(i.query, "query", 200))))] : []),
    ...(api.folderLook ? [tool("folder_look",
      "Look inside a folder on this Mac (read-only, inside the home folder): what is there, the README, what kind of project it looks like and whether it is already a project. Use it when the person points you at a folder (\"check the shop folder in Documents\"); then tell them in a sentence or two what it is.",
      { path: s("The folder: an absolute path, ~/…, or a path inside the home folder (for example Documents/shop).") }, ["path"],
      (i) => `Look in ${clip(String(i.path ?? ""), 50)}`, (i) => ok(api.folderLook!(need(i.path, "path", 1024))))] : []),
    ...(api.folderFind ? [tool("folder_find",
      "Find folders on this Mac by name, in the usual places code lives (home, Documents, Desktop, Developer, code, projects…). Use it when the person names a folder but not where it is.",
      { name: s("The folder name as they said it.") }, ["name"],
      (i) => `Find a folder: ${clip(String(i.name ?? ""), 40)}`, (i) => ok(api.folderFind!(need(i.name, "name", 120))))] : []),
    ...(api.projectAdd ? [tool("project_add",
      "Add a folder as a new project in Opscode, so workers can work in it. Only after you looked at it with folder_look AND the person said yes to adding it in their latest words (set confirmed true only then).",
      { path: s("The folder path exactly as folder_look showed it."), confirmed: { type: "boolean", description: "true only when the person said yes to adding this folder in their latest words." } }, ["path", "confirmed"],
      (i) => `Add ${clip(String(i.path ?? "").split("/").pop() ?? "", 40)} as a project`,
      (i) => {
        if (i.confirmed !== true) throw new Error("Ask the person first: tell them what the folder is and ask if it should become a project.");
        return ok(api.projectAdd!(need(i.path, "path", 1024)));
      })] : []),
    ...(api.modelsList ? [tool("models_list",
      "What a worker can run on: each engine installed on this Mac with its models and effort levels, and the default. Use it when the person asks which models there are, or names a model you must match to an id.",
      {}, [], () => "List the models", () => ok(api.modelsList!()))] : []),
  ];
}
