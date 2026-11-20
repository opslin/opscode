// One assistant reply as a React island, built from assistant-ui elements (MIT):
//  - the work (tool calls and in-between notes) folds into Run activity, the final answer stays visible;
//  - each tool gets the right element: Terminal block for commands, Code diff for edits, Tool error for
//    failures, Tool call for the rest; a call that needs the person is an Approval card, always in view;
//  - Thinking indicator while it works with nothing new to show; File tree of what it changed at the end;
//  - Stopped run when stopped (continue in one tap), Error state when it failed (retry).
// Markdown is Opscode's own renderer (safe DOM built from text nodes), mounted as nodes.

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { BookOpenIcon, GitBranchIcon, FileTextIcon, GlobeIcon, SearchIcon, ShieldAlertIcon, SquareTerminalIcon, UsersIcon, WrenchIcon } from "lucide-react";
import { RunActivity, type RunActivityEntry } from "@/components/assistant-ui/elements/run-activity";
import { TerminalBlock } from "@/components/assistant-ui/elements/terminal-block";
import { CodeDiff, type DiffLine } from "@/components/assistant-ui/elements/code-diff";
import { FileTree, type FileTreeNode } from "@/components/assistant-ui/elements/file-tree";
import { ToolError } from "@/components/assistant-ui/elements/tool-error";
import { ToolCall } from "@/components/assistant-ui/elements/tool-call";
import { ApprovalCard } from "@/components/assistant-ui/elements/approval-card";
import { ThinkingIndicator } from "@/components/assistant-ui/elements/thinking-indicator";
import { StoppedRun } from "@/components/assistant-ui/elements/stopped-run";
import { ErrorState } from "@/components/assistant-ui/elements/error-state";

export type MsgPart =
  | { kind: "text"; text: string }
  | { kind: "tool"; call_id: string; tool: string; summary: string; detail?: string; status: "awaiting_approval" | "awaiting_answer" | "running" | "done" | "error" | "denied"; output?: string; branch?: { names: string[]; current: string }; choices?: { id: string; label: string; hint?: string }[]; questions?: AskQ[]; answers?: { id: string; picks: string[]; other?: string }[]; skipped?: boolean };
interface AskQ { id: string; header?: string; question: string; options: { label: string; description?: string }[]; multi?: boolean }
export interface MsgSnap { turnId: string; parts: MsgPart[]; status: "streaming" | "complete" | "interrupted" | "failed"; error?: string; startedAt?: number; endedAt?: number }
export interface MsgHandlers {
  approve(callId: string, allow: boolean, remember?: "allow" | "current", choice?: string): void;
  /** Opens the question card of this call again (it sits on top of the message box). */
  openQuestion?(callId: string): void;
  continue?(): void;
  retry?(): void;
  /** Opscode's markdown renderer: text -> a DOM node. */
  markdown(text: string): Node;
}

const COMMANDS = new Set(["Bash", "run_command"]);
const EDITS = new Set(["Edit", "MultiEdit", "Write", "write_file", "NotebookEdit"]);
const ICON: Record<string, typeof WrenchIcon> = { Read: FileTextIcon, read_file: FileTextIcon, Grep: SearchIcon, Glob: SearchIcon, WebSearch: GlobeIcon, WebFetch: GlobeIcon, web_search: GlobeIcon, Task: UsersIcon, Agent: UsersIcon, Bash: SquareTerminalIcon, run_command: SquareTerminalIcon };

