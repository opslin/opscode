// The end-to-end pipeline for a whole new project (docs/orchestration-architecture.md §4).
// The runtime owns the order, the per-stage mode and the gates; the Conductor writes each
// stage's briefs and says when a stage's reports prove it done (stage_done). Only the
// person opens a gate (there is no tool for it). Each stage writes one file the next
// stage reads, so no worker ever needs another stage's chat history.

import type { ModeId } from "./modes";
import { MODES } from "./modes";

export type StageId = "spec" | "gap" | "plan" | "ui" | "build" | "test" | "review" | "deliver";
export const STAGE_IDS: readonly StageId[] = ["spec", "gap", "plan", "ui", "build", "test", "review", "deliver"];

interface StageDef { id: StageId; title: string; mode: ModeId; gate: boolean; file?: string; how: (folder: string, rounds: number) => string }

const STAGES: Record<StageId, StageDef> = {
  spec: {
    id: "spec", title: "Spec", mode: "warlord", gate: false, file: "spec.md",
    how: (f) => `Start one build chat (kind plan, tier base) that reads the requirement (the person's words above and any files they named) and writes ${f}/spec.md: every feature as a short heading with "Done when" checks, open questions first. Ask the person only what blocks the spec (ask, with your recommendation).`,
  },
  gap: {
    id: "gap", title: "Gap report", mode: "shinobi", gate: false, file: "gap.md",
    how: (f) => `First run library_search yourself for the spec's main features (it is free). Then start one build chat (kind plan, tier base) that reads ${f}/spec.md plus what you found, and writes ${f}/gap.md: each feature marked have (with file paths), change, or new.`,
  },
  plan: {
    id: "plan", title: "Plan", mode: "godmode", gate: true, file: "plan.md",
    how: (f) => `Start one build chat (kind plan, tier opus) that reads ${f}/spec.md and ${f}/gap.md and writes ${f}/plan.md: milestones; tasks with the files they touch and the check that proves each; the contracts between projects (API and data shapes); the order, with tasks that touch the same files stacked.`,
  },
  ui: {
    id: "ui", title: "UI & assets", mode: "warlord", gate: true, file: "ui.md",
    how: (f, rounds) => [
      `1. Brand kit: if docs/opscode/brand/brand.md does not exist, start one chat (kind brand) that writes it from the project's logo, theme and existing images. Everything after it follows it.`,
      `2. Assets: for each batch of images ${f}/plan.md needs (app icon, category or feature icons, banners, login or splash art, empty-state illustrations), start one art-director chat (kind art) that writes ${f}/assets/<batch>/brief.md with one prompt per asset, then one Codex chat per batch (kind asset; pass the logo and the brand kit's reference images as images) that makes them at the brief's paths.`,
      `3. Screens: Codex chats (kind ui) build the screens the plan lists with the project's components and the new assets, one per screen group.`,
      `4. Visual review: one reviewer (role review, kind visual) per batch and per screen group checks them against the brand kit. Send failing items back to the same Codex chat with the reviewer's corrected prompt lines; at most ${rounds} ${rounds === 1 ? "round" : "rounds"}.`,
      `5. Write ${f}/ui.md: each asset and screen with its path and whether it passed review. The person then looks at them in the gallery.`,
    ].join("\n"),
  },
  build: {
    id: "build", title: "Build", mode: "shinobi", gate: false,
    how: (f) => `Work through ${f}/plan.md's tasks in order: one build chat per task (kind feature; kind fix for repairs; engine codex for UI wiring and mechanical work), tasks that touch the same files one after another, one chat per project for cross-project contracts. A task is done when its report's Check line proves it. Keep ${f}/plan.md's task list ticked.`,
  },
  test: {
    id: "test", title: "Test", mode: "warlord", gate: false,
    how: (f) => `Start one chat per project (kind fix) that runs the project's own test suites and fixes what fails, and for each project with screens one chat (kind qa) that walks the flows in ${f}/spec.md in the browser or iOS Simulator and reports bugs; send those bugs to a kind fix chat. Each reports the commands or flows it ran in its Check line.`,
  },
  review: {
    id: "review", title: "Review", mode: "godmode", gate: false,
    how: (f) => `Start one reviewer per project (role review) that checks the work against ${f}/spec.md's "Done when" lines. Send serious findings back to a build chat (kind fix) and wait for its proof.`,
  },
  deliver: {
    id: "deliver", title: "Deliver", mode: "shinobi", gate: true, file: "release.md",
    how: (f) => `Start one chat (kind chore) that builds the release artifacts the plan names and writes ${f}/release.md: what was built, how to run it, what is left.`,
  },
};

