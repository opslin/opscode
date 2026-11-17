// A pipeline as assistant-ui's Job progress: weighted stages (build counts most), where it is,
// an estimate of what is left, and a way out. Stage modes and gates stay on the card around it.

import { JobProgress, type JobStage } from "@/components/assistant-ui/elements/job-progress";

export interface PipelineSnap {
  id: string;
  title: string;
  state: "running" | "gate" | "done" | "stopped";
  stages: { id: string; name: string; state: string }[];
  current: number;
  createdAt: number;
  updatedAt: number;
  /** 0..1 within the current stage (from its chats), estimated by the caller. */
  stageProgress: number;
  /** Text for the stage now: "2 workers on it", "Waits for your OK". */
  now: string;
}
export interface PipelineHandlers { stop(id: string): void }

// How much of a whole project each stage usually takes.
const WEIGHT: Record<string, number> = { spec: 1, gap: 1, plan: 2, ui: 3, build: 6, test: 2, review: 1, deliver: 1 };

export function Pipeline({ p, on }: { p: PipelineSnap; on: PipelineHandlers }) {
  const live = p.stages.filter((s) => s.state !== "skipped");
  const stages: JobStage[] = live.map((s) => ({ name: s.name, weight: WEIGHT[s.id] ?? 1, ...(s.id === p.stages[p.current]?.id ? { description: p.now } : {}) }));
  const idx = Math.max(0, live.findIndex((s) => s.id === p.stages[p.current]?.id));
  const done = p.state === "done";
  const stopped = p.state === "stopped";
  // ETA from the pace so far: time per unit of weight done, times the weight left.
  const total = live.reduce((n, s) => n + (WEIGHT[s.id] ?? 1), 0) || 1;
  const doneW = live.slice(0, idx).reduce((n, s) => n + (WEIGHT[s.id] ?? 1), 0) + (WEIGHT[live[idx]?.id ?? ""] ?? 1) * p.stageProgress;
  const spent = Date.now() - p.createdAt;
  const left = doneW > 0.5 ? (spent / doneW) * (total - doneW) : 0;
  const eta = p.state === "gate" ? "Waits for your OK" : left > 0 ? `about ${left < 3_600_000 ? `${Math.max(1, Math.round(left / 60_000))} min` : `${Math.round(left / 3_600_000)} h`} left` : "Estimating…";
  return (
    <JobProgress
      data-pipeline={p.id}
      className="max-w-none"
      title={p.title}
      stages={stages}
      stageIndex={done ? stages.length : idx}
      stageProgress={done ? 1 : p.stageProgress}
      eta={eta}
      elapsedMs={(done || stopped ? p.updatedAt : Date.now()) - p.createdAt}
      {...(done ? { outcome: { status: "success" as const, summary: "Every stage went through." } } : stopped ? { outcome: { status: "cancelled" as const, summary: "Stopped. Files the stages wrote stay." } } : { onCancel: () => on.stop(p.id) })}
    />
  );
}
