#!/usr/bin/env node
// A stand-in for `codex app-server`: JSON-RPC over stdio. Logs requests to $OPSCODE_FAKE_ENGINE_LOG.
// FAKE_REPORT=<status> answers with a worker report. Prompt "run" asks to run a command (writes from-codex.txt when approved); "hang" never finishes.
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
const log = process.env.OPSCODE_FAKE_ENGINE_LOG;
if (process.argv.includes("--version")) { console.log("codex-cli 9.9.9"); process.exit(0); }
// Accounts: the sign-in lives in the codex home (CODEX_HOME, else OPSCODE_FAKE_DEFAULT_CODEX_HOME for "the Mac's own").
// Without OPSCODE_FAKE_DEFAULT_CODEX_HOME the fake keeps its old behaviour (always signed in, plan team).
// A test completes a browser sign-in by writing fake-login-complete.json there ({email, plan, workspace} or {fail}).
const cHome = process.env.CODEX_HOME || process.env.OPSCODE_FAKE_DEFAULT_CODEX_HOME || null;
const authFile = cHome ? join(cHome, "fake-auth.json") : null;
const doneFile = cHome ? join(cHome, "fake-login-complete.json") : null;
const readAuth = () => { try { return JSON.parse(readFileSync(authFile, "utf8")); } catch { return null; } };
if (process.argv[2] === "logout" && authFile) { try { (await import("node:fs")).rmSync(authFile, { force: true }); } catch {} console.log("Successfully logged out"); process.exit(0); }
if (process.argv[2] === "login" && process.argv[3] === "status") { const a = authFile ? readAuth() : {}; console.log(a ? "Logged in using ChatGPT" : "Not logged in"); process.exit(a ? 0 : 1); }
const out = (m) => process.stdout.write(JSON.stringify({ jsonrpc: "2.0", ...m }) + "\n");
const note = (method, params) => out({ method, params });
const L = (x) => log && appendFileSync(log, JSON.stringify({ bin: "codex", pid: process.pid, ...x }) + "\n");
L({ argv: process.argv.slice(2), cwd: process.cwd(), codex_home: process.env.CODEX_HOME ?? null });
const homeKey = process.env.CODEX_HOME ? basename(process.env.CODEX_HOME) : "default";
// `codex exec` (Opscode's image_generate runs it): the prompt comes in on stdin and the result is JSONL, as the real one.
// OPSCODE_FAKE_IMAGE_FILE = { "<codex home folder name | default>": { mode: ok|credits|limit|auth|crash|refuse|noimage|slow, count, message, ms } }.
if (process.argv[2] === "exec") {
  let prompt = ""; for await (const c of process.stdin) prompt += c;
  const cfg = (() => { try { return JSON.parse(readFileSync(process.env.OPSCODE_FAKE_IMAGE_FILE, "utf8"))[homeKey]; } catch { return null; } })() ?? { mode: "ok" };
  L({ exec: true, key: homeKey, prompt, mode: cfg.mode });
  const ev = (o) => process.stdout.write(JSON.stringify(o) + "\n");
  const thread = `exec-thread-${process.pid}-${Date.now()}`;
  const fail = (msg) => { ev({ type: "error", message: msg }); ev({ type: "turn.failed", error: { message: msg } }); process.exit(1); };
  ev({ type: "thread.started", thread_id: thread }); ev({ type: "turn.started" });
  if (cfg.mode === "credits") fail("Your workspace is out of credits. Add credits to continue.");
  if (cfg.mode === "limit") fail(cfg.message ?? "You've hit your usage limit. Try again in 2 hours 31 minutes.");
  if (cfg.mode === "auth") fail("Not logged in. Please run `codex login`.");
  if (cfg.mode === "crash") fail("The image service returned an unexpected error.");
  if (cfg.mode === "slow") await new Promise((r) => setTimeout(r, Number(cfg.ms ?? 5000)));
  if (cfg.mode === "refuse") { ev({ type: "item.completed", item: { id: "i0", type: "agent_message", text: "I can't create that image." } }); ev({ type: "turn.completed", usage: {} }); process.exit(0); }
  if (cfg.mode !== "noimage") {
    const home = process.env.CODEX_HOME || process.env.OPSCODE_FAKE_DEFAULT_CODEX_HOME;
    const dir = join(home, "generated_images", thread);
    mkdirSync(dir, { recursive: true });
    const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64");
    for (let k = 0; k < (cfg.count ?? 1); k++) writeFileSync(join(dir, `exec-${k}.png`), PNG);
  }
  ev({ type: "item.completed", item: { id: "i1", type: "agent_message", text: "done" } }); ev({ type: "turn.completed", usage: {} });
  process.exit(0);
}
let buf = ""; let srvId = 1000; const waiters = new Map(); let thread = null;
process.stdin.on("data", (d) => {
  buf += d; let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    const m = JSON.parse(line);
    if (m.method) L({ method: m.method, params: m.params });
    if (m.id !== undefined && !m.method) { waiters.get(m.id)?.(m.result); continue; }
    if (m.method === "initialize") out({ id: m.id, result: { userAgent: "fake" } });
    else if (m.method === "account/rateLimits/read") { const s = Math.floor(Date.now() / 1000); out({ id: m.id, result: { rateLimits: { primary: { usedPercent: (() => { try { { const u = JSON.parse(readFileSync(process.env.OPSCODE_FAKE_USAGE_FILE, "utf8")); return u.by_home?.[homeKey]?.codex5h ?? u.codex5h ?? 1; } } catch { return 1; } })(), windowDurationMins: 300, resetsAt: s + 4 * 3600 }, secondary: { usedPercent: 55, windowDurationMins: 10080, resetsAt: s + 2 * 86400 }, planType: "team", rateLimitReachedType: null }, rateLimitResetCredits: { availableCount: 2, credits: [{ id: "c2", resetType: "codexRateLimits", status: "available", grantedAt: s - 86400, expiresAt: s + 29 * 86400, title: "Full reset (Weekly + 5 hr)", description: "Free reset" }, { id: "c1", resetType: "codexRateLimits", status: "available", grantedAt: s - 20 * 86400, expiresAt: s + 9 * 86400, title: "Full reset (Weekly + 5 hr)", description: "Free reset" }, { id: "c0", resetType: "codexRateLimits", status: "used", grantedAt: s - 40 * 86400, expiresAt: s - 10 * 86400, title: "old" }] } } }); }
    else if (m.method === "account/read") {
      const a = authFile ? readAuth() : { plan: "team" };
      out({ id: m.id, result: a ? { account: { type: "chatgpt", email: a.email ?? null, planType: a.plan ?? "team", workspaceName: a.workspace ?? null }, userId: "u1", requiresOpenaiAuth: true } : { account: null, userId: null, requiresOpenaiAuth: true } });
    }
    else if (m.method === "account/login/start" && authFile) {
      const loginId = `login-${Date.now()}`;
      out({ id: m.id, result: { type: "chatgpt", loginId, authUrl: "https://auth.openai.com/oauth/authorize?fake=1" } });
      const t = setInterval(async () => {
        const fs = await import("node:fs");
        if (!fs.existsSync(doneFile)) return;
        let r = {}; try { r = JSON.parse(readFileSync(doneFile, "utf8")); } catch { return; }
        fs.rmSync(doneFile, { force: true }); clearInterval(t);
        if (r.fail) return note("account/login/completed", { loginId, success: false, error: `Login server error: ${r.fail}` });
        mkdirSync(cHome, { recursive: true });
        writeFileSync(authFile, JSON.stringify({ email: r.email, plan: r.plan ?? "plus", workspace: r.workspace }));
        note("account/login/completed", { loginId, success: true, error: null });
      }, 60);
      globalThis.__loginTimer = t; globalThis.__loginId = loginId;
      if (process.env.OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS) setTimeout(() => { if (!existsSync(doneFile)) writeFileSync(doneFile, JSON.stringify({ email: process.env.OPSCODE_FAKE_LOGIN_EMAIL_CODEX ?? "second@chatgpt.example", plan: "pro", workspace: "Personal" })); }, Number(process.env.OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS));
    }
    else if (m.method === "account/login/cancel") { clearInterval(globalThis.__loginTimer); out({ id: m.id, result: { status: "canceled" } }); note("account/login/completed", { loginId: globalThis.__loginId, success: false, error: "Login server error: Login was not completed" }); }
    else if (m.method === "model/list") out({ id: m.id, result: { data: [...(process.env.OPSCODE_FAKE_CODEX_MODELS ?? "").split(",").filter(Boolean).map((x) => ({ id: x, model: x, displayName: x, hidden: false })), { id: "gpt-fake", model: "gpt-fake", displayName: "GPT Fake", hidden: false, supportedReasoningEfforts: [{ reasoningEffort: "low" }, { reasoningEffort: "high" }] }] } });
    if ((m.method === "thread/start" || m.method === "thread/resume") && m.params?.config?.["mcp_servers.opscode_devices"]) dev = m.params.config["mcp_servers.opscode_devices"];
    // The voice agent / a Manager: its own tools over MCP, Codex's other tools switched off.
    if ((m.method === "thread/start" || m.method === "thread/resume") && m.params?.config?.["mcp_servers.opscode_chief"]) {
      chief = m.params.config["mcp_servers.opscode_chief"];
      L({ thread_params: { method: m.method, sandbox: m.params.sandbox, approvalPolicy: m.params.approvalPolicy, features: Object.fromEntries(Object.entries(m.params.config).filter(([k]) => k.startsWith("features.") || k === "web_search")), baseInstructions: m.params.baseInstructions ?? null, mcp: Object.keys(m.params.config).filter((k) => k.startsWith("mcp_servers.")) } });
    }
    if (m.method === "thread/start") { thread = "thread-new-1"; out({ id: m.id, result: { thread: { id: thread } } }); }
    if (m.method === "thread/start") { /* answered above */ }
    else if (m.method === "thread/resume") { thread = m.params.threadId; out({ id: m.id, result: { thread: { id: thread } } }); }
    else if (m.method === "thread/inject_items" && process.env.OPSCODE_FAKE_INJECT_FAIL) out({ id: m.id, error: { code: -32600, message: "Invalid request: unknown variant `thread/inject_items`" } });
    else if (m.method === "turn/start") { out({ id: m.id, result: { turn: { id: "turn-1", status: "inProgress" } } }); void run(m.params); }
    else if (m.method === "turn/interrupt") { out({ id: m.id, result: {} }); note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "interrupted" } }); }
    else if (m.id !== undefined) out({ id: m.id, result: {} });
  }
});
const ask = (method, params) => new Promise((res) => { const id = srvId++; waiters.set(id, res); out({ id, method, params }); });
let dev = null; // Opscode's browser over MCP, from the thread's config
let chief = null; // the voice agent's own tools over MCP (brain mode)
// Brain mode: FAKE_TOOL <name> <json> lines call the agent's tools like Codex would; FAKE_CMD=«cmd» asks to run a command (must be declined).
async function chiefRun(full) {
  if (!chief) return false;
  const post = (id, method, params) => fetch(chief.url, { method: "POST", headers: { ...chief.http_headers, "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id, method, params }) }).then((x) => x.json());
  await post(1, "initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "fake", version: "1" } });
  const calls = [...full.matchAll(/FAKE_TOOL ([a-z_]+) (\{.*\})(?:<\/note>|<\/heard>)?\s*$/gm)];
  let n = 0;
  for (const [, name, json] of calls) {
    const item = { type: "mcpToolCall", id: `mcp-${++n}`, server: "opscode_chief", tool: name, arguments: JSON.parse(json), status: "inProgress" };
    note("item/started", { threadId: thread, turnId: "turn-1", item });
    const r = await post(n + 1, "tools/call", { name, arguments: JSON.parse(json) });
    const t = r.result?.content?.find((c) => c.type === "text")?.text ?? "";
    L({ chief_tool: name, result: t, is_error: r.result?.isError === true });
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...item, status: r.result?.isError ? "failed" : "completed", result: { content: r.result?.content ?? [] } } });
  }
  const cmd = /FAKE_CMD=«([^»]*)»/.exec(full)?.[1];
  if (cmd) {
    const r = await ask("item/commandExecution/requestApproval", { itemId: "cmd-1", command: cmd });
    L({ brain_cmd: cmd, decision: r?.decision ?? null });
  }
  note("item/agentMessage/delta", { threadId: thread, turnId: "turn-1", itemId: "m1", delta: calls.length ? "Chief handled it." : "Chief read the note." });
  note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
  return true;
}
// FAKE_DEVICE <tool> <json> lines: call it like Codex would (an mcpToolCall item around the MCP call).
async function deviceCalls(full) {
  const calls = [...full.matchAll(/FAKE_DEVICE ([a-z_]+) (\{.*\})\s*$/gm)];
  if (!calls.length || !dev) return false;
  let n = 0;
  for (const [, name, json] of calls) {
    const item = { type: "mcpToolCall", id: `mcp-${++n}`, server: "opscode_devices", tool: name, arguments: JSON.parse(json), status: "inProgress" };
    note("item/started", { threadId: thread, turnId: "turn-1", item });
    const r = await fetch(dev.url, { method: "POST", headers: { ...dev.http_headers, "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: n, method: "tools/call", params: { name, arguments: JSON.parse(json) } }) }).then((x) => x.json());
    const t = r.result?.content?.find((c) => c.type === "text")?.text ?? "";
    if (log) appendFileSync(log, JSON.stringify({ bin: "codex", device_tool: name, result: t, is_error: r.result?.isError === true }) + "\n");
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...item, status: r.result?.isError ? "failed" : "completed", result: { content: r.result?.content ?? [] } } });
  }
  note("item/agentMessage/delta", { threadId: thread, turnId: "turn-1", itemId: "m1", delta: "Checked the page." });
  note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
  return true;
}
async function run(p) {
  if (await chiefRun(p.input[0].text)) return;
  if (await deviceCalls(p.input[0].text)) return;
  const text = p.input[0].text.split("\n").pop();
  const delta = (t) => note("item/agentMessage/delta", { threadId: thread, turnId: "turn-1", itemId: "m1", delta: t });
  const imgs = p.input.filter((x) => x.type === "localImage").map((x) => x.path);
  if (process.env.OPSCODE_FAKE_ENGINE_LOG) appendFileSync(process.env.OPSCODE_FAKE_ENGINE_LOG, JSON.stringify({ bin: "codex", turn_input: { images: imgs, model: p.model ?? null, effort: p.effort ?? null, text: p.input[0].text } }) + "\n");
  // FAKE_IMAGE=<path>: like Codex's image tool: an imageGeneration item that takes a moment, saves the file
  // (savedPath), then a file edit, then the report.
  const img = /FAKE_IMAGE=([\w./-]+)/.exec(p.input[0].text);
  if (img) {
    const target = join(process.cwd(), img[1]);
    note("item/started", { threadId: thread, turnId: "turn-1", item: { type: "imageGeneration", id: "ig-1", status: "inProgress", revisedPrompt: "A glossy 3D shopping bag icon, violet #6C63E8, white background, no text" } });
    await new Promise((r) => setTimeout(r, Number(process.env.OPSCODE_FAKE_IMAGE_MS ?? 2500)));
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64"));
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { type: "imageGeneration", id: "ig-1", status: "completed", revisedPrompt: "A glossy 3D shopping bag icon", savedPath: target } });
    note("item/started", { threadId: thread, turnId: "turn-1", item: { type: "fileChange", id: "fc-1", status: "inProgress", changes: [{ path: join(process.cwd(), "assets/manifest.json"), diff: "+1" }] } });
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { type: "fileChange", id: "fc-1", status: "completed", changes: [{ path: join(process.cwd(), "assets/manifest.json"), diff: "+1" }] } });
    await new Promise((r) => setTimeout(r, Number(process.env.OPSCODE_FAKE_IMAGE_MS ?? 2500)));
    delta(`Status: done\nFound: made the shopping bag icon\nCheck: wrote ${img[1]}`);
    note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
    return;
  }
  // FAKE_ASSET=<path>: "make" an image there (a tiny PNG) and report it; FAKE_ASSET_LOST=<path>: report a file that was never saved.
  const made = /FAKE_ASSET=([\w./-]+)/.exec(p.input[0].text);
  const lost = /FAKE_ASSET_LOST=([\w./-]+)/.exec(p.input[0].text);
  if (made || lost) {
    if (made && !p.input[0].text.includes("none of them exists") || (lost && p.input[0].text.includes("none of them exists"))) {
      const target = join(process.cwd(), (made ?? lost)[1]);
      mkdirSync(dirname(target), { recursive: true });
      writeFileSync(target, Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64"));
    }
    delta(`Status: done\nFound: made the asset\nCheck: wrote ${(made ?? lost)[1]}`);
    note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
    return;
  }
  const rep = /FAKE_REPORT=([a-z]+)/.exec(p.input[0].text);
  if (rep) {
    delta(`Status: ${rep[1]}\nFound: codex did it${rep[1] === "question" ? "\nQuestion: blue or green? I recommend blue." : ""}`);
    note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
    return;
  }
  if (text.includes("hang")) { delta("Thinking"); return; }
  // FAKE_CMD=«command»: ask to run exactly this command (like Codex's commandExecution approval) and log the decision.
  const cmdM = /FAKE_CMD=«([^»]*)»/.exec(text);
  // FAKE_CODEX_ASK: Codex's own question tool (request_user_input, a server request), then go on with the answer.
  if (text.includes("FAKE_CODEX_ASK")) {
    const r = await ask("item/tool/requestUserInput", { threadId: thread, turnId: "turn-1", itemId: "ask-cx", isBlocking: true, questions: [{ id: "color", header: "Color", question: "Which color for the button?", isOther: true, options: [{ label: "Blue (Recommended)", description: "Matches the brand" }, { label: "Green", description: "Like the old one" }] }] });
    if (log) appendFileSync(log, JSON.stringify({ bin: "codex", user_input: r }) + "\n");
    delta(`Using ${r?.answers?.color?.answers?.join(", ") || "my own pick"}.`);
    note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
    return;
  }
  // FAKE_CODEX_LIMIT: Codex runs out of its plan limit mid-turn (error, no retry).
  if (text.includes("FAKE_CODEX_LIMIT")) { note("error", { threadId: thread, turnId: "turn-1", willRetry: false, error: { message: "You've hit your usage limit. Upgrade to Pro or try again at 5:00 PM." } }); return; }
  // FAKE_CODEX_PLAN: Codex's own plan (turn/plan/updated), like its update_plan tool.
  if (text.includes("FAKE_CODEX_PLAN")) note("turn/plan/updated", { threadId: thread, turnId: "turn-1", explanation: "Codex plan", plan: [{ step: "Read the cart code", status: "completed" }, { step: "Fix the total", status: "inProgress" }, { step: "Run the tests", status: "pending" }] });
  // FAKE_LIST_PLAN: plans in words only (a numbered list), no task_checkpoint, like a real Codex did.
  if (text.includes("FAKE_LIST_PLAN")) { delta("Here is the plan:\n\n1. **Read** `src/cart.ts`\n   - check total()\n2. Fix total()\n3. Run npm test\n\nTell me to go ahead."); note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } }); return; }
  // FAKE_CODEX_TOOLS: an edit and a passing test run, the way Codex reports them (no approvals).
  if (text.includes("FAKE_CODEX_TOOLS")) {
    const fc = { type: "fileChange", id: "fc-t", status: "inProgress", changes: [{ path: join(process.cwd(), "src/cart.ts"), diff: "-1\n+2" }, { path: join(process.cwd(), "src/cart.test.ts"), diff: "+x" }] };
    note("item/started", { threadId: thread, turnId: "turn-1", item: fc });
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...fc, status: "completed" } });
    const ex = { type: "commandExecution", id: "exec-t", command: '/bin/zsh -lc "npm test"', cwd: process.cwd(), status: "inProgress" };
    note("item/started", { threadId: thread, turnId: "turn-1", item: ex });
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...ex, status: "completed", exitCode: 0, aggregatedOutput: "PASS cart.test.ts\n1 passed" } });
    delta("Fixed and tested.");
  } else if (cmdM) {
    const item = { type: "commandExecution", id: "exec-cmd", command: cmdM[1], cwd: process.cwd(), status: "inProgress" };
    note("item/started", { threadId: thread, turnId: "turn-1", item });
    const r = await ask("item/commandExecution/requestApproval", { threadId: thread, turnId: "turn-1", itemId: "exec-cmd", command: cmdM[1] });
    if (process.env.OPSCODE_FAKE_ENGINE_LOG) appendFileSync(process.env.OPSCODE_FAKE_ENGINE_LOG, JSON.stringify({ bin: "codex", cmd: cmdM[1], decision: r.decision }) + "\n");
    note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...item, status: r.decision === "accept" ? "completed" : "declined", exitCode: 0, aggregatedOutput: "" } });
    delta(`Codex ${r.decision}`);
  } else if (text.includes("run")) {
    delta("Running it. ");
    const item = { type: "commandExecution", id: "exec-1", command: "/bin/zsh -lc \"echo hi > from-codex.txt\"", cwd: process.cwd(), status: "inProgress" };
    note("item/started", { threadId: thread, turnId: "turn-1", item });
    const r = await ask("item/commandExecution/requestApproval", { threadId: thread, turnId: "turn-1", itemId: "exec-1", command: item.command });
    if (r.decision === "accept") { writeFileSync(join(process.cwd(), "from-codex.txt"), "hi\n"); note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...item, status: "completed", exitCode: 0, aggregatedOutput: "" } }); delta("Done."); }
    else { note("item/completed", { threadId: thread, turnId: "turn-1", item: { ...item, status: "declined" } }); delta("Not run."); }
  } else delta(`Codex says: ${text.split("\n").pop()}`);
  note("thread/tokenUsage/updated", { threadId: thread, turnId: "turn-1", tokenUsage: { total: { totalTokens: 130, inputTokens: 120, cachedInputTokens: 100, outputTokens: 10 }, last: { totalTokens: 130 }, modelContextWindow: 400000 } });
  note("turn/completed", { threadId: thread, turn: { id: "turn-1", status: "completed" } });
}
