// Measures what it costs to start a Claude Code worker: how many tokens the very first
// request carries (system prompt, tool list, skills, settings), at each lean level.
// It makes one tiny Haiku request per level, so it only runs when the person asks.

import { spawnProgram } from "../proc";
import { tmpdir } from "node:os";
import { cleanEnv } from "./detect";

export type WorkerStart = "standard" | "lean" | "leanest";
export const WORKER_STARTS: readonly WorkerStart[] = ["standard", "lean", "leanest"];

/** The extra Claude Code flags a Chief's worker gets at a level (the MCP flag comes from the lean setting). */
export function workerStartFlags(level: WorkerStart): string[] {
  if (level === "standard") return [];
  return level === "lean" ? ["--disable-slash-commands"] : ["--disable-slash-commands", "--setting-sources", "project,local"];
}

export interface StartMeasure { level: WorkerStart; tokens?: number; error?: string }

function one(bin: string, cwd: string, level: WorkerStart, leanMcp: boolean): Promise<StartMeasure> {
  return new Promise((resolve) => {
    const args = ["-p", "Reply with the single word: ok", "--output-format", "json", "--model", "claude-haiku-5-5", "--effort", "low", "--no-session-persistence", ...(leanMcp ? ["--strict-mcp-config"] : []), ...workerStartFlags(level)];
    const child = spawnProgram(bin, args, { cwd, env: cleanEnv(), stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    let done = false;
    const end = (r: StartMeasure): void => { if (done) return; done = true; clearTimeout(timer); resolve(r); };
    const timer = setTimeout(() => { child.kill("SIGTERM"); end({ level, error: "Claude Code did not answer in 90 seconds." }); }, 90_000);
    child.stdout.on("data", (d: Buffer) => (out += d.toString("utf8")));
    child.stderr.on("data", (d: Buffer) => (err = (err + d.toString("utf8")).slice(-1000)));
    child.on("error", (e) => end({ level, error: `could not start Claude Code: ${e.message}` }));
    child.on("close", () => {
      try {
        const j = JSON.parse(out) as { usage?: Record<string, number>; is_error?: boolean; result?: string };
        const u = j.usage;
        if (!u || j.is_error) return end({ level, error: String(j.result ?? err.trim().split("\n").at(-1) ?? "no usage reported").slice(0, 200) });
        end({ level, tokens: (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) });
      } catch {
        end({ level, error: (err.trim().split("\n").at(-1) || "unreadable answer").slice(0, 200) });
      }
    });
  });
}

/** Runs the levels one after another (so they do not skew each other). */
export async function measureStart(bin: string, cwd: string | undefined, leanMcp: boolean): Promise<StartMeasure[]> {
  const out: StartMeasure[] = [];
  for (const level of WORKER_STARTS) out.push(await one(bin, cwd ?? tmpdir(), level, leanMcp));
  return out;
}
