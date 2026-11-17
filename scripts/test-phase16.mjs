// Chief: profiles, notes and wake-ups, the board, worker chats on fake Claude Code / Codex,
// reports, approvals, autonomy (proposed / go-ahead), slots and limits, chat_send/stop,
// quotes, remember, automations, the MCP endpoint's guards, and a Chief on an API key.

import { createServer } from "node:http";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep, waitFor } from "./lib/harness.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res?.error ?? res?.result)?.slice(0, 300);

// ---- mock Anthropic API (for a Chief on an API key) ---------------------------------------------
const mock = { requests: [], script: [] };
const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const A = {
  text: (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }],
  tool: (id, name, input) => [{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }],
};
const api = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    mock.requests.push(JSON.parse(body || "null"));
    const step = mock.script.shift();
    if (!step) return res.writeHead(500).end("no script");
    res.writeHead(200, { "content-type": "text/event-stream" }).end(sse(step));
  });
});
await new Promise((r) => api.listen(0, "127.0.0.1", r));

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p16-")));
const projA = join(base, "shop");
const projB = join(base, "admin");
mkdirSync(projA);
mkdirSync(projB);
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const stateDir = join(base, "state");
const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wa = (await C.call("workspace.add", { path: projA })).result.workspace.id;
  const wb = (await C.call("workspace.add", { path: projB })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });

  // ---- profiles ---------------------------------------------------------------------------------
  let res = await C.call("chief.create", { name: "Boss" });
  const chief = res.result?.chief;
  t.check("chief.create makes a Chief on Claude Code with defaults", chief?.brain.engine === "claude-code" && chief.autonomy === 2 && chief.updates === "results" && chief.worker_access === "edit" && /Crew rules/.test(chief.soul), why(res));
  const cid = chief.id;
  const home = chief.chat_id;
  res = await C.call("chat.list", {});
  const homeMeta = res.result.chats.find((c) => c.id === home);
  t.check("its own chat is marked as a Chief chat with its brain", homeMeta?.chief?.role === "home" && homeMeta.engine === "claude-code" && homeMeta.model === "sonnet" && homeMeta.workspace_id === `chief:${cid}`, why(res));
  res = await C.call("turn.submit", { workspace_id: `chief:${cid}`, chat_id: home, text: "hi" });
  t.check("its chat can't be driven with turn.submit", !!res.error, why(res));
  res = await C.call("chat.delete", { chat_id: home });
  t.check("its chat can't be deleted as a chat", !!res.error, why(res));
  res = await C.call("chief.update", { chief_id: cid, brain: { engine: "codex" } });
  t.check("a Chief can't run on Codex", !!res.error, why(res));
  res = await C.call("chief.update", { chief_id: cid, autonomy: 9 });
  t.check("autonomy is 1-3", !!res.error, why(res));
  res = await C.call("chief.update", { chief_id: cid, project_ids: [wa, wb, "nope"], max_parallel: 2 });
  t.check("chief.update keeps only known projects", res.result?.chief.project_ids.length === 2 && res.result.chief.max_parallel === 2, why(res));

  // ---- helpers ----------------------------------------------------------------------------------
  const homeDone = () => C.find("turn.event", (p) => p.chat_id === home && ["completed", "failed", "interrupted"].includes(p.type)).length;
  const view = async () => (await C.call("chief.get", { chief_id: cid })).result;
  /** Sends a note and waits until the Chief has handled it (and anything queued before it). */
  const note = async (text) => {
    const before = homeDone();
    const r = await C.call("chief.note", { chief_id: cid, text });
    for (const end = Date.now() + 10000; Date.now() < end; await sleep(50)) {
      const v = await view();
      if (homeDone() > before && !v.running && v.queued_notes === 0 && chiefPrompts().some((e) => e.prompt.includes(text.split("\n")[0]))) break;
    }
    return r;
  };
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const toolResults = (name) => entries().filter((e) => e.chief_tool === name);
  const chiefPrompts = () => entries().filter((e) => e.prompt && (e.prompt.includes("<board>")));

  // ---- a note that starts work -------------------------------------------------------------------
  res = await note(`build the login screen\n${tool("chat_start", { title: "Login screen", brief: "Goal: login screen. FAKE_REPORT=review", quotes: ["build the login screen"], project_ids: [wa], engine: "claude-code", tier: "base" })}`);
  t.check("chief.note starts a Chief turn", typeof res.result?.turn_id === "string" && res.result.queued === false, why(res));
  const argv = entries().find((e) => e.argv?.includes("--mcp-config"))?.argv ?? [];
  t.check("the Chief runs Claude Code with its own prompt, no built-in tools, only its MCP tools", argv.includes("--system-prompt") && argv[argv.indexOf("--tools") + 1] === "" && argv.includes("--strict-mcp-config") && argv[argv.indexOf("--allowedTools") + 1] === "mcp__opscode_chief" && argv[argv.indexOf("--model") + 1] === "sonnet", argv.join(" ").slice(0, 300));
  const sys = argv[argv.indexOf("--system-prompt") + 1] ?? "";
  t.check("its prompt has autonomy, updates, soul and projects", /Level 2 of 3/.test(sys) && /Results only/.test(sys) && /Crew rules/.test(sys) && sys.includes(wa) && sys.includes(wb), sys.slice(0, 200));
  t.check("the note reaches it wrapped, with the board", chiefPrompts().some((e) => e.prompt.includes("<note>build the login screen") && e.prompt.includes("<board>")), "");
  t.check("chat_start returns an item and a started chat", /"state":"started"/.test(toolResults("chat_start")[0]?.result ?? "") && /\[\[1\]\]/.test(toolResults("chat_start")[0]?.result ?? ""), toolResults("chat_start")[0]?.result);
  let v = await view();
  let item = v.items[0];
  t.check("the board has the item with its build chat", item?.title === "Login screen" && item.chats.length === 1 && item.chats[0].role === "build" && item.chats[0].workspace_id === wa, why({ result: v }));
  const worker = item.chats[0].chat_id;
  res = await C.call("chat.list", {});
  const wm = res.result.chats.find((c) => c.id === worker);
  t.check("the worker chat is a real chat in the project, engine and tier applied, mode capped by access", wm?.workspace_id === wa && wm.engine === "claude-code" && wm.model === "sonnet" && wm.mode === "auto_edits" && wm.chief?.id === cid && wm.chief.role === "build" && wm.title === "Login screen", why({ result: wm }));
  const workerPrompt = entries().find((e) => e.prompt?.includes("Goal: login screen") && !e.prompt.includes("<board>"))?.prompt ?? "";
  t.check("the worker's brief carries the person's words and the report format", workerPrompt.includes("\"build the login screen\"") && workerPrompt.includes("Status: done | review | question | blocked"), workerPrompt.slice(-200));
  await waitFor(async () => false, 1);
  let ok = await waitFor(() => C.find("turn.event", (p) => p.chat_id === worker && p.type === "completed").length > 0, 8000);
  await sleep(1800);
  v = await view();
  item = v.items[0];
  t.check("a worker's report moves the item to review with its finding", ok && item.state === "review" && /did the work for shop/.test(item.detail ?? "") && item.chats[0].status === "review", why({ result: item }));
  ok = await waitFor(() => chiefPrompts().some((e) => e.prompt.includes("<chat_update") && e.prompt.includes('status="review"') && e.prompt.includes("Branch: work-1")), 6000);
  t.check("the Chief wakes with a chat_update", ok, "");
  const hist = (await C.call("turn.history", { chat_id: home })).result.messages;
  t.check("the update shows in its chat as an update line, not the person's words", hist.some((m) => m.role === "user" && m.event === true && /Update: Login screen/.test(m.text)), JSON.stringify(hist.map((m) => [m.role, m.event, m.text.slice(0, 40)])));
  t.check("MCP tool calls show as Chief tool cards", hist.some((m) => m.parts?.some((p) => p.kind === "tool" && p.summary === "Start work: Login screen")), "");

  // ---- quotes must be verbatim ------------------------------------------------------------------
  // The quote is escaped in the tool line so the note itself does not contain it.
  await note(`make the cart\nFAKE_TOOL chat_start {"title":"Cart","brief":"Goal: cart","quotes":["make the \\u0063art fancy"],"project_ids":["${wa}"]}`);
  t.check("a quote that is not the person's words is refused", toolResults("chat_start").at(-1)?.is_error === true && /word for word/.test(toolResults("chat_start").at(-1)?.result), toolResults("chat_start").at(-1)?.result);

  // ---- remember ---------------------------------------------------------------------------------
  await note(`never use red buttons\n${tool("remember", { text: "Never use red buttons.", quote: "never use red buttons" })}`);
  const notes = (await C.call("memory.list", {})).result?.notes ?? [];
  t.check("remember saves a kept note from the person's words", notes.some((n) => n.body === "Never use red buttons." && n.state === "kept" && n.scope === "global"), why({ result: notes }));
  await note(`use buttons\n${tool("remember", { text: "Never use buttons.", quote: "use buttons" })}`);
  t.check("remember refuses a note that flips the meaning", toolResults("remember").at(-1)?.is_error === true, toolResults("remember").at(-1)?.result);

  // ---- approvals: the worker waits for the person ------------------------------------------------
  await note(`write the file\n${tool("chat_start", { title: "Write file", brief: "FAKE_BASH=«rm -rf old-build»", quotes: [], project_ids: [wa] })}`);
  v = await view();
  item = v.items.find((i) => i.title === "Write file");
  const w2 = item.chats[0].chat_id;
  ok = await waitFor(() => C.find("turn.event", (p) => p.chat_id === w2 && p.type === "approval_request").length > 0, 6000);
  v = await view();
  item = v.items.find((i) => i.title === "Write file");
  t.check("a worker's permission prompt puts the item in Needs you", ok && item.state === "needs_you" && /approval/.test(item.detail ?? ""), why({ result: item }));
  const ap = C.find("turn.event", (p) => p.chat_id === w2 && p.type === "approval_request")[0].params;
  await C.call("turn.approve", { turn_id: ap.turn_id, call_id: ap.call_id, allow: true });
  await waitFor(() => C.find("turn.event", (p) => p.chat_id === w2 && p.type === "completed").length > 0, 6000);
  await sleep(300);
  v = await view();
  item = v.items.find((i) => i.title === "Write file");
  // (In auto edits a worker's file edits run without asking; a deleting command still asks, as here.)
  t.check("after the person approves, a done report finishes the item", item.state === "done", why({ result: item }));

  // ---- a question, asked and answered ------------------------------------------------------------
  await note(`pick colors\n${tool("chat_start", { title: "Colors", brief: "FAKE_REPORT=question", quotes: [], project_ids: [wb], engine: "codex" })}`);
  v = await view();
  item = v.items.find((i) => i.title === "Colors");
  t.check("a Codex worker starts for UI work", item?.chats[0].engine === "codex" && item.chats[0].workspace_id === wb, why({ result: item }));
  await waitFor(() => C.find("turn.event", (p) => p.chat_id === item.chats[0].chat_id && ["completed", "failed"].includes(p.type)).length > 0, 8000);
  await sleep(1800);
  v = await view();
  const colors = v.items.find((i) => i.title === "Colors");
  t.check("a worker's finished turn on Codex is followed too", ["review", "running", "done"].includes(colors.state), why({ result: colors }));
  await note(`ask me\n${tool("ask", { question: "Blue or green?", recommended: "Blue", item_id: `[[${colors.ref}]]`, must_wait: true })}`);
  v = await view();
  let asked = v.items.find((i) => i.title === "Colors");
  t.check("ask puts a question on the item (must_wait: no go-ahead)", asked.state === "needs_you" && asked.ask?.question === "Blue or green?" && !asked.ask.go_ahead_at, why({ result: asked }));
  const before = homeDone();
  res = await C.call("chief.items.answer", { item_id: asked.id, text: "Green" });
  await waitFor(() => homeDone() > before, 6000);
  v = await view();
  asked = v.items.find((i) => i.title === "Colors");
  t.check("answering from the board clears it and sends the Chief a note", !asked.ask && chiefPrompts().some((e) => e.prompt.includes("Blue or green?") && e.prompt.includes("Green")), why(res));

  // ---- go-ahead at level 3 ----------------------------------------------------------------------
  await C.call("chief.update", { chief_id: cid, autonomy: 3 });
  await note(`decide\n${tool("ask", { question: "Ship now?", recommended: "Yes", item_id: `[[${colors.ref}]]` })}`);
  ok = await waitFor(() => chiefPrompts().some((e) => e.prompt.includes("<no_answer") && e.prompt.includes("Ship now?") && e.prompt.includes("Yes")), 25000);
  t.check("level 3: a question without must_wait goes ahead with the recommendation", ok, "");
  t.check("level 3 prompt is used", (entries().filter((e) => e.argv?.includes("--system-prompt")).at(-1)?.argv ?? []).some((a) => /Level 3 of 3/.test(a)), "");

  // ---- level 1: proposals the person starts --------------------------------------------------------
  await C.call("chief.update", { chief_id: cid, autonomy: 1 });
  await note(`both apps\n${tool("chat_start", { title: "Shared header", brief: "FAKE_REPORT=review", quotes: [], project_ids: [wa, wb] })}`);
  v = await view();
  let prop = v.items.find((i) => i.title === "Shared header");
  t.check("level 1: work across two projects is proposed, not started", prop?.state === "proposed" && prop.chats.length === 0 && prop.pending.length === 2, why({ result: prop }));
  res = await C.call("chief.items.start", { item_id: prop.id });
  v = await view();
  prop = v.items.find((i) => i.title === "Shared header");
  t.check("the person starts a proposal from the board", prop.chats.length === 2 && !prop.pending, why(res));
  await waitFor(() => prop.chats.every((c) => C.find("turn.event", (p) => p.chat_id === c.chat_id && p.type === "completed").length > 0), 8000);
  await sleep(400);

  // ---- slots: max_parallel ------------------------------------------------------------------------
  await C.call("chief.update", { chief_id: cid, autonomy: 2, max_parallel: 1 });
  await note(`slow one\n${tool("chat_start", { title: "Slow", brief: "FAKE_HANG", quotes: [], project_ids: [wa] })}`);
  await note(`next one\n${tool("chat_start", { title: "Next", brief: "FAKE_REPORT=review", quotes: [], project_ids: [wb] })}`);
  v = await view();
  const slow = v.items.find((i) => i.title === "Slow");
  let next = v.items.find((i) => i.title === "Next");
  t.check("with every slot busy, new work waits", slow.state === "running" && next.state === "waiting" && next.chats.length === 0 && /slots are busy/.test(toolResults("chat_start").at(-1)?.result), why({ result: [slow.state, next.state] }));

  // chat_send to a busy chat waits for its turn to end
  await note(`tell it\n${tool("chat_send", { chat_id: slow.chats[0].chat_id, text: "Use the small icon." })}`);
  t.check("chat_send to a busy chat is delivered after its current turn", /after_current_turn/.test(toolResults("chat_send").at(-1)?.result), toolResults("chat_send").at(-1)?.result);
  await note(`stop it\n${tool("chat_stop", { chat_id: slow.chats[0].chat_id })}`);
  t.check("chat_stop stops the running turn", /"stopped":true/.test(toolResults("chat_stop").at(-1)?.result), toolResults("chat_stop").at(-1)?.result);
  ok = await waitFor(async () => false, 1);
  ok = await waitFor(() => C.find("turn.event", (p) => p.chat_id === slow.chats[0].chat_id && p.type === "interrupted").length > 0, 5000);
  await sleep(500);
  v = await view();
  next = v.items.find((i) => i.title === "Next");
  t.check("a freed slot starts the waiting work by itself", ok && next.chats.length === 1, why({ result: next }));
  t.check("a stop by the Chief does not wake it, and drops its queued message", !chiefPrompts().some((e) => e.prompt.includes("stopped by the person")) && !entries().some((e) => e.prompt?.includes("Use the small icon") && !e.prompt.includes("<board>")), "");
  await waitFor(() => C.find("turn.event", (p) => p.chat_id === next.chats[0]?.chat_id && p.type === "completed").length > 0, 8000);
  await sleep(300);
  // chat_send to an idle chat runs now
  await note(`more\n${tool("chat_send", { chat_id: next.chats[0].chat_id, text: "Also add a footer. FAKE_REPORT=done" })}`);
  t.check("chat_send to an idle chat starts its next turn now", /"delivered":"now"/.test(toolResults("chat_send").at(-1)?.result) && (await waitFor(() => entries().some((e) => e.prompt?.includes("[Boss] Also add a footer")), 5000)), toolResults("chat_send").at(-1)?.result);
  await sleep(1500);

  // ---- digest, search, queue ----------------------------------------------------------------------
  await note(`status\n${tool("chat_digest", { chat_id: worker })}\n${tool("chat_search", { query: "login screen" })}\n${tool("queue_add", { title: "Dark mode", project_ids: [wa] })}`);
  t.check("chat_digest returns its goal and latest answer", /did the work for shop/.test(toolResults("chat_digest").at(-1)?.result ?? ""), toolResults("chat_digest").at(-1)?.result);
  t.check("chat_search finds a chat by topic", (toolResults("chat_search").at(-1)?.result ?? "").includes(worker), toolResults("chat_search").at(-1)?.result);
  v = await view();
  const dark = v.items.find((i) => i.title === "Dark mode");
  t.check("queue_add puts work on the board, not started", dark?.state === "queued" && dark.chats.length === 0, why({ result: dark }));
  await note(`drop it\n${tool("queue_update", { item_id: `[[${dark.ref}]]`, state: "dropped" })}`);
  v = await view();
  t.check("queue_update drops it off the board", !v.items.some((i) => i.title === "Dark mode"), "");
  res = await C.call("chief.items.update", { item_id: item.id, state: "done", pinned: true });
  t.check("the person can mark an item done from the board", res.result?.item.state === "done" && res.result.item.pinned === true, why(res));

  // ---- the person's chat outside its projects -------------------------------------------------------
  await C.call("chief.update", { chief_id: cid, project_ids: [wb] });
  await note(`poke\n${tool("chat_send", { chat_id: worker, text: "hi" })}\n${tool("chat_start", { title: "X", brief: "x", quotes: [], project_ids: [wa] })}`);
  t.check("a Chief can't start work outside its projects", toolResults("chat_start").at(-1)?.is_error === true, toolResults("chat_start").at(-1)?.result);
  t.check("its own worker chats stay reachable", toolResults("chat_send").at(-1)?.is_error === false, toolResults("chat_send").at(-1)?.result);
  await C.call("chief.update", { chief_id: cid, project_ids: [] });

  // ---- automations -------------------------------------------------------------------------------
  await C.call("automation.file_write", { workspace_id: wa, scope: "project", name: "ship", text: "description: Ship it\ninputs: { what: { description: What, required: true } }\nsteps:\n  go: { run: \"echo shipping {{inputs.what}}\" }\n" });
  await C.call("chief.update", { chief_id: cid, max_parallel: 3 });
  await note(`ship it\n${tool("automation_run", { project_id: wa, name: "ship", inputs: { what: "v1" }, title: "Ship v1" })}`);
  t.check("the Chief sees the project's automations in its prompt", (entries().filter((e) => e.argv?.includes("--system-prompt")).at(-1)?.argv ?? []).some((a) => /ship \[project\] — Ship it \(inputs: what\*\)/.test(a)), "");
  ok = await waitFor(() => chiefPrompts().some((e) => e.prompt.includes("<automation_update") && e.prompt.includes('status="succeeded"')), 10000);
  v = await view();
  const ship = v.items.find((i) => i.title === "Ship v1");
  t.check("automation_run tracks the run on the board and wakes the Chief when it ends", ok && ship?.state === "review" && ship.automation?.status === "succeeded", why({ result: ship }));

  // ---- MCP endpoint guards ------------------------------------------------------------------------
  const url = `http://127.0.0.1:${rt.port}/mcp/chief`;
  const body = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" });
  let r = await fetch(url, { method: "POST", body, headers: { "content-type": "application/json" } });
  t.check("MCP endpoint: no token is 401", r.status === 401, String(r.status));
  r = await fetch(url, { method: "POST", body, headers: { "content-type": "application/json", authorization: `Bearer ${rt.token}` } });
  t.check("MCP endpoint: the session token is not a Chief token", r.status === 401, String(r.status));
  r = await fetch(url, { method: "POST", body, headers: { "content-type": "application/json", origin: "https://evil.example" } });
  t.check("MCP endpoint: browser origins are refused", r.status === 403, String(r.status));
  r = await fetch(url, { method: "GET" });
  t.check("MCP endpoint: GET is 405", r.status === 405, String(r.status));
  const used = entries().filter((e) => e.argv?.includes("--mcp-config")).at(-1).argv;
  const tok = JSON.parse(used[used.indexOf("--mcp-config") + 1]).mcpServers.opscode_chief.headers.Authorization;
  r = await fetch(url, { method: "POST", body, headers: { "content-type": "application/json", authorization: tok } });
  t.check("MCP endpoint: a token stops working when its turn ends", r.status === 401, String(r.status));

  // ---- notes while the Chief is busy are batched -----------------------------------------------------
  const b0 = homeDone();
  const r1 = await C.call("chief.note", { chief_id: cid, text: "first FAKE_TOOL chat_digest {\"chat_id\":\"" + worker + "\"}" });
  const r2 = await C.call("chief.note", { chief_id: cid, text: "second note" });
  t.check("a note while the Chief is busy waits", r1.result?.queued === false && r2.result?.queued === true, why(r2));
  await waitFor(() => homeDone() >= b0 + 2, 8000);
  t.check("then it arrives in the next turn", chiefPrompts().some((e) => e.prompt.includes("<note>second note</note>")), "");

  // ---- a Chief on an API key ------------------------------------------------------------------------
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-KEY123456789", base_url: `http://127.0.0.1:${api.address().port}`, model: "test-model" });
  res = await C.call("chief.create", { name: "Api", brain: { engine: "api" } });
  const c2 = res.result.chief;
  mock.script.push(A.tool("tu1", "queue_add", { title: "From API" }), A.text("Queued [[1]]."));
  const d0 = C.find("turn.event", (p) => p.chat_id === c2.chat_id && p.type === "completed").length;
  await C.call("chief.note", { chief_id: c2.id, text: "remember to do this later" });
  ok = await waitFor(() => C.find("turn.event", (p) => p.chat_id === c2.chat_id && p.type === "completed").length > d0, 6000);
  const v2 = (await C.call("chief.get", { chief_id: c2.id })).result;
  const req0 = mock.requests[0];
  t.check("an API-key Chief gets only its own tools and its prompt", ok && req0?.tools?.map((x) => x.name).sort().join(",") === "ask,automation_run,chat_digest,chat_search,chat_send,chat_start,chat_stop,library_search,queue_add,queue_update,remember" && /You are Api, the Chief in Opscode/.test(JSON.stringify(req0.system)), JSON.stringify(req0?.tools?.map((x) => x.name)));
  t.check("and its tool calls work on its own board", v2.items.some((i) => i.title === "From API" && i.state === "queued") && v2.items[0].ref > 1, why({ result: v2.items }));

  // ---- remove ----------------------------------------------------------------------------------------
  res = await C.call("chief.remove", { chief_id: c2.id });
  const left = (await C.call("chief.list", {})).result.chiefs;
  const chats = (await C.call("chat.list", {})).result.chats;
  t.check("chief.remove deletes the Chief, its board and its chat", res.result?.removed === true && left.length === 1 && !chats.some((c) => c.id === c2.chat_id), why(res));

  // ---- restart: running work is marked as stopped ------------------------------------------------------
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("runtime stops cleanly", exit.startsWith("code=0"), exit);
}
const rt2 = await startRuntime({ env, stateDir, keepState: true });
try {
  const C = await session(rt2);
  const chiefs = (await C.call("chief.list", {})).result.chiefs;
  const v = (await C.call("chief.get", { chief_id: chiefs[0].id })).result;
  t.check("after a restart the board is back and nothing claims to run", v.items.length > 3 && !v.items.some((i) => i.state === "running") && !v.items.some((i) => i.chats.some((c) => c.state === "running")), JSON.stringify(v.items.map((i) => i.state)));
  C.close();
} finally {
  await rt2.stop();
  api.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
