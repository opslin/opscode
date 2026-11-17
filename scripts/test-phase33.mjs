// Hand-off slice H1: the task ledger. Opscode records what happened in a chat (goal, the user's words,
// files changed and read, commands with results, what the user refused, what was running at a stop)
// from the events it already sees, with no model call. It must survive an engine switch, a stop and a
// restart, hide secrets, and go away with the chat.
import { existsSync, mkdirSync, mkdtempSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const L = await import(join(process.cwd(), "dist/runtime/ledger.js"));

// ---- pure helpers ---------------------------------------------------------------------------------
t.check("Codex's shell wrapper is taken off a command", L.unwrapCommand('/bin/zsh -lc "npm test"') === "npm test" && L.unwrapCommand("npm test") === "npm test");
t.check("exit codes are read from Codex and Claude Code output", L.exitCode("x\n(exit 2)") === 2 && L.exitCode("Exit code 1\nFAIL") === 1 && L.exitCode("ok") === null);
t.check("file paths come from cards, including several and a sub-agent's", JSON.stringify(L.pathsOf("Edit a.ts, b/c.ts")) === '["a.ts","b/c.ts"]' && JSON.stringify(L.pathsOf("helper › Read x.md")) === '["x.md"]' && L.pathsOf("Edit files").length === 0);
const red = L.redact('API_KEY=abc123456 Authorization: Bearer abcdefgh12345678 sk-ant-abcdefghijklmnop1234 ghp_abcdefghijklmnopqrstuv https://u:pw123@host/x password: "hunter22"');
t.check("secrets are hidden", !/abc123456|abcdefgh12345678|sk-ant-abcdef|ghp_abc|pw123|hunter22/.test(red), red);

// ---- live: real runtime with the fake engines ----------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p33-")));
mkdirSync(join(base, "src"));
writeFileSync(join(base, "src/cart.ts"), "export const total = 1;\n");
writeFileSync(join(base, "package.json"), "{}");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs") };
const stateDir = join(base, "state");
const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(60)) { const v = await fn(); if (v) return v; } return null; };

