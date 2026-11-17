// Hand-off slice H3: when a chat moves to another engine, the new engine gets a pack built from
// Opscode's task ledger (goal, plan, decisions, the user's words, files changed, commands and results,
// what was running at a stop, next step) instead of the old ~8k characters of chat text.
//   full   - the engine has no session for this chat yet: the whole pack.
//   update - the engine is coming back to its own earlier session: only what happened since its last turn.
// Delivery is per engine (engines/claude.ts, engines/codex.ts, agent/agent.ts). Nothing here calls a model.

import type { ChatMessage } from "../shared/protocol";
import { planFileRel, type LedgerView } from "./ledger";
import { GIT_SAFE, run } from "./project";

export type EngineFamily = "claude-code" | "codex" | "api" | "echo";

/** The built-in agent's id is "<provider>/<model>"; Claude Code and Codex use their own names. */
export function familyOf(engineId: string): EngineFamily {
  return engineId === "claude-code" || engineId === "codex" || engineId === "echo" ? engineId : "api";
}

const NAME: Record<EngineFamily, string> = { "claude-code": "Claude Code", codex: "Codex", api: "the built-in agent", echo: "Echo" };
/** "codex/gpt-6-luna" -> "Codex"; "anthropic/claude-…" (the built-in agent) -> "the built-in agent". */
export const engineName = (id: string): string => NAME[familyOf(id.split("/")[0])];

export interface HandoffPlan {
  kind: "full" | "update";
  /** Who worked last ("codex/gpt-6-luna"). */
  from: string;
  to: string;
  /** For "update": the end of this engine's own last turn in the chat. */
  since?: string;
}

/**
 * Decides, before a turn starts, whether it is a hand-off. `hasSession` = the engine resumes its own
 * session for this chat. Null when the same engine continues, or nothing happened in the chat yet.
 */
export function planHandoff(l: LedgerView | undefined, engineId: string, hasSession: boolean): HandoffPlan | null {
  const to = familyOf(engineId);
  if (!l || to === "echo") return null;
  const done = l.turns.filter((t) => t.status !== "running" && familyOf(t.engine) !== "echo");
  const last = done.at(-1);
  if (!last || familyOf(last.engine) === to) return null;
  const own = done.filter((t) => familyOf(t.engine) === to).at(-1);
  const from = last.model ? `${last.engine}/${last.model}` : last.engine;
  if (own && hasSession) return { kind: "update", from, to: engineId, since: own.ended_at ?? own.at };
  return { kind: "full", from, to: engineId };
}

/** `git status --short` and `git diff --stat` (safe flags, short). "" when not a git repository. */
export async function gitSummary(root: string): Promise<string> {
  const st = await run("git", [...GIT_SAFE, "status", "--short", "--untracked-files=normal"], root, { timeout: 4000, max: 256 * 1024 });
  if (st.code !== 0) return "";
  const lines = st.out.trimEnd().split("\n").filter(Boolean);
  const diff = await run("git", [...GIT_SAFE, "diff", "--stat", "HEAD"], root, { timeout: 4000, max: 256 * 1024 });
  const stat = diff.code === 0 ? diff.out.trimEnd().split("\n").slice(-25).join("\n") : "";
  return [lines.length ? `git status (${lines.length} changed):\n${lines.slice(0, 40).join("\n")}${lines.length > 40 ? "\n…" : ""}` : "git status: clean", stat ? `git diff --stat HEAD:\n${stat}` : ""].filter(Boolean).join("\n\n");
}

const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);
const clipEnd = (s: string, n: number): string => (s.length > n ? `…${s.slice(-n)}` : s);
const mark = (s: string): string => (s === "done" ? "[x]" : s === "in_progress" ? "[>]" : "[ ]");
/** The pack is kept under this many characters (~6k tokens). */
export const PACK_MAX = 24_000;

/** Recent conversation as real turns (Codex gets them as history items). Skips runtime-written lines. */
export function recentMessages(history: readonly ChatMessage[], max = 6): { role: "user" | "assistant"; text: string }[] {
  return history
    .filter((m) => !m.event && m.text.trim() && m.status !== "streaming")
    .slice(-max)
    .map((m) => ({ role: m.role, text: m.role === "assistant" ? clipEnd(m.text.trim(), 2000) : clip(m.text.trim(), 2000) }));
}

/**
 * The hand-off text. `withMessages` false when the engine gets the recent conversation as real history
 * (Codex inject), so the user's words are not sent twice.
 */
