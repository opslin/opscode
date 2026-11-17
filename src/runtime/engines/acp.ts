// Coding agents that speak ACP (Agent Client Protocol: JSON-RPC over stdio), run with the person's own sign-in:
//   Antigravity   `agy acp`      (Google AI Pro / Gemini sign-in)
//   Qoder         `qoder --acp`  (Qoder sign-in, credits)
// One adapter for both. A chat keeps the agent's session id, so the next message resumes it. What the agent does
// (run a command, edit a file, read, search) shows as cards; when it asks, the same Opscode rules as for Codex apply:
// read-only never edits, Supervised asks, Auto edits lets edits and safe commands through, Full access asks nothing.

import { readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, isAbsolute, relative } from "node:path";
import type { AcpEngineId } from "../../shared/protocol";
import type { Engine, EngineInput, TurnHost } from "../turns";
import { cleanEnv, ENGINE_NAMES, type EngineModel, type EngineStore } from "./detect";
import type { AccountStore } from "./accounts";
import { startAppServer } from "./codex";
import { branchCreations, guardBranch } from "./branchGuard";
import { classifyCommand } from "./safety";
import { skillsNote } from "./skillsNote";
import { CHIEF_MCP, FILE_LINK_NOTE, priorContext } from "./claude";
import { DEVICES_MCP } from "../devices/mcp";

/** The voice agent's own tool a call belongs to (agents name MCP tools like `mcp_opscode_chief_work_status`), if any. */
function chiefToolOf(tools: { def: { name: string }; describe(i: Record<string, unknown>): { summary: string } }[], u: Record<string, unknown>): (typeof tools)[number] | undefined {
  const label = `${String(u.name ?? "")} ${String(u.title ?? "")} ${String(u.toolName ?? "")}`;
  if (!label.includes(CHIEF_MCP)) return undefined;
  return tools.find((t) => label.includes(`${CHIEF_MCP}_${t.def.name}`) || label.includes(`${CHIEF_MCP}__${t.def.name}`));
}

/** How each agent is started in ACP mode. */
export const ACP_ARGS: Record<AcpEngineId, string[]> = { antigravity: ["acp"], qoder: ["--acp"] };
export const ACP_AUTH_CODE = -32000; // "Authentication required"

const clip = (s: string, n: number): string => (s.length > n ? `${s.slice(0, n)}…` : s);
const rec = (v: unknown): Record<string, unknown> => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const IMAGE_TYPES: Record<string, string> = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif", ".webp": "image/webp" };

export interface AcpSession {
  sessionId: string;
  models: { id: string; label: string }[];
  currentModel?: string;
  modes: { id: string; name: string }[];
}

/** What came back from initialize. */
export interface AcpInit {
  loadSession: boolean;
  resume: boolean;
  image: boolean;
  authMethods: { id: string; name: string; description?: string }[];
  canLogout: boolean;
  /** The agent can connect to an HTTP MCP server (how it gets Opscode's shared tools, such as image_generate). */
  mcpHttp: boolean;
  agent: string;
}

export function parseInit(r: Record<string, unknown>): AcpInit {
  const caps = rec(r.agentCapabilities);
  const sc = rec(caps.sessionCapabilities);
  return {
    loadSession: caps.loadSession === true,
    resume: sc.resume !== undefined,
    image: rec(caps.promptCapabilities).image === true,
    authMethods: (Array.isArray(r.authMethods) ? r.authMethods : []).map((m) => rec(m)).filter((m) => typeof m.id === "string").map((m) => ({ id: String(m.id), name: String(m.name ?? m.id), ...(typeof m.description === "string" ? { description: m.description } : {}) })),
    canLogout: rec(caps.auth).logout !== undefined,
    mcpHttp: rec(caps.mcpCapabilities).http === true,
    agent: String(rec(r.agentInfo).name ?? "agent"),
  };
}

export function parseSession(r: Record<string, unknown>): AcpSession {
  const models = rec(r.models);
  const modes = rec(r.modes);
  return {
    sessionId: String(r.sessionId ?? ""),
    models: (Array.isArray(models.availableModels) ? models.availableModels : []).slice(0, 200).map((m) => rec(m)).filter((m) => typeof m.modelId === "string" && m.modelId.length <= 120).map((m) => ({ id: String(m.modelId), label: String(m.name ?? m.modelId).slice(0, 120) })),
    ...(typeof models.currentModelId === "string" ? { currentModel: models.currentModelId } : {}),
    modes: (Array.isArray(modes.availableModes) ? modes.availableModes : []).map((m) => rec(m)).filter((m) => typeof m.id === "string").map((m) => ({ id: String(m.id), name: String(m.name ?? m.id) })),
  };
}

