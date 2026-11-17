// Sub-agents: agent files (built-in, personal, project), the run_agent tool, the
// limited toolset a helper gets, approvals, permission modes, limits, interrupt.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 240);

const llm = { requests: [], script: [] };
const sse = (evs) => evs.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const textEv = (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }];
const toolsEv = (calls) => [...calls.flatMap(([id, name, input], index) => [{ type: "content_block_start", index, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index }]), { type: "message_delta", delta: { stop_reason: "tool_use" } }];
const toolEv = (id, name, input) => toolsEv([[id, name, input]]);
const llmServer = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    llm.requests.push(JSON.parse(b));
    const s = llm.script.shift();
    if (s === "hang") { res.writeHead(200, { "content-type": "text/event-stream" }); res.write(": hang\n\n"); return; }
    res.writeHead(200, { "content-type": "text/event-stream" }).end(s ?? sse(textEv("ok")));
  });
});
await new Promise((r) => llmServer.listen(0, "127.0.0.1", r));
const step = (evs) => llm.script.push(sse(evs));
const isChild = (r) => JSON.stringify(r.system).includes("You are the sub-agent");
const toolNames = (r) => (r.tools ?? []).map((x) => x.name).sort();

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p11-")));
const proj = join(base, "project");
mkdirSync(proj);
writeFileSync(join(proj, "README.md"), "hello project");
const outside = join(base, "outside");
mkdirSync(outside);

