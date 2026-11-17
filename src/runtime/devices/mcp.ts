// Device tools (browser now; simulators later) as an MCP server over HTTP, so
// Claude Code and Codex chats get the same tools as the built-in agent. Loopback
// only (the runtime's own server), no browser origins, and a bearer token that
// lives only while one turn runs. Permission modes and approvals are decided
// here, the same way the built-in agent decides them, so every engine and every
// mode (Normal chats, Chief workers, Conductor modes, automations) behaves alike.

import { randomBytes } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import type { PermissionMode } from "../../shared/protocol";
import { policy, type Tool } from "../agent/tools";

export const DEVICES_MCP_PATH = "/mcp/devices";
/** The server name engines see (Claude Code tools are mcp__opscode_devices__<name>). */
export const DEVICES_MCP = "opscode_devices";
const MAX_BODY = 1024 * 1024;

type Json = Record<string, unknown>;

/** What the endpoint needs from the turn a token was issued for. */
export interface GrantHost {
  root: string;
  mode(): PermissionMode;
  /** The engine's own card for this call (running, same tool), so approval shows on it; undefined if none. */
  claimCall(toolName: string): string | undefined;
  toolStart(call: { call_id: string; tool: string; summary: string; detail?: string }, needsApproval: boolean): void;
  toolEnd(callId: string, r: { output: string; is_error: boolean; denied?: boolean }): void;
  approve(callId: string): Promise<boolean>;
  askApproval(callId: string, card?: { summary: string; detail?: string }): Promise<boolean>;
}

interface Grant {
  tools: Tool[];
  host: GrantHost;
  abort: AbortController;
}

export class DeviceGrants {
  private readonly grants = new Map<string, Grant>();
  private seq = 0;

  issue(tools: Tool[], host: GrantHost): string {
    const token = randomBytes(24).toString("hex");
    this.grants.set(token, { tools, host, abort: new AbortController() });
    return token;
  }

  revoke(token: string): void {
    this.grants.get(token)?.abort.abort();
    this.grants.delete(token);
  }

  get(token: string): Grant | undefined {
    return this.grants.get(token);
  }

  nextId(): string {
    return `dev-${(++this.seq).toString(36)}`;
  }
}

export function devicesMcpHandler(grants: DeviceGrants, version: string) {
  return (req: IncomingMessage, res: ServerResponse): void => {
    const reply = (status: number, body?: unknown): void => {
      res.statusCode = status;
      if (body === undefined) { res.end(); return; }
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify(body));
    };
    if (req.headers.origin !== undefined) return reply(403);
    if (req.method !== "POST") { res.setHeader("allow", "POST"); return reply(405); }
    const auth = req.headers.authorization;
    const grant = auth?.startsWith("Bearer ") ? grants.get(auth.slice(7).trim()) : undefined;
    if (!grant) return reply(401);

    let size = 0;
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY) { reply(413); req.destroy(); return; }
      chunks.push(c);
    });
    req.on("end", () => {
      if (res.writableEnded) return;
      let msg: unknown;
      try { msg = JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch { return reply(400, { jsonrpc: "2.0", id: null, error: { code: -32700, message: "parse error" } }); }
      const batch = Array.isArray(msg) ? msg : [msg];
      void Promise.all(batch.map((m) => handle(m as Json, grant, grants, version))).then((out) => {
        const answers = out.filter((x): x is Json => x !== undefined);
        if (answers.length === 0) return reply(202);
        reply(200, Array.isArray(msg) ? answers : answers[0]);
      });
    });
  };
}

async function handle(m: Json, grant: Grant, grants: DeviceGrants, version: string): Promise<Json | undefined> {
  if (typeof m !== "object" || m === null || typeof m.method !== "string") return m && "id" in m ? { jsonrpc: "2.0", id: m.id ?? null, error: { code: -32600, message: "invalid request" } } : undefined;
  const id = m.id;
  if (id === undefined) return undefined;
  const ok = (result: unknown): Json => ({ jsonrpc: "2.0", id, result });
  const params = (m.params ?? {}) as Json;
  switch (m.method) {
    case "initialize":
      return ok({ protocolVersion: typeof params.protocolVersion === "string" ? params.protocolVersion : "2025-06-18", capabilities: { tools: { listChanged: false } }, serverInfo: { name: "opscode-devices", version } });
    case "ping":
      return ok({});
    case "tools/list": {
      const mode = grant.host.mode();
      return ok({ tools: grant.tools.filter((t) => policy(mode, t.kind) !== "hide").map((t) => ({ name: t.def.name, description: t.def.description, inputSchema: t.def.schema })) });
    }
    case "tools/call":
      return ok(await callTool(grant, grants, String(params.name ?? ""), (params.arguments ?? {}) as Record<string, unknown>));
    default:
      return { jsonrpc: "2.0", id, error: { code: -32601, message: `unknown method ${m.method}` } };
  }
}

const textResult = (text: string, isError: boolean): Json => ({ content: [{ type: "text", text }], isError });

/** Same decisions as the built-in agent's runTool: mode rule, the tool's own gate, then approval. */
async function callTool(grant: Grant, grants: DeviceGrants, name: string, input: Record<string, unknown>): Promise<Json> {
  const { host } = grant;
  const tool = grant.tools.find((t) => t.def.name === name);
  if (!tool) return textResult(`Unknown tool ${name}.`, true);
  let rule = policy(host.mode(), tool.kind);
  if (rule === "hide") return textResult("This chat is read-only, so that action is not available.", true);
  let { summary, detail } = tool.describe(input);
  if (tool.gate) {
    let g;
    try { g = await tool.gate(input); } catch (e) { g = { rule: "deny" as const, summary, reason: e instanceof Error ? e.message : String(e) }; }
    summary = g.summary;
    detail = g.detail ?? detail;
    if (g.rule === "deny") return textResult(g.reason ?? "Not allowed.", true);
    rule = g.rule;
  }
  // Reuse the engine's card for this call when there is one; otherwise show our own.
  const engineCard = host.claimCall(name);
  const callId = engineCard ?? grants.nextId();
  if (!engineCard) host.toolStart({ call_id: callId, tool: name, summary, ...(detail ? { detail } : {}) }, rule === "ask");
  if (rule === "ask") {
    const allowed = engineCard ? await host.askApproval(callId, { summary, ...(detail ? { detail } : {}) }) : await host.approve(callId);
    if (!allowed) {
      if (!engineCard) host.toolEnd(callId, { output: "The user denied this action.", is_error: true, denied: true });
      return textResult("The user denied this action.", true);
    }
  }
  try {
    const r = await tool.run(input, { root: host.root, signal: grant.abort.signal, saveNote: () => { throw new Error("not available"); }, readSkill: () => undefined });
    if (!engineCard) host.toolEnd(callId, { output: r.output, is_error: r.is_error });
    const content: Json[] = [{ type: "text", text: r.output }];
    if (r.image) content.push({ type: "image", data: r.image.data, mimeType: r.image.media_type });
    return { content, isError: r.is_error };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (!engineCard) host.toolEnd(callId, { output: msg, is_error: true });
    return textResult(msg, true);
  }
}
