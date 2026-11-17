// A minimal stdio MCP server for tests: one tool, "echo_text".
import { createInterface } from "node:readline";
const rl = createInterface({ input: process.stdin });
const send = (m) => process.stdout.write(JSON.stringify({ jsonrpc: "2.0", ...m }) + "\n");
rl.on("line", (line) => {
  const m = JSON.parse(line);
  if (m.method === "initialize") send({ id: m.id, result: { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "mock", version: "1" } } });
  else if (m.method === "tools/list") send({ id: m.id, result: { tools: [{ name: "echo_text", description: "Echo the text back", inputSchema: { type: "object", properties: { text: { type: "string" } }, required: ["text"] } }] } });
  else if (m.method === "tools/call") send({ id: m.id, result: { content: [{ type: "text", text: `echo: ${m.params.arguments.text} (pid ${process.pid})` }] } });
  else if (m.id !== undefined) send({ id: m.id, error: { code: -32601, message: "nope" } });
});
