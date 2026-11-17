// Codex as a chat engine. Runs `codex app-server` (JSON-RPC over stdio) once
// per message in the project folder, with your ChatGPT sign-in. The thread id
// is kept on the chat so the next message resumes it. Commands and file
// changes Codex wants to make show as cards; approvals come back to you.

import { branchCreations, guardBranch } from "./branchGuard";
import { classifyCommand } from "./safety";
import { skillsNote } from "./skillsNote";
import { spawnProgram } from "../proc";
import { relative, isAbsolute } from "node:path";
import type { PermissionMode } from "../../shared/protocol";
import type { Engine, EngineInput, TurnHost } from "../turns";
import { cleanEnv, type EngineStore } from "./detect";
import type { AccountStore } from "./accounts";
import { CHIEF_MCP, FILE_LINK_NOTE, priorContext } from "./claude";
import { DEVICES_MCP } from "../devices/mcp";

/** Opscode mode -> Codex sandbox + approval policy. Full access still stays inside the project (workspace-write). */
export const CODEX_POLICY: Record<PermissionMode, { sandbox: string; approvalPolicy: string }> = {
  read: { sandbox: "read-only", approvalPolicy: "never" },
  supervised: { sandbox: "read-only", approvalPolicy: "untrusted" },
  auto_edits: { sandbox: "workspace-write", approvalPolicy: "untrusted" },
  full: { sandbox: "workspace-write", approvalPolicy: "never" },
};
const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);

/**
 * The voice agent (and a Manager) on Codex: it only talks and calls its own tools over MCP. Codex's shell, web, image and
 * computer tools are switched off, the sandbox is read-only, and every approval Codex asks for is answered here: the
 * agent's own tools are accepted, everything else declined (the worker does the coding, not the voice agent).
 */
const BRAIN_CONFIG = { "features.shell_tool": false, "features.image_generation": false, "features.browser_use": false, "features.computer_use": false, "features.in_app_browser": false, web_search: "disabled" };
const BRAIN_POLICY = { sandbox: "read-only", approvalPolicy: "on-request" };

interface Rpc {
  call(method: string, params: unknown): Promise<Record<string, unknown>>;
  notify(method: string, params?: unknown): void;
  close(): void;
}

/** Starts `codex app-server` (or another agent that speaks JSON-RPC over stdio: ACP agents pass their own args and name) and speaks JSON-RPC to it. onRequest answers server->client requests. */
export function startAppServer(bin: string, cwd: string, onNotify: (method: string, params: Record<string, unknown>) => void, onRequest: (method: string, params: Record<string, unknown>) => Promise<unknown>, onExit: (code: number | null, stderr: string) => void, env: NodeJS.ProcessEnv = cleanEnv(), args: string[] = ["app-server"], name = "Codex"): Rpc {
  const child = spawnProgram(bin, args, { cwd, env, stdio: ["pipe", "pipe", "pipe"] });
  let next = 1;
  const pending = new Map<number, { resolve: (v: Record<string, unknown>) => void; reject: (e: Error) => void }>();
  const write = (m: unknown): void => { if (!child.stdin.destroyed) child.stdin.write(`${JSON.stringify(m)}\n`); };
  let stderr = "";
  child.stderr.on("data", (d: Buffer) => (stderr = (stderr + d.toString("utf8")).slice(-2000)));
  child.stdin.on("error", () => {});
  let buf = "";
  child.stdout.on("data", (d: Buffer) => {
    buf += d.toString("utf8");
    if (buf.length > 16_000_000 && buf.indexOf("\n") < 0) { buf = ""; return; } // a line that never ends is dropped, not kept in memory
    let i: number;
    while ((i = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, i).trim();
      buf = buf.slice(i + 1);
      if (!line) continue;
      let m: Record<string, unknown>;
      try { m = JSON.parse(line) as Record<string, unknown>; } catch { continue; }
      if (typeof m.method === "string" && m.id !== undefined) {
        const reqId = m.id;
        void onRequest(m.method, (m.params ?? {}) as Record<string, unknown>).then((result) => write({ jsonrpc: "2.0", id: reqId, result }), (e: unknown) => write({ jsonrpc: "2.0", id: reqId, error: { code: -32000, message: e instanceof Error ? e.message : String(e) } }));
      } else if (typeof m.method === "string") onNotify(m.method, (m.params ?? {}) as Record<string, unknown>);
      else if (typeof m.id === "number" && pending.has(m.id)) {
        const p = pending.get(m.id)!;
        pending.delete(m.id);
        if (m.error) p.reject(Object.assign(new Error(String((m.error as { message?: unknown }).message ?? `${name} error`)), { rpcCode: (m.error as { code?: unknown }).code }));
        else p.resolve((m.result ?? {}) as Record<string, unknown>);
      }
    }
  });
  child.on("error", (e) => { for (const p of pending.values()) p.reject(new Error(`could not start ${name}: ${e.message}`)); pending.clear(); });
  child.on("close", (code) => {
    for (const p of pending.values()) p.reject(new Error(`${name} stopped (code ${code})${stderr.trim() ? `: ${stderr.trim().split("\n").slice(-2).join(" ")}` : ""}`));
    pending.clear();
    onExit(code, stderr);
  });
  return {
    call: (method, params) => new Promise((resolve, reject) => { const id = next++; pending.set(id, { resolve, reject }); write({ jsonrpc: "2.0", id, method, params }); }),
    notify: (method, params) => write({ jsonrpc: "2.0", method, ...(params === undefined ? {} : { params }) }),
    close: () => { child.stdin.end(); setTimeout(() => { if (child.exitCode === null) child.kill("SIGTERM"); }, 1500).unref(); },
  };
}

