// The three modes: presets on a Chief that turn it into a project Conductor.
//
//   GODMODE  ultimate multi-agent, full power, full-stack thinking
//   WARLORD  strong development execution, balanced intelligence
//   SHINOBI  stealthy, efficient, low cost, fast
//
// A mode fixes which model each worker tier runs on (exact ids, not "latest"
// aliases), how many workers run at once, how deep review goes, and how often
// Opus may be used. The Chief's prompt section is generated from this same table,
// so what the Chief is told and what the runtime does can never disagree.

import type { StartSpec, Tier } from "./store";

export type ModeId = "godmode" | "warlord" | "shinobi";
export const MODE_IDS: readonly ModeId[] = ["godmode", "warlord", "shinobi"];

export interface Pick { model: string; effort: string }
export type TierKey = "fast" | "base" | "frontier" | "opus" | "review";
export interface Mode {
  id: ModeId;
  name: string;
  tagline: string;
  brain: { engine: "claude-code"; model: string; effort: string };
  max_parallel: number;
  daily_chats: number;
  /** Chats on Opus a day; beyond it a task runs on the mode's frontier tier. null = no limit. */
  opus_per_day: number | null;
  /** How many times UI work is refined before the person sees it. */
  ui_rounds: number;
  /** A worker chat that ended a turn with more than this many tokens of history is replaced by a fresh worker when it gets a follow-up. */
  handoff_tokens: number;
  /** Claude Code models per tier. */
  tiers: Record<TierKey, Pick>;
  /** Codex effort by tier. */
  codex: Record<"fast" | "base" | "frontier", string>;
  /** Codex model by tier (ids from Codex's own model list; one this Codex does not have is left out, so it uses its default). */
  codex_models: Record<"fast" | "base" | "frontier", string>;
  lines: { plan: string; complex: string; review: string };
}

const HAIKU = "claude-haiku-5-5";
const SONNET = "claude-sonnet-5-5";
const OPUS = "claude-opus-5-5";

export const MODES: Record<ModeId, Mode> = {
  godmode: {
    id: "godmode", name: "GODMODE", tagline: "Ultimate multi-agent. Full power, full-stack thinking.",
    brain: { engine: "claude-code", model: SONNET, effort: "medium" },
    max_parallel: 4, daily_chats: 60, opus_per_day: null, ui_rounds: 3, handoff_tokens: 150_000,
    tiers: { fast: { model: HAIKU, effort: "low" }, base: { model: SONNET, effort: "medium" }, frontier: { model: OPUS, effort: "high" }, opus: { model: OPUS, effort: "high" }, review: { model: OPUS, effort: "high" } },
    codex: { fast: "low", base: "medium", frontier: "high" },
    codex_models: { fast: "gpt-6-luna", base: "gpt-6.1-sol", frontier: "gpt-6-astra" },
    lines: {
      plan: "Plans are made by an Opus worker (tier opus).",
      complex: "Complicated functions (payments, auctions, data models, security, anything hard) go to Opus workers (tier frontier); normal functions to Sonnet (tier base).",
      review: "Review every feature that changes behaviour with an Opus reviewer, before the next feature starts.",
    },
  },
  warlord: {
    id: "warlord", name: "WARLORD", tagline: "Strong development. Balanced intelligence.",
    brain: { engine: "claude-code", model: SONNET, effort: "medium" },
    max_parallel: 2, daily_chats: 30, opus_per_day: 4, ui_rounds: 2, handoff_tokens: 150_000,
    tiers: { fast: { model: HAIKU, effort: "low" }, base: { model: SONNET, effort: "medium" }, frontier: { model: SONNET, effort: "high" }, opus: { model: OPUS, effort: "high" }, review: { model: SONNET, effort: "high" } },
    codex: { fast: "low", base: "medium", frontier: "medium" },
    codex_models: { fast: "gpt-6-luna", base: "gpt-6.1-sol", frontier: "gpt-6.1-sol" },
    lines: {
      plan: "Plans are made by a Sonnet worker (tier frontier). Use Opus (tier opus) only when the project is genuinely complex: many connected systems or a risky architecture.",
      complex: "Complicated functions go to Sonnet at high effort (tier frontier); normal functions to Sonnet at medium (tier base). Opus is for plans only.",
      review: "Review at the end of each milestone (a group of related features), not after every feature, with a Sonnet reviewer.",
    },
  },
  shinobi: {
    id: "shinobi", name: "SHINOBI", tagline: "Stealthy, efficient, low cost, fast.",
    brain: { engine: "claude-code", model: SONNET, effort: "medium" },
    max_parallel: 1, daily_chats: 15, opus_per_day: 1, ui_rounds: 1, handoff_tokens: 120_000,
    tiers: { fast: { model: HAIKU, effort: "low" }, base: { model: SONNET, effort: "medium" }, frontier: { model: SONNET, effort: "medium" }, opus: { model: OPUS, effort: "medium" }, review: { model: SONNET, effort: "low" } },
    codex: { fast: "low", base: "low", frontier: "medium" },
    codex_models: { fast: "gpt-6-luna", base: "gpt-6.1-sol", frontier: "gpt-6.1-sol" },
    lines: {
      plan: "Plans are made by a Sonnet worker (tier frontier). Opus (tier opus) only sometimes: for a big, hard-to-reverse plan, at most once a day.",
      complex: "Everything goes to Sonnet at medium effort (tier base or frontier); chores to Haiku (tier fast).",
      review: "One light review at the end of the work, with a Sonnet reviewer, not one per feature.",
    },
  },
};

