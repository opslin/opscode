// Phase 5 tests: provider config (keys never leave the runtime), the agent loop
// against a local mock of both provider APIs, tool sandboxing, approvals.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 200);
const KEY = "sk-test-SECRETKEY1234";

// ---- mock provider ------------------------------------------------------------
const mock = { requests: [], script: [] };
const sseA = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const A = {
  text: (s) => [
    { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
    ...s.match(/.{1,6}/gs).map((c) => ({ type: "content_block_delta", index: 0, delta: { type: "text_delta", text: c } })),
    { type: "content_block_stop", index: 0 },
    { type: "message_delta", delta: { stop_reason: "end_turn" } },
  ],
  tool: (id, name, input) => {
    const j = JSON.stringify(input);
    return [
      { type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } },
      { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: j.slice(0, 5) } },
      { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: j.slice(5) } },
      { type: "content_block_stop", index: 0 },
      { type: "message_delta", delta: { stop_reason: "tool_use" } },
    ];
  },
};
const sseO = (chunks) => chunks.map((c) => `data: ${typeof c === "string" ? c : JSON.stringify(c)}\n\n`).join("");
const O = {
  text: (s) => [...s.match(/.{1,6}/gs).map((c) => ({ choices: [{ delta: { content: c } }] })), { choices: [{ delta: {}, finish_reason: "stop" }] }, "[DONE]"],
  tool: (id, name, input) => {
    const j = JSON.stringify(input);
    return [
      { choices: [{ delta: { tool_calls: [{ index: 0, id, function: { name, arguments: j.slice(0, 5) } }] } }] },
      { choices: [{ delta: { tool_calls: [{ index: 0, function: { arguments: j.slice(5) } }] } }] },
      { choices: [{ delta: {}, finish_reason: "tool_calls" }] },
      "[DONE]",
    ];
  },
};

const server = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const rec = { url: req.url, headers: req.headers, body: body ? JSON.parse(body) : null };
    mock.requests.push(rec);
    const step = mock.script.shift();
    if (!step) {
      res.writeHead(500).end("no script");
      return;
    }
    if (step.status) {
      res.writeHead(step.status, { "content-type": "application/json" }).end(JSON.stringify({ error: { message: `${step.message} ${req.headers["x-api-key"] ?? ""}` } }));
      return;
    }
    res.writeHead(200, { "content-type": "text/event-stream" });
    res.end(step.sse);
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const MOCK = `http://127.0.0.1:${server.address().port}`;

// ---- fixture ---------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p5-")));
const proj = join(base, "project");
mkdirSync(proj);
mkdirSync(join(base, "outside"));
writeFileSync(join(proj, "README.md"), "hello from the project\n");
writeFileSync(join(base, "outside", "secret.txt"), "TOP SECRET\n");

