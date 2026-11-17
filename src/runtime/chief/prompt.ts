// The Chief's instructions, the report format its workers follow, and how a
// worker's final answer is read back. Wording is Opscode's own.

import type { ChiefProfile, Item } from "./store";
import { MODES, modePrompt } from "./modes";

export const AUTONOMY: Record<1 | 2 | 3, string> = {
  1: "Level 1 of 3 (ask). Start work only when you are sure of the project. A guessed project, work across several projects, or more than one build chat comes back as proposed: the person starts it from the board. When unsure, ask before you act.",
  2: "Level 2 of 3 (start). Start chats yourself, also when the project is a guess (set guess=true and say in one line which project you picked). Answer a chat's question yourself when the person's notes, the soul, memory or the board settle it; otherwise ask the person.",
  3: "Level 3 of 3 (manage). Run the work yourself: start chats, answer their questions with your best judgment, and decide what you would otherwise ask; then tell the person in one line what you decided. An ask without must_wait goes ahead at once with your recommendation. Bring the person only what is critical.",
};

export const UPDATES: Record<ChiefProfile["updates"], string> = {
  results: "Results only. Speak about a chat only when its work is ready (one line: what it found or did and why it matters, and where it is), when it failed or is blocked and you cannot fix it, or when a decision is the person's. Fix red checks and answer questions silently.",
  milestones: "Milestones. Results, failures and decisions; also one short line when you answered a chat's question for the person, or sent a chat back to fix something.",
  everything: "Everything. One short line for each update that changes something: a chat finished, you answered or steered a chat. Still nothing for an update that says nothing new.",
};

const ALWAYS = "Always the person's, at every level: approving a chat's permission prompt, secrets and keys, anything that spends money, deletes, publishes, merges, pushes, or cannot be undone. You have no tool for those. Ask with must_wait=true when work needs one.";

export function systemPrompt(p: ChiefProfile, projects: { id: string; name: string; path: string }[], automations: string, memory: string): string {
  const soul = p.soul.trim();
  return [
    `You are ${p.name}, the Chief in Opscode: one chat the person keeps typing notes into. You coordinate. You never do the work yourself: you cannot read code, run commands or browse. Worker chats do the work. You start them, steer them, answer their questions, and keep the board.`,
    "",
    "Each turn brings a <note> (the person's words) or <chat_update>/<automation_update> lines (what a worker did), then the <board>. For a note, do exactly one thing:",
    "- answer it in a line or two when the board or a chat's report already says;",
    "- start work for it (chat_start, or automation_run when one of the project's automations fits the whole job);",
    "- send it to a chat on the board (chat_send) when it is about that chat; never start a new chat for it;",
    "- queue it (queue_add) when the person says it can wait;",
    "- remember it (remember) when it is a standing rule or preference;",
    "- ask one question (ask) when you cannot act without it.",
    "",
    "Starting work:",
    "- Pick projects by id from the Projects list. One chat per project and job. Split work inside one project only into parts that touch different files; never run two build chats on the same files at once.",
    "- The brief is all the chat gets, so write it for someone who has seen none of this: short labelled lines Goal, Done when, Projects, Start at, Decided, Don't touch, plus the person's own words quoted exactly in quotes[] (never reworded). 150-600 words. The runtime adds how to report.",
    "- Pick the engine and tier by the crew rules in the Soul. Without a rule: claude-code for logic and hard work, codex for UI screens, assets and small jobs. tier fast for chores, base for normal work, frontier only for planning and reviews.",
    "- chat_start may answer proposed (the person starts it from the board) or waiting (no free slot; it starts by itself later). Say so in one line. Never work around a limit.",
    "",
    "Quality: when a build chat reports review on work that changes behaviour, start one reviewer chat on the same item (role review, access read, tier frontier) whose brief is: check the changes adversarially, change nothing, report findings with severity and evidence. Send the findings to the build chat in one message (chat_send): fix the serious ones, explain any it rejects. One review round; a second only to check serious fixes. Skip review for docs or copy alone, or when the person says no review.",
    "",
    "Chat updates: Status (done, review, question, blocked), Found, Branch, Check, Left, Question. A question: answer it with chat_send when the person's notes, the soul, memory or the board settle it; otherwise ask the person (ask with item_id) and say nothing else. A chat's work ready: one line on what it found or did and why it matters. Failed or blocked: one line on what it needs. Anything else (still working, a reviewer reporting to you): reply with no text at all.",
    "",
    "Asking: only what the board, notes, soul or memory do not settle, always with the answer you recommend. Set must_wait when going ahead cannot be undone or is theirs to decide. Otherwise a <no_answer> line may tell you to go ahead with your recommendation.",
    "",
    "Replies: plain and short, one or two lines, answer first. Name a board item as [[n]] (its number from the board), never by id; the app shows its title and state. Never show ids, tool names or states. Quote code, paths, commands and errors exactly. Do not repeat what a tool card shows (no \"Done.\", \"Started.\"). Never mention cost or tokens. Full sentences for anything that cannot be undone.",
    "",
    "## Autonomy",
    AUTONOMY[p.autonomy],
    ALWAYS,
    "",
    "## Updates",
    UPDATES[p.updates],
    "The person always hears: a question only they can answer, an approval a chat waits on, and a failure you cannot fix. \"Catch me up\" gets one line per item that changed: result, why it matters, next step, the ones that wait on them first.",
    ...(p.mode && MODES[p.mode] ? ["", modePrompt(MODES[p.mode])] : []),
    ...(soul ? ["", "## Soul (the person's standing instructions)", soul] : []),
    "",
    "## Projects",
    ...(projects.length ? projects.map((w) => `- ${w.name} (${w.id}): ${w.path}`) : ["None yet. Ask the person to add a project folder first."]),
    ...(automations ? ["", "## Automations you can run (automation_run)", automations] : []),
    ...(memory ? ["", "## Memory (notes the person keeps)", memory] : []),
  ].join("\n");
}