export const isMode = (v: unknown): v is ModeId => typeof v === "string" && (MODE_IDS as readonly string[]).includes(v);

/** What a worker runs on. Reviews use the mode's review model whatever tier was asked. */
/** Testing a running app through the browser/simulator: Sonnet did it as well as Fable at about a seventh
 *  of the cost, and better than Haiku (testing/reports/2026-11-16-browser-real-test.md). */
export const QA_PICK: Record<ModeId, Pick> = { godmode: { model: SONNET, effort: "high" }, warlord: { model: SONNET, effort: "medium" }, shinobi: { model: SONNET, effort: "medium" } };

export function pickFor(mode: Mode, tier: Tier | undefined, role: StartSpec["role"], opusUsedToday: number, opusWindowFull = false, kind?: StartSpec["kind"]): { pick: Pick; note?: string } {
  // QA builds run on Sonnet in every mode; only an explicit tier opus (an escalation) goes higher.
  if (kind === "qa" && role === "build" && tier !== "opus") return { pick: QA_PICK[mode.id] };
  const key: TierKey = role === "review" ? "review" : tier && tier in mode.tiers ? (tier as TierKey) : "base";
  let pick = mode.tiers[key];
  // The plan's weekly Opus window is nearly full: Opus picks (reviews too) fall back to Sonnet at the mode's frontier effort.
  if (pick.model === OPUS && opusWindowFull) {
    const f = mode.tiers.frontier.model === OPUS ? { model: SONNET, effort: "high" } : mode.tiers.frontier;
    return { pick: f, note: `Your plan's weekly Opus limit is nearly used up, so this ran on Sonnet at ${f.effort} effort instead.` };
  }
  if (pick.model === OPUS && key !== "review" && mode.opus_per_day !== null && opusUsedToday >= mode.opus_per_day) {
    pick = mode.tiers.frontier;
    return { pick, note: `${mode.name} allows ${mode.opus_per_day} Opus ${mode.opus_per_day === 1 ? "chat" : "chats"} a day and it is used up, so this ran on ${pick.model === OPUS ? "Opus" : "Sonnet"} at ${pick.effort} effort instead.` };
  }
  return { pick };
}

const modelName = (id: string): string => (id === OPUS ? "Opus 5.5" : id === SONNET ? "Sonnet 5.5" : id === HAIKU ? "Haiku 5.5" : id);

