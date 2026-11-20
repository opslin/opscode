// Claude Code as a chat engine. Runs your installed `claude` program once per
// message, in the project folder, with your Claude sign-in:
//   claude -p --input-format stream-json --output-format stream-json
//          --permission-prompt-tool stdio  (we answer its permission prompts)
//          --resume <session>              (its own memory of the chat)
// Text streams back as deltas; each tool call becomes a card; anything that
// needs permission shows the card's Allow / Deny.

import { permissionFor, WRITE_TOOLS } from "./safety";
import { skillsNote } from "./skillsNote";
import { spawnProgram } from "../proc";
import { existsSync, readdirSync } from "node:fs";
import { relative, isAbsolute, join } from "node:path";
import type { PermissionMode } from "../../shared/protocol";
import type { Engine, EngineInput, TurnHost } from "../turns";
import { cleanEnv, type EngineStore } from "./detect";
import type { AccountStore } from "./accounts";
import { workerStartFlags } from "./startcost";
import { DEVICES_MCP } from "../devices/mcp";
import { inlineImage } from "../attachments";
import { guardBranch } from "./branchGuard";
import { SKILL_FINDER_NOTE } from "../skillFinder";
import { CHECKPOINT_NOTE } from "../checkpoint";
import { IMAGE_NOTE } from "../imageNote";
import { QUESTION_NOTE, claudeAnswers, normalizeQuestions, resultText, type AskResult } from "../ask";

/** The MCP server name a Chief's tools appear under in Claude Code (tools are mcp__opscode_chief__<name>). */
export const CHIEF_MCP = "opscode_chief";
// Read only is "default" with the writing tools switched off (not Claude Code's plan mode, which saves a
// plan file); Opscode then answers each request itself (engines/safety.ts).
const MODE: Record<PermissionMode, string> = { read: "default", supervised: "default", auto_edits: "acceptEdits", auto: "acceptEdits", full: "bypassPermissions" };
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);

/** How long Opscode keeps Claude Code's input open for a background job that reports nothing, and after the last one ends. */
const BG_IDLE_MS = Number(process.env.OPSCODE_CLAUDE_BG_IDLE_MS) || 30 * 60_000;
const BG_SETTLE_MS = Number(process.env.OPSCODE_CLAUDE_BG_SETTLE_MS) || 20_000;
/** A background command meant to keep running (a dev server, a watcher, following a log): not worth waiting for. */
const LONG_LIVED = /\b(dev|start|serve|server|watch|preview|tail\s+-[fF]|logs\s+-f|--watch|nodemon|ngrok|simulator|emulator)\b/i;
export function longLived(call: { name: string; input: Record<string, unknown> } | undefined): boolean {
  if (!call || call.name !== "Bash") return false;
  const cmd = String(call.input.command ?? "");
  return call.input.run_in_background === true && LONG_LIVED.test(cmd) && !/\b(build|test|install|analyze|assemble)\b/i.test(cmd);
}

/** Every engine: files it makes for the user (a PDF, a sheet, an APK) come back as links Opscode can open. */
export const FILE_LINK_NOTE = "When you give the user a file or folder you made or changed, link it with its full path: [name](</absolute/path/to/file>). Opscode shows it as a link they can open or show in Finder.";

/** Every step re-sends the whole conversation, so fewer, fuller steps cost less (each extra tool call re-reads the context). */
export const STEP_NOTE = "Work in few, full steps: put related shell commands into one call (chain them with && and print only what you need, e.g. with head or grep), read several files in one go when you can, and do not re-read a file you just read or wrote. Each extra tool call costs a full re-read of the conversation.";

const repoNotes = new Map<string, string>();
/**
 * A project folder that is not a git repository but holds several (an app per folder): workers otherwise think there is no
 * history and cannot tell their own changes or new test failures from old ones. "" when the folder is a repository or holds none.
 */
export function repoNote(root: string): string {
  const hit = repoNotes.get(root);
  if (hit !== undefined) return hit;
  let note = "";
  try {
    if (!existsSync(join(root, ".git"))) {
      const repos = readdirSync(root, { withFileTypes: true }).filter((e) => e.isDirectory() && !e.name.startsWith(".") && existsSync(join(root, e.name, ".git"))).map((e) => e.name).slice(0, 12);
      if (repos.length) note = `This project folder is not a git repository itself, but these folders inside it each are: ${repos.join(", ")}. Run git inside them (git -C <folder> status / diff / log). When a test fails, use git -C <folder> diff to see whether the failing code is something you changed, and say which failures were there before you started.`;
    }
  } catch { /* unreadable: no note */ }
  repoNotes.set(root, note);
  return note;
}