/** What a permission request should do under an Opscode permission mode: allow it, refuse it, or ask the person. */
export function permissionPolicy(mode: "read" | "supervised" | "auto_edits" | "full", kindIn: string, command: string | undefined, root: string): "allow" | "deny" | "ask" {
  // The agent names the kind of a request itself. One that carries a command is a command, whatever it is called.
  const kind = command !== undefined ? "execute" : kindIn;
  const harmless = kind === "read" || kind === "search" || kind === "think";
  if (mode === "full") return "allow";
  if (harmless) return "allow";
  // A web fetch can send what it has read away: it goes ahead on Auto edits, asks on Supervised, and is not allowed read-only.
  if (kind === "fetch") return mode === "auto_edits" ? "allow" : mode === "read" ? "deny" : "ask";
  if (mode === "read") return "deny";
  if (mode === "auto_edits") {
    if (kind === "edit") return "allow";
    if (kind === "execute" && command && classifyCommand(command, root) === "safe") return "allow";
  }
  return "ask";
}

const TOOL_NAME: Record<string, string> = { execute: "run_command", edit: "write_file", delete: "write_file", move: "write_file", read: "read_file", search: "search", fetch: "web_search", think: "think", other: "tool" };

/** The text an agent put in a tool call's content (text blocks and diffs). */
export function contentText(content: unknown, rel: (p: unknown) => string): string {
  if (!Array.isArray(content)) return "";
  const out: string[] = [];
  for (const c of content) {
    const b = rec(c);
    if (b.type === "content") { const t = rec(b.content); if (t.type === "text" && typeof t.text === "string") out.push(t.text); }
    else if (b.type === "diff") out.push(`${rel(b.path)}\n${typeof b.newText === "string" ? b.newText : ""}`);
    else if (b.type === "terminal") out.push(`(terminal ${String(b.terminalId ?? "")})`);
  }
  return out.join("\n");
}

export class AcpEngine implements Engine {
  constructor(private readonly agent: AcpEngineId, private readonly store: EngineStore, private readonly accounts?: AccountStore) {}

  get id(): string { return this.agent; }
  private get name(): string { return ENGINE_NAMES[this.agent]; }

  /** Models this agent offers (it tells them when a session starts). Empty when it is not installed or not signed in. */
  async models(): Promise<EngineModel[]> {
    const bin = this.store.pathOf(this.agent);
    if (!bin) return [];
    // Starting a session is how both questions are answered ("who is signed in" and "which models"): one start serves both, and
    // one that is already under way for the account list is shared (accounts.ts probeAcp).
    if (this.accounts) {
      await this.accounts.status(this.agent, this.accounts.active(this.agent), true).catch(() => undefined);
      return this.store.acpModels(this.agent);
    }
    const rpc = startAppServer(bin, tmpdir(), () => {}, async () => ({}), () => {}, cleanEnv(), ACP_ARGS[this.agent], this.name);
    try {
      const within = <T>(p: Promise<T>): Promise<T> => Promise.race([p, new Promise<never>((_, rej) => setTimeout(() => rej(new Error("timeout")), 20_000).unref())]);
      await within(rpc.call("initialize", { protocolVersion: 1, clientCapabilities: {} }));
      const s = parseSession(await within(rpc.call("session/new", { cwd: tmpdir(), mcpServers: [] })));
      const list = s.models.map((m, i) => ({ id: m.id, label: m.label, ...(i >= 5 ? { more: true } : {}) }));
      if (list.length) this.store.setAcpModels(this.agent, list);
      return list;
    } catch (e) {
      // Signed out: no models. Any other trouble (slow network, a crash) keeps the list it already knows.
      if ((e as { rpcCode?: unknown }).rpcCode === ACP_AUTH_CODE) this.store.setAcpModels(this.agent, []);
      return this.store.acpModels(this.agent);
    } finally {
      rpc.close();
    }
  }