/** The prompt section: generated from the table above. */
export function modePrompt(mode: Mode): string {
  const t = mode.tiers;
  const row = (k: TierKey, use: string): string => `- tier ${k}: ${modelName(t[k].model)}, ${t[k].effort} effort. ${use}`;
  return [
    `## Mode: ${mode.name}`,
    `${mode.tagline} This mode decides how you work; where it differs from the rules above, this section wins.`,
    "",
    "Models by tier (Claude Code workers; the runtime applies them, you only choose the tier):",
    row("fast", "Chores: search, summaries, running a check and reading its result."),
    `- kind qa (testing the running app in the browser or iOS Simulator): ${modelName(QA_PICK[mode.id].model)}, ${QA_PICK[mode.id].effort} effort, whatever tier you ask for (tier opus only to escalate).`,
    row("base", "Normal work."),
    row("frontier", "Hard work."),
    row("opus", `Planning a big project.${mode.opus_per_day === null ? "" : ` At most ${mode.opus_per_day} a day; the runtime downgrades beyond that.`}`),
    `- reviews: ${modelName(t.review.model)}, ${t.review.effort} effort, whatever tier you ask for.`,
    "Codex does UI screens, images and small UI jobs in every mode; its tier sets only how hard it thinks.",
    "",
    mode.lines.plan,
    mode.lines.complex,
    mode.lines.review,
    `UI work: at most ${mode.ui_rounds} refinement ${mode.ui_rounds === 1 ? "round" : "rounds"} before the person sees it.`,
    `Up to ${mode.max_parallel} worker ${mode.max_parallel === 1 ? "chat runs" : "chats run"} at once.`,
    "",
    "",
    "Job size, before anything else. A bug ('X does not work', a failing test, a regression) is a fix: start one build chat with kind fix straight away — no plan stage, no plan worker, whatever this mode allows; the fix skill makes the worker reproduce and prove it. Something new or changed is a feature (kind feature): check the Library first (library_search: do we already have it?), then build; a short plan worker only when it spans several parts. A whole new project or app gets the pipeline (pipeline_start): the runtime runs its stages in order, each on its own mode, and the person approves the plan, the screens and the delivery. Lookups and one-off runs are chores (kind chore, tier fast).",
    "Engines by strength: Claude Code for logic, debugging, data, payments, plans, brand kits, art direction and reviews; Codex for screens, image assets (only Codex can make images), mechanical edits across many files, and as a second opinion on a hard bug Claude has failed twice. Name the engine only when you want the other one; otherwise the kind decides. Images: kind brand first (docs/opscode/brand/brand.md), then kind art (Claude writes the prompts), then kind asset (Codex makes them, with the logo as images), then role review kind visual (Claude looks at them).",
    "Pipeline stages: a <pipeline_stage> line says what the stage needs. Start its chats on that stage's item (item_id), and when their reports prove the work, call stage_done. You never approve a gate; a sent-back stage tells you what the person wants changed.",
    "A change across several projects is a change set: one build chat per project, each brief naming the shared contract (the API or data shape they agree on) and what the other chats cover. You own the order; tell the next chat when the one before it is done.",
    "Escalation: when a worker fails a task twice (checks stay red, or the reviewer rejects it twice), start that one task again one tier higher with a short note of what failed. Do not raise the rest of the project. Never go above this mode's tiers.",
    "Attachments: when the person attaches pictures, files or folders, an <attached> block lists them with paths (you see the pictures yourself). Workers do not see your messages: pass each worker the ones its task needs in chat_start attachments, and say in the brief what they show (\"the design to match\", \"the bug screenshot\").",
    "Missing know-how: a worker can fetch a skill it lacks from the skills.sh registry by itself (the person is asked first; it is removed after the task unless needed repeatedly or the person keeps it). When a task is specialised (a file format, a framework, a tool), say so in its brief so the worker looks for one instead of guessing.",
    "Every task is a fresh worker with its own short brief. Never ask a worker to continue a long earlier conversation; summarise what it needs in the brief.",
    "A report whose Check line is missing proves nothing: on fix and feature jobs the runtime sends that worker back once by itself; if the next report still proves nothing, treat the task as not done.",
    `When you message a worker whose chat has grown past ${Math.round(mode.handoff_tokens / 1000)}k tokens, the runtime does not continue that chat: it starts a fresh worker with the old one's last report and your message, and tells you (delivered fresh_worker). Treat the new chat as the same task.`,
  ].join("\n");
}