let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
let chatId;
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const ended = (tid) => waitFor(() => C.find("turn.event", (p) => p.turn_id === tid && ["completed", "failed", "interrupted"].includes(p.type))[0]);
  const ledger = async () => (await C.call("chat.ledger", { chat_id: chatId })).result.ledger;

  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code", model: "claude-opus-5-5" })).result.chat;
  chatId = chat.id;
  t.check("a new chat has no ledger yet", (await ledger()) === null);

  // 1. Claude reads, edits, runs a failing test and a command with a token in it.
  const r1 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: "Fix the cart total. Keep the code style short. FAKE_TOOLS" })).result;
  await ended(r1.turn_id);
  let l = await ledger();
  t.check("the goal is the user's first message, word for word", l?.goal.startsWith("Fix the cart total. Keep the code style short."), l?.goal);
  t.check("files read and changed are recorded (paths inside the project)", l?.files_read.some((f) => f.path === "src/cart.ts") && l?.files_changed.some((f) => f.path === "src/cart.ts" && f.engine === "claude-code"), JSON.stringify([l?.files_read, l?.files_changed]));
  const test1 = l?.commands.find((c) => c.cmd === "npm test");
  t.check("the failing test is recorded with its exit code and the end of its output", test1 && !test1.ok && test1.exit === 1 && /total is wrong/.test(test1.tail), JSON.stringify(test1));
  t.check("…and listed as an open error", l?.open_errors.length === 1 && l.open_errors[0].cmd === "npm test");
  t.check("no secret reaches the ledger (output or command)", !/sk-ant-abcdef|abcdefgh12345678/.test(JSON.stringify(l)));
  t.check("the turn is recorded with engine and model", l?.turns.at(-1)?.engine === "claude-code" && l.turns.at(-1).model === "claude-opus-5-5" && l.turns.at(-1).status === "complete", JSON.stringify(l?.turns));
  t.check("the last reply is kept", /The test still fails/.test(l?.last_reply ?? ""));

  // 2. Switch to Codex: the ledger carries on (the engine session is reset, the ledger is not).
  await C.call("chat.set_engine", { chat_id: chatId, engine: "codex", model: "gpt-fake" });
  const r2 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: "Continue. FAKE_CODEX_TOOLS" })).result;
  await ended(r2.turn_id);
  l = await ledger();
  t.check("after switching to Codex the goal and earlier work are still there", l?.goal.startsWith("Fix the cart total") && l.commands.some((c) => c.cmd === "npm test" && c.engine === "claude-code"));
  const cart = l?.files_changed.find((f) => f.path === "src/cart.ts");
  t.check("a file changed by both engines counts twice, last by Codex", cart?.count === 2 && cart.engine === "codex", JSON.stringify(cart));
  t.check("Codex's own changes are added", l?.files_changed.some((f) => f.path === "src/cart.test.ts"));
  t.check("Codex's passing run clears the open error", l?.open_errors.length === 0 && l.commands.at(-1).cmd === "npm test" && l.commands.at(-1).ok && l.commands.at(-1).engine === "codex", JSON.stringify(l?.commands.at(-1)));
  t.check("both engines are in the turn list", l?.turns.map((x) => x.engine).join(",") === "claude-code,codex");
  t.check("the user's messages are kept in order", l?.user_messages.map((m) => m.text.split(".")[0]).join("|") === "Fix the cart total|Continue");

  // 3. Back to Claude; the user stops a build mid-way: the running step is recorded.
  await C.call("chat.set_engine", { chat_id: chatId, engine: "claude-code", model: "claude-sonnet-5-5" });
  const r3 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: "Build it FAKE_TOOLS FAKE_TOOLS_HANG" })).result;
  await waitFor(() => C.find("turn.event", (p) => p.turn_id === r3.turn_id && p.type === "tool_start" && /npm run build/.test(p.summary))[0]);
  await C.call("turn.interrupt", { turn_id: r3.turn_id });
  await ended(r3.turn_id);
  l = await ledger();
  t.check("a stop records what was running (tool, command, engine, why)", l?.in_flight?.summary === "Run npm run build" && l.in_flight.detail === "npm run build" && l.in_flight.engine === "claude-code" && l.in_flight.why === "interrupted", JSON.stringify(l?.in_flight));
  t.check("the stopped turn is marked interrupted", l?.turns.at(-1)?.status === "interrupted");

  // 4. A refused action is remembered.
  await C.call("chat.set_mode", { chat_id: chatId, mode: "supervised" });
  const r4 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: "clean up FAKE_BASH=«rm -rf build»" })).result;
  const asked = await waitFor(() => C.find("turn.event", (p) => p.turn_id === r4.turn_id && p.type === "approval_request")[0]);
  if (asked) await C.call("turn.approve", { turn_id: r4.turn_id, call_id: asked.params.call_id, allow: false });
  await ended(r4.turn_id);
  l = await ledger();
  t.check("what the user said no to is recorded", l?.denied.some((d) => /rm -rf build/.test(d.summary)), JSON.stringify(l?.denied));
  t.check("a finished turn after a stop clears the running step", !l?.in_flight);
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
  await rt.stop();
}

// 5. Restart: the ledger is on disk (private), and survives; deleting the chat deletes it.
const file = join(stateDir, "ledger", `${chatId}.json`);
t.check("the ledger file is private (0600)", existsSync(file) && (statSync(file).mode & 0o777) === 0o600);
writeFileSync(join(stateDir, "ledger", "gone-chat.json"), "{}");
rt = await startRuntime({ env, stateDir, keepState: true });
try {
  const C = await session(rt);
  const l = (await C.call("chat.ledger", { chat_id: chatId })).result.ledger;
  t.check("after a restart the ledger is still there", l?.goal.startsWith("Fix the cart total") && l.turns.length === 4, JSON.stringify(l?.turns?.length));
  t.check("ledgers of chats that no longer exist are removed at start", !existsSync(join(stateDir, "ledger", "gone-chat.json")));
  t.check("an unknown chat is refused", (await C.call("chat.ledger", { chat_id: "nope" })).error?.code !== undefined);
  await C.call("chat.delete", { chat_id: chatId });
  t.check("deleting the chat deletes its ledger", !existsSync(file));
} catch (e) {
  t.check("no exception after restart", false, String(e?.stack ?? e));
}
await rt.stop();
process.exit(t.finish());
