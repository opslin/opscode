// Device slice D1: the agent's browser. A fake "window" session registers as
// the device host and answers browser ops; the checks cover the runtime side:
// RPCs, the /mcp/devices endpoint (tokens, origins, per-turn life), permission
// modes and approvals, site approval for pages outside this computer, and the
// same tools reaching Claude Code, Codex and the built-in agent.

import { mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p27-")));
const proj = join(base, "web");
mkdirSync(proj, { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const logLines = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));

// ---- mock Anthropic API for the built-in agent ----------------------------------------------
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
    mock.requests.push(body ? JSON.parse(body) : null);
    const step = mock.script.shift();
    if (!step) return res.writeHead(500).end("no script");
    res.writeHead(200, { "content-type": "text/event-stream" }).end(sse(step));
  });
});
await new Promise((r) => api.listen(0, "127.0.0.1", r));

const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const H = await session(rt); // plays Opscode's window (main)
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };

  t.check("no browser before the window registers", (await C.call("devices.status", {})).result?.browser === false);
  t.check("devices.reply from a session that is not the host is ignored", (await C.call("devices.reply", { rid: "x", result: {} })).result?.ok === false);
  t.check("devices.reply rejects unknown keys", !!(await H.call("devices.reply", { rid: "x", nope: 1 })).error);
  await H.call("devices.host.register", {});
  t.check("after register the browser is available", (await C.call("devices.status", {})).result?.browser === true);

  // The fake window answers every browser op and records it.
  const ops = [];
  let seen = 0;
  const answer = setInterval(() => {
    for (const n of H.find("devices.request").slice(seen)) {
      seen++;
      const { rid, op, args } = n.params;
      ops.push({ op, args });
      const result =
        op === "navigate" ? { text: `Loaded "Home" — ${args.url}` }
        : op === "read" ? { text: 'Page: "Home"\n- button "Go" [ref_1]' }
        : op === "screenshot" ? { text: "Screenshot 800x600", image: { media_type: "image/jpeg", data: "/9j/AAAA" } }
        : op === "act" ? { text: `Clicked button "Go" (${args.action} ${args.ref ?? ""}).` }
        : op === "eval" ? { text: "42" }
        : { text: "ok" };
      void H.call("devices.reply", op === "logs" ? { rid, error: "boom from the window" } : { rid, result });
    }
  }, 20);
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const finished = (turnId) => waitFor(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
  const approveWhenAsked = async (turnId, allow, n = 1) => {
    for (let i = 0; i < n; i++) {
      const ev = await waitFor(() => events(turnId).filter((e) => e.type === "approval_request")[i]);
      if (!ev) return null;
      await C.call("turn.approve", { turn_id: turnId, call_id: ev.call_id, allow });
    }
    return events(turnId).filter((e) => e.type === "approval_request");
  };

  // ---- Claude Code, Supervised -----------------------------------------------------------
  const sup = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "supervised" })).result.chat;
  const lines = (...calls) => calls.map(([n, a]) => `FAKE_DEVICE ${n} ${JSON.stringify(a)}`).join("\n");
  let r = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `check the page\n${lines(["browser_navigate", { url: "localhost:5173" }], ["browser_read", {}], ["browser_act", { action: "click", ref: "ref_1" }], ["browser_screenshot", {}])}` })).result;
  const asked = await approveWhenAsked(r.turn_id, true);
  await finished(r.turn_id);
  const argv = logLines().filter((l) => l.bin === "claude" && l.argv?.includes("--input-format")).at(-1)?.argv ?? [];
  const cfgAt = argv.indexOf("--mcp-config");
  const cfg = cfgAt > 0 ? JSON.parse(argv[cfgAt + 1]).mcpServers.opscode_devices : null;
  t.check("Claude Code gets Opscode's browser as an MCP server", cfg?.type === "http" && /\/mcp\/devices$/.test(cfg.url) && /^Bearer [0-9a-f]{48}$/.test(cfg.headers?.Authorization ?? ""), JSON.stringify(cfg));
  t.check("and is told the tools are allowed (Opscode asks, not Claude Code)", argv[argv.indexOf("--allowedTools") + 1] === "mcp__opscode_devices");
  t.check("and gets the browser note in its prompt", (argv[argv.indexOf("--append-system-prompt") + 1] ?? "").includes("browser_navigate"));
  const tools = logLines().find((l) => l.device_tools)?.device_tools ?? [];
  t.check("Supervised lists every browser tool", ["browser_navigate", "browser_read", "browser_find", "browser_act", "browser_screenshot", "browser_logs", "browser_eval", "browser_tabs", "browser_batch"].every((n) => tools.includes(n)), tools.join(","));
  t.check("a local page opens without asking; a click asks once", asked?.length === 1 && asked[0].call_id === "toolu_d3", JSON.stringify(asked?.map((e) => e.call_id)));
  t.check("the approval is on Claude Code's own card (no second card)", !events(r.turn_id).some((e) => e.type === "tool_start" && /^dev-/.test(e.call_id)));
  const nav = ops.find((o) => o.op === "navigate");
  t.check("the window is asked to open http://localhost:5173/ for this project", nav?.args.url === "http://localhost:5173/" && nav.args.workspace_id === wid && nav.args.chat_id === sup.id, JSON.stringify(nav));
  const dev = logLines().filter((l) => l.device_tool);
  t.check("read returns the outline with refs", dev.find((l) => l.device_tool === "browser_read")?.result.includes("[ref_1]"));
  t.check("the click runs after approval", dev.find((l) => l.device_tool === "browser_act")?.result.startsWith("Clicked") && ops.some((o) => o.op === "act" && o.args.ref === "ref_1"));
  t.check("a screenshot comes back as an image for the model", dev.find((l) => l.device_tool === "browser_screenshot")?.image === true);
  const card = events(r.turn_id).find((e) => e.type === "tool_start" && e.call_id === "toolu_d2");
  t.check("cards use Opscode's own words", card?.summary === "Read the page", JSON.stringify(card?.summary));

  const old = cfg.headers.Authorization;
  const post = (headers, body = { jsonrpc: "2.0", id: 1, method: "tools/list" }) => fetch(cfg.url, { method: "POST", headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body) });
  t.check("the token dies with the turn", (await post({ authorization: old })).status === 401);
  t.check("no token -> 401", (await post({})).status === 401);
  t.check("a browser origin -> 403", (await post({ authorization: old, origin: "http://evil.example" })).status === 403);

  // Denied click
  writeFileSync(logFile, "");
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `again\n${lines(["browser_act", { action: "click", ref: "ref_1" }])}` })).result;
  await approveWhenAsked(r.turn_id, false);
  await finished(r.turn_id);
  t.check("a denied click is not run", /denied/.test(logLines().find((l) => l.device_tool === "browser_act")?.result ?? "") && ops.filter((o) => o.op === "act").length === 1);

  // A site outside this computer asks once per chat; denied = not opened.
  writeFileSync(logFile, "");
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `web\n${lines(["browser_navigate", { url: "https://example.com/docs" }])}` })).result;
  const ext = await approveWhenAsked(r.turn_id, false);
  await finished(r.turn_id);
  t.check("opening a site outside this computer asks", ext?.length === 1 && events(r.turn_id).some((e) => e.type === "tool_start" && /example\.com/.test(e.summary)));
  t.check("and when denied the page is not opened", !ops.some((o) => o.op === "navigate" && o.args.url.includes("example.com")));
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `web\n${lines(["browser_navigate", { url: "https://example.com/docs" }], ["browser_navigate", { url: "https://example.com/other" }])}` })).result;
  const ext2 = await approveWhenAsked(r.turn_id, true);
  await finished(r.turn_id);
  t.check("allowed once, the same site opens again without asking", ext2?.length === 1 && ops.filter((o) => o.op === "navigate" && o.args.url.includes("example.com")).length === 2);
  t.check("bad addresses are refused", !!(await (async () => {
    writeFileSync(logFile, "");
    const x = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `x\n${lines(["browser_navigate", { url: "file:///etc/passwd" }])}` })).result;
    await finished(x.turn_id);
    return logLines().find((l) => l.device_tool === "browser_navigate" && l.is_error && /http/.test(l.result));
  })()));
  t.check("a window error reaches the model as a tool error", await (async () => {
    writeFileSync(logFile, "");
    const x = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: `x\n${lines(["browser_logs", { kind: "console" }])}` })).result;
    await finished(x.turn_id);
    return /boom from the window/.test(logLines().find((l) => l.device_tool === "browser_logs")?.result ?? "");
  })());

  // ---- Read only: look, don't touch ------------------------------------------------------
  writeFileSync(logFile, "");
  const ro = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "read" })).result.chat;
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: ro.id, text: `look\n${lines(["browser_navigate", { url: "http://localhost:3000" }], ["browser_act", { action: "click", ref: "ref_1" }])}` })).result;
  await finished(r.turn_id);
  const roTools = logLines().find((l) => l.device_tools)?.device_tools ?? [];
  t.check("Read only offers reading tools only", roTools.includes("browser_read") && roTools.includes("browser_navigate") && !roTools.includes("browser_act") && !roTools.includes("browser_eval") && !roTools.includes("browser_batch"), roTools.join(","));
  t.check("and refuses an action even if asked", /read-only/.test(logLines().find((l) => l.device_tool === "browser_act")?.result ?? ""));
  t.check("but can open a local page", ops.some((o) => o.op === "navigate" && o.args.url === "http://localhost:3000/" && o.args.chat_id === ro.id));

  // ---- Full access: no asking, outside sites too -----------------------------------------
  const full = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "full" })).result.chat;
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: full.id, text: `go\n${lines(["browser_navigate", { url: "https://news.example.org" }], ["browser_eval", { code: "6*7" }])}` })).result;
  await finished(r.turn_id);
  t.check("Full access runs actions and outside sites without asking", !events(r.turn_id).some((e) => e.type === "approval_request") && ops.some((o) => o.op === "eval") && ops.some((o) => o.args.url === "https://news.example.org/"));

  // Batch in Auto edits: one call, several steps, no asking.
  writeFileSync(logFile, "");
  const ae = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "auto_edits" })).result.chat;
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: ae.id, text: `batch\n${lines(["browser_batch", { actions: [{ tool: "browser_navigate", input: { url: "http://localhost:4000" } }, { tool: "browser_act", input: { action: "click", ref: "ref_1" } }, { tool: "browser_screenshot", input: {} }] }])}` })).result;
  await finished(r.turn_id);
  const b = logLines().find((l) => l.device_tool === "browser_batch");
  t.check("Auto edits: a batch runs its steps in order without asking", !events(r.turn_id).some((e) => e.type === "approval_request") && /1\. browser_navigate[\s\S]*2\. browser_act[\s\S]*3\. browser_screenshot/.test(b?.result ?? "") && b?.image === true, b?.result);
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: ae.id, text: `batch\n${lines(["browser_batch", { actions: [{ tool: "browser_navigate", input: { url: "https://elsewhere.example" } }] }])}` })).result;
  await finished(r.turn_id);
  t.check("a batch cannot open an outside site the user has not allowed", /outside this computer/.test(logLines().filter((l) => l.device_tool === "browser_batch").at(-1)?.result ?? "") && !ops.some((o) => o.args.url?.includes("elsewhere")));

  // ---- Codex -----------------------------------------------------------------------------
  writeFileSync(logFile, "");
  const cx = (await C.call("chat.create", { workspace_id: wid, engine: "codex", mode: "auto_edits" })).result.chat;
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: cx.id, text: `look\n${lines(["browser_read", { mode: "text" }])}` })).result;
  await finished(r.turn_id);
  const start = logLines().find((l) => l.bin === "codex" && l.method === "thread/start");
  const cxCfg = start?.params?.config?.["mcp_servers.opscode_devices"];
  t.check("Codex gets the browser in the thread's config", /\/mcp\/devices$/.test(cxCfg?.url ?? "") && /^Bearer /.test(cxCfg?.http_headers?.Authorization ?? ""), JSON.stringify(start?.params?.config));
  t.check("and the browser note in its instructions", (start?.params?.developerInstructions ?? "").includes("browser_navigate"));
  t.check("Codex's browser call runs", logLines().find((l) => l.bin === "codex" && l.device_tool === "browser_read")?.result.includes("[ref_1]") && ops.some((o) => o.op === "read" && o.args.mode === "text" && o.args.chat_id === cx.id));
  const cxCard = events(r.turn_id).find((e) => e.type === "tool_start" && e.call_id === "mcp-1");
  t.check("its card is Opscode's (not a generic MCP card)", cxCard?.tool === "mcp__opscode_devices__browser_read" && cxCard.summary === "Read the page text", JSON.stringify(cxCard));

  // ---- Built-in agent --------------------------------------------------------------------
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-0000", base_url: `http://127.0.0.1:${api.address().port}`, model: "test-model" });
  const ag = (await C.call("chat.create", { workspace_id: wid, engine: "api", mode: "auto_edits" })).result.chat;
  mock.script.push(A.tool("tu_1", "browser_screenshot", {}), A.text("Looks fine."));
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: ag.id, text: "how does it look?" })).result;
  await finished(r.turn_id);
  const first = mock.requests[0];
  t.check("the built-in agent gets the browser tools directly", (first?.tools ?? []).some((x) => x.name === "browser_read") && (first?.tools ?? []).some((x) => x.name === "browser_act"));
  t.check("and the browser note in its system prompt", JSON.stringify(first?.system ?? "").includes("browser_navigate"));
  t.check("and the skill finder, so any model can look for a missing skill", (first?.tools ?? []).some((x) => x.name === "skill_find") && (first?.tools ?? []).some((x) => x.name === "skill_install") && JSON.stringify(first?.system ?? "").includes("skill_find"));
  const second = JSON.stringify(mock.requests[1]?.messages ?? []);
  t.check("its screenshot goes back to the model as an image", second.includes('"type":"image"') && second.includes("/9j/AAAA"));

  // ---- Window gone: no browser tools at all ------------------------------------------------
  H.close();
  clearInterval(answer);
  t.check("when the window's session closes the browser is unavailable", !!(await waitFor(async () => (await C.call("devices.status", {})).result?.browser === false)));
  writeFileSync(logFile, "");
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: sup.id, text: "plain question" })).result;
  await finished(r.turn_id);
  const plain = logLines().filter((l) => l.bin === "claude" && l.argv?.includes("--input-format")).at(-1)?.argv ?? [];
  t.check("and engines start without the browser (only the skill finder remains)", !(plain[plain.indexOf("--append-system-prompt") + 1] ?? "").includes("browser_navigate") && (plain[plain.indexOf("--append-system-prompt") + 1] ?? "").includes("skill_find"));
  C.close();
} finally {
  api.close();
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
