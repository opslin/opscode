// The agent loop: stream a model reply, run any tool calls it makes (asking
// the user first for writes and commands), feed results back, repeat.

import type { ChatMessage } from "../../shared/protocol";
import type { Engine, EngineInput, TurnHost } from "../turns";
import { streamLlm, type Block, type LlmConfig, type Msg } from "./llm";
import { TOOLS, policy, type Tool, type ToolChoice } from "./tools";
import { devicesNote, FILE_LINK_NOTE, STEP_NOTE, repoNote } from "../engines/claude";
import { autoAsks, riskOf, toolRisk } from "../engines/safety";

const MAX_STEPS = 25;
const SUB_MAX_STEPS = 12;
const SUB_MAX_RUNS = 8;
const SUB_MAX_REPLY = 12_000;
/** The tools a sub-agent may have for each access level (never MCP, computer, notes, skills or other sub-agents). */
const SUB_TOOLS: Record<"read" | "edit" | "full", string[]> = {
  read: ["list_dir", "read_file"],
  edit: ["list_dir", "read_file", "write_file"],
  full: ["list_dir", "read_file", "write_file", "run_command"],
};

const COMPUTER_GUIDE = [
  "",
  "You can use the user's computer through the computer_* tools. Rules:",
  "- If you have computer_see: use it, not screenshots. It lists an app's buttons, fields and text as [id] lines; act with computer_click / computer_type / computer_key / computer_menu / computer_open by id. Each action's result says whether the window changed and gives the new list: read it instead of looking again. Never say something worked unless a result showed it. Take computer_screenshot only to judge how something looks.",
  "- Without computer_see: take a screenshot first; coordinates are pixels in the latest screenshot; one action at a time, then screenshot to check.",
  "- Risky steps (buying, paying, sending, deleting, submitting) ask the user first; the rest runs. Terminals, password managers, system prompts and this app are off limits; if an action is refused, do not try to work around it — tell the user.",
  "- Never type passwords, codes or secrets, and do not read them out of the screen. Stop and ask if a step needs them.",
].join("\n");

const SUB_GUIDE = "You can hand a self-contained task to a sub-agent with run_agent (agent name + the full task: it cannot see this chat). It works on its own and returns a short report. Use one for a side job like searching the code, so this chat stays focused; do small things yourself.";

export const SYSTEM = (workspaceName: string, memory: string, skills: { name: string; description: string }[], invoked?: { name: string; body: string }, computer = false, agents: { name: string; description: string }[] = []): string =>
  [
    "You are Opscode, a coding agent working inside one project folder on the user's computer.",
    `The project is "${workspaceName}". Tool paths are relative to the project root; you cannot reach anything outside it.`,
    "Use list_dir and read_file to understand the code before changing it. Make small, focused edits.",
    "write_file and run_command ask the user for approval first; if a call is denied, do not retry it — explain what you wanted and continue with what you can do.",
    "Be concise. Say what you did and what you found; do not restate file contents the user can see.",
    "When the user writes @path (for example @src/app.ts), they mean that project file or folder; read it before answering.",
    "When the user states a lasting preference or corrects you in a way that should apply next time, call save_note once.",
    ...(memory ? ["", "Notes the user keeps for this work (follow them as the user's own words):", memory] : []),
    ...(skills.length ? ["", "Skills available. When one matches the task, call use_skill with its name and follow it:", ...skills.map((s) => `- ${s.name}: ${s.description}`)] : []),
    ...(computer ? [COMPUTER_GUIDE] : []),
    ...(agents.length ? ["", SUB_GUIDE, "Sub-agents:", ...agents.map((a) => `- ${a.name}: ${a.description}`)] : []),
    ...(invoked ? ["", `The user invoked the skill "${invoked.name}". Follow these steps for their request:`, invoked.body] : []),
  ].join("\n");

function toMessages(history: readonly ChatMessage[], text: string): Msg[] {
  const out: Msg[] = [];
  for (const m of history) {
    if (!m.text.trim()) continue;
    const last = out[out.length - 1];
    if (last && last.role === m.role) last.blocks.push({ type: "text", text: `\n${m.text}` });
    else out.push({ role: m.role, blocks: [{ type: "text", text: m.text }] });
  }
  const last = out[out.length - 1];
  if (last?.role === "user") last.blocks.push({ type: "text", text: `\n${text}` });
  else out.push({ role: "user", blocks: [{ type: "text", text }] });
  // Providers require the first message to be from the user.
  while (out[0] && out[0].role !== "user") out.shift();
  return out;
}

/** Screenshots are large; keep only the newest few in what is sent back to the model. */
function pruneImages(messages: Msg[], keep: number): void {
  let seen = 0;
  for (let i = messages.length - 1; i >= 0; i--) {
    for (const b of (messages[i] as Msg).blocks) {
      if (b.type === "tool_result" && b.image && ++seen > keep) {
        delete b.image;
        b.content += "\n(older screenshot omitted)";
      }
    }
  }
}

export class AgentEngine implements Engine {
  constructor(private readonly config: () => LlmConfig) {}

  get id(): string {
    const c = this.config();
    return `${c.kind}/${c.model}`;
  }

