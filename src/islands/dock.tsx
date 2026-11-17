// The Conductor's live dock as a React island, built from assistant-ui elements (MIT):
// gates as Approval cards (with the stage's images and a feedback box), one Agent status pill
// per running worker, and one Task card per worker whose transcript is its Tool timeline plus
// the images it is making (Image generation resolving into the real picture).
// Data comes from crew.js (turn events Opscode already streams): no model tokens.

import { useEffect, useState } from "react";
import { FileTextIcon, FilePlusIcon, GlobeIcon, ImageIcon, KeyRoundIcon, PencilIcon, SearchIcon, SquareTerminalIcon, WrenchIcon, ChevronDownIcon, ArrowUpRightIcon } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { ApprovalCard } from "@/components/assistant-ui/elements/approval-card";
import { AgentStatus } from "@/components/assistant-ui/elements/agent-status";
import { TaskCard } from "@/components/assistant-ui/elements/task-card";
import { ToolTimeline } from "@/components/assistant-ui/elements/tool-timeline";
import { ImageGeneration } from "@/components/assistant-ui/elements/image-generation";
import { ImageGallery, type GalleryImage } from "@/components/assistant-ui/elements/image-gallery";
import { SubagentList } from "@/components/assistant-ui/elements/subagent-list";
import { AgentHandoff } from "@/components/assistant-ui/elements/agent-handoff";
import { cn } from "@/lib/utils";

export interface DockGate { id: string; title: string; stage: string; summary?: string; folder: string; modeName: string; emblem?: string; images: GalleryImage[] }
export interface DockStep { id: string; tool: string; verb: string; chip: string }
export interface DockImage { id: string; prompt: string; generating: boolean; src?: string; failed?: boolean }
export interface DockWorker {
  chatId: string; title: string; engine: string; engineSvg: string; model: string; kind?: string; modeName?: string; emblem?: string;
  state: "working" | "waiting" | "done" | "failed"; started: number; ended?: number;
  verb: string; detail: string; steps: DockStep[]; files: string[]; images: DockImage[]; found?: string; check?: string;
}
export interface DockHandoff { id: string; from: string; to: string; reason: string; carried: string[]; settled: boolean }
export interface DockSnapshot { gates: DockGate[]; workers: DockWorker[]; handoffs: DockHandoff[] }
export interface DockHandlers { approve(id: string): void; sendBack(id: string, text: string): void; openChat(chatId: string): void }

const ICONS: Record<string, LucideIcon> = {
  Read: FileTextIcon, Write: FilePlusIcon, Edit: PencilIcon, MultiEdit: PencilIcon, NotebookEdit: PencilIcon, write_file: PencilIcon,
  Bash: SquareTerminalIcon, run_command: SquareTerminalIcon, Grep: SearchIcon, Glob: SearchIcon, WebSearch: GlobeIcon, WebFetch: GlobeIcon, web_search: GlobeIcon,
  image_generation: ImageIcon,
};

