// Engines: Claude Code and Codex as chat engines (fake CLIs that speak the same
// protocols). Detection, models, per-chat engine/model/effort, permission-mode
// mapping, approvals, sessions resumed, usage, switching engines, interrupt, errors.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor, sleep } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, CONFLICT: -32009 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 260);
const FAKE_CLAUDE = join(process.cwd(), "scripts/lib/fake-claude.mjs");
const FAKE_CODEX = join(process.cwd(), "scripts/lib/fake-codex.mjs");

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p13-")));
const proj = join(base, "project");
mkdirSync(proj);
const logFile = join(base, "engines.log");
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const clear = () => writeFileSync(logFile, "");
const lastArgv = (bin) => entries().filter((e) => e.bin === bin && e.argv).at(-1);
const flag = (argv, f) => { const i = argv.indexOf(f); return i < 0 ? undefined : argv[i + 1]; };
const env = { OPSCODE_CLAUDE_BIN: FAKE_CLAUDE, OPSCODE_CODEX_BIN: FAKE_CODEX, OPSCODE_FAKE_ENGINE_LOG: logFile };
const stateDir = join(base, "state");
let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const text = (turn) => evs(turn).filter((e) => e.type === "delta").map((e) => e.text).join("");
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const submit = async (chat, txt) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: txt })).result.turn_id;
  const meta = async (id) => (await C.call("chat.list", {})).result.chats.find((c) => c.id === id);
  const run = async (chat, txt, ms = 8000) => { const turn = await submit(chat, txt); await waitFor(() => finished(turn), ms); return turn; };

  // ---- detection --------------------------------------------------------------------------------
  let res = await C.call("engines.list", { refresh: true });
  const cl = res.result?.engines.find((e) => e.id === "claude-code");
  const cx = res.result?.engines.find((e) => e.id === "codex");
  t.check("Claude Code detected with its version and models", cl?.found && cl.version === "9.9.9 (Claude Code)" && cl.models.some((m) => m.id === "claude-sonnet-5-5" && m.efforts.includes("max")), why(res));
  t.check("Codex detected; its models come from the app-server", cx?.found && cx.version === "codex-cli 9.9.9" && cx.models.some((m) => m.id === "gpt-fake" && m.efforts.join() === "low,high"), why(res));
  t.check("lean mode is on by default", res.result.settings.claude_lean === true);
  res = await C.call("engines.set", { claude_path: "/no/such/claude" });
  t.check("engines.set rejects a path that is not a program", res.error?.code === E.INVALID, why(res));
  res = await C.call("engines.set", { default_effort: "huge" });
  t.check("engines.set rejects an unknown effort", res.error?.code === E.INVALID, why(res));

  // ---- Claude Code: a reply, flags, session, usage --------------------------------------------------
  clear();
  let chat = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", model: "sonnet", effort: "high" })).result.chat;
  t.check("chat.create records engine, model and effort", chat.engine === "claude-code" && chat.model === "sonnet" && chat.effort === "high", JSON.stringify(chat));
  let turn = await run(chat, "hello there");
  t.check("Claude Code reply streams into the chat", evs(turn).some((e) => e.type === "completed") && text(turn).includes("Claude says: hello there"), text(turn) || JSON.stringify(evs(turn).at(-1)));
  let a = lastArgv("claude");
  t.check("runs in the project folder with stream-json and our permission prompts", a?.cwd === proj && a.argv.includes("-p") && flag(a.argv, "--input-format") === "stream-json" && flag(a.argv, "--output-format") === "stream-json" && flag(a.argv, "--permission-prompt-tool") === "stdio", JSON.stringify(a));
  t.check("model, effort and Supervised -> permission-mode default", flag(a.argv, "--model") === "sonnet" && flag(a.argv, "--effort") === "high" && flag(a.argv, "--permission-mode") === "default" && !a.argv.includes("--dangerously-skip-permissions"));
  t.check("lean mode skips your MCP servers (--strict-mcp-config)", a.argv.includes("--strict-mcp-config"));
  t.check("no --resume on the first message", !a.argv.includes("--resume"));
  let m = await meta(chat.id);
  t.check("the session id and token usage are saved on the chat", m.engine_session === "sess-claude-1" && m.usage?.output_tokens === 5 && m.usage.cached_tokens === 100 && m.usage.context_tokens === 128, JSON.stringify(m));
  turn = await run(chat, "second message");
  a = lastArgv("claude");
  t.check("the next message resumes the session", flag(a.argv, "--resume") === "sess-claude-1");
  t.check("a resumed session gets only the new message", entries().filter((e) => e.prompt).at(-1)?.prompt === "second message");
  t.check("usage adds up across messages", (await meta(chat.id)).usage.output_tokens === 10);

  // ---- approvals ------------------------------------------------------------------------------------------
  turn = await submit(chat, "please FAKE_WRITE a file");
  t.check("a write asks first, on its card", await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === "toolu_1"), 6000), JSON.stringify(evs(turn).map((e) => e.type)));
  const card = evs(turn).find((e) => e.type === "tool_start");
  t.check("the card shows the path relative to the project", card?.summary === "Write from-claude.txt", card?.summary);
  t.check("nothing is written before you allow it", !existsSync(join(proj, "from-claude.txt")));
  await C.call("turn.approve", { turn_id: turn, call_id: "toolu_1", allow: true });
  await waitFor(() => finished(turn), 6000);
  t.check("after Allow the file is written and the card is done", readFileSync(join(proj, "from-claude.txt"), "utf8") === "hello from claude\n" && evs(turn).some((e) => e.type === "tool_end" && e.call_id === "toolu_1" && !e.is_error));
  rmSync(join(proj, "from-claude.txt"));
  turn = await submit(chat, "FAKE_WRITE again");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 6000);
  await C.call("turn.approve", { turn_id: turn, call_id: "toolu_1", allow: false });
  await waitFor(() => finished(turn), 6000);
  t.check("after Deny nothing is written and Claude is told", !existsSync(join(proj, "from-claude.txt")) && text(turn).includes("You said no"));

  // ---- permission modes ------------------------------------------------------------------------------------
  // Read only is "default" with the writing tools switched off, not plan mode (plan mode saves a plan file).
  for (const [mode, expect, bypass] of [["read", "default", false], ["auto_edits", "acceptEdits", false], ["full", "bypassPermissions", true]]) {
    await C.call("chat.set_mode", { chat_id: chat.id, mode });
    await run(chat, "hi");
    a = lastArgv("claude");
    t.check(`${mode} -> --permission-mode ${expect}`, flag(a.argv, "--permission-mode") === expect && a.argv.includes("--dangerously-skip-permissions") === bypass && (mode !== "read" || flag(a.argv, "--disallowedTools") === "Write,Edit,MultiEdit,NotebookEdit"), JSON.stringify(a.argv));
  }
  await C.call("chat.set_mode", { chat_id: chat.id, mode: "supervised" });
  await C.call("engines.set", { claude_lean: false });
  await run(chat, "hi");
  t.check("lean mode off loads your MCP servers again", !lastArgv("claude").argv.includes("--strict-mcp-config"));
  await C.call("engines.set", { claude_lean: true });

  // ---- failure and interrupt -----------------------------------------------------------------------------------
  turn = await run(chat, "please FAKE_FAIL");
  t.check("an error from Claude Code fails the turn with its message", evs(turn).some((e) => e.type === "failed" && e.error.includes("it broke")), JSON.stringify(evs(turn).at(-1)));
  turn = await submit(chat, "FAKE_HANG forever");
  await waitFor(() => text(turn).includes("Working"), 6000);
  res = await C.call("chat.set_engine", { chat_id: chat.id, engine: "codex" });
  t.check("the engine can't change while a reply is running", res.error?.code === E.CONFLICT, why(res));
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("Stop ends a Claude Code turn", await waitFor(() => evs(turn).some((e) => e.type === "interrupted"), 6000));

  // ---- switch to Codex mid-chat --------------------------------------------------------------------------------
  clear();
  res = await C.call("chat.set_engine", { chat_id: chat.id, engine: "codex", model: "gpt-fake", effort: "low" });
  t.check("switching engine starts that engine's context fresh", res.result?.chat.engine === "codex" && !res.result.chat.engine_session && !res.result.chat.usage, why(res));
  turn = await run(chat, "what did we do?");
  const startReq = entries().find((e) => e.method === "thread/start");
  const turnReq = entries().find((e) => e.method === "turn/start");
  t.check("Codex app-server runs in the project folder", entries().find((e) => e.bin === "codex" && e.argv)?.argv.join(" ") === "app-server" && entries().find((e) => e.argv)?.cwd === proj);
  t.check("Supervised -> read-only sandbox, ask for untrusted commands", startReq?.params.sandbox === "read-only" && startReq.params.approvalPolicy === "untrusted" && startReq.params.cwd === proj, JSON.stringify(startReq?.params));
  t.check("model and effort reach Codex", startReq?.params.model === "gpt-fake" && turnReq?.params.effort === "low" && turnReq.params.model === "gpt-fake");
  // Since the hand-off (H3): the earlier messages go into the new thread as history items, and the message is only the user's words.
  const injReq = entries().find((e) => e.method === "thread/inject_items");
  t.check("the earlier messages come along as context (Codex history items)", /Goal \(the user's own words\): hello there/.test(injReq?.params.items?.[0]?.content?.[0]?.text ?? "") && injReq.params.items.some((i) => i.role === "user") && turnReq?.params.input[0].text === "what did we do?", JSON.stringify(injReq?.params?.items?.map((i) => i.role)) + " " + turnReq?.params.input[0].text.slice(0, 120));
  t.check("Codex reply streams in", text(turn).includes("Codex says: what did we do?"), text(turn));
  m = await meta(chat.id);
  t.check("Codex thread and usage are saved", m.engine_session === "thread-new-1" && m.usage?.context_window === 400000 && m.usage.cached_tokens === 100, JSON.stringify(m));
  clear();
  await run(chat, "and now?");
  t.check("the next message resumes the Codex thread", entries().some((e) => e.method === "thread/resume" && e.params.threadId === "thread-new-1") && !entries().some((e) => e.method === "thread/start"));

  turn = await submit(chat, "run a command");
  t.check("a Codex command asks first, on its card", await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === "exec-1"), 6000));
  t.check("the card shows the command", evs(turn).find((e) => e.type === "tool_start")?.summary.startsWith("Run echo hi"), evs(turn).find((e) => e.type === "tool_start")?.summary);
  await C.call("turn.approve", { turn_id: turn, call_id: "exec-1", allow: true });
  await waitFor(() => finished(turn), 6000);
  t.check("after Allow Codex runs it", existsSync(join(proj, "from-codex.txt")) && text(turn).includes("Done."));
  rmSync(join(proj, "from-codex.txt"));
  turn = await submit(chat, "run it again");
  await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 6000);
  await C.call("turn.approve", { turn_id: turn, call_id: "exec-1", allow: false });
  await waitFor(() => finished(turn), 6000);
  t.check("after Deny Codex does not run it", !existsSync(join(proj, "from-codex.txt")) && text(turn).includes("Not run."));
  for (const [mode, sandbox, approval] of [["read", "read-only", "never"], ["auto_edits", "workspace-write", "untrusted"], ["full", "workspace-write", "never"]]) {
    clear();
    await C.call("chat.set_mode", { chat_id: chat.id, mode });
    await run(chat, "hi");
    const r = entries().find((e) => e.method === "thread/resume");
    t.check(`${mode} -> Codex sandbox ${sandbox}, approvals ${approval}`, r?.params.sandbox === sandbox && r.params.approvalPolicy === approval, JSON.stringify(r?.params));
  }
  turn = await submit(chat, "hang please");
  await waitFor(() => text(turn).includes("Thinking"), 6000);
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("Stop ends a Codex turn", await waitFor(() => evs(turn).some((e) => e.type === "interrupted"), 6000));

  // ---- defaults -------------------------------------------------------------------------------------------------------
  await C.call("engines.set", { default_engine: "codex", default_model: "gpt-fake", default_effort: "high" });
  const c2 = (await C.call("chat.create", { workspace_id: wid })).result.chat;
  t.check("new chats start on the default engine, model and effort", c2.engine === "codex" && c2.model === "gpt-fake" && c2.effort === "high", JSON.stringify(c2));
  await C.call("engines.set", { default_engine: "api", default_model: "", default_effort: "" });
  t.check("engines.json is private (0600)", (await import("node:fs")).statSync(join(stateDir, "engines.json")).mode % 0o1000 === 0o600);
  C.close();
  await rt.stop();

  // ---- a missing program -------------------------------------------------------------------------------------------------
  rt = await startRuntime({ env: { OPSCODE_CLAUDE_BIN: join(base, "nope"), OPSCODE_CODEX_BIN: join(base, "nope"), OPSCODE_AGY_BIN: join(base, "nope"), OPSCODE_QODER_BIN: join(base, "nope") }, stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("engines.list", { refresh: true });
  t.check("a missing program is reported as not found", res.result?.engines.every((e) => !e.found), why(res));
  const c3 = (await C.call("chat.create", { workspace_id: (await C.call("workspace.list")).result.workspaces[0].id, engine: "claude-code" })).result.chat;
  const tt = (await C.call("turn.submit", { workspace_id: c3.workspace_id, chat_id: c3.id, text: "hi" })).result.turn_id;
  await waitFor(() => C.find("turn.event", (p) => p.turn_id === tt && p.type === "failed").length > 0, 6000);
  t.check("a chat on a missing engine fails with a clear message", C.find("turn.event", (p) => p.turn_id === tt && p.type === "failed")[0]?.params.error.includes("Claude Code"), JSON.stringify(C.find("turn.event", (p) => p.turn_id === tt).map((n) => n.params).at(-1)));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