/** Told to outside engines when the browser tools are on (the built-in agent's prompt says the same). */
export const BROWSER_NOTE = "To see or test a web page (for example this project's dev server), use the browser_* tools: they drive the Browser tab in Opscode's side panel, which the user watches. browser_navigate returns the page's elements as [ref_N]; act on refs with browser_act, whose result says what changed and any errors, so read again only when you need more. Put several predictable steps in one browser_batch call. Take a browser_screenshot only to check how something looks.";
export const IOS_NOTE = "To run or check an iOS app, use the ios_simulator tool: build with xcodebuild for the simulator, then launch with app_path, and look with screenshot (its pixels are tap points).";
/** The prompt note for whichever device tools a turn has. */
export function devicesNote(names: string[]): string {
  return [names.some((n) => n.startsWith("browser_")) ? BROWSER_NOTE : "", names.includes("ios_simulator") ? IOS_NOTE : "", names.includes("skill_find") ? SKILL_FINDER_NOTE : "", names.includes("task_checkpoint") ? CHECKPOINT_NOTE : "", names.includes("image_generate") ? IMAGE_NOTE : "", names.includes("ask_user") ? QUESTION_NOTE : ""].filter(Boolean).join("\n\n");
}

/** One line for a tool card, with paths shown relative to the project. */
export function describeClaudeTool(name: string, input: Record<string, unknown>, root: string): { summary: string; detail: string } {
  const rel = (p: unknown): string => {
    const s = String(p ?? "");
    if (!isAbsolute(s)) return s;
    const r = relative(root, s);
    return r && !r.startsWith("..") ? r : s;
  };
  const detail = clip(typeof input.content === "string" ? input.content : typeof input.command === "string" ? input.command : JSON.stringify(input, null, 2), 2000);
  switch (name) {
    case "Read": return { summary: `Read ${rel(input.file_path)}`, detail };
    case "Write": return { summary: `Write ${rel(input.file_path)}`, detail };
    case "Edit": case "MultiEdit": return { summary: `Edit ${rel(input.file_path)}`, detail: clip(JSON.stringify(input.edits ?? { old: input.old_string, new: input.new_string }, null, 2), 2000) };
    case "NotebookEdit": return { summary: `Edit ${rel(input.notebook_path)}`, detail };
    case "Bash": return { summary: `Run ${clip(String(input.command ?? "").split("\n")[0], 80)}`, detail };
    case "Glob": return { summary: `Find ${String(input.pattern ?? "")}`, detail };
    case "Grep": return { summary: `Search ${clip(String(input.pattern ?? ""), 60)}`, detail };
    case "WebFetch": return { summary: `Fetch ${clip(String(input.url ?? ""), 80)}`, detail };
    case "WebSearch": return { summary: `Search the web: ${clip(String(input.query ?? ""), 60)}`, detail };
    case "Task": case "Agent": return { summary: `Sub-agent ${String(input.subagent_type ?? input.description ?? "")}`, detail: clip(String(input.prompt ?? ""), 2000) };
    default: return { summary: name.replace(/^mcp__/, "").replace(/__/g, " · "), detail };
  }
}

/** Earlier messages, for a chat that switches to this engine mid-way (it has no session yet). */
export function priorContext(history: readonly { role: string; text: string }[], max = 8000): string {
  const lines: string[] = [];
  let used = 0;
  for (const m of [...history].reverse()) {
    if (!m.text.trim()) continue;
    const line = `${m.role === "user" ? "User" : "Assistant"}: ${m.text.trim()}`;
    if (used + line.length > max) break;
    lines.unshift(line);
    used += line.length;
  }
  return lines.length ? `Earlier in this conversation (for context):\n${lines.join("\n\n")}\n\n---\n\n` : "";
}

export class ClaudeCodeEngine implements Engine {
  /** Called with Claude Code's rate_limit_event info (plan limits) during a chat, and the account that chat ran on. */
  onLimits?: (info: Record<string, unknown>, account: string) => void;

  constructor(private readonly store: EngineStore, private readonly accounts?: AccountStore) {}

  get id(): string {
    return "claude-code";
  }