export interface PipelineStage {
  id: StageId;
  mode: ModeId;
  gate: boolean;
  state: "pending" | "running" | "gate" | "done" | "skipped";
  item_id?: string;
  summary?: string;
}

export interface Pipeline {
  id: string;
  chief_id: string;
  title: string;
  /** The person's words this pipeline is for, verbatim. */
  goal: string;
  project_ids: string[];
  /** Where stage files go, relative to the first project's folder. */
  folder: string;
  stages: PipelineStage[];
  /** Index of the stage now running or waiting at its gate. */
  current: number;
  state: "running" | "gate" | "done" | "stopped";
  created_at: string;
  updated_at: string;
}

export const isStage = (v: unknown): v is StageId => typeof v === "string" && (STAGE_IDS as readonly string[]).includes(v);
export const stageTitle = (id: StageId): string => STAGES[id].title;

export function slug(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) || "project";
}

/** The stage list for a new pipeline: all stages in order, minus skipped ones, with mode overrides. */
export function newStages(skip: StageId[] = [], modes: Partial<Record<StageId, ModeId>> = {}): PipelineStage[] {
  return STAGE_IDS.map((id) => ({ id, mode: modes[id] ?? STAGES[id].mode, gate: STAGES[id].gate, state: skip.includes(id) ? "skipped" as const : "pending" as const }));
}

/** What the Conductor reads when a stage starts (or resumes after a restart). */
export function stageText(pl: Pipeline, s: PipelineStage, ref: number, resumed = false): string {
  const d = STAGES[s.id];
  const files = pl.stages.slice(0, pl.current).filter((x) => x.state === "done" && STAGES[x.id].file).map((x) => `${pl.folder}/${STAGES[x.id].file}`);
  return [
    `<pipeline_stage pipeline="${pl.id}" stage="${s.id}" item="[[${ref}]]" mode="${MODES[s.mode].name}"${resumed ? ' resumed="true"' : ""}>`,
    resumed ? `Opscode stopped while this stage ran. Look at what its chats left (their reports on [[${ref}]], and the files below), then continue it; do not start over.` : `Stage ${s.id} of "${pl.title}" starts now.`,
    `The person's words: "${pl.goal}"`,
    files.length ? `Earlier stages wrote: ${files.join(", ")}. Briefs point workers at these files; never paste their contents.` : "",
    d.how(pl.folder, MODES[s.mode].ui_rounds),
    `Start every chat of this stage on item [[${ref}]] (chat_start item_id). This stage's workers run on ${MODES[s.mode].name}'s models. When the stage's reports prove its work, call stage_done with a two-line summary.${s.gate ? " The person then approves it before the next stage starts: tell them in one line what to look at." : " The next stage then starts by itself."}`,
    "</pipeline_stage>",
  ].filter(Boolean).join("\n");
}

/** One line per live pipeline, for the Conductor's board. */
export function pipelineLines(list: Pipeline[], refOf: (itemId?: string) => number | undefined): string {
  const live = list.filter((p) => p.state === "running" || p.state === "gate");
  if (!live.length) return "";
  return `<pipelines>\n${live.map((p) => {
    const st = p.stages.map((s) => `${s.id}${s.state === "done" ? "✓" : s.state === "skipped" ? "–" : s.state === "gate" ? "(waits for the person)" : s.state === "running" ? `(running [[${refOf(s.item_id) ?? "?"}]], ${MODES[s.mode].name})` : ""}`).join(" → ");
    return `- ${p.id} "${p.title}": ${st}`;
  }).join("\n")}\n</pipelines>`;
}
