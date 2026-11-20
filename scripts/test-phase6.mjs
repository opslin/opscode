// Slice-1 tests: settings fields, memory notes (scope, drafts, prompt injection,
// save_note tool), and MCP servers (stdio + HTTP, listing, approval-gated calls,
// cleanup on shutdown).

import { mkdirSync, mkdtempSync, realpathSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 200);
const MOCK_MCP = join(process.cwd(), "scripts/lib/mock-mcp.mjs");

// ---- mock Anthropic (records requests) + mock HTTP MCP ----------------------------
const llm = { requests: [], script: [] };
const sse = (evs) => evs.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const textEv = (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }];
const toolEv = (id, name, input) => [{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }];
const llmServer = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    llm.requests.push(JSON.parse(b));
    const step = llm.script.shift();
    res.writeHead(200, { "content-type": "text/event-stream" }).end(step?.sse ?? sse(textEv("(no script)")));
  });
});
await new Promise((r) => llmServer.listen(0, "127.0.0.1", r));

const mcpHttp = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    const m = JSON.parse(b);
    if (m.id === undefined) return res.writeHead(202).end();
    const reply = (result) => res.writeHead(200, { "content-type": "application/json", "mcp-session-id": "s1" }).end(JSON.stringify({ jsonrpc: "2.0", id: m.id, result }));
    if (m.method === "initialize") reply({ protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "http-mock" } });
    else if (m.method === "tools/list") reply({ tools: [{ name: "ping", description: "Ping", inputSchema: { type: "object", properties: {} } }] });
    else reply({ content: [{ type: "text", text: "pong over http" }] });
  });
});
await new Promise((r) => mcpHttp.listen(0, "127.0.0.1", r));

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p6-")));
const proj = join(base, "project");
mkdirSync(proj);
const rt = await startRuntime();
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
let mcpPid = null;