export function buildPack(l: LedgerView, chatId: string, p: HandoffPlan, o: { git?: string; withMessages: boolean }): string {
  const after = (at: string): boolean => !p.since || at > p.since;
  const fromName = engineName(p.from);
  const out: string[] = [];
  if (p.kind === "full") {
    out.push(`<handoff from="${p.from}" to="${p.to}">`);
    out.push(`You are taking over this chat's task from ${fromName} (${p.from}). Opscode recorded what happened. Trust it, but check the real files before you change anything.`);
    out.push("", `Goal (the user's own words): ${l.goal || "(not recorded)"}`);
  } else {
    out.push(`<handoff kind="update" from="${p.from}" to="${p.to}">`);
    out.push(`While you were away, ${fromName} (${p.from}) worked on this chat. This is what changed since your last turn; the rest you already know.`);
  }
  if (l.plan?.steps.length) {
    out.push("", `Plan (${l.plan.by}):`, ...l.plan.steps.map((s, i) => `${i + 1}. ${mark(s.status)} ${s.step}`));
    if (l.plan.explanation) out.push(clip(l.plan.explanation, 600));
  }
  const decisions = l.decisions.filter((d) => p.kind === "full" || after(d.at));
  if (decisions.length) out.push("", "Decisions already made (do not redo them):", ...decisions.map((d) => `- ${d.text}`));
  if (o.withMessages) {
    const users = l.user_messages.filter((m) => after(m.at)).slice(p.kind === "full" ? -4 : -6);
    if (users.length) out.push("", "The user's latest messages (word for word; follow their rules and style):", ...users.map((m) => `> ${m.text.replace(/\n/g, "\n> ")}`));
  }
  const changed = l.files_changed.filter((f) => after(f.at));
  if (changed.length) out.push("", `Files changed${p.kind === "update" ? " since your last turn" : ""}: ${changed.slice(-40).map((f) => `${f.path}${f.engine !== p.to ? ` (${engineName(f.engine)})` : ""}`).join(", ")}`);
  if (o.git) out.push("", o.git);
  const cmds = l.commands.filter((c) => after(c.at)).slice(-6);
  if (cmds.length) out.push("", "Commands run (latest last):", ...cmds.map((c) => `- \`${clip(c.cmd, 160)}\` → ${c.ok ? "ok" : `failed${c.exit !== null ? ` (exit ${c.exit})` : ""}`}`));
  if (l.open_errors.length) out.push("", "Still failing:", ...l.open_errors.slice(-3).map((c) => `- \`${clip(c.cmd, 160)}\`:\n${c.tail.split("\n").map((x) => `    ${x}`).join("\n")}`));
  const denied = l.denied.filter((d) => after(d.at));
  if (denied.length) out.push("", `The user said no to: ${denied.map((d) => d.summary).join("; ")}. Do not try these again without asking.`);
  if (l.in_flight) out.push("", `Stopped during: ${l.in_flight.summary}${l.in_flight.detail && !l.in_flight.summary.includes(l.in_flight.detail) ? ` (${clip(l.in_flight.detail, 200)})` : ""}, by ${engineName(l.in_flight.engine)} (${l.in_flight.why}). It may be half done: check it first.`);
  // The other engine's last turn ended early (a plan limit, a crash): its last step may be half done.
  const lastTurn = l.turns.filter((x) => x.status !== "running").at(-1);
  if (lastTurn && lastTurn.status === "failed" && engineName(lastTurn.engine) !== engineName(p.to)) out.push("", `${engineName(lastTurn.engine)}'s last turn stopped early${lastTurn.error ? ` (${clip(lastTurn.error.replace(/\|\d{9,}$/, ""), 160)})` : ""}. Check that its last step is finished.`);
  if (l.next) out.push("", `Next step: ${l.next.text}`);
  if (l.notes && (p.kind === "full" || after(l.notes.at))) out.push("", `Notes: ${clip(l.notes.text, 1200)}`);
  if (l.last_reply && o.withMessages) out.push("", `${fromName}'s last reply (end):`, clipEnd(l.last_reply, 1500));
  if (l.plan || l.decisions.length || l.next) out.push("", `Plan file: ${planFileRel(chatId)} (keep it current with task_checkpoint).`);
  if (p.kind === "full") out.push("", `Before editing: ${o.git ? "look at git status, " : ""}${l.open_errors.length ? "re-run the failing check, " : ""}${l.in_flight ? "re-open what was being changed, " : ""}then continue with the next step.`);
  out.push("</handoff>");
  let text = out.join("\n");
  if (text.length > PACK_MAX) text = `${text.slice(0, PACK_MAX - 40)}\n… (shortened)\n</handoff>`;
  return text;
}

/** Rough token count (about 4 characters per token). */
export const tokensOf = (s: string): number => Math.ceil(s.length / 4);