export class CodexEngine implements Engine {
  /** Called with account/rateLimits/updated (plan limits) during a chat, and the account that chat ran on. */
  onLimits?: (params: Record<string, unknown>, account: string) => void;

  constructor(private readonly store: EngineStore, private readonly accounts?: AccountStore) {}

  get id(): string {
    return "codex";
  }

  /** Models this Codex offers (asks a short-lived app-server). */
  async models(): Promise<{ id: string; label: string; efforts?: string[] }[]> {
    const bin = this.store.codexPath();
    if (!bin) return [];
    let rpc: Rpc | null = null;
    try {
      rpc = startAppServer(bin, process.cwd(), () => {}, async () => ({}), () => {});
      await rpc.call("initialize", { clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" }, capabilities: null });
      rpc.notify("initialized");
      const res = await Promise.race([rpc.call("model/list", {}), new Promise<never>((_, rej) => setTimeout(() => rej(new Error("timeout")), 15_000).unref())]);
      const data = Array.isArray(res.data) ? (res.data as Record<string, unknown>[]) : [];
      const list = data.filter((m) => m.hidden !== true).map((m, i) => ({
        id: String(m.model ?? m.id),
        label: String(m.displayName ?? m.model ?? m.id).replace(/^GPT-/, "GPT-"),
        efforts: Array.isArray(m.supportedReasoningEfforts) ? (m.supportedReasoningEfforts as Record<string, unknown>[]).map((e) => String(e.reasoningEffort)) : undefined,
        ...(typeof m.description === "string" ? { description: m.description } : {}),
        ...(i >= 4 ? { more: true } : {}),
      }));
      this.store.setCodexModels(list);
      return list;
    } catch {
      return [];
    } finally {
      rpc?.close();
    }
  }

  async run(input: EngineInput, emit: (delta: string) => void, host: TurnHost): Promise<void> {
    const brain = host.chief;
    const bin = this.store.codexPath();
    if (!bin) throw new Error("Codex is not installed (no `codex` program found). Install Codex or the ChatGPT app, or set its path in Settings → Models & keys.");
    const chat = host.chat;
    const account = host.account ?? "default";
    const policy = brain ? BRAIN_POLICY : CODEX_POLICY[host.mode()];
    const rel = (p: unknown): string => { const s = String(p ?? ""); if (!isAbsolute(s)) return s; const r = relative(host.root, s); return r && !r.startsWith("..") ? r : s; };
    const cards = new Set<string>();
    let threadId: string | null = null;
    let turnId: string | null = null;
    let done: (err?: Error) => void = () => {};
    const finished = new Promise<void>((resolve, reject) => { done = (err) => (err ? reject(err) : resolve()); });
    let exited = false;

    const card = (item: Record<string, unknown>): void => {
      const id = String(item.id);
      if (cards.has(id)) return;
      let tool = String(item.type);
      let summary = tool;
      let detail = "";
      switch (item.type) {
        case "commandExecution": tool = "run_command"; summary = `Run ${clip(String(item.command ?? "").replace(/^\/bin\/(z|ba)?sh -lc /, "").replace(/^"|"$/g, ""), 80)}`; detail = String(item.command ?? ""); break;
        case "fileChange": {
          const changes = Array.isArray(item.changes) ? (item.changes as Record<string, unknown>[]) : [];
          tool = "write_file";
          summary = `Edit ${changes.map((c) => rel(c.path)).join(", ") || "files"}`;
          detail = clip(changes.map((c) => `${rel(c.path)}\n${String(c.diff ?? "")}`).join("\n\n"), 2000);
          break;
        }
        case "mcpToolCall": {
          detail = clip(JSON.stringify(item.arguments ?? {}, null, 2), 2000);
          // Opscode's own device tools get their own card names, so the device endpoint can put approval on this card.
          const own = brain && item.server === CHIEF_MCP ? brain.tools.find((t) => t.def.name === String(item.tool ?? "")) : undefined;
          if (own) { tool = `mcp__${CHIEF_MCP}__${String(item.tool)}`; summary = own.describe((item.arguments ?? {}) as Record<string, unknown>).summary; break; }
          const dev = item.server === DEVICES_MCP ? host.devices?.describe(String(item.tool ?? ""), (item.arguments ?? {}) as Record<string, unknown>) : undefined;
          if (dev) { tool = `mcp__${DEVICES_MCP}__${String(item.tool)}`; summary = dev.summary; detail = dev.detail ?? detail; break; }
          tool = "mcp"; summary = `${String(item.server ?? "")} · ${String(item.tool ?? "")}`;
          break;
        }
        case "webSearch": tool = "web_search"; summary = `Search the web: ${clip(String(item.query ?? ""), 60)}`; break;
        // Codex's image tool: the card shows progress, then the saved file (savedPath) when it completes.
        case "imageGeneration": tool = "image_generation"; summary = `Generate image${item.revisedPrompt ? `: ${clip(String(item.revisedPrompt), 70)}` : ""}`; detail = clip(String(item.revisedPrompt ?? ""), 2000); break;
        default: return; // messages, reasoning, plans are not cards
      }
      cards.add(id);
      host.toolStart({ call_id: id, tool, summary, detail }, false);
    };
    const finish = (item: Record<string, unknown>): void => {
      const id = String(item.id);
      if (!cards.has(id)) return;
      if (item.type === "commandExecution") {
        const code = typeof item.exitCode === "number" ? item.exitCode : null;
        const out = typeof item.aggregatedOutput === "string" ? item.aggregatedOutput : "";
        host.toolEnd(id, { output: `${out}${code !== null ? `${out ? "\n" : ""}(exit ${code})` : ""}` || "(no output)", is_error: item.status === "failed" || item.status === "declined" || (code !== null && code !== 0) });
      } else if (item.type === "imageGeneration") {
        const saved = typeof item.savedPath === "string" ? item.savedPath : "";
        host.toolEnd(id, { output: item.status === "failed" ? "Failed" : saved || "Done", is_error: item.status === "failed" });
      } else host.toolEnd(id, { output: item.status === "failed" ? "Failed" : "Done", is_error: item.status === "failed" || item.status === "declined" });
    };

    const ask = async (itemId: string, fallback: { summary: string; detail: string }): Promise<boolean> => {
      if (!cards.has(itemId)) { cards.add(itemId); host.toolStart({ call_id: itemId, tool: "codex", summary: fallback.summary, detail: fallback.detail }, false); }
      return host.askApproval(itemId);
    };

    const rpc = startAppServer(bin, host.root,
      (method, p) => {
        if (method === "item/agentMessage/delta" && typeof p.delta === "string") emit(p.delta);
        else if (method === "item/started") card(p.item as Record<string, unknown>);
        else if (method === "item/completed") { const it = p.item as Record<string, unknown>; card(it); finish(it); }
        else if (method === "turn/plan/updated" && Array.isArray(p.plan)) host.planUpdated?.((p.plan as Record<string, unknown>[]).map((x) => ({ step: String(x.step ?? ""), status: x.status })), typeof p.explanation === "string" ? p.explanation : undefined);
        else if (method === "thread/tokenUsage/updated") {
          const tu = p.tokenUsage as { total?: Record<string, number>; last?: Record<string, number>; modelContextWindow?: number } | undefined;
          // Codex reports running totals for the whole thread, and a chat's Codex usage is that thread's.
          const t = tu?.total ?? {};
          host.setEngineState({ usage: { input_tokens: Math.max(0, (t.inputTokens ?? 0) - (t.cachedInputTokens ?? 0)), output_tokens: t.outputTokens ?? 0, cached_tokens: t.cachedInputTokens ?? 0, ...(tu?.last ? { context_tokens: tu.last.totalTokens ?? 0 } : {}), ...(tu?.modelContextWindow ? { context_window: tu.modelContextWindow } : {}), reported_at: new Date().toISOString(), cache_tokens: tu?.last?.cachedInputTokens ?? 0, ...(host.chat.model ? { model: host.chat.model } : {}) } });
        } else if (method === "turn/completed") {
          const turn = p.turn as { status?: string; error?: { message?: string } | null } | undefined;
          if (turn?.status === "failed") done(new Error(turn.error?.message ?? "Codex failed"));
          else done();
        } else if (method === "account/rateLimits/updated") {
          this.onLimits?.(p, account);
        } else if (method === "error") {
          const e = p.error as { message?: string } | undefined;
          if (p.willRetry !== true) done(new Error(e?.message ?? "Codex error"));
        }
      },
      async (method, p) => {
        if (brain) {
          // Only the agent's own tools are accepted; anything else (a command, a file change, another MCP server) is declined.
          const mine = /mcp/i.test(method) && /approval|elicitation/i.test(method) && JSON.stringify(p).includes(CHIEF_MCP);
          if (mine) return { decision: "accept", action: "accept" };
          if (method === "execCommandApproval" || method === "applyPatchApproval") return { decision: "denied" };
          if (/approval|elicitation|permissions/i.test(method)) return { decision: "decline", action: "decline" };
        }
        if (method === "item/commandExecution/requestApproval" || method === "execCommandApproval") {
          // A new git branch is the person's call (own card; the project's branch rule may already answer).
          const cmd = Array.isArray(p.command) ? (p.command as string[]).join(" ") : String(p.command ?? "");
          const id = String(p.itemId ?? p.callId ?? "");
          if (id) {
            if (!cards.has(id) && branchCreations(cmd).length) { cards.add(id); host.toolStart({ call_id: id, tool: "codex", summary: `Run ${clip(cmd, 80)}`, detail: cmd }, false); }
            const b = await guardBranch(host, id, cmd);
            if (b) return method === "execCommandApproval" ? { decision: b.allow ? "approved" : "denied" } : { decision: b.allow ? "accept" : "decline" };
          }
        }
        if (method === "item/commandExecution/requestApproval") {
          // Auto edits: reading, searching, read-only queries and local tests run without a question (engines/safety.ts).
          if (host.mode() === "auto_edits" && classifyCommand(String(p.command ?? ""), host.root) === "safe") return { decision: "accept" };
          const ok = await ask(String(p.itemId), { summary: `Run ${clip(String(p.command ?? ""), 80)}`, detail: String(p.command ?? "") });
          return { decision: ok ? "accept" : "decline" };
        }
        if (method === "item/fileChange/requestApproval") {
          const ok = await ask(String(p.itemId), { summary: "Change files", detail: String(p.reason ?? "") });
          return { decision: ok ? "accept" : "decline" };
        }
        if (method === "execCommandApproval" && host.mode() === "auto_edits" && classifyCommand(([] as string[]).concat((p.command as string[]) ?? []).join(" "), host.root) === "safe") return { decision: "approved" };
        if (method === "execCommandApproval" || method === "applyPatchApproval") {
          const ok = await ask(String(p.callId ?? p.itemId ?? `legacy-${Date.now()}`), { summary: method === "execCommandApproval" ? `Run ${clip(([] as string[]).concat((p.command as string[]) ?? []).join(" "), 80)}` : "Change files", detail: "" });
          return { decision: ok ? "approved" : "denied" };
        }
        if (method === "item/permissions/requestApproval") return { decision: "decline" };
        // Opscode's device tools are approved by Opscode itself (per mode, on the card), so Codex need not ask.
        if (/mcp/i.test(method) && /approval|elicitation/i.test(method) && JSON.stringify(p).includes(DEVICES_MCP)) return { decision: "accept", action: "accept" };
        throw new Error(`Opscode does not handle ${method}`);
      },
      (code, stderr) => { exited = true; done(new Error(`Codex stopped (code ${code})${stderr.trim() ? `: ${stderr.trim().split("\n").slice(-2).join(" ")}` : ""}`)); },
      this.accounts ? this.accounts.env("codex", account) : cleanEnv());

    const onAbort = (): void => {
      if (threadId && turnId) void rpc.call("turn/interrupt", { threadId, turnId }).catch(() => {});
      setTimeout(() => rpc.close(), 1500).unref();
      done();
    };
    input.signal.addEventListener("abort", onAbort, { once: true });
    try {
      await rpc.call("initialize", { clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" }, capabilities: null });
      rpc.notify("initialized");
      // Opscode's browser over MCP, for this turn only (the token dies when the turn ends).
      const config = brain
        ? { [`mcp_servers.${CHIEF_MCP}`]: { url: brain.mcp.url, http_headers: { Authorization: `Bearer ${brain.mcp.token}` }, tool_timeout_sec: 600 }, ...BRAIN_CONFIG }
        : host.devices ? { [`mcp_servers.${DEVICES_MCP}`]: { url: host.devices.url, http_headers: { Authorization: `Bearer ${host.devices.token}` }, tool_timeout_sec: 600 } } : undefined;
      const common = { cwd: host.root, approvalPolicy: policy.approvalPolicy, sandbox: policy.sandbox, ...(chat.model ? { model: chat.model } : {}), ...(config ? { config } : {}) };
      let thread: Record<string, unknown> | null = null;
      if (chat.engine_session) {
        try { thread = await rpc.call("thread/resume", { threadId: chat.engine_session, ...common }); } catch { thread = null; }
      }
      const fresh = !thread;
      const dev = brain ? "" : [host.memory ? `Notes the user keeps for this work (follow them as the user's own words):\n${host.memory}` : "", FILE_LINK_NOTE, host.devices?.note ?? "", skillsNote(host.skillFiles ?? [])].filter(Boolean).join("\n\n");
      if (!thread) thread = await rpc.call("thread/start", { ...common, ...(brain ? { baseInstructions: brain.system } : {}), ...(dev ? { developerInstructions: dev } : {}) });
      threadId = String((thread.thread as { id?: unknown } | undefined)?.id ?? "");
      if (!threadId) throw new Error("Codex did not start a thread");
      host.setEngineState({ engine_session: threadId });
      // Taking over from another engine: the pack and the recent conversation go into the thread as real
      // history (thread/inject_items). If Codex refuses, the pack goes in front of the message instead.
      let lead = input.handoff ? "" : fresh ? priorContext(input.history) : "";
      if (input.handoff) {
        const h = input.handoff;
        const items = [
          // Back in its own thread (update) Codex has not seen the other engine's turns, so it gets the user's words too.
          { type: "message", role: "developer", content: [{ type: "input_text", text: h.kind === "update" ? h.text : h.bare }] },
          ...h.messages.map((m) => ({ type: "message", role: m.role, content: [{ type: m.role === "user" ? "input_text" : "output_text", text: m.text }] })),
        ];
        let injected = false;
        try { await rpc.call("thread/inject_items", { threadId, items }); injected = true; } catch (e) { host.log?.(`codex inject_items failed: ${String(e)}`); }
        if (injected) host.handoffSent?.("inject", (h.kind === "update" ? h.text : h.bare).length + h.messages.reduce((n, m) => n + m.text.length, 0));
        else { lead = `${h.text}\n\n`; host.handoffSent?.("message", h.text.length); }
      }
      const text = lead + input.text;
      // Reference images (brand logo, earlier assets) go in as local images, like `codex exec -i`.
      const imgs = (input.images ?? []).map((path) => ({ type: "localImage", path }));
      const started = await rpc.call("turn/start", { threadId, input: [{ type: "text", text, text_elements: [] }, ...imgs], ...(chat.effort ? { effort: chat.effort } : {}), ...(chat.model ? { model: chat.model } : {}), approvalPolicy: policy.approvalPolicy });
      turnId = String((started.turn as { id?: unknown } | undefined)?.id ?? "");
      await finished;
    } finally {
      input.signal.removeEventListener("abort", onAbort);
      if (!exited) rpc.close();
    }
  }
}