  async run(input: EngineInput, emit: (delta: string) => void, host: TurnHost): Promise<void> {
    const name = this.name;
    // The voice agent (or a Manager) runs here only to talk and call its own tools over MCP; the agent's other tools are refused below.
    const brain = host.chief;
    const bin = this.store.pathOf(this.agent);
    if (!bin) throw new Error(`${name} is not installed (no \`${this.agent === "antigravity" ? "agy" : "qoder"}\` program found). Install it, or set its path in Settings → Models & keys.`);
    const chat = host.chat;
    const account = host.account ?? "default";
    const rel = (p: unknown): string => { const s = String(p ?? ""); if (!isAbsolute(s)) return s; const r = relative(host.root, s); return r && !r.startsWith("..") ? r : s; };
    const cards = new Set<string>();
    const ended = new Set<string>();
    let sessionId = "";
    let replaying = false;
    let exited = false;
    let init: AcpInit | null = null;

    const card = (u: Record<string, unknown>): void => {
      const id = String(u.toolCallId ?? "");
      if (!id || cards.has(id)) return;
      const kind = String(u.kind ?? "other");
      const raw = rec(u.rawInput);
      const command = typeof raw.command === "string" ? raw.command : Array.isArray(raw.command) ? (raw.command as unknown[]).map(String).join(" ") : undefined;
      const title = String(u.title ?? kind);
      cards.add(id);
      const own = brain ? chiefToolOf(brain.tools, u) : undefined;
      if (own) { host.toolStart({ call_id: id, tool: `mcp__${CHIEF_MCP}__${own.def.name}`, summary: own.describe(rec(u.args ?? u.rawInput)).summary, detail: "" }, false); return; }
      host.toolStart({ call_id: id, tool: TOOL_NAME[kind] ?? "tool", summary: clip(command && kind === "execute" ? `Run ${command}` : title, 100), detail: clip(command ?? (Object.keys(raw).length ? JSON.stringify(raw, null, 2) : contentText(u.content, rel)), 2000) }, false);
    };
    const finish = (u: Record<string, unknown>): void => {
      const id = String(u.toolCallId ?? "");
      if (!cards.has(id) || ended.has(id)) return;
      const status = String(u.status ?? "");
      if (status !== "completed" && status !== "failed") return;
      ended.add(id);
      const out = contentText(u.content, rel) || (typeof u.rawOutput === "string" ? u.rawOutput : u.rawOutput !== undefined ? clip(JSON.stringify(u.rawOutput), 2000) : "");
      host.toolEnd(id, { output: clip(out, 4000) || (status === "failed" ? "Failed" : "Done"), is_error: status === "failed" });
    };

    const rpc = startAppServer(bin, host.root,
      (method, p) => {
        if (method !== "session/update" || replaying || (p.sessionId && sessionId && p.sessionId !== sessionId)) return;
        const u = rec(p.update);
        switch (u.sessionUpdate) {
          case "agent_message_chunk": { const c = rec(u.content); if (c.type === "text" && typeof c.text === "string") emit(c.text); break; }
          case "tool_call": card(u); finish(u); break;
          case "tool_call_update": card(u); finish(u); break;
          case "plan": host.planUpdated?.((Array.isArray(u.entries) ? u.entries : []).map((e) => ({ step: String(rec(e).content ?? ""), status: rec(e).status })), undefined); break;
          case "usage_update": {
            const used = typeof u.used === "number" ? u.used : 0;
            const size = typeof u.size === "number" ? u.size : 0;
            if (used > 0 || size > 0) host.setEngineState({ usage: { input_tokens: used, output_tokens: 0, cached_tokens: 0, context_tokens: used, ...(size ? { context_window: size } : {}), reported_at: new Date().toISOString(), cache_tokens: 0, ...(chat.model ? { model: chat.model } : {}) } });
            break;
          }
          default: break; // thoughts, commands, mode changes: not shown
        }
      },
      async (method, p) => {
        if (method === "session/request_permission" && brain) {
          // Only the agent's own tools run; a command, an edit or another server's tool is refused.
          const tc = rec(p.toolCall);
          const options = (Array.isArray(p.options) ? p.options : []).map((o) => rec(o));
          const mine = !!chiefToolOf(brain.tools, tc);
          const o = options.find((x) => (mine ? x.kind === "allow_once" || x.kind === "allow_always" : x.kind === "reject_once" || x.kind === "reject_always"));
          return o ? { outcome: { outcome: "selected", optionId: String(o.optionId) } } : { outcome: { outcome: "cancelled" } };
        }
        if (method === "session/request_permission") {
          const tc = rec(p.toolCall);
          const id = String(tc.toolCallId ?? `perm-${Date.now()}`);
          const kind = String(tc.kind ?? "other");
          const raw = rec(tc.rawInput);
          const command = typeof raw.command === "string" ? raw.command : Array.isArray(raw.command) ? (raw.command as unknown[]).map(String).join(" ") : undefined;
          const options = (Array.isArray(p.options) ? p.options : []).map((o) => rec(o));
          const pick = (...kinds: string[]): Record<string, unknown> | undefined => { for (const k of kinds) { const o = options.find((x) => x.kind === k); if (o) return o; } return undefined; };
          const answer = (allow: boolean): unknown => {
            const o = allow ? pick("allow_once", "allow_always") : pick("reject_once", "reject_always");
            return o ? { outcome: { outcome: "selected", optionId: String(o.optionId) } } : { outcome: { outcome: "cancelled" } };
          };
          card({ ...tc, toolCallId: id, kind, title: tc.title ?? kind });
          if (command && branchCreations(command).length) { const b = await guardBranch(host, id, command); if (b) return answer(b.allow); }
          const policy = permissionPolicy(host.mode(), kind, command, host.root);
          if (policy === "allow") return answer(true);
          if (policy === "deny") { host.toolEnd(id, { output: "Not allowed in read-only mode.", is_error: true, denied: true }); ended.add(id); return answer(false); }
          return answer(await host.askApproval(id));
        }
        throw new Error(`Opscode does not handle ${method}`);
      },
      (code, stderr) => { exited = true; if (!sessionId) return; void code; void stderr; },
      this.accounts ? this.accounts.env(this.agent, account) : cleanEnv(), ACP_ARGS[this.agent], name);

    const onAbort = (): void => {
      if (sessionId) rpc.notify("session/cancel", { sessionId });
      setTimeout(() => rpc.close(), 3000).unref();
    };
    input.signal.addEventListener("abort", onAbort, { once: true });
    try {
      init = parseInit(await rpc.call("initialize", { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false }, clientInfo: { name: "opscode", title: "Opscode", version: "0.0.1" } }));
      // Opscode's shared tools (image_generate, the browser...) reach agents that can use an HTTP MCP server; the token lives for this turn only.
      const mcpServers = brain ? [{ type: "http", name: CHIEF_MCP, url: brain.mcp.url, headers: [{ name: "Authorization", value: `Bearer ${brain.mcp.token}` }] }] : host.devices && init.mcpHttp ? [{ type: "http", name: DEVICES_MCP, url: host.devices.url, headers: [{ name: "Authorization", value: `Bearer ${host.devices.token}` }] }] : [];
      let session: AcpSession | null = null;
      const fresh0 = !chat.engine_session;
      if (chat.engine_session && (init.resume || init.loadSession)) {
        try {
          if (init.resume) session = { ...parseSession(await rpc.call("session/resume", { sessionId: chat.engine_session, cwd: host.root, mcpServers })), sessionId: chat.engine_session };
          else { replaying = true; sessionId = chat.engine_session; session = { ...parseSession(await rpc.call("session/load", { sessionId: chat.engine_session, cwd: host.root, mcpServers })), sessionId: chat.engine_session }; }
        } catch (e) { host.log?.(`${name}: could not resume the session: ${String(e)}`); session = null; }
        finally { replaying = false; }
      }
      const fresh = !session;
      if (!session) session = parseSession(await rpc.call("session/new", { cwd: host.root, mcpServers }));
      sessionId = session.sessionId;
      if (!sessionId) throw new Error(`${name} did not start a session`);
      host.setEngineState({ engine_session: sessionId });
      void fresh0;
      if (session.models.length) this.store.setAcpModels(this.agent, session.models.map((m, i) => ({ id: m.id, label: m.label, ...(i >= 5 ? { more: true } : {}) })));
      // The model the chat asked for, when the agent offers it.
      if (chat.model && chat.model !== session.currentModel && session.models.some((m) => m.id === chat.model)) {
        try { await rpc.call("session/set_model", { sessionId, modelId: chat.model }); }
        catch { try { await rpc.call("session/set_config_option", { sessionId, configId: "model", value: chat.model }); } catch (e) { host.log?.(`${name}: could not pick the model: ${String(e)}`); } }
      }
      let lead = "";
      if (input.handoff) { lead = `${input.handoff.text}\n\n`; host.handoffSent?.("message", input.handoff.text.length); }
      else if (fresh) lead = priorContext(input.history);
      const notes = brain ? `<instructions>\n${brain.system}\n</instructions>` : [host.memory ? `Notes the user keeps for this work (follow them as the user's own words):\n${host.memory}` : "", FILE_LINK_NOTE, host.devices && init.mcpHttp ? host.devices.note : "", skillsNote(host.skillFiles ?? [])].filter(Boolean).join("\n\n");
      const text = `${fresh && notes ? `${notes}\n\n` : ""}${lead}${input.text}`;
      const blocks: Record<string, unknown>[] = [{ type: "text", text }];
      if (init.image) {
        for (const path of input.images ?? []) {
          const mime = IMAGE_TYPES[extname(path).toLowerCase()];
          if (!mime) continue;
          try { blocks.push({ type: "image", mimeType: mime, data: readFileSync(path).toString("base64") }); } catch { /* unreadable: the note lists its path */ }
        }
      }
      const done = await rpc.call("session/prompt", { sessionId, prompt: blocks });
      const reason = String(done.stopReason ?? "end_turn");
      if (reason === "refusal") throw new Error(`${name} refused this request.`);
      if (reason === "max_tokens") emit("\n\n(The reply was cut: the model reached its length limit.)");
    } catch (e) {
      if (input.signal.aborted) return;
      const code = (e as { rpcCode?: unknown }).rpcCode;
      if (code === ACP_AUTH_CODE) throw new Error(`${name}: authentication required. Sign in again.`);
      throw e;
    } finally {
      input.signal.removeEventListener("abort", onAbort);
      if (!exited) rpc.close();
    }
  }
}