/** Re-renders every second while something runs, so elapsed times tick. */
function useNow(active: boolean): number {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!active) return;
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [active]);
  return now;
}
const elapsed = (ms: number): string => { const s = Math.max(0, Math.round(ms / 1000)); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, "0")}s`; };

function Gate({ g, on }: { g: DockGate; on: DockHandlers }) {
  const [text, setText] = useState("");
  const [asking, setAsking] = useState(false);
  return (
    <ApprovalCard
      className="max-w-none"
      data-gate={g.id}
      state="request"
      icon={<KeyRoundIcon className="size-4" />}
      title={`${g.stage} needs your OK`}
      subtitle={`${g.title} · ${g.modeName}`}
      {...(g.summary ? { description: g.summary } : {})}
      details={[{ label: "Files", value: `${g.folder}/` }]}
      allowOnceLabel="Approve"
      denyLabel={asking ? "Send back" : "Request changes"}
      onAllowOnce={() => on.approve(g.id)}
      onDeny={() => { if (!asking) setAsking(true); else if (text.trim()) on.sendBack(g.id, text.trim()); }}
    >
      {g.images.length ? <ImageGallery images={g.images} maxVisible={8} /> : null}
      {asking ? (
        <textarea
          autoFocus
          rows={2}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey && text.trim()) { e.preventDefault(); on.sendBack(g.id, text.trim()); } }}
          placeholder="What should change? The Conductor sends the stage back with your words."
          className="bg-foreground/[0.04] dark:bg-foreground/[0.06] placeholder:text-muted-foreground w-full resize-none rounded-xl px-3.5 py-2.5 text-[13px] outline-none focus-visible:ring-1 focus-visible:ring-foreground/20"
        />
      ) : null}
    </ApprovalCard>
  );
}

function Worker({ w, now, on }: { w: DockWorker; now: number; on: DockHandlers }) {
  const [open, setOpen] = useState(w.images.length > 0);
  const [tlOpen, setTlOpen] = useState(false);
  // An image starting opens the card once, so the person sees it being made (they can close it again).
  const imgs = w.images.length;
  useEffect(() => { if (imgs > 0) setOpen(true); }, [imgs]);
  const running = w.state === "working" || w.state === "waiting";
  const time = running ? elapsed(now - w.started) : `Worked for ${elapsed((w.ended ?? now) - w.started)}`;
  const steps = w.steps.map((s) => ({ id: s.id, verb: s.verb, chip: s.chip, icon: ICONS[s.tool] ?? WrenchIcon }));
  const meta = [w.model, w.kind, w.modeName].filter(Boolean).join(" · ");
  return (
    <TaskCard
      data-chat={w.chatId}
      data-engine={w.engine}
      data-state={w.state}
      label={w.title}
      meta={meta}
      state={w.state}
      elapsed={time}
      open={open}
      onOpenChange={setOpen}
      actions={
        <span className="flex items-center gap-1.5">
          {w.emblem ? <img src={w.emblem} alt="" className="size-4 [image-rendering:pixelated]" /> : null}
          <span className="text-muted-foreground size-3.5 [&>svg]:size-3.5" aria-hidden dangerouslySetInnerHTML={{ __html: w.engineSvg }} />
          <button type="button" aria-label="Open this worker's chat" title="Open this worker's chat" onClick={() => on.openChat(w.chatId)} className="text-muted-foreground hover:text-foreground hover:bg-foreground/[0.06] flex size-6 items-center justify-center rounded-full">
            <ArrowUpRightIcon className="size-3.5" />
          </button>
        </span>
      }
      result={running ? undefined : (
        <div className="flex flex-col gap-0.5 text-[13px]">
          <span className={cn(w.state === "failed" ? "text-red-600 dark:text-red-400" : "text-foreground/80")}>{w.state === "failed" ? "Stopped with an error" : w.found ?? "Done"}</span>
          {w.check ? <span className="text-muted-foreground truncate font-mono text-[11px]">Proved by: {w.check}</span> : null}
        </div>
      )}
    >
      {steps.length ? (
        <ToolTimeline
          steps={steps}
          visibleSteps={steps.length}
          streaming={running}
          open={tlOpen}
          onOpenChange={setTlOpen}
          activeLabel={w.detail ? `${w.verb} ${w.detail}` : w.verb}
          restingLabel={`${w.files.length ? `Edited ${w.files.length} ${w.files.length === 1 ? "file" : "files"} · ` : ""}${steps.length} ${steps.length === 1 ? "step" : "steps"}`}
          stats={w.files.map((file) => ({ file }))}
        />
      ) : null}
      {w.images.length ? (
        <div className="flex flex-wrap gap-3 pt-1">
          {w.images.map((im) => (
            <ImageGeneration key={im.id} data-image={im.id} className="w-44" prompt={im.failed ? "Image failed" : im.prompt || "Image"} generating={im.generating} src={im.src} />
          ))}
        </div>
      ) : null}
    </TaskCard>
  );
}

/** Two or more workers: assistant-ui's Subagent list, done first (it marks completions from the front). */
function Roster({ workers }: { workers: DockWorker[] }) {
  const order = [...workers].sort((a, b) => Number(b.state === "done" || b.state === "failed") - Number(a.state === "done" || a.state === "failed"));
  const finished = order.filter((w) => w.state === "done" || w.state === "failed").length;
  // A worker's own progress is not known; steps taken make a fair, never-finishing estimate.
  const progress = order.map((w) => (w.state === "done" || w.state === "failed" ? 100 : Math.min(90, 8 + w.steps.length * 9 + w.images.filter((i) => !i.generating).length * 15)));
  return (
    <SubagentList
      className="max-w-none"
      agents={order.map((w) => ({ name: w.title, model: [w.model, w.kind].filter(Boolean).join(" · ") }))}
      completedCount={finished}
      progress={progress}
      showSummary={false}
      summaryAgent={{ name: "", model: "" }}
    />
  );
}

export function Dock({ snap, on }: { snap: DockSnapshot; on: DockHandlers }) {
  const running = snap.workers.filter((w) => w.state === "working" || w.state === "waiting");
  const now = useNow(running.length > 0);
  const [collapsed, setCollapsed] = useState(false);
  if (!snap.gates.length && !snap.workers.length) return null;
  return (
    <div className="aui-island flex flex-col gap-2 pb-2" data-slot="opscode-dock">
      {snap.gates.map((g) => <Gate key={g.id} g={g} on={on} />)}
      {snap.workers.length ? (
        <div className="flex items-center gap-1.5 px-1">
          <div className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">
            {running.length ? running.slice(0, 4).map((w) => (
              <AgentStatus key={w.chatId} data-chat={w.chatId} state={w.state === "waiting" ? "waiting" : "working"} label={w.detail ? `${w.verb} ${w.detail}` : w.verb} elapsed={elapsed(now - w.started)} />
            )) : <span className="text-muted-foreground text-xs">Finished just now</span>}
          </div>
          <button type="button" onClick={() => setCollapsed(!collapsed)} aria-expanded={!collapsed} className="text-muted-foreground hover:text-foreground hover:bg-foreground/[0.06] flex h-6 items-center gap-1 rounded-full px-2 text-xs">
            {collapsed ? "Show" : "Hide"} <ChevronDownIcon className={cn("size-3.5 transition-transform", collapsed && "rotate-180")} />
          </button>
        </div>
      ) : null}
      {!collapsed && snap.workers.length >= 2 ? <Roster workers={snap.workers} /> : null}
      {!collapsed ? snap.handoffs.map((x) => <AgentHandoff key={x.id} data-handoff={x.id} className="max-w-none px-1" from={x.from} to={x.to} reason={x.reason} carried={x.carried} settled={x.settled} />) : null}
      {!collapsed ? snap.workers.slice(0, 6).map((w) => <Worker key={w.chatId} w={w} now={now} on={on} />) : null}
    </div>
  );
}
