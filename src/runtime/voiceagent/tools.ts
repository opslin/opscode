// The voice agent's tools. They are the only way it touches the worker: start it with a brief, add to it, ask how it is
// doing, stop it, answer an approval the worker is waiting on, and take a quick look at the project to write a better
// brief. None of them can edit files or run commands; the worker does that, under the chat's own permission mode.

import type { Tool, ToolResult } from "../agent/tools";
import { listDir, readFile } from "../files";

/** What the tools need from the service (kept narrow so the tools can be tested alone). */
export interface WorkerApi {
  root: string;
  workStart(brief: string, title: string | undefined): string;
  workTell(worker: string | undefined, message: string, interrupt: boolean): Promise<string>;
  workStatus(worker: string | undefined): string;
  workStop(worker: string | undefined): string;
  workApprove(callId: string, allow: boolean): string;
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
      { brief: s("The whole brief, written for a colleague who was not in the conversation."), title: s("Two to five words naming the work.") },
      ["brief"],
      (i) => `Brief the worker: ${clip(String(i.title ?? i.brief ?? ""), 60)}`,
      (i) => {
        const brief = need(i.brief, "brief", BRIEF_MAX);
        if (brief.length < BRIEF_MIN) throw new Error("That brief is too short for a worker that cannot hear the conversation. Say what to do, where, and how to check it is done.");
        return ok(api.workStart(brief, typeof i.title === "string" ? i.title : undefined));
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
      "Answer an approval the worker is waiting on. Only after the person clearly said yes or no in their latest words. Use the call_id shown in <workers> or work_status.",
      { call_id: s("The approval's call id."), allow: { type: "boolean", description: "true = the person said yes, false = they said no." } },
      ["call_id", "allow"],
      (i) => `${i.allow === true ? "Approve" : "Refuse"} a worker request`,
      (i) => {
        if (typeof i.allow !== "boolean") throw new Error("allow must be true or false");
        return ok(api.workApprove(need(i.call_id, "call_id", 200), i.allow));
      }),

    tool("peek",
      "A quick look at the project, read-only: a folder (its entries) or the start of a file (about 3000 characters). For writing a better brief, not for investigating.",
      { path: s("A path inside the project, relative to its root. Empty = the root.") },
      [],
      (i) => `Peek: ${String(i.path ?? "") || "."}`,
      (i) => {
        const rel = typeof i.path === "string" ? i.path.trim().replace(/^\/+/, "") : "";
        api.peeked?.(rel);
        let isDir = true;
        try { listDir(api.root, rel); } catch { isDir = false; }
        if (isDir) {
          const d = listDir(api.root, rel);
          return ok(d.entries.slice(0, 80).map((e) => `${e.kind === "dir" ? "dir " : "file"} ${e.name}`).join("\n") + (d.truncated || d.entries.length > 80 ? "\n…more" : ""));
        }
        const f = readFile(api.root, rel, 3000);
        if (f.encoding !== "utf8") return ok("A binary file; nothing to read.");
        return ok(f.content + (f.truncated ? "\n…(file continues)" : ""));
      }),
  ];
}