const stateDir = join(base, "state");
const rt = await startRuntime({ stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-1234", base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  const mkChat = async (mode) => (await C.call("chat.create", { workspace_id: wid, mode })).result.chat;
  const submit = async (chat, text) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text })).result.turn_id;

  // ---- agent files ------------------------------------------------------------------------------
  let res = await C.call("subagent.list");
  t.check("the built-in explorer exists (read access)", res.result?.agents.some((a) => a.name === "explorer" && a.scope === "builtin" && a.access === "read"), why(res));
  res = await C.call("subagent.save", { scope: "user", name: "writer", description: "Writes small files", access: "edit", body: "Write what the task says." });
  t.check("save a personal agent", res.result?.agents.some((a) => a.name === "writer" && a.scope === "user" && a.access === "edit"), why(res));
  t.check("agent file is private (0600) and holds the fields", (statSync(join(stateDir, "agents", "writer.md")).mode & 0o777) === 0o600 && /access: edit/.test(readFileSync(join(stateDir, "agents", "writer.md"), "utf8")));
  res = await C.call("subagent.read", { name: "writer" });
  t.check("read returns the instructions", res.result?.body === "Write what the task says.", why(res));
  for (const [name, params] of [["bad name", { name: "Bad Name" }], ["no description", { description: "" }], ["no body", { body: "  " }], ["bad access", { access: "root" }], ["project without a project", { scope: "project" }]]) {
    res = await C.call("subagent.save", { scope: "user", name: "x1", description: "d", access: "read", body: "b", ...params });
    t.check(`save rejects ${name}`, code(res) === E.INVALID, why(res));
  }
  res = await C.call("subagent.save", { scope: "project", workspace_id: wid, name: "explorer", description: "Project explorer override", access: "read", body: "Look only in src." });
  t.check("a project agent is saved in .opscode/agents", existsSync(join(proj, ".opscode", "agents", "explorer.md")), why(res));
  res = await C.call("subagent.list", { workspace_id: wid });
  t.check("a project agent overrides the built-in of the same name", res.result.agents.find((a) => a.name === "explorer")?.scope === "project");
  res = await C.call("subagent.list");
  t.check("without a project the built-in shows", res.result.agents.find((a) => a.name === "explorer")?.scope === "builtin");
  res = await C.call("subagent.delete", { scope: "project", workspace_id: wid, name: "explorer" });
  t.check("delete the project agent", res.result?.deleted === true && !existsSync(join(proj, ".opscode", "agents", "explorer.md")), why(res));
  res = await C.call("subagent.delete", { scope: "user", name: "nope" });
  t.check("delete of a missing agent is not-found", code(res) === E.NOT_FOUND, why(res));
  mkdirSync(join(outside, "agents"));
  symlinkSync(outside, join(proj, ".opscode-link"));
  rmSync(join(proj, ".opscode"), { recursive: true, force: true });
  symlinkSync(outside, join(proj, ".opscode"));
  res = await C.call("subagent.save", { scope: "project", workspace_id: wid, name: "evil", description: "d", access: "read", body: "b" });
  t.check("a linked .opscode folder is refused", code(res) === E.INVALID && !existsSync(join(outside, "agents", "evil.md")), why(res));
  rmSync(join(proj, ".opscode"), { force: true });
  rmSync(join(proj, ".opscode-link"), { force: true });

  // ---- the main agent is told about them -------------------------------------------------------------
  let chat = await mkChat("supervised");
  let turn = await submit(chat, "hi");
  await waitFor(() => finished(turn), 6000);
  let req = llm.requests.at(-1);
  t.check("run_agent is offered with the catalog in the prompt", toolNames(req).includes("run_agent") && JSON.stringify(req.system).includes("explorer:") && JSON.stringify(req.system).includes("writer:"), toolNames(req).join());

  // ---- a read-only helper -----------------------------------------------------------------------------
  llm.requests.length = 0;
  step(toolEv("c1", "run_agent", { agent: "explorer", task: "What is in the README?" })); // main 1
  step(toolEv("k1", "read_file", { path: "README.md" })); // child 1
  step(textEv("The README says: hello project")); // child 2 (final)
  step(textEv("The explorer found it.")); // main 2
  turn = await submit(chat, "ask the explorer");
  await waitFor(() => finished(turn), 8000);
  const reqs = llm.requests;
  const kid = reqs.filter(isChild);
  t.check("the turn completes", evs(turn).some((e) => e.type === "completed"), evs(turn).find((e) => e.type === "failed")?.error);
  t.check("the helper has its own context: the task is its only message", kid[0] && kid[0].messages.length === 1 && JSON.stringify(kid[0].messages[0]).includes("What is in the README?") && !JSON.stringify(kid[0].messages).includes("ask the explorer"));
  t.check("the helper gets its instructions and no memory of the chat", JSON.stringify(kid[0].system).includes("Find the answer to the task by reading files"));
  t.check("a read helper has only list_dir and read_file (no run_agent, no write, no run)", toolNames(kid[0]).join() === "list_dir,read_file", toolNames(kid[0]).join());
  const mainAfter = reqs.filter((r) => !isChild(r)).at(-1);
  const tr = JSON.stringify(mainAfter.messages.at(-1));
  t.check("only the helper's final report goes back to the main agent", tr.includes("The README says: hello project") && !tr.includes("Let me look"), tr.slice(0, 200));
  t.check("the main agent never sees the helper's file read", !JSON.stringify(mainAfter.messages).includes("tool_use_id\":\"k1"));
  const starts = evs(turn).filter((e) => e.type === "tool_start");
  t.check("cards: the sub-agent call and the helper's own call, named after it", starts.some((e) => e.tool === "run_agent" && e.summary === "Sub-agent explorer") && starts.some((e) => e.call_id === "sa1-k1" && e.summary.startsWith("explorer › ")), JSON.stringify(starts.map((e) => [e.call_id, e.summary])));

  // ---- unknown agent / empty task ---------------------------------------------------------------------
  llm.requests.length = 0;
  step(toolsEv([["u1", "run_agent", { agent: "ghost", task: "x" }], ["u2", "run_agent", { agent: "explorer", task: "  " }]]));
  step(textEv("ok"));
  turn = await submit(chat, "bad calls");
  await waitFor(() => finished(turn), 6000);
  const ends = evs(turn).filter((e) => e.type === "tool_end");
  t.check("unknown agent and empty task are errors the model can read", ends.find((e) => e.call_id === "u1")?.output.includes('No sub-agent named "ghost"') && ends.find((e) => e.call_id === "u2")?.output.includes("Give the sub-agent a task") && ends.every((e) => e.is_error), JSON.stringify(ends.map((e) => e.output)));

  // ---- an editing helper: approvals + modes ------------------------------------------------------------
  llm.requests.length = 0;
  step(toolEv("w1", "run_agent", { agent: "writer", task: "Create notes.txt" }));
  step(toolEv("k1", "write_file", { path: "notes.txt", content: "from helper" }));
  step(textEv("Wrote notes.txt"));
  step(textEv("done"));
  turn = await submit(chat, "have the writer write");
  t.check("the helper's write asks for approval under the same turn", await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === "sa1-k1"), 6000), JSON.stringify(evs(turn).map((e) => e.type)));
  t.check("nothing is written before approval", !existsSync(join(proj, "notes.txt")));
  await C.call("turn.approve", { turn_id: turn, call_id: "sa1-k1", allow: true });
  await waitFor(() => finished(turn), 6000);
  t.check("after approval the file exists", readFileSync(join(proj, "notes.txt"), "utf8") === "from helper");
  t.check("an edit helper has write_file but not run_command", toolNames(llm.requests.find(isChild)).join() === "list_dir,read_file,write_file", toolNames(llm.requests.find(isChild)).join());

  llm.requests.length = 0;
  step(toolEv("w2", "run_agent", { agent: "writer", task: "Create other.txt" }));
  step(toolEv("k1", "write_file", { path: "other.txt", content: "x" }));
  step(textEv("Denied, so I stopped"));
  step(textEv("ok"));
  turn = await submit(chat, "writer again");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 6000);
  const pending = evs(turn).find((e) => e.type === "approval_request");
  await C.call("turn.approve", { turn_id: turn, call_id: pending.call_id, allow: false });
  await waitFor(() => finished(turn), 6000);
  t.check("a denied helper action does not run, and the helper is told", !existsSync(join(proj, "other.txt")) && JSON.stringify(llm.requests.filter(isChild).at(-1).messages).includes("The user denied this action"));

  const ro = await mkChat("read");
  llm.requests.length = 0;
  step(toolEv("r1", "run_agent", { agent: "writer", task: "Create ro.txt" }));
  step(textEv("I can only read here"));
  step(textEv("ok"));
  turn = await submit(ro, "writer in read-only");
  await waitFor(() => finished(turn), 6000);
  t.check("in a read-only chat even an edit helper cannot write", llm.requests.find(isChild) && toolNames(llm.requests.find(isChild)).join() === "list_dir,read_file" && !existsSync(join(proj, "ro.txt")), toolNames(llm.requests.find(isChild) ?? {}).join());
  t.check("run_agent itself is still offered in a read-only chat", toolNames(llm.requests[0]).includes("run_agent"));

  // ---- a full helper in supervised mode gets run_command (still asks) ---------------------------------------------
  await C.call("subagent.save", { scope: "user", name: "runner", description: "Runs commands", access: "full", body: "Run what is asked." });
  llm.requests.length = 0;
  step(toolEv("f1", "run_agent", { agent: "runner", task: "echo" }));
  step(textEv("nothing to run"));
  step(textEv("ok"));
  turn = await submit(chat, "runner");
  await waitFor(() => finished(turn), 6000);
  t.check("a full helper may have run_command (never MCP, computer, notes or skills)", toolNames(llm.requests.find(isChild)).join() === "list_dir,read_file,run_command,write_file", toolNames(llm.requests.find(isChild)).join());

  // ---- limit per message -----------------------------------------------------------------------------------
  llm.requests.length = 0;
  step(toolsEv(Array.from({ length: 9 }, (_, i) => [`m${i}`, "run_agent", { agent: "explorer", task: `job ${i}` }])));
  for (let i = 0; i < 8; i++) step(textEv(`report ${i}`));
  step(textEv("all done"));
  turn = await submit(chat, "nine helpers");
  await waitFor(() => finished(turn), 10000);
  const e9 = evs(turn).filter((e) => e.type === "tool_end");
  t.check("at most 8 helper runs per message; the 9th is refused", llm.requests.filter(isChild).length === 8 && e9.find((e) => e.call_id === "m8")?.output.includes("At most 8"), `${llm.requests.filter(isChild).length} runs`);

  // ---- interrupt while a helper works ---------------------------------------------------------------------------
  llm.requests.length = 0;
  step(toolEv("h1", "run_agent", { agent: "explorer", task: "slow" }));
  llm.script.push("hang");
  turn = await submit(chat, "slow helper");
  await waitFor(() => llm.requests.some(isChild), 6000);
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("interrupting stops the helper too", await waitFor(() => evs(turn).some((e) => e.type === "interrupted"), 6000));
  t.check("the chat can be used again", (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: "again" })).result?.turn_id !== undefined);
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  llmServer.closeAllConnections?.();
  llmServer.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