const secs = (ms: number): string => { const s = Math.max(1, Math.round(ms / 1000)); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`; };
const after = (summary: string): string => summary.replace(/^(Read|Write|Edit|Run|Search the web:)\s+/, "").trim();

/** Markdown as a mounted node (the renderer builds it from text nodes, so nothing is parsed as HTML). */
function Markdown({ text, md }: { text: string; md: (t: string) => Node }) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => { ref.current?.replaceChildren(md(text)); }, [text, md]);
  return <div ref={ref} className="op-md" />;
}

/** An edit's detail -> diff lines: Claude's {old,new} JSON, Codex's unified diff, or a new file's text. */
function diffOf(tool: string, detail: string | undefined): { lines: DiffLine[]; add: number; del: number } | null {
  if (!detail) return null;
  const lines: DiffLine[] = [];
  try {
    const j = JSON.parse(detail) as { old?: string; new?: string; edits?: { old_string?: string; new_string?: string }[] };
    const pairs = j.edits?.map((e) => [e.old_string ?? "", e.new_string ?? ""]) ?? [[j.old ?? "", j.new ?? ""]];
    for (const [o, n] of pairs) { for (const t of o.split("\n")) if (o) lines.push({ kind: "removed", text: t }); for (const t of n.split("\n")) if (n) lines.push({ kind: "added", text: t }); }
  } catch {
    const body = detail.split("\n");
    const unified = body.some((l) => /^[+-]/.test(l) && !/^(\+\+\+|---)/.test(l));
    for (const l of body.slice(tool === "write_file" ? 1 : 0)) {
      if (/^(\+\+\+|---|@@|diff )/.test(l)) continue;
      if (unified) lines.push({ kind: l.startsWith("+") ? "added" : l.startsWith("-") ? "removed" : "context", text: unified && /^[+\- ]/.test(l) ? l.slice(1) : l });
      else lines.push({ kind: "added", text: l });
    }
  }
  if (!lines.length) return null;
  return { lines: lines.slice(0, 80), add: lines.filter((l) => l.kind === "added").length, del: lines.filter((l) => l.kind === "removed").length };
}

/** What a question card left in the chat: waiting (with Open), what you chose, or skipped. */
function AskLine({ p, open }: { p: Extract<MsgPart, { kind: "tool" }>; open?: () => void }) {
  const qs = p.questions ?? [];
  const clean = (l: string) => l.replace(/\s*\((recommended|suggested)\)\s*$/i, "");
  if (p.status === "awaiting_answer") {
    return (
      <div className="ask-line" data-state="waiting" data-call={p.call_id}>
        <span className="ask-dot" />
        <span className="ask-line-text">Waiting for your answer: {qs[0]?.question}{qs.length > 1 ? ` (+${qs.length - 1} more)` : ""}</span>
        {open ? <button type="button" className="ask-line-btn" onClick={open}>Open</button> : null}
      </div>
    );
  }
  if (p.skipped || !p.answers?.length) {
    return <div className="ask-line" data-state="skipped" data-call={p.call_id}><span className="ask-line-text">Question skipped: the agent decides. {qs[0]?.question}</span></div>;
  }
  return (
    <div className="ask-line" data-state="answered" data-call={p.call_id}>
      {qs.map((q) => {
        const a = p.answers!.find((x) => x.id === q.id);
        const said = a ? [...a.picks.map(clean), ...(a.other?.trim() ? [`"${a.other.trim()}"`] : [])].join(", ") : "(no answer)";
        return <div key={q.id} className="ask-line-row"><span className="ask-line-q">{q.header ?? q.question}</span><span className="ask-line-a">You chose: {said}</span></div>;
      })}
    </div>
  );
}

function Tool({ p }: { p: Extract<MsgPart, { kind: "tool" }> }) {
  const [open, setOpen] = useState(false);
  const target = after(p.summary);
  if (p.status === "error" && !COMMANDS.has(p.tool)) {
    return <ToolError name={p.tool} target={target} message={(p.output ?? "It failed.").slice(0, 600)} attempt={1} maxAttempts={1} retrying={false} />;
  }
  if (COMMANDS.has(p.tool)) {
    const out = (p.output ?? "").replace(/\n?\(exit (-?\d+)\)\s*$/, "");
    const exit = /\(exit (-?\d+)\)\s*$/.exec(p.output ?? "");
    const lines = out ? out.split("\n").slice(-200) : [];
    return <TerminalBlock command={target} lines={lines} visibleCount={lines.length} done={p.status !== "running"} {...(exit ? { exitCode: Number(exit[1]) } : p.status === "error" ? { exitCode: 1 } : p.status === "done" ? { exitCode: 0 } : {})} maxCollapsedLines={12} />;
  }
  if (EDITS.has(p.tool)) {
    const d = diffOf(p.tool, p.detail);
    if (d) return <CodeDiff filename={target.split(", ")[0] || "file"} additions={d.add} deletions={d.del} lines={d.lines} cycle={0} />;
  }
  return <ToolCall label={p.summary} activeLabel={p.summary} query={target} request={p.detail ?? ""} result={p.output ?? ""} running={p.status === "running"} failed={p.status === "denied"} open={open} onOpenChange={setOpen} />;
}

/** What the reply changed, as a tree with +/− per file. */
function changes(parts: MsgPart[]): { nodes: FileTreeNode[]; add: number; del: number } | null {
  const files = new Map<string, { add: number; del: number }>();
  for (const p of parts) if (p.kind === "tool" && EDITS.has(p.tool) && p.status === "done") {
    const d = diffOf(p.tool, p.detail);
    for (const f of after(p.summary).split(", ")) if (f) { const x = files.get(f) ?? { add: 0, del: 0 }; x.add += d?.add ?? 0; x.del += d?.del ?? 0; files.set(f, x); }
  }
  if (!files.size) return null;
  const nodes: FileTreeNode[] = [];
  const seen = new Set<string>();
  for (const f of [...files.keys()].sort()) {
    const segs = f.split("/");
    segs.forEach((name, i) => {
      const path = segs.slice(0, i + 1).join("/");
      if (seen.has(path)) return;
      seen.add(path);
      const leaf = i === segs.length - 1;
      nodes.push({ path, name, depth: i, kind: leaf ? "file" : "folder", ...(leaf ? { additions: files.get(f)!.add, deletions: files.get(f)!.del } : {}) });
    });
  }
  return { nodes, add: [...files.values()].reduce((n, x) => n + x.add, 0), del: [...files.values()].reduce((n, x) => n + x.del, 0) };
}

function useTick(active: boolean): number {
  const [now, setNow] = useState(Date.now());
  useEffect(() => { if (!active) return; const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t); }, [active]);
  return now;
}

export function Message({ m, on }: { m: MsgSnap; on: MsgHandlers }) {
  const streaming = m.status === "streaming";
  const now = useTick(streaming);
  const [open, setOpen] = useState(false);
  const tools = m.parts.filter((p): p is Extract<MsgPart, { kind: "tool" }> => p.kind === "tool");
  const lastTool = m.parts.reduce((n, p, i) => (p.kind === "tool" ? i : n), -1);
  // The answer is the text after the last tool; text before it is commentary inside the work.
  const answer = m.parts.slice(lastTool + 1).filter((p): p is { kind: "text"; text: string } => p.kind === "text").map((p) => p.text).join("");
  const asking = tools.filter((p) => p.status === "awaiting_approval");
  const questions = tools.filter((p) => !!p.questions?.length);
  const entries: RunActivityEntry[] = m.parts.slice(0, lastTool + 1).flatMap((p, i): RunActivityEntry[] => {
    if (p.kind === "text") return p.text.trim() ? [{ id: `t${i}`, kind: "commentary", label: p.text.trim().split("\n")[0]!.slice(0, 120), content: <Markdown text={p.text} md={on.markdown} /> }] : [];
    if (p.status === "awaiting_approval" || p.questions?.length) return [];
    const Icon = ICON[p.tool] ?? WrenchIcon;
    return [{ id: p.call_id, kind: "tool", label: p.summary, content: <div className="flex flex-col gap-2"><span className="sr-only"><Icon /></span><Tool p={p} /></div> }];
  });
  const took = m.startedAt ? secs((m.endedAt ?? now) - m.startedAt) : undefined;
  const running = tools.find((p) => p.status === "running");
  const runStatus = streaming ? (asking.length ? "requires-action" : "running") : m.status === "interrupted" ? "cancelled" : m.status === "failed" ? "error" : "complete";
  const tree = !streaming ? changes(m.parts) : null;
  const words = answer.trim().split(/\s+/).filter(Boolean).slice(-40);
  return (
    <div className="aui-island flex flex-col gap-3" data-slot="opscode-message" data-turn={m.turnId} data-status={m.status}>
      {entries.length ? (
        <RunActivity
          status={runStatus}
          statusLabel={streaming ? (running ? running.summary : "Working") : `Worked ${took ?? ""}`.trim()}
          durationLabel={streaming && took ? `· ${took}` : `· ${tools.length} ${tools.length === 1 ? "step" : "steps"}`}
          entries={entries}
          open={open}
          onOpenChange={setOpen}
        />
      ) : null}
      {questions.map((p) => <AskLine key={p.call_id} p={p} {...(on.openQuestion ? { open: () => on.openQuestion!(p.call_id) } : {})} />)}
      {asking.map((p) => p.choices?.length ? (
        // More than one way to say yes (where a skill is installed): one button per choice, what each means in the details.
        <ApprovalCard key={p.call_id} className="max-w-none" data-call={p.call_id} data-choices="true" state="request"
          icon={<BookOpenIcon className="size-4" />} title="Install this skill?" subtitle={p.summary}
          description={p.detail?.slice(0, 600)}
          details={p.choices.map((c) => ({ label: c.label, value: c.hint ?? "" }))}
          allowOnceLabel={p.choices[0]!.label} denyLabel="Don't install"
          onAllowOnce={() => on.approve(p.call_id, true, undefined, p.choices![0]!.id)}
          {...(p.choices[1] ? { alwaysAllowLabel: p.choices[1].label, onAlwaysAllow: () => on.approve(p.call_id, true, undefined, p.choices![1]!.id) } : {})}
          onDeny={() => on.approve(p.call_id, false)}>
          {p.choices[2] ? (
            <button type="button" data-choice={p.choices[2].id} className="self-start text-xs text-muted-foreground underline underline-offset-2 hover:text-foreground" onClick={() => on.approve(p.call_id, true, undefined, p.choices![2]!.id)}>
              {p.choices[2].label}
            </button>
          ) : null}
        </ApprovalCard>
      ) : p.branch ? (
        // A new git branch: its own card. Create it, or keep working on the current branch; either answer can be remembered for the project.
        <ApprovalCard key={p.call_id} className="max-w-none" data-call={p.call_id} data-branch="true" state="request"
          icon={<GitBranchIcon className="size-4" />} title="Create a new branch?"
          subtitle={p.branch.current ? `Now on ${p.branch.current}` : "Git"}
          description={p.branch.names.length > 1 ? "The agent wants to create these branches." : "The agent wants to create this branch, then work on it."}
          details={[{ label: p.branch.names.length > 1 ? "New branches" : "New branch", value: p.branch.names.join(", ") }, ...(p.branch.current ? [{ label: "Instead", value: `Keep working on ${p.branch.current}` }] : [])]}
          allowOnceLabel="Create branch" alwaysAllowLabel="Always allow here" denyLabel={p.branch.current ? `Stay on ${p.branch.current}` : "Don't create"}
          onAllowOnce={() => on.approve(p.call_id, true)} onAlwaysAllow={() => on.approve(p.call_id, true, "allow")} onDeny={() => on.approve(p.call_id, false)}>
          <button type="button" className="self-start text-xs text-muted-foreground underline underline-offset-2 hover:text-foreground" onClick={() => on.approve(p.call_id, false, "current")}>
            {p.branch.current ? `Always stay on ${p.branch.current} in this project` : "Never create branches in this project"}
          </button>
        </ApprovalCard>
      ) : (
        <ApprovalCard key={p.call_id} className="max-w-none" data-call={p.call_id} state="request" variant={COMMANDS.has(p.tool) ? "destructive" : "default"}
          icon={<ShieldAlertIcon className="size-4" />} title={COMMANDS.has(p.tool) ? "Run this command?" : EDITS.has(p.tool) ? "Change this file?" : "Allow this?"} subtitle={p.tool}
          command={p.detail ? p.detail.slice(0, 1200) : p.summary} allowOnceLabel="Allow" denyLabel="Deny"
          onAllowOnce={() => on.approve(p.call_id, true)} onDeny={() => on.approve(p.call_id, false)} />
      ))}
      {m.status === "interrupted" ? (
        <StoppedRun words={words.length ? words : ["(nothing", "written", "yet)"]} reason="You stopped it." {...(on.continue ? { onContinue: on.continue } : {})} />
      ) : answer ? <Markdown text={answer} md={on.markdown} /> : null}
      {streaming && !answer && !asking.length && !questions.some((p) => p.status === "awaiting_answer") && (!running || entries.length === 0) ? <ThinkingIndicator label={tools.length ? "Thinking about what it found" : "Thinking"} elapsed={took ?? "0s"} /> : null}
      {tree ? <FileTree nodes={tree.nodes} visibleCount={tree.nodes.length} totalAdditions={tree.add} totalDeletions={tree.del} /> : null}
      {m.status === "failed" ? <ErrorState title="The reply failed" detail={m.error ?? "Something went wrong."} retrying={false} onRetry={on.retry ?? (() => {})} /> : null}
    </div>
  );
}