  async run(input: EngineInput, emit: (delta: string) => void, host: TurnHost): Promise<void> {
    const cfg = this.config();
    if (host.chief) {
      // A Chief: its own prompt, only its own tools, and silence is a valid answer.
      await this.loop({ cfg, system: host.chief.system, messages: toMessages(input.history, input.text), all: host.chief.tools, signal: input.signal, host, emit, maxSteps: 16 });
      return;
    }
    // "/name rest of the request" runs a skill directly.
    const slash = /^\/([a-z0-9][a-z0-9-]{0,63})(?:\s+([\s\S]*))?$/.exec(input.text.trim());
    const body = slash ? host.readSkill(slash[1]) : undefined;
    const invoked = slash && body !== undefined ? { name: slash[1], body } : undefined;
    const userText = invoked ? (slash?.[2]?.trim() || `Run the ${invoked.name} skill.`) : input.text;
    // Taking over from Claude Code or Codex: the chat text is already in the history; the pack adds the work.
    if (input.handoff) host.handoffSent?.("message", input.handoff.bare.length);
    const messages = toMessages(input.history, input.handoff ? `${input.handoff.bare}\n\n${userText}` : userText);
    const all: Tool[] = [...TOOLS, ...host.extraTools];
    let subRuns = 0;
    if (host.agents.length) all.push(this.subagentTool(cfg, host, () => subRuns++ < SUB_MAX_RUNS));
    const system = SYSTEM(host.workspaceName, host.memory, host.skills, invoked, host.extraTools.some((t) => t.kind === "computer"), host.agents) + `\n\n${FILE_LINK_NOTE}\n\n${STEP_NOTE}${repoNote(host.root) ? `\n\n${repoNote(host.root)}` : ""}` + (() => { const n = devicesNote(host.extraTools.map((t) => t.def.name)); return n ? `\n\n${n}` : ""; })();
    await this.loop({ cfg, system, messages, all, signal: input.signal, host, emit, maxSteps: MAX_STEPS, emptyIsError: true });
  }

  /** The run_agent tool: runs a helper loop with its own context and a limited toolset. */
  private subagentTool(cfg: LlmConfig, host: TurnHost, allowed: () => boolean): Tool {
    let n = 0;
    return {
      def: {
        name: "run_agent",
        description: "Hand a self-contained task to a named sub-agent. It cannot see this chat, so include everything it needs. Returns its final report.",
        schema: { type: "object", properties: { agent: { type: "string", description: "The sub-agent's name." }, task: { type: "string", description: "The complete task." } }, required: ["agent", "task"] },
      },
      kind: "agent",
      describe: (i) => ({ summary: `Sub-agent ${String(i.agent ?? "")}`, detail: String(i.task ?? "").slice(0, 2000) }),
      run: async (i, ctx) => {
        const name = typeof i.agent === "string" ? i.agent : "";
        const task = typeof i.task === "string" ? i.task.trim() : "";
        const def = host.getAgent(name);
        if (!def) return { output: `No sub-agent named "${name}". Available: ${host.agents.map((a) => a.name).join(", ")}.`, is_error: true };
        if (!task) return { output: "Give the sub-agent a task.", is_error: true };
        if (!allowed()) return { output: `At most ${SUB_MAX_RUNS} sub-agent runs per message.`, is_error: true };
        const prefix = `sa${++n}-`;
        const kids = TOOLS.filter((t) => SUB_TOOLS[def.access].includes(t.def.name));
        // Its cards show under the same turn, named after it; approvals work as for any tool.
        const child: TurnHost = {
          ...host,
          extraTools: [],
          agents: [],
          toolStart: (c, needs) => host.toolStart({ ...c, call_id: prefix + c.call_id, summary: `${def.name} › ${c.summary}` }, needs),
          approve: (id) => host.approve(prefix + id),
          toolEnd: (id, r) => host.toolEnd(prefix + id, r),
        };
        const system = [
          `You are the sub-agent "${def.name}", helping the main Opscode agent in the project "${host.workspaceName}". Tool paths are relative to the project root; you cannot reach anything outside it.`,
          `You may only use these tools: ${kids.map((t) => t.def.name).join(", ")}. Whatever you change or run still needs the user's approval.`,
          "The main agent cannot see your work, only your last message: finish with a short, concrete report of what you found or did.",
          "", "Your instructions:", def.body,
          ...(host.memory ? ["", "Notes the user keeps for this work:", host.memory] : []),
        ].join("\n");
        let cur = "";
        await this.loop({ cfg, system, messages: [{ role: "user", blocks: [{ type: "text", text: task }] }], all: kids, signal: ctx.signal, host: child, emit: (d) => (cur += d), maxSteps: SUB_MAX_STEPS, onToolStep: () => (cur = "") });
        const out = cur.trim();
        return { output: out ? out.slice(0, SUB_MAX_REPLY) : "(the sub-agent returned nothing)", is_error: false };
      },
    };
  }