try {
  const C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("settings.set", { patch: { default_mode: "supervised" } }); // approval checks (the default is now Auto)
  const run = async (text) => (await C.call("turn.submit", { workspace_id: wid, text })).result.turn_id;
  const system = () => llm.requests.at(-1).system;

  // ---- settings ----------------------------------------------------------------------
  let res = await C.call("settings.set", { patch: { text_size: "large", density: "compact", memory_enabled: true } });
  t.check("new settings accepted", res.result?.settings?.text_size === "large" && res.result.settings.density === "compact", why(res));
  res = await C.call("settings.set", { patch: { text_size: "huge" } });
  t.check("bad text_size refused", code(res) === E.INVALID, why(res));
  res = await C.call("settings.set", { patch: { density: 3 } });
  t.check("bad density refused", code(res) === E.INVALID, why(res));

  // ---- memory CRUD ----------------------------------------------------------------------
  res = await C.call("memory.add", { body: "Use pnpm, never npm.", title: "Tooling", scope: "global" });
  const kept = res.result?.note;
  t.check("memory.add (global) is kept", kept?.state === "kept" && kept.scope === "global" && kept.title === "Tooling", why(res));
  res = await C.call("memory.add", { body: "x", scope: "no-such-workspace" });
  t.check("note for an unknown project -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("memory.add", { body: "   ", scope: "global" });
  t.check("blank note refused", code(res) === E.INVALID, why(res));
  res = await C.call("memory.add", { body: "y".repeat(2500), scope: "global" });
  t.check("overlong note refused", code(res) === E.INVALID, why(res));
  res = await C.call("memory.add", { body: "This project uses tabs.", scope: wid });
  const proj1 = res.result?.note;
  t.check("project-scoped note", proj1?.scope === wid, why(res));

  // The echo engine answers when no provider is set; add one for the prompt tests.
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-1234", base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  llm.script.push({ sse: sse(textEv("ok")) });
  let turn = await run("hello");
  await waitFor(() => finished(turn), 8000);
  t.check("kept notes (global + project) are in the system prompt", system().includes("Tooling: Use pnpm, never npm.") && system().includes("This project uses tabs."), system().slice(-300));

  // drafts, pin, keep-by-editing
  res = await C.call("memory.add", { body: "Agent guess: prefers snake_case.", scope: wid });
  const draftId = res.result.note.id;
  res = await C.call("memory.update", { id: draftId, state: "draft" });
  t.check("note can be set to draft", res.result?.note?.state === "draft", why(res));
  llm.script.push({ sse: sse(textEv("ok")) });
  turn = await run("again");
  await waitFor(() => finished(turn), 8000);
  t.check("draft notes are NOT loaded", !system().includes("snake_case"));
  await C.call("memory.update", { id: draftId, pinned: true });
  llm.script.push({ sse: sse(textEv("ok")) });
  turn = await run("pinned?");
  await waitFor(() => finished(turn), 8000);
  t.check("pinning a draft loads it", system().includes("snake_case"));
  await C.call("memory.update", { id: draftId, pinned: false, state: "draft" });
  res = await C.call("memory.update", { id: draftId, body: "Agent guess: prefers camelCase." });
  t.check("editing a draft keeps it", res.result?.note?.state === "kept" && res.result.note.body.includes("camelCase"), why(res));

  // other-project / unknown id
  res = await C.call("memory.update", { id: "nope", body: "x" });
  t.check("update unknown note -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("memory.delete", { id: "nope" });
  t.check("delete unknown note -> not found", code(res) === E.NOT_FOUND, why(res));

  // ---- save_note tool ---------------------------------------------------------------------
  llm.script.push({ sse: sse(toolEv("tu_n", "save_note", { title: "Style", note: "User prefers 2-space indents." })) });
  llm.script.push({ sse: sse(textEv("Noted.")) });
  turn = await run("I like 2-space indents");
  await waitFor(() => finished(turn), 8000);
  res = await C.call("memory.list");
  const saved = res.result.notes.find((n) => n.title === "Style");
  t.check("save_note stores a draft for this project, without asking", saved?.state === "draft" && saved.scope === wid && !evs(turn).some((e) => e.type === "approval_request"), JSON.stringify(saved));
  t.check("memory.changed is broadcast", C.find("memory.changed", () => true).length > 0);

  // ---- memory off ---------------------------------------------------------------------------
  await C.call("settings.set", { patch: { memory_enabled: false } });
  llm.script.push({ sse: sse(toolEv("tu_n2", "save_note", { note: "should not save" })) });
  llm.script.push({ sse: sse(textEv("ok")) });
  turn = await run("remember something");
  await waitFor(() => finished(turn), 8000);
  t.check("memory off: no notes in the prompt", !llm.requests.at(-2).system.includes("pnpm"));
  t.check("memory off: save_note reports an error", evs(turn).find((e) => e.type === "tool_end")?.is_error === true);
  res = await C.call("memory.list");
  t.check("memory off: nothing was saved", !res.result.notes.some((n) => n.body === "should not save"));
  await C.call("settings.set", { patch: { memory_enabled: true } });

  res = await C.call("memory.delete", { id: kept.id });
  t.check("memory.delete", res.result?.deleted === true, why(res));

  // ---- MCP: validation ----------------------------------------------------------------------------
  res = await C.call("mcp.add", { input: "http://example.com/mcp" });
  t.check("plain-http MCP URL to a remote host refused", code(res) === E.INVALID, why(res));
  res = await C.call("mcp.add", { input: 'node "unclosed' });
  t.check("unclosed quote refused", code(res) === E.INVALID, why(res));

  // ---- MCP: stdio -------------------------------------------------------------------------------------
  res = await C.call("mcp.add", { input: `${process.execPath} ${MOCK_MCP}`, name: "local" });
  const stdioId = res.result?.server?.id;
  t.check("mcp.add (command) returns the server", !!stdioId && res.result.server.transport === "stdio", why(res));
  let local;
  for (let i = 0; i < 100 && local?.state !== "ready"; i++) { await new Promise((r) => setTimeout(r, 50)); local = (await C.call("mcp.list")).result.servers.find((s) => s.id === stdioId); }
  t.check("server becomes ready with its tool", local?.state === "ready" && local.tools[0]?.name === "echo_text", JSON.stringify(local));
  t.check("mcp.changed is broadcast", C.find("mcp.changed", () => true).length > 0);

  llm.script.push({ sse: sse(toolEv("tu_m", "mcp__local__echo_text", { text: "hi mcp" })) });
  llm.script.push({ sse: sse(textEv("done")) });
  turn = await run("use the mcp tool");
  t.check("MCP tool asks for approval", await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000));
  t.check("MCP tool is offered to the model", llm.requests.at(-1).tools.some((x) => x.name === "mcp__local__echo_text"));
  await C.call("turn.approve", { turn_id: turn, call_id: "tu_m", allow: true });
  await waitFor(() => finished(turn), 8000);
  const out = evs(turn).find((e) => e.type === "tool_end")?.output ?? "";
  t.check("MCP tool result comes back", /echo: hi mcp/.test(out), out);
  mcpPid = Number(/pid (\d+)/.exec(out)?.[1]);

  // disable removes the tool
  res = await C.call("mcp.set_enabled", { id: stdioId, enabled: false });
  llm.script.push({ sse: sse(textEv("x")) });
  turn = await run("tools now?");
  await waitFor(() => finished(turn), 8000);
  t.check("disabled server's tools are not offered", !llm.requests.at(-1).tools.some((x) => x.name.startsWith("mcp__local")));
  const dead = (p) => { try { process.kill(p, 0); return false; } catch { return true; } };
  t.check("disabling stops the server process", await waitFor(() => dead(mcpPid), 4000), `pid ${mcpPid}`);

  // a server that fails to start shows an error, not a crash
  res = await C.call("mcp.add", { input: "/definitely/not/a/command", name: "broken" });
  const brokenId = res.result?.server?.id;
  let broken;
  for (let i = 0; i < 100 && broken?.state !== "error"; i++) { await new Promise((r) => setTimeout(r, 50)); broken = (await C.call("mcp.list")).result.servers.find((s) => s.id === brokenId); }
  t.check("a server that can't start shows an error", broken?.state === "error" && /could not start/.test(broken.error ?? ""), JSON.stringify(broken));
  res = await C.call("mcp.remove", { id: brokenId });
  t.check("mcp.remove", res.result?.removed === true, why(res));
  res = await C.call("mcp.remove", { id: brokenId });
  t.check("remove twice -> not found", code(res) === E.NOT_FOUND, why(res));

  // ---- MCP: HTTP ------------------------------------------------------------------------------------------
  res = await C.call("mcp.add", { input: `http://127.0.0.1:${mcpHttp.address().port}/mcp`, name: "web" });
  const httpId = res.result?.server?.id;
  let web;
  for (let i = 0; i < 100 && web?.state !== "ready"; i++) { await new Promise((r) => setTimeout(r, 50)); web = (await C.call("mcp.list")).result.servers.find((s) => s.id === httpId); }
  t.check("HTTP MCP server lists its tool", web?.state === "ready" && web.tools[0]?.name === "ping", JSON.stringify(web));
  llm.script.push({ sse: sse(toolEv("tu_h", "mcp__web__ping", {})) });
  llm.script.push({ sse: sse(textEv("done")) });
  turn = await run("ping it");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000);
  await C.call("turn.approve", { turn_id: turn, call_id: "tu_h", allow: true });
  await waitFor(() => finished(turn), 8000);
  t.check("HTTP MCP tool call works", /pong over http/.test(evs(turn).find((e) => e.type === "tool_end")?.output ?? ""));

  // a live stdio server must die with the runtime
  res = await C.call("mcp.set_enabled", { id: stdioId, enabled: true });
  for (let i = 0; i < 100; i++) { const l = (await C.call("mcp.list")).result.servers.find((s) => s.id === stdioId); if (l?.state === "ready") break; await new Promise((r) => setTimeout(r, 50)); }
  llm.script.push({ sse: sse(toolEv("tu_m2", "mcp__local__echo_text", { text: "pid please" })) });
  llm.script.push({ sse: sse(textEv("done")) });
  turn = await run("get pid");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000);
  await C.call("turn.approve", { turn_id: turn, call_id: "tu_m2", allow: true });
  await waitFor(() => finished(turn), 8000);
  mcpPid = Number(/pid (\d+)/.exec(evs(turn).find((e) => e.type === "tool_end")?.output ?? "")?.[1]);
  t.check("have a live MCP child to check shutdown", Number.isInteger(mcpPid) && !dead(mcpPid), `pid ${mcpPid}`);

  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  const dead = (p) => { try { process.kill(p, 0); return false; } catch { return true; } };
  t.check("shutdown kills MCP child processes", Number.isInteger(mcpPid) && (await waitFor(() => dead(mcpPid), 4000)), `pid ${mcpPid}`);
  llmServer.close();
  mcpHttp.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
