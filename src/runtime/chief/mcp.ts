// The Chief's tools as an MCP server over HTTP, for a Chief that runs on
// Claude Code. Loopback only (it is on the runtime's own server), no browser
// origins, and a bearer token that exists only while one Chief turn runs.

import type { IncomingMessage, ServerResponse } from "node:http";
import type { Tool } from "../agent/tools";

export const CHIEF_MCP_PATH = "/mcp/chief";
const MAX_BODY = 1024 * 1024;

type Json = Record<string, unknown>;

export function chiefMcpHandler(toolsFor: (token: string) => Tool[] | undefined, version: string) {
  return (req: IncomingMessage, res: ServerResponse): void => {
    const reply = (status: number, body?: unknown): void => {
      res.statusCode = status;
      if (body === undefined) { res.end(); return; }
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify(body));
    };
    // A browser page never talks to this endpoint.
    if (req.headers.origin !== undefined) return reply(403);
    if (req.method !== "POST") { res.setHeader("allow", "POST"); return reply(405); }
    const auth = req.headers.authorization;
    const tools = auth?.startsWith("Bearer ") ? toolsFor(auth.slice(7).trim()) : undefined;
    if (!tools) return reply(401);

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
      void Promise.all(batch.map((m) => handle(m as Json, tools, version))).then((out) => {
        const answers = out.filter((x): x is Json => x !== undefined);
        if (answers.length === 0) return reply(202);
        reply(200, Array.isArray(msg) ? answers : answers[0]);
      });
    });
  };
}

async function handle(m: Json, tools: Tool[], version: string): Promise<Json | undefined> {
  if (typeof m !== "object" || m === null || typeof m.method !== "string") return m && "id" in m ? { jsonrpc: "2.0", id: m.id ?? null, error: { code: -32600, message: "invalid request" } } : undefined;
  const id = m.id;
  if (id === undefined) return undefined; // a notification
  const ok = (result: unknown): Json => ({ jsonrpc: "2.0", id, result });
  const params = (m.params ?? {}) as Json;
  switch (m.method) {
    case "initialize":
      return ok({ protocolVersion: typeof params.protocolVersion === "string" ? params.protocolVersion : "2025-06-18", capabilities: { tools: { listChanged: false } }, serverInfo: { name: "opscode-chief", version } });
    case "ping":
      return ok({});
    case "tools/list":
      return ok({ tools: tools.map((t) => ({ name: t.def.name, description: t.def.description, inputSchema: t.def.schema })) });
    case "tools/call": {
      const t = tools.find((x) => x.def.name === params.name);
      if (!t) return ok({ content: [{ type: "text", text: `Unknown tool ${String(params.name)}.` }], isError: true });
      const input = (params.arguments ?? {}) as Record<string, unknown>;
      try {
        const r = await t.run(input, { root: "", signal: new AbortController().signal, saveNote: () => { throw new Error("not available"); }, readSkill: () => undefined });
        return ok({ content: [{ type: "text", text: r.output }, ...(r.image ? [{ type: "image", data: r.image.data, mimeType: r.image.media_type }] : [])], isError: r.is_error });
      } catch (e) {
        return ok({ content: [{ type: "text", text: e instanceof Error ? e.message : String(e) }], isError: true });
      }
    }
    default:
      return { jsonrpc: "2.0", id, error: { code: -32601, message: `unknown method ${m.method}` } };
  }
}