  private async loop(o: { cfg: LlmConfig; system: string; messages: Msg[]; all: Tool[]; signal: AbortSignal; host: TurnHost; emit: (d: string) => void; maxSteps: number; emptyIsError?: boolean; onToolStep?: () => void }): Promise<void> {
    const { cfg, system, messages, all, signal, host, emit, maxSteps } = o;
    const input = { signal };
    for (let step = 0; step < maxSteps; step++) {
      if (input.signal.aborted) return;
      const blocks: Block[] = [];
      let text = "";
      let reason: "end" | "tool_use" | "length" | "other" = "end";
      // The mode can change between steps (the user may switch it mid-chat).
      const tools = all.filter((t) => policy(host.mode(), t.kind) !== "hide").map((t) => t.def);
      for await (const ev of streamLlm(cfg, { system, messages, tools, signal: input.signal })) {
        if (input.signal.aborted) return;
        if (ev.type === "text") {
          text += ev.text;
          emit(ev.text);
        } else if (ev.type === "tool") {
          if (text) { blocks.push({ type: "text", text }); text = ""; }
          blocks.push({ type: "tool_use", id: ev.id, name: ev.name, input: ev.input });
        } else reason = ev.reason;
      }
      if (text) blocks.push({ type: "text", text });
      if (blocks.length === 0) {
        if (step === 0 && o.emptyIsError) throw new Error("the model returned an empty reply");
        return;
      }
      messages.push({ role: "assistant", blocks });

      const calls = blocks.filter((b): b is Extract<Block, { type: "tool_use" }> => b.type === "tool_use");
      if (calls.length === 0) {
        if (reason === "length") emit("\n\n_(The reply was cut off at the model's length limit.)_");
        return;
      }
      o.onToolStep?.();

      const results: Block[] = [];
      for (const call of calls) {
        if (input.signal.aborted) return;
        results.push({ type: "tool_result", id: call.id, ...(await this.runTool(all, call.id, call.name, call.input, input.signal, host)) });
      }
      messages.push({ role: "user", blocks: results });
      pruneImages(messages, 2);
    }
    emit(`\n\n_(Stopped after ${maxSteps} steps. Send another message to continue.)_`);
  }

  private async runTool(all: Tool[], id: string, name: string, input: Record<string, unknown>, signal: AbortSignal, host: TurnHost): Promise<{ content: string; is_error: boolean; image?: { media_type: string; data: string } }> {
    const tool = all.find((t) => t.def.name === name);
    if (!tool) return { content: `Unknown tool "${name}".`, is_error: true };
    let rule = policy(host.mode(), tool.kind);
    // Auto: the call itself decides — a risky command or a destructive tool asks, the rest goes ahead.
    if (host.mode() === "auto" && rule !== "hide" && (tool.kind === "command" || tool.kind === "mcp")) {
      const risk = tool.kind === "command" ? riskOf(String(input.command ?? ""), host.root) : toolRisk(name);
      rule = autoAsks(risk, host.trusted?.() ?? false) ? "ask" : "auto";
    }
    if (rule === "hide") {
      const msg = "This chat is read-only, so that action is not available.";
      return { content: msg, is_error: true };
    }
    let { summary, detail } = tool.describe(input);
    let approvedApp: string | undefined;
    let choices: ToolChoice[] | undefined;
    if (tool.gate) {
      // The tool decides at run time (e.g. by the app in front). A gate can refuse but never loosen "hide".
      let g;
      try {
        g = await tool.gate(input);
      } catch (e) {
        g = { rule: "deny" as const, summary, reason: e instanceof Error ? e.message : String(e) };
      }
      summary = g.summary;
      detail = g.detail ?? detail;
      if (g.rule === "deny") {
        const msg = g.reason ?? "Not allowed.";
        host.toolStart({ call_id: id, tool: name, summary, detail }, false);
        host.toolEnd(id, { output: msg, is_error: true, denied: true });
        return { content: msg, is_error: true };
      }
      rule = g.rule;
      approvedApp = g.app;
      choices = g.choices;
    }
    host.toolStart({ call_id: id, tool: name, summary, detail, ...(choices?.length ? { choices } : {}) }, rule === "ask");
    if (rule === "ask") {
      const allowed = await host.approve(id);
      if (!allowed) {
        const msg = "The user denied this action.";
        host.toolEnd(id, { output: msg, is_error: true, denied: true });
        return { content: msg, is_error: true };
      }
    }
    try {
      const askUser = host.askUser;
      const r = await tool.run(input, { root: host.root, signal, saveNote: host.saveNote, readSkill: host.readSkill, ...(approvedApp !== undefined ? { approvedApp } : {}), ...(host.choiceOf?.(id) !== undefined ? { choice: host.choiceOf(id) } : {}), ...(askUser ? { ask: (qs) => askUser(id, qs) } : {}) });
      host.toolEnd(id, { output: r.output, is_error: r.is_error });
      return { content: r.output, is_error: r.is_error, ...(r.image ? { image: r.image } : {}) };
    } catch (e) {
      // Protocol failures (outside project, not found…) and bad inputs are the model's to read and adapt to.
      const msg = e instanceof Error ? e.message : String(e);
      host.toolEnd(id, { output: msg, is_error: true });
      return { content: msg, is_error: true };
    }
  }
}