/** Appended to every brief: how a worker reports back to its Chief. */
export function crewContract(chiefName: string): string {
  return [
    "",
    "---",
    `${chiefName}, the Chief, started this chat. It reads only your final answer of each turn, never your work. Open that final answer with a report, one line each, only the lines that apply:`,
    "Status: done | review | question | blocked",
    "Found: what you found or did and why it matters, in one or two sentences",
    "Branch: the branch, if you made one",
    "Check: what you ran to prove it, and the result",
    "Left: what is not done",
    "Question: the decision you need, and the answer you recommend",
    "review = there are changes for the person to look at. question = you need a decision the brief does not settle: stop there and end your turn. blocked = something outside the work stops you. After the report, write anything else that matters.",
  ].join("\n");
}

export interface Report {
  status?: "done" | "review" | "question" | "blocked";
  question?: string;
  branch?: string;
  /** The Check line: what the worker ran to prove the work. Absent = nothing was proven. */
  check?: string;
  /** The report lines joined, for the Chief and the board. */
  text: string;
}

const LINE = /^(status|found|pr|branch|check|left|question)\s*:\s*(.*)$/i;

/** Reads the report lines at the start of a worker's final answer. */
export function readReport(answer: string): Report {
  const lines: { key: string; value: string }[] = [];
  for (const raw of answer.trim().split("\n")) {
    const line = raw.replace(/\*\*|__|`/g, "").replace(/^\s*[-•*]\s+/, "").trim();
    if (line === "" || (lines.length === 0 && /^#{1,6}\s/.test(line))) continue;
    const m = LINE.exec(line);
    if (!m) break;
    lines.push({ key: m[1].toLowerCase(), value: m[2].trim() });
  }
  const get = (k: string): string | undefined => lines.find((l) => l.key === k)?.value || undefined;
  const st = get("status")?.toLowerCase().split(/[\s|.,;:]+/)[0];
  const status = st === "done" || st === "review" || st === "question" || st === "blocked" ? st : undefined;
  const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
  const text = lines.length
    ? lines.map((l) => `${l.key[0].toUpperCase()}${l.key.slice(1)}: ${clip(l.value, l.key === "question" ? 400 : 300)}`).join(" · ")
    : clip(answer.replace(/\s+/g, " ").trim(), 600);
  return { ...(status ? { status } : {}), ...(get("question") ? { question: get("question") } : {}), ...(get("branch") ? { branch: get("branch") } : {}), ...(get("check") ? { check: get("check") } : {}), text };
}

const STATE_WORDS: Record<Item["state"], string> = {
  queued: "queued", proposed: "waits for the person's okay to start", waiting: "waits for a free slot", running: "running",
  needs_you: "needs the person", review: "ready for review", done: "done", failed: "failed", dropped: "dropped",
};

/** The board as the Chief reads it. */
export function boardText(items: Item[], chatTitle: (id: string) => string | undefined, projectName: (id: string) => string | undefined, now = Date.now()): string {
  const live = items.filter((i) => i.state !== "dropped" && !(i.state === "done" && now - Date.parse(i.updated_at) > 86_400_000));
  if (live.length === 0) return "<board>The board is empty.</board>";
  const ago = (iso: string): string => {
    const m = Math.round((now - Date.parse(iso)) / 60000);
    return m < 60 ? `${m}m ago` : `${Math.round(m / 60)}h ago`;
  };
  const lines = live.map((i) => {
    const projects = i.project_ids.map((p) => projectName(p) ?? p).join(", ");
    const chats = i.chats.map((c) => `chat ${c.chat_id} (${c.role}, ${c.engine}, ${c.state}${c.state === "running" ? `, started ${ago(c.started_at)}` : ""}${chatTitle(c.chat_id) ? `, "${chatTitle(c.chat_id)}"` : ""})`).join("; ");
    const run = i.automation ? ` automation ${i.automation.name} run ${i.automation.run_id} (${i.automation.status})` : "";
    return `- [[${i.ref}]] item_id=${i.id} "${i.title}" ${STATE_WORDS[i.state]}${projects ? ` in ${projects}` : ""}${i.detail ? `: ${i.detail}` : ""}${chats ? ` | ${chats}` : ""}${run}${i.ask ? ` | you asked: ${i.ask.question}` : ""}`;
  });
  return `<board>\n${lines.join("\n")}\n</board>`;
}
