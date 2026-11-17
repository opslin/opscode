// task_checkpoint (hand-off slice H2): the model saves the task state (plan, decisions, next step,
// notes) into Opscode's task ledger, and Opscode writes <project>/.opscode/tasks/<chat>/plan.md from it.
// Any engine can then continue the task: Claude Code and Codex get the tool over /mcp/devices, the
// built-in agent directly. Kind "note": free in every mode (it changes only Opscode's own records),
// so a read-only planning chat can save its plan too.

import type { Tool } from "./agent/tools";
import type { LedgerStore } from "./ledger";
import type { ToolScope } from "./turns";

export const CHECKPOINT_NOTE = "Keep the task state with task_checkpoint: right after you make a plan, when a step is done, when you decide something the next person must not undo, and before you stop. Another engine may continue this task from it.";

export function checkpointTool(ledger: LedgerStore, scope: ToolScope): Tool {
  return {
    def: {
      name: "task_checkpoint",
      description: "Save the task state so any engine can continue it. Send the whole plan each time (every step with its status).",
      schema: {
        type: "object",
        properties: {
          plan: { type: "array", items: { type: "object", properties: { step: { type: "string" }, status: { type: "string", enum: ["pending", "in_progress", "done"] } }, required: ["step", "status"] } },
          decisions: { type: "array", items: { type: "string" }, description: "New decisions only" },
          next: { type: "string", description: "The next step" },
          notes: { type: "string", description: "Anything else the next engine needs" },
        },
      },
    },
    kind: "note",
    describe: (i) => {
      const plan = Array.isArray(i.plan) ? (i.plan as { status?: string }[]) : [];
      const done = plan.filter((p) => p?.status === "done").length;
      const bits = [plan.length ? `plan ${done}/${plan.length} done` : "", Array.isArray(i.decisions) && i.decisions.length ? `${i.decisions.length} decision${i.decisions.length > 1 ? "s" : ""}` : "", typeof i.next === "string" && i.next ? `next: ${i.next.slice(0, 60)}` : ""].filter(Boolean);
      return { summary: `Checkpoint${bits.length ? `: ${bits.join(", ")}` : ""}` };
    },
    async run(i) {
      try {
        const r = ledger.checkpoint(scope.chatId, i);
        return { output: `Saved ${r.saved.join(", ")}.${r.file ? ` Plan file: ${r.file}` : ""}`, is_error: false };
      } catch (e) {
        return { output: e instanceof Error ? e.message : String(e), is_error: true };
      }
    },
  };
}