const rt = await startRuntime();
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const last = (turn) => evs(turn).at(-1);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;

  async function run(text) {
    const r = await C.call("turn.submit", { workspace_id: wid, text });
    return r.result?.turn_id;
  }

  // ---- provider config ---------------------------------------------------------
  let res = await C.call("provider.list");
  t.check("two providers, none configured", res.result?.providers?.length === 2 && res.result.providers.every((p) => !p.configured && !p.active), why(res));
  res = await C.call("provider.set", { id: "anthropic", api_key: KEY, base_url: "http://example.com" });
  t.check("plain http to a non-local host is refused", code(res) === E.INVALID, why(res));
  res = await C.call("provider.set", { id: "anthropic", api_key: "has space" });
  t.check("key with whitespace is refused", code(res) === E.INVALID, why(res));
  res = await C.call("provider.set", { id: "anthropic", api_key: KEY, base_url: MOCK, model: "test-model" });
  const info = res.result?.providers?.find((p) => p.id === "anthropic");
  t.check("provider.set configures and auto-activates", info?.configured && info.active && info.model === "test-model", why(res));
  t.check("the key is never returned (only last 4)", info?.key_hint === KEY.slice(-4) && !JSON.stringify(res.result).includes(KEY));
  res = await C.call("provider.set", { id: "anthropic", base_url: "https://other.example.com" });
  t.check("changing base URL without re-entering the key is refused", code(res) === E.INVALID, why(res));
  const file = join(rt.stateDir, "providers.json");
  t.check("providers.json is mode 0600", existsSync(file) && (statSync(file).mode & 0o777) === 0o600, existsSync(file) ? (statSync(file).mode & 0o777).toString(8) : "missing");
  res = await C.call("settings.get");
  t.check("settings never contain the key", !JSON.stringify(res.result).includes(KEY));

  // ---- Anthropic: plain reply -----------------------------------------------------
  mock.script.push({ sse: sseA(A.text("Hi there, I can help.")) });
  let turn = await run("hello");
  t.check("engine id reports provider/model", (await C.call("turn.history", { workspace_id: wid })).result && evs(turn).length >= 0);
  t.check("plain reply completes", await waitFor(() => finished(turn), 8000) && last(turn).type === "completed");
  t.check("streamed text assembles", evs(turn).filter((e) => e.type === "delta").map((e) => e.text).join("") === "Hi there, I can help.");
  const req0 = mock.requests.at(-1);
  t.check("request: path, key header, model, tools", req0.url === "/v1/messages" && req0.headers["x-api-key"] === KEY && req0.body.model === "test-model" && ["list_dir", "read_file", "write_file", "run_command", "save_note", "use_skill"].every((n) => req0.body.tools.some((x) => x.name === n)) && req0.body.stream === true, req0.url);
  t.check("started event names the engine", evs(turn)[0].engine === "anthropic/test-model", evs(turn)[0].engine);

  // ---- Anthropic: read tool (no approval) --------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_1", "read_file", { path: "README.md" })) });
  mock.script.push({ sse: sseA(A.text("The README says hello.")) });
  turn = await run("what is in the readme?");
  t.check("tool turn completes", await waitFor(() => finished(turn), 8000) && last(turn).type === "completed", JSON.stringify(last(turn)));
  const ts = evs(turn).find((e) => e.type === "tool_start");
  const te = evs(turn).find((e) => e.type === "tool_end");
  t.check("read_file runs without asking", ts?.tool === "read_file" && !evs(turn).some((e) => e.type === "approval_request") && te?.output.includes("hello from the project") && te.is_error === false, JSON.stringify(te));
  const fed = mock.requests.at(-1).body.messages.at(-1);
  t.check("tool result is fed back to the model", fed.role === "user" && fed.content[0].type === "tool_result" && fed.content[0].tool_use_id === "tu_1" && fed.content[0].content.includes("hello from the project"));
  res = await C.call("turn.history", { workspace_id: wid });
  const parts = res.result.messages.at(-1).parts;
  t.check("history keeps ordered parts (tool then text)", parts?.[0]?.kind === "tool" && parts[0].status === "done" && parts.at(-1).kind === "text", JSON.stringify(parts)?.slice(0, 200));

  // ---- sandbox: path escape --------------------------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_2", "read_file", { path: "../outside/secret.txt" })) });
  mock.script.push({ sse: sseA(A.text("I could not read that.")) });
  turn = await run("read the secret");
  await waitFor(() => finished(turn), 8000);
  const esc = evs(turn).find((e) => e.type === "tool_end");
  t.check("path escape is blocked and reported as an error", esc?.is_error === true && !esc.output.includes("TOP SECRET"), esc?.output);

  // ---- approvals: write allowed -----------------------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_3", "write_file", { path: "notes/new.txt", content: "written by agent\n" })) });
  mock.script.push({ sse: sseA(A.text("Done.")) });
  turn = await run("write a note");
  t.check("write_file asks for approval", await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000));
  t.check("nothing is written before approval", !existsSync(join(proj, "notes/new.txt")));
  res = await C.call("turn.approve", { turn_id: turn, call_id: "tu_3", allow: true });
  t.check("turn.approve resolves", res.result?.resolved === true, why(res));
  t.check("approved turn completes", await waitFor(() => finished(turn), 8000) && last(turn).type === "completed");
  t.check("file written inside the project", existsSync(join(proj, "notes/new.txt")) && readFileSync(join(proj, "notes/new.txt"), "utf8") === "written by agent\n");
  res = await C.call("turn.approve", { turn_id: turn, call_id: "tu_3", allow: true });
  t.check("approving twice -> resolved:false", res.result?.resolved === false, why(res));

  // ---- approvals: denied ------------------------------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_4", "write_file", { path: "denied.txt", content: "no" })) });
  mock.script.push({ sse: sseA(A.text("Understood.")) });
  turn = await run("write denied");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000);
  await C.call("turn.approve", { turn_id: turn, call_id: "tu_4", allow: false });
  t.check("denied turn completes", await waitFor(() => finished(turn), 8000) && last(turn).type === "completed");
  t.check("denied write does not happen", !existsSync(join(proj, "denied.txt")));
  t.check("the model is told it was denied", mock.requests.at(-1).body.messages.at(-1).content[0].content.includes("denied"));
  t.check("denied part is recorded", (await C.call("turn.history", { workspace_id: wid })).result.messages.at(-1).parts[0].status === "denied");

  // ---- run_command ---------------------------------------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_5", "run_command", { command: "echo agent-$((6*7)); echo TOKEN=${ELECTRON_RUN_AS_NODE:-unset}" })) });
  mock.script.push({ sse: sseA(A.text("ran.")) });
  turn = await run("run it");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000);
  await C.call("turn.approve", { turn_id: turn, call_id: "tu_5", allow: true });
  await waitFor(() => finished(turn), 8000);
  const cmd = evs(turn).find((e) => e.type === "tool_end");
  t.check("run_command output + exit code", cmd?.output.includes("exit code 0") && cmd.output.includes("agent-42") && cmd.output.includes("TOKEN=unset"), cmd?.output);

  // ---- interrupt while awaiting approval ------------------------------------------
  mock.script.push({ sse: sseA(A.tool("tu_6", "write_file", { path: "stopped.txt", content: "x" })) });
  turn = await run("write then stop");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000);
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("interrupt while awaiting approval ends the turn", await waitFor(() => finished(turn), 8000) && last(turn).type === "interrupted", JSON.stringify(last(turn)));
  t.check("nothing is written after interrupt", !existsSync(join(proj, "stopped.txt")));
  res = await C.call("turn.history", { workspace_id: wid });
  t.check("interrupted tool is not left 'awaiting'", res.result.messages.at(-1).parts.every((p) => p.kind !== "tool" || (p.status !== "awaiting_approval" && p.status !== "running")));

  // ---- provider errors never leak the key --------------------------------------------
  mock.script.push({ status: 401, message: "invalid x-api-key" });
  turn = await run("will fail");
  t.check("HTTP error -> failed event", await waitFor(() => finished(turn), 8000) && last(turn).type === "failed");
  t.check("error mentions status but not the key", /401/.test(last(turn).error) && !last(turn).error.includes(KEY), last(turn).error);
  res = await C.call("turn.history", { workspace_id: wid });
  t.check("failed reply keeps its error in history", res.result.messages.at(-1).status === "failed" && /401/.test(res.result.messages.at(-1).error ?? ""));

  // ---- OpenAI-compatible --------------------------------------------------------------
  res = await C.call("provider.set", { id: "openai", api_key: KEY + "O", base_url: MOCK, model: "gpt-test" });
  t.check("openai configured but not auto-activated", res.result?.providers?.find((p) => p.id === "openai")?.configured && !res.result.providers.find((p) => p.id === "openai").active, why(res));
  res = await C.call("provider.select", { id: "openai" });
  t.check("provider.select activates it", res.result?.providers?.find((p) => p.id === "openai")?.active === true, why(res));
  mock.script.push({ sse: sseO(O.tool("call_1", "list_dir", { path: "" })) });
  mock.script.push({ sse: sseO(O.text("Found README.md.")) });
  turn = await run("list files");
  t.check("openai tool turn completes", await waitFor(() => finished(turn), 8000) && last(turn).type === "completed", JSON.stringify(last(turn)));
  const oreq = mock.requests.at(-1);
  const oFirst = mock.requests.at(-2);
  t.check("openai request: path, bearer, tool schema", oFirst.url === "/chat/completions" && oFirst.headers.authorization === `Bearer ${KEY}O` && oFirst.body.tools[0].type === "function", oFirst.url);
  t.check("openai tool result goes back as role=tool", oreq.body.messages.at(-1).role === "tool" && oreq.body.messages.at(-1).tool_call_id === "call_1" && oreq.body.messages.at(-1).content.includes("README.md"));
  t.check("openai assistant tool_calls are replayed", oreq.body.messages.at(-2).tool_calls?.[0]?.function?.name === "list_dir");

  // ---- select / remove -------------------------------------------------------------------
  res = await C.call("provider.select", { id: "anthropic" });
  res = await C.call("provider.remove", { id: "anthropic" });
  t.check("removing the active provider falls back to another", res.result?.providers?.find((p) => p.id === "openai")?.active === true, why(res));
  res = await C.call("provider.remove", { id: "openai" });
  t.check("no provider left -> none active", res.result?.providers?.every((p) => !p.active && !p.configured), why(res));
  res = await C.call("provider.select", { id: "openai" });
  t.check("selecting an unconfigured provider is refused", code(res) === E.INVALID, why(res));
  turn = await run("back to stub");
  await waitFor(() => finished(turn), 8000);
  t.check("without a provider the stub engine answers", evs(turn)[0].engine === "echo" && last(turn).type === "completed");
  t.check("removing wiped the key from disk", !readFileSync(join(rt.stateDir, "providers.json"), "utf8").includes(KEY));

  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  server.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}

process.exit(t.finish());
