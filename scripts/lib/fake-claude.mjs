#!/usr/bin/env node
// A stand-in for `claude -p --input-format stream-json --output-format stream-json`.
// Logs its argv/cwd to $OPSCODE_FAKE_ENGINE_LOG. Behaviour by marker words in the prompt:
// FAKE_WRITE (asks to write a file), FAKE_HANG, FAKE_FAIL, FAKE_DECIDE=<word> (ends with "decision: <word>").
// As a reviewer ("decision: <approve | request_changes>" asked): approves when the report contains REVIEW_OK.
// A retry (the prompt says the last attempt did not pass) reports REVIEW_OK.
// As a Chief (--mcp-config given): each line `FAKE_TOOL <name> <json args>` in the prompt calls that tool over MCP.
// FAKE_REPORT=<status> answers with a worker report ("Status: <status>").
import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const log = process.env.OPSCODE_FAKE_ENGINE_LOG;
if (process.argv.includes("--version")) { console.log("9.9.9 (Claude Code)"); process.exit(0); }
if (log) appendFileSync(log, JSON.stringify({ bin: "claude", argv: process.argv.slice(2), cwd: process.cwd(), config_dir: process.env.CLAUDE_CONFIG_DIR ?? null }) + "\n");
// Accounts: `claude auth status | login | logout`, with the sign-in kept in the config folder (CLAUDE_CONFIG_DIR, else
// OPSCODE_FAKE_DEFAULT_HOME for "the Mac's own"). A test completes a browser sign-in by writing fake-login-complete.json
// there ({email, plan, org}, or {fail: "message"}); a pasted code on stdin also completes it (as $OPSCODE_FAKE_LOGIN_EMAIL).
if (process.argv[2] === "auth") {
  const { existsSync, mkdirSync, rmSync } = await import("node:fs");
  const home = process.env.CLAUDE_CONFIG_DIR || process.env.OPSCODE_FAKE_DEFAULT_HOME || join(process.env.HOME ?? ".", ".claude-fake");
  mkdirSync(home, { recursive: true });
  const authFile = join(home, "fake-auth.json");
  const doneFile = join(home, "fake-login-complete.json");
  const sub = process.argv[3];
  const read = () => { try { return JSON.parse(readFileSync(authFile, "utf8")); } catch { return null; } };
  if (sub === "status") {
    const a = read();
    console.log(JSON.stringify(a ? { loggedIn: true, authMethod: a.method ?? "claude.ai", apiProvider: "firstParty", configDirectory: home, loginExpiresAt: "2099-01-01T00:00:00.000Z", email: a.email, orgName: a.org ?? `${a.email}'s Organization`, subscriptionType: a.plan ?? "pro" } : { loggedIn: false, authMethod: "none", apiProvider: "firstParty", configDirectory: home }, null, 2));
    process.exit(a ? 0 : 1);
  }
  if (sub === "logout") { rmSync(authFile, { force: true }); console.log("Successfully logged out"); process.exit(0); }
  if (sub === "login") {
    const flag = process.argv.includes("--console") ? "console" : process.argv.includes("--sso") ? "sso" : "claude.ai";
    const ei = process.argv.indexOf("--email");
    console.log("Opening browser to sign in…");
    console.log(`If the browser didn't open, visit: https://claude.com/cai/oauth/authorize?fake=1&method=${flag}${ei > 0 ? "&login_hint=given" : ""}`);
    process.stdout.write("Paste code here if prompted > ");
    const finish = (who) => { writeFileSync(authFile, JSON.stringify({ email: who.email, plan: who.plan ?? "pro", org: who.org, method: flag })); console.log("\nLogin successful."); process.exit(0); };
    process.stdin.on("data", (d) => { if (String(d).trim()) finish({ email: process.env.OPSCODE_FAKE_LOGIN_EMAIL ?? "pasted@example.com" }); });
    // The smoke has no one to finish the browser step: OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS completes it by itself.
    if (process.env.OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS) setTimeout(() => finish({ email: process.env.OPSCODE_FAKE_LOGIN_EMAIL ?? "work@example.com", plan: "team", org: "Work Org" }), Number(process.env.OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS));
    const t = setInterval(() => {
      if (!existsSync(doneFile)) return;
      let r = {}; try { r = JSON.parse(readFileSync(doneFile, "utf8")); } catch { return; }
      rmSync(doneFile, { force: true });
      if (r.fail) { console.log(`\nLogin failed: ${r.fail}`); process.exit(1); }
      clearInterval(t); finish(r);
    }, 60);
    process.on("SIGTERM", () => process.exit(143));
    await new Promise(() => {});
  }
  process.exit(2);
}
// One-shot probe (claude -p "<prompt>" --output-format json): reports how big the first request was. Each
// lean flag removes something from it, like the real thing.
if (process.argv.includes("--output-format") && process.argv[process.argv.indexOf("--output-format") + 1] === "json" && !process.argv.includes("--input-format")) {
  let n = 60_000;
  if (process.argv.includes("--strict-mcp-config")) n -= 8_000;
  if (process.argv.includes("--disable-slash-commands")) n -= 9_000;
  if (process.argv.includes("--setting-sources")) n -= 14_000;
  console.log(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "ok", usage: { input_tokens: 3, cache_creation_input_tokens: n, cache_read_input_tokens: 0, output_tokens: 4 } }));
  process.exit(0);
}
const out = (m) => process.stdout.write(JSON.stringify(m) + "\n");
const resumeAt = process.argv.indexOf("--resume");
const session = resumeAt > 0 ? process.argv[resumeAt + 1] : "sess-claude-1";
let buf = "";
const waiters = new Map();
process.stdin.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    const m = JSON.parse(line);
    if (m.type === "user") {
      const c = m.message.content;
      const imgs = Array.isArray(c) ? c.filter((b) => b.type === "image") : [];
      if (log && imgs.length) appendFileSync(log, JSON.stringify({ bin: "claude", user_images: imgs.map((b) => `${b.source?.media_type}:${String(b.source?.data ?? "").length}`) }) + "\n");
      void turn(typeof c === "string" ? c : (c.find((b) => b.type === "text")?.text ?? ""));
    }
    if (m.type === "control_response") waiters.get(m.response.request_id)?.(m.response.response);
    // Plan limits: answer initialize and get_usage like Claude Code (Pro, 5 hours 15% used, week 43%).
    if (m.type === "control_request" && m.request?.subtype === "initialize") out({ type: "control_response", response: { subtype: "success", request_id: m.request_id, response: { commands: [] } } });
    if (m.type === "control_request" && m.request?.subtype === "get_usage") {
      if (log) appendFileSync(log, JSON.stringify({ bin: "claude", get_usage: true }) + "\n");
      const inH = (h) => new Date(Date.now() + h * 3600_000).toISOString();
      // OPSCODE_FAKE_USAGE_FILE: {"claude5h": 93, "resetInS": 3, "opus": 95} overrides the numbers (read on every check).
      let f = {};
      try { if (process.env.OPSCODE_FAKE_USAGE_FILE) f = JSON.parse(readFileSync(process.env.OPSCODE_FAKE_USAGE_FILE, "utf8")); } catch { /* defaults */ }
      const reset5h = f.resetInS !== undefined ? new Date(Date.now() + f.resetInS * 1000).toISOString() : inH(2.5);
      out({ type: "control_response", response: { subtype: "success", request_id: m.request_id, response: { subscription_type: "pro", rate_limits_available: true, rate_limits: { five_hour: { utilization: f.claude5h ?? 15, resets_at: reset5h }, seven_day: { utilization: 43, resets_at: inH(57) }, seven_day_opus: f.opus !== undefined ? { utilization: f.opus, resets_at: inH(57) } : null, extra_usage: { is_enabled: false }, model_scoped: [{ display_name: "Fable", utilization: 7, resets_at: inH(57) }] } } } });
    }
  }
});
const text = (t) => { out({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: t } }, parent_tool_use_id: null, session_id: session }); out({ type: "assistant", message: { content: [{ type: "text", text: t }] }, parent_tool_use_id: null, session_id: session }); };
let bigCtx = false; // FAKE_BIG_CTX in a prompt: this chat reports 160k tokens of history from now on
const result = (extra = {}) => out({ type: "result", subtype: "success", is_error: false, result: "ok", session_id: session, usage: { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: bigCtx ? 160000 : 100, cache_creation_input_tokens: 20, iterations: [{ input_tokens: 3, output_tokens: 5, cache_read_input_tokens: bigCtx ? 160000 : 100, cache_creation_input_tokens: 20 }] }, modelUsage: { "claude-sonnet-5-5": { inputTokens: 10, outputTokens: 5, contextWindow: 1000000 } }, ...extra });
const mcpAt = process.argv.indexOf("--mcp-config");
// opscode_devices (the browser) is any chat's; any other server makes this a Chief.
const mcpServers = mcpAt > 0 ? JSON.parse(process.argv[mcpAt + 1]).mcpServers : {};
const mcpName = Object.keys(mcpServers).find((k) => k !== "opscode_devices") ?? "";
const mcp = mcpName ? mcpServers[mcpName] : null;
const dev = mcpServers.opscode_devices ?? null;
async function mcpCall(method, params, id = 1, server = mcp) {
  const r = await fetch(server.url, { method: "POST", headers: { ...server.headers, "content-type": "application/json", accept: "application/json, text/event-stream" }, body: JSON.stringify({ jsonrpc: "2.0", id, method, params }) });
  return r.status === 200 ? (await r.json()).result : { status: r.status };
}
// FAKE_DEVICE <tool> <json args> lines: call Opscode's browser tools like Claude Code would (card first, then MCP).
async function deviceCalls(prompt) {
  const calls = [...prompt.matchAll(/FAKE_DEVICE ([a-z_]+) (\{.*\})\s*$/gm)];
  if (!calls.length) return false;
  if (!dev) { text("no device tools"); result(); return true; }
  const list = await mcpCall("tools/list", {}, 900, dev);
  if (log) appendFileSync(log, JSON.stringify({ bin: "claude", device_tools: (list?.tools ?? []).map((t) => t.name) }) + "\n");
  let n = 0;
  for (const [, name, json] of calls) {
    const id = `toolu_d${++n}`;
    out({ type: "assistant", message: { content: [{ type: "tool_use", id, name: `mcp__opscode_devices__${name}`, input: JSON.parse(json) }] }, parent_tool_use_id: null, session_id: session });
    const r = await mcpCall("tools/call", { name, arguments: JSON.parse(json) }, 900 + n, dev);
    const t = r?.content?.find((c) => c.type === "text")?.text ?? JSON.stringify(r);
    if (log) appendFileSync(log, JSON.stringify({ bin: "claude", device_tool: name, result: t, is_error: r?.isError === true, image: r?.content?.some((c) => c.type === "image") ?? false }) + "\n");
    out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: id, content: t, is_error: r?.isError === true }] }, session_id: session });
  }
  text("Checked the page.");
  result();
  return true;
}
async function chiefTurn(prompt) {
  await mcpCall("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "fake", version: "1" } });
  const calls = [...prompt.matchAll(/FAKE_TOOL ([a-z_]+) (\{.*\})(?:<\/note>|<\/heard>)?\s*$/gm)];
  let n = 0;
  for (const [, name, json] of calls) {
    const id = `toolu_c${++n}`;
    const full = `mcp__${mcpName}__${name}`;
    out({ type: "assistant", message: { content: [{ type: "tool_use", id, name: full, input: JSON.parse(json) }] }, parent_tool_use_id: null, session_id: session });
    const r = await mcpCall("tools/call", { name, arguments: JSON.parse(json) }, n + 1);
    const text = r?.content?.[0]?.text ?? JSON.stringify(r);
    if (log) appendFileSync(log, JSON.stringify({ bin: "claude", chief_tool: name, result: text, is_error: r?.isError === true }) + "\n");
    out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: id, content: text, is_error: r?.isError === true }] }, session_id: session });
  }
  text(calls.length ? "Chief handled it." : prompt.includes("<chat_update") || prompt.includes("<no_answer") || prompt.includes("<automation_update") ? "" : "Chief read the note.");
  result();
}
async function turn(prompt) {
  if (prompt.includes("FAKE_BIG_CTX")) bigCtx = true;
  out({ type: "system", subtype: "init", session_id: session, cwd: process.cwd(), tools: mcp ? [`mcp__${mcpName}__chat_start`] : ["Write"], mcp_servers: mcp ? [{ name: mcpName, status: "connected" }] : [{ name: "fake-docs", status: "connected" }] });
  if (log) appendFileSync(log, JSON.stringify({ bin: "claude", prompt }) + "\n");
  if (mcp) return chiefTurn(prompt);
  if (await deviceCalls(prompt)) return;
  const rep = /FAKE_REPORT=([a-z]+)/.exec(prompt);
  if (rep && !prompt.includes("FAKE_WRITE")) { text(`Status: ${rep[1]}\nFound: did the work for ${process.cwd().split("/").pop()}${rep[1] === "question" ? "\nQuestion: blue or green? I recommend blue." : ""}${prompt.includes("FAKE_CHECK") ? "\nCheck: ran npm test, green" : ""}\nBranch: work-1`); result(); return; }
  if (prompt.includes("FAKE_HANG")) { text("Working on it"); return; }
  // FAKE_LIMIT: the plan limit runs out mid-turn, the way Claude Code reports it (rate_limit_event rejected + error result).
  if (prompt.includes("FAKE_LIMIT")) {
    out({ type: "assistant", message: { content: [{ type: "tool_use", id: "lim1", name: "Edit", input: { file_path: join(process.cwd(), "src/half.ts"), old_string: "a", new_string: "b" } }] }, parent_tool_use_id: null, session_id: session });
    out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "lim1", content: "The file has been updated." }] }, session_id: session });
    out({ type: "rate_limit_event", rate_limit_info: { rateLimitType: "five_hour", utilization: 1, resetsAt: Math.floor(Date.now() / 1000) + 3600, status: "rejected" }, session_id: session });
    out({ type: "result", subtype: "error_during_execution", is_error: true, result: `Claude AI usage limit reached|${Math.floor(Date.now() / 1000) + 3600}`, session_id: session, usage: {} });
    return;
  }
  // FAKE_TODO: Claude Code's own to-do list (TodoWrite), when its build has one.
  if (prompt.includes("FAKE_TODO")) {
    out({ type: "assistant", message: { content: [{ type: "tool_use", id: "todo1", name: "TodoWrite", input: { todos: [{ content: "Plan the API", status: "completed", activeForm: "Planning" }, { content: "Write the API", status: "in_progress", activeForm: "Writing" }] } }] }, parent_tool_use_id: null, session_id: session });
    out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "todo1", content: "Todos updated" }] }, session_id: session });
    text("Planned."); result(); return;
  }
  // FAKE_TOOLS: read, edit, a failing test and a command with a token in it, the way Claude Code reports tools
  // (no approvals: cards from tool_use, ends from tool_result). FAKE_TOOLS_HANG then starts a build and never finishes.
  if (prompt.includes("FAKE_TOOLS")) {
    const use = (id, name, input) => out({ type: "assistant", message: { content: [{ type: "tool_use", id, name, input }] }, parent_tool_use_id: null, session_id: session });
    const res = (id, content, is_error = false) => out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: id, content, is_error }] }, session_id: session });
    const f = join(process.cwd(), "src/cart.ts");
    use("t1", "Read", { file_path: f }); res("t1", "export const total = 1;");
    use("t2", "Edit", { file_path: f, old_string: "1", new_string: "2" }); res("t2", "The file has been updated.");
    use("t3", "Bash", { command: "npm test" }); res("t3", "Exit code 1\nFAIL cart.test.ts\n  total is wrong\nANTHROPIC_API_KEY=sk-ant-abcdefghijklmnop1234", true);
    use("t4", "Bash", { command: 'curl -s -H "Authorization: Bearer abcdefgh12345678" https://api.x/y' }); res("t4", "{\"ok\":true}");
    if (prompt.includes("FAKE_TOOLS_HANG")) { use("t5", "Bash", { command: "npm run build" }); text("Building"); return; }
    text("Tools done. The test still fails.");
    result();
    return;
  }
  if (prompt.includes("FAKE_AUTH_FAIL")) { out({ type: "result", subtype: "error_during_execution", is_error: true, result: "Not logged in · Please run /login", session_id: session, usage: {} }); process.exit(1); }
  if (prompt.includes("FAKE_FAIL")) { out({ type: "result", subtype: "error_during_execution", is_error: true, result: "it broke", session_id: session, usage: {} }); process.exit(1); }
  // FAKE_BASH=<command>: ask to run a shell command the way Claude Code does (can_use_tool), report what came back.
  const bash = /FAKE_BASH=«([^»]*)»/.exec(prompt);
  if (bash) {
    out({ type: "assistant", message: { content: [{ type: "tool_use", id: "toolu_b", name: "Bash", input: { command: bash[1] } }] }, parent_tool_use_id: null, session_id: session });
    out({ type: "control_request", request_id: "req-b", request: { subtype: "can_use_tool", tool_name: "Bash", input: { command: bash[1] }, tool_use_id: "toolu_b" } });
    const r = await new Promise((res) => waiters.set("req-b", res));
    if (log) appendFileSync(log, JSON.stringify({ bin: "claude", bash: bash[1], behavior: r.behavior, message: r.message ?? null }) + "\n");
    out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "toolu_b", content: r.behavior === "allow" ? "ran" : r.message, is_error: r.behavior !== "allow" }] }, session_id: session });
    text(`Bash ${r.behavior}`);
    result();
    return;
  }
  if (prompt.includes("FAKE_WRITE")) {
    text("I'll write it. ");
    const path = join(process.cwd(), "from-claude.txt");
    out({ type: "assistant", message: { content: [{ type: "tool_use", id: "toolu_1", name: "Write", input: { file_path: path, content: "hello from claude\n" } }] }, parent_tool_use_id: null, session_id: session });
    out({ type: "control_request", request_id: "req-1", request: { subtype: "can_use_tool", tool_name: "Write", input: { file_path: path, content: "hello from claude\n" }, tool_use_id: "toolu_1" } });
    const r = await new Promise((res) => waiters.set("req-1", res));
    if (r.behavior === "allow") { writeFileSync(path, r.updatedInput.content); out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "toolu_1", content: `File created successfully at: ${path}` }] }, session_id: session }); text(/FAKE_REPORT=([a-z]+)/.test(prompt) ? `Status: ${/FAKE_REPORT=([a-z]+)/.exec(prompt)[1]}\nFound: wrote the file` : "Done."); }
    else { out({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "toolu_1", content: r.message, is_error: true }] }, session_id: session }); text("You said no, so I stopped."); }
    result();
    return;
  }
  if (prompt.includes("decision: <approve | request_changes>")) { text(prompt.includes("REVIEW_OK") ? "Looks right.\ndecision: approve" : "Missing the main part.\ndecision: request_changes"); result(); return; }
  if (prompt.includes("did not pass its checks")) { text("Fixed it. REVIEW_OK"); result(); return; }
  const d = /FAKE_DECIDE=([a-z_]+)/.exec(prompt);
  text(`Claude says: ${prompt.split("\n").pop()}${d ? `\ndecision: ${d[1]}` : ""}`);
  result();
}