  async run(input: EngineInput, emit: (delta: string) => void, host: TurnHost): Promise<void> {
    const bin = this.store.claudePath();
    if (!bin) throw new Error("Claude Code is not installed (no `claude` program found). Install it, or set its path in Settings → Models & keys.");
    const chat = host.chat;
    const mode = host.mode();
    const chief = host.chief;
    const args = ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose", "--include-partial-messages", "--permission-prompt-tool", "stdio", "--permission-mode", chief ? "default" : MODE[mode]];
    if (mode === "full" && !chief) args.push("--dangerously-skip-permissions");
    if (mode === "read" && !chief) args.push("--disallowedTools", WRITE_TOOLS.join(","));
    if (chat.model) args.push("--model", chat.model);
    if (chat.effort) args.push("--effort", chat.effort);
    if (chat.engine_session) args.push("--resume", chat.engine_session);
    if (chief) {
      // A Chief: our prompt replaces Claude Code's, no built-in tools, only the Chief's tools over MCP.
      const mcp = { mcpServers: { [CHIEF_MCP]: { type: "http", url: chief.mcp.url, headers: { Authorization: `Bearer ${chief.mcp.token}` } } } };
      args.push("--system-prompt", chief.system, "--tools", "", "--mcp-config", JSON.stringify(mcp), "--strict-mcp-config", "--allowedTools", `mcp__${CHIEF_MCP}`);
    } else {
      if (this.store.settings().claude_lean) args.push("--strict-mcp-config");
      // A Chief's workers start leaner than a Normal chat; a Normal chat gets none of this.
      if (chat.chief) args.push(...workerStartFlags(this.store.settings().worker_start));
      // Opscode's browser (and later simulators) over MCP. Opscode decides modes and approvals for these
      // tools itself, so Claude Code is told they are allowed and does not ask a second time.
      if (host.devices) args.push("--mcp-config", JSON.stringify({ mcpServers: { [DEVICES_MCP]: { type: "http", url: host.devices.url, headers: { Authorization: `Bearer ${host.devices.token}` } } } }), "--allowedTools", `mcp__${DEVICES_MCP}`);
      const notes = [host.memory ? `Notes the user keeps for this work (follow them as the user's own words):\n${host.memory}` : "", "When the user writes @path, they mean that file or folder in this project.", FILE_LINK_NOTE, STEP_NOTE, repoNote(host.root), host.devices?.note ?? "", skillsNote(host.skillFiles ?? [])].filter(Boolean).join("\n\n");
      args.push("--append-system-prompt", notes);
    }

    const account = host.account ?? "default";
    const child = spawnProgram(bin, args, { cwd: host.root, env: this.accounts ? this.accounts.env("claude-code", account) : cleanEnv(), stdio: ["pipe", "pipe", "pipe"] });
    const send = (m: unknown): void => { if (!child.stdin.destroyed) child.stdin.write(`${JSON.stringify(m)}\n`); };
    let stderr = "";
    child.stderr.on("data", (d: Buffer) => (stderr = (stderr + d.toString("utf8")).slice(-2000)));
    child.stdin.on("error", () => {});

    const cards = new Set<string>();
    const prefix = `mcp__${CHIEF_MCP}__`;
    const describe = (name: string, input: Record<string, unknown>): { summary: string; detail?: string } => {
      const own = chief && name.startsWith(prefix) ? chief.tools.find((t) => t.def.name === name.slice(prefix.length)) : undefined;
      if (own) return own.describe(input);
      const dev = name.startsWith(`mcp__${DEVICES_MCP}__`) ? host.devices?.describe(name.slice(DEVICES_MCP.length + 7), input) : undefined;
      return dev ?? describeClaudeTool(name, input, host.root);
    };
    let streamed = false; // text came as partial deltas, so skip the full message text
    let result: { is_error: boolean; text: string } | null = null;
    // Background jobs (a background build, Monitor, a background helper). Claude Code keeps working after its `result`
    // when one of them ends, and then may ask permission again: its input must stay open until they are done.
    const inputs = new Map<string, { name: string; input: Record<string, unknown> }>(); // tool_use id -> call
    const bg = new Map<string, string>(); // task id -> what it is
    let idle = false; // the last thing Claude Code sent was a `result`
    let bgTimer: NodeJS.Timeout | null = null;
    const closeInput = (): void => { if (bgTimer) clearTimeout(bgTimer); bgTimer = null; if (!child.stdin.destroyed && !child.stdin.writableEnded) child.stdin.end(); };
    const holdOrClose = (): void => {
      if (bgTimer) clearTimeout(bgTimer);
      if (!idle) { bgTimer = null; return; }
      // Nothing left in the background: give Claude a moment to answer a job that just ended, then close.
      if (!bg.size) { bgTimer = setTimeout(closeInput, BG_SETTLE_MS); bgTimer.unref(); return; }
      bgTimer = setTimeout(() => {
        emit(`\n\n(Opscode stopped waiting: ${[...bg.values()].join(", ")} sent nothing for ${BG_IDLE_MS >= 60_000 ? `${Math.round(BG_IDLE_MS / 60_000)} minutes` : `${Math.round(BG_IDLE_MS / 1000)} seconds`}.)`);
        closeInput();
      }, BG_IDLE_MS);
      bgTimer.unref();
    };
    let usage = { ...(chat.usage ?? { input_tokens: 0, output_tokens: 0, cached_tokens: 0 }) };

    const onAbort = (): void => {
      child.kill("SIGINT");
      setTimeout(() => { if (child.exitCode === null) child.kill("SIGTERM"); }, 2000).unref();
    };
    input.signal.addEventListener("abort", onAbort, { once: true });

    const handle = async (m: Record<string, unknown>): Promise<void> => {
      const taskEvent = m.type === "system" && typeof m.subtype === "string" && m.subtype.startsWith("task_");
      if (taskEvent) {
        if (m.subtype === "task_started" && typeof m.task_id === "string") {
          const call = typeof m.tool_use_id === "string" ? inputs.get(m.tool_use_id) : undefined;
          if (!longLived(call)) bg.set(m.task_id, clip(String(m.description || call?.name || "a background job"), 60));
        } else if (m.subtype === "task_notification" && typeof m.task_id === "string") bg.delete(m.task_id);
        holdOrClose(); // while idle: a job that ended (or reported progress) restarts the wait
      } else if (m.type !== "result" && idle) { idle = false; holdOrClose(); } // Claude Code is working again
      if (m.type === "rate_limit_event" && m.rate_limit_info && typeof m.rate_limit_info === "object") this.onLimits?.(m.rate_limit_info as Record<string, unknown>, account);
      if (m.type === "system" && m.subtype === "init" && typeof m.session_id === "string") {
        const servers = Array.isArray(m.mcp_servers) ? (m.mcp_servers as Record<string, unknown>[]).filter((x) => typeof x?.name === "string").map((x) => ({ name: String(x.name).slice(0, 80), status: String(x.status ?? "unknown").slice(0, 20) })) : [];
        host.setEngineState({ engine_session: m.session_id, connectors: servers.slice(0, 50) });
      }
      else if (m.type === "stream_event") {
        const ev = m.event as Record<string, unknown> | undefined;
        const d = ev?.delta as Record<string, unknown> | undefined;
        if (ev?.type === "content_block_delta" && d?.type === "text_delta" && typeof d.text === "string" && !m.parent_tool_use_id) {
          streamed = true;
          emit(d.text);
        }
      } else if (m.type === "assistant") {
        const msg = m.message as { content?: Record<string, unknown>[] } | undefined;
        for (const b of msg?.content ?? []) {
          if (b.type === "text" && !streamed && !m.parent_tool_use_id && typeof b.text === "string") emit(b.text);
          if (b.type === "tool_use" && typeof b.id === "string") inputs.set(b.id, { name: String(b.name), input: (b.input ?? {}) as Record<string, unknown> });
          if (b.type === "tool_use" && typeof b.id === "string" && !cards.has(b.id)) {
            cards.add(b.id);
            const d = describe(String(b.name), (b.input ?? {}) as Record<string, unknown>);
            host.toolStart({ call_id: b.id, tool: String(b.name), summary: m.parent_tool_use_id ? `helper › ${d.summary}` : d.summary, detail: d.detail }, false);
            // Claude Code's own to-do list (when it has one) is the task plan; a helper's is not.
            const todos = (b.input as { todos?: unknown } | undefined)?.todos;
            if (b.name === "TodoWrite" && !m.parent_tool_use_id && Array.isArray(todos)) host.planUpdated?.((todos as Record<string, unknown>[]).map((x) => ({ step: String(x.content ?? x.activeForm ?? ""), status: x.status })));
          }
        }
        streamed = false;
      } else if (m.type === "user") {
        const msg = m.message as { content?: unknown } | undefined;
        if (Array.isArray(msg?.content)) {
          for (const b of msg.content as Record<string, unknown>[]) {
            if (b.type !== "tool_result" || typeof b.tool_use_id !== "string" || !cards.has(b.tool_use_id)) continue;
            const out = typeof b.content === "string" ? b.content : Array.isArray(b.content) ? (b.content as Record<string, unknown>[]).map((x) => (x.type === "text" ? String(x.text) : `[${String(x.type)}]`)).join("\n") : "";
            host.toolEnd(b.tool_use_id, { output: out, is_error: b.is_error === true });
          }
        }
      } else if (m.type === "control_request") {
        const req = m.request as Record<string, unknown>;
        const rid = m.request_id;
        if (req?.subtype === "can_use_tool" && chief) {
          // A Chief asks nobody: its own tools are pre-allowed, anything else is refused.
          send({ type: "control_response", response: { subtype: "success", request_id: rid, response: { behavior: "deny", message: "A Manager has only its own tools." } } });
        } else if (req?.subtype === "can_use_tool" && req.tool_name === "AskUserQuestion") {
          // Claude Code's own question tool: Opscode shows the question card and sends back the person's answers.
          const id = typeof req.tool_use_id === "string" ? req.tool_use_id : `ask-${String(rid)}`;
          const input = (req.input ?? {}) as Record<string, unknown>;
          const questions = normalizeQuestions(input.questions);
          const r: AskResult = !questions.length ? { skipped: true, reason: "The question had no options to show." } : host.askUser ? await host.askUser(id, questions, { tool: "AskUserQuestion" }) : { skipped: true, reason: "Nobody can answer questions here." };
          const answers = "skipped" in r ? {} : claudeAnswers(input.questions, questions, r.answers);
          if ("skipped" in r || !Object.keys(answers).length) {
            send({ type: "control_response", response: { subtype: "success", request_id: rid, response: { behavior: "deny", message: resultText(questions, "skipped" in r ? r : { skipped: true, reason: "No answer was given." }) } } });
          } else {
            send({ type: "control_response", response: { subtype: "success", request_id: rid, response: { behavior: "allow", updatedInput: { ...input, answers } } } });
          }
        } else if (req?.subtype === "can_use_tool") {
          const id = typeof req.tool_use_id === "string" ? req.tool_use_id : `perm-${String(rid)}`;
          // Reading, searching, read-only queries and local tests need no question; in read only, anything else is refused.
          // A new git branch is the person's call (own card; the project's branch rule may already answer).
          if (String(req.tool_name) === "Bash" && typeof (req.input as { command?: unknown } | undefined)?.command === "string") {
            if (!cards.has(id)) {
              cards.add(id);
              const d = describe("Bash", (req.input ?? {}) as Record<string, unknown>);
              host.toolStart({ call_id: id, tool: "Bash", summary: d.summary, detail: d.detail }, false);
            }
            const b = await guardBranch(host, id, String((req.input as { command: string }).command));
            if (b) {
              send({ type: "control_response", response: { subtype: "success", request_id: rid, response: b.allow ? { behavior: "allow", updatedInput: req.input ?? {} } : { behavior: "deny", message: b.message ?? "The user denied this action." } } });
              if (!b.allow) host.toolEnd(id, { output: b.message ?? "The user chose not to create a new branch.", is_error: true, denied: true });
              return;
            }
          }
          const verdict = permissionFor(host.mode(), String(req.tool_name), (req.input ?? {}) as Record<string, unknown>, host.root, host.trusted?.() ?? false);
          if (verdict === "allow") {
            send({ type: "control_response", response: { subtype: "success", request_id: rid, response: { behavior: "allow", updatedInput: req.input ?? {} } } });
            return;
          }
          if (verdict === "deny") {
            const why = "This chat is read only: it can read, search and run read-only checks, but not change files, data or servers.";
            send({ type: "control_response", response: { subtype: "success", request_id: rid, response: { behavior: "deny", message: why } } });
            if (cards.has(id)) host.toolEnd(id, { output: why, is_error: true, denied: true });
            return;
          }
          if (!cards.has(id)) {
            cards.add(id);
            const d = describe(String(req.tool_name), (req.input ?? {}) as Record<string, unknown>);
            host.toolStart({ call_id: id, tool: String(req.tool_name), summary: d.summary, detail: d.detail }, false);
          }
          const allowed = await host.askApproval(id);
          send({ type: "control_response", response: { subtype: "success", request_id: rid, response: allowed ? { behavior: "allow", updatedInput: req.input ?? {} } : { behavior: "deny", message: "The user denied this action." } } });
          if (!allowed) host.toolEnd(id, { output: "The user denied this action.", is_error: true, denied: true });
        } else {
          send({ type: "control_response", response: { subtype: "error", request_id: rid, error: `Opscode does not handle ${String(req?.subtype)}` } });
        }
      } else if (m.type === "result") {
        const u = (m.usage ?? {}) as Record<string, number>;
        usage = {
          input_tokens: usage.input_tokens + (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0),
          output_tokens: usage.output_tokens + (u.output_tokens ?? 0),
          cached_tokens: usage.cached_tokens + (u.cache_read_input_tokens ?? 0),
        };
        const iters = Array.isArray((u as unknown as { iterations?: unknown[] }).iterations) ? ((u as unknown as { iterations: Record<string, number>[] }).iterations) : [];
        const last = iters.at(-1);
        if (last) usage.context_tokens = (last.input_tokens ?? 0) + (last.cache_read_input_tokens ?? 0) + (last.cache_creation_input_tokens ?? 0) + (last.output_tokens ?? 0);
        // modelUsage: { "<model id>": { contextWindow, ... } } names the model that answered and its window.
        const mu = m.modelUsage && typeof m.modelUsage === "object" ? Object.entries(m.modelUsage as Record<string, Record<string, unknown>>) : [];
        const main = mu.sort((a, b) => Number(b[1]?.outputTokens ?? 0) - Number(a[1]?.outputTokens ?? 0))[0];
        if (main) {
          usage.model = main[0].slice(0, 80);
          if (typeof main[1]?.contextWindow === "number" && main[1].contextWindow > 0) usage.context_window = main[1].contextWindow;
        }
        usage.reported_at = new Date().toISOString();
        usage.cache_tokens = (last?.cache_read_input_tokens ?? u.cache_read_input_tokens ?? 0) + (last?.cache_creation_input_tokens ?? u.cache_creation_input_tokens ?? 0);
        host.setEngineState({ ...(typeof m.session_id === "string" ? { engine_session: m.session_id } : {}), usage });
        result = { is_error: m.is_error === true || (typeof m.subtype === "string" && m.subtype.startsWith("error")), text: typeof m.result === "string" ? m.result : "" };
        // An error ends the turn; otherwise wait while a background job may still wake Claude Code up.
        if (result.is_error || !bg.size) closeInput();
        else { idle = true; holdOrClose(); }
      }
    };

    // Taking over from another engine: the pack goes in this message, so it stays in Claude Code's own
    // session (later --resume turns keep it; nothing is sent twice). Otherwise the old plain-text history.
    const prompt = input.handoff ? `${input.handoff.text}\n\n${input.text}` : (chat.engine_session ? "" : priorContext(input.history)) + input.text;
    if (input.handoff) host.handoffSent?.("message", input.handoff.text.length);
    // Pictures go in as image blocks, so the model sees them (a Conductor has no file tools at all). Ones too big stay paths in the text.
    const shots = (input.images ?? []).map(inlineImage).filter((x): x is { media_type: string; data: string } => !!x);
    send({ type: "user", message: { role: "user", content: shots.length ? [{ type: "text", text: prompt }, ...shots.map((s) => ({ type: "image", source: { type: "base64", media_type: s.media_type, data: s.data } }))] : prompt } });

    await new Promise<void>((resolve, reject) => {
      let buf = "";
      let chain = Promise.resolve();
      child.stdout.on("data", (d: Buffer) => {
        buf += d.toString("utf8");
        let i: number;
        while ((i = buf.indexOf("\n")) >= 0) {
          const line = buf.slice(0, i).trim();
          buf = buf.slice(i + 1);
          if (!line) continue;
          let m: Record<string, unknown>;
          try { m = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
          chain = chain.then(() => handle(m)).catch(() => {});
        }
      });
      child.on("error", (e) => reject(new Error(`could not start Claude Code: ${e.message}`)));
      child.on("close", (code) => {
        if (bgTimer) clearTimeout(bgTimer);
        void chain.then(() => {
          input.signal.removeEventListener("abort", onAbort);
          if (input.signal.aborted) return resolve();
          if (result?.is_error) return reject(new Error(result.text || "Claude Code reported an error"));
          if (!result) return reject(new Error(`Claude Code stopped (code ${code})${stderr.trim() ? `: ${stderr.trim().split("\n").slice(-3).join(" ")}` : ""}`));
          resolve();
        });
      });
    });
  }
}
