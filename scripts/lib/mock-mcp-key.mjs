// A stdio MCP server that refuses to start without MOCK_KEY=letmein (like a server needing a token).
import { createInterface } from "node:readline";
const rl = createInterface({ input: process.stdin });
const send = (m) => process.stdout.write(JSON.stringify({ jsonrpc: "2.0", ...m }) + "\n");
const ok = process.env.MOCK_KEY === "letmein";
rl.on("line", (line) => {
  const m = JSON.parse(line);
  if (m.method === "initialize") return ok ? send({ id: m.id, result: { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "k", version: "1" } } }) : send({ id: m.id, error: { code: -32000, message: "401 Unauthorized: missing API key" } });
  if (m.method === "tools/list") send({ id: m.id, result: { tools: [{ name: "has_key", description: `PATH set: ${!!process.env.PATH}`, inputSchema: { type: "object", properties: {} } }] } });
  else if (m.id !== undefined) send({ id: m.id, error: { code: -32601, message: "nope" } });
});
