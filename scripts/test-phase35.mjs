// Hand-off slice H3: switching a chat between engines hands over the task record, not just chat text.
//   Claude -> Codex: the pack and the recent conversation go into the new Codex thread as history
//                    (thread/inject_items); the turn's message is only the user's words.
//   Codex -> Claude: a new Claude session whose first message is the pack + the user's words.
//   Back to an engine it used before: its own session is resumed and it gets only what changed meanwhile.
// If Codex refuses inject_items, the pack goes in front of the message instead.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const H = await import(join(process.cwd(), "dist/runtime/handoff.js"));

// ---- pure ------------------------------------------------------------------------------------------------
const turn = (engine, status, at, model) => ({ turn_id: at, engine, status, at, ended_at: at, ...(model ? { model } : {}) });
const led = (turns) => ({ version: 1, chat_id: "c", goal: "Fix it", decisions: [], user_messages: [], files_changed: [], files_read: [], commands: [], denied: [], turns, last_reply: "", updated_at: "x", open_errors: [] });
t.check("same engine again: no hand-off", H.planHandoff(led([turn("codex", "complete", "1")]), "codex", true) === null);
t.check("first time on a new engine: full hand-off from the last engine and model", JSON.stringify(H.planHandoff(led([turn("claude-code", "complete", "1", "claude-opus-5-5")]), "codex", false)) === JSON.stringify({ kind: "full", from: "claude-code/claude-opus-5-5", to: "codex" }));
const back = H.planHandoff(led([turn("claude-code", "complete", "1"), turn("codex", "complete", "2"), turn("codex", "interrupted", "3")]), "claude-code", true);
t.check("back to an engine with its own session: update since its own last turn", back?.kind === "update" && back.since === "1" && back.from === "codex", JSON.stringify(back));
t.check("back without its session (lost): full again", H.planHandoff(led([turn("claude-code", "complete", "1"), turn("codex", "complete", "2")]), "claude-code", false)?.kind === "full");
t.check("the built-in agent (provider/model id) counts as one engine; Echo never hands off", H.familyOf("anthropic/claude-sonnet-5-5") === "api" && H.planHandoff(led([turn("codex", "complete", "1")]), "echo", false) === null && H.planHandoff(led([turn("echo", "complete", "1")]), "codex", false) === null);
t.check("a chat with no record yet: no hand-off", H.planHandoff(undefined, "codex", false) === null && H.planHandoff(led([]), "codex", false) === null);
const L2 = { ...led([]), files_changed: [{ path: "old.ts", count: 1, engine: "claude-code", at: "1" }, { path: "new.ts", count: 1, engine: "codex", at: "3" }], commands: [{ cmd: "npm test", ok: true, exit: 0, tail: "", engine: "codex", at: "3" }] };
const upd = H.buildPack(L2, "c", { kind: "update", from: "codex", to: "claude-code", since: "2" }, { withMessages: true });
t.check("an update lists only what changed since then (marked with who did it)", /new\.ts \(Codex\)/.test(upd) && !/old\.ts/.test(upd) && /npm test` → ok/.test(upd) && /While you were away, Codex/.test(upd) && !/Goal \(the user/.test(upd), upd);

// ---- live --------------------------------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p35-")));
mkdirSync(join(base, "src"));
writeFileSync(join(base, "src/cart.ts"), "export const total = 1;\n");
writeFileSync(join(base, "package.json"), "{}");
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const mark = () => entries().length;
const since = (n) => entries().slice(n);
const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(60)) { const v = await fn(); if (v) return v; } return null; };

let rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const say = async (chatId, text) => {
    const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result;
    await waitFor(() => C.find("turn.event", (p) => p.turn_id === r.turn_id && ["completed", "failed", "interrupted"].includes(p.type))[0]);
    return r.turn_id;
  };
  const hoEvent = (tid) => C.find("turn.event", (p) => p.turn_id === tid && p.type === "handoff")[0]?.params?.handoff;
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code", model: "claude-opus-5-5" })).result.chat;

  // 1. Claude works: reads, edits, a failing test; saves a plan and a decision.
  let tid = await say(chat.id, "Fix the cart total. Keep functions short. FAKE_TOOLS");
  t.check("the first turn is not a hand-off", !hoEvent(tid));
  await say(chat.id, `ok\nFAKE_DEVICE task_checkpoint ${JSON.stringify({ plan: [{ step: "Fix total()", status: "done" }, { step: "Make npm test pass", status: "in_progress" }], decisions: ["Do not change the cart API"], next: "Fix the failing total test" })}`);

  // 2. Switch to Codex: pack + conversation as thread history; the message is only the user's words.
  await C.call("chat.set_engine", { chat_id: chat.id, engine: "codex", model: "gpt-fake" });
  let n = mark();
  tid = await say(chat.id, "Continue please.");
  let log = since(n);
  const inj = log.find((e) => e.bin === "codex" && e.method === "thread/inject_items");
  const items = inj?.params?.items ?? [];
  const dev = items[0]?.content?.[0]?.text ?? "";
  t.check("Codex gets the pack as a developer item in a NEW thread", log.some((e) => e.method === "thread/start") && items[0]?.role === "developer" && dev.startsWith('<handoff from="claude-code/claude-opus-5-5" to="codex">'), dev.slice(0, 120));
  t.check("the pack has goal, plan, decision, changed file, the failing test, next step and plan file", /Goal \(the user's own words\): Fix the cart total\. Keep functions short\./.test(dev) && /\[x\] Fix total\(\)/.test(dev) && /\[>\] Make npm test pass/.test(dev) && /Do not change the cart API/.test(dev) && /Files changed: src\/cart\.ts/.test(dev) && /Still failing:\n- `npm test`/.test(dev) && /total is wrong/.test(dev) && /Next step: Fix the failing total test/.test(dev) && /Plan file: \.opscode\/tasks\//.test(dev), dev);
  t.check("no secret in the pack", !/sk-ant-abcdef|abcdefgh12345678/.test(JSON.stringify(items)));
  t.check("the recent conversation follows as real user/assistant items (the user's words not repeated in the pack)", items.slice(1).map((i) => i.role).join(",") === "user,assistant,user,assistant" && items[1].content[0].type === "input_text" && items[2].content[0].type === "output_text" && /Fix the cart total/.test(items[1].content[0].text) && !/latest messages/.test(dev), JSON.stringify(items.slice(1).map((i) => [i.role, i.content[0].text.slice(0, 30)])));
  const ti = log.find((e) => e.bin === "codex" && e.turn_input)?.turn_input;
  t.check("the turn's message is just the user's words (no old 'Earlier in this conversation' text)", ti?.text === "Continue please.", JSON.stringify(ti));
  const ho = hoEvent(tid);
  t.check("the chat shows the hand-off (full, from Claude, as history, with a size)", ho?.kind === "full" && ho.from === "claude-code/claude-opus-5-5" && ho.to === "codex" && ho.via === "inject" && ho.tokens > 100 && ho.tokens < 6000, JSON.stringify(ho));
  const hist = (await C.call("turn.history", { chat_id: chat.id })).result.messages;
  t.check("…and keeps it on the reply (seen again after reopening the chat)", hist.find((m) => m.turn_id === tid && m.role === "assistant")?.handoff?.via === "inject");

  // 3. Codex again: same engine, no hand-off, thread resumed.
  n = mark();
  tid = await say(chat.id, "FAKE_CODEX_TOOLS");
  log = since(n);
  t.check("the next Codex turn is not a hand-off and resumes the same thread", !hoEvent(tid) && !log.some((e) => e.method === "thread/inject_items") && log.some((e) => e.method === "thread/resume"));

  // 4. Back to Claude: its OWN session is resumed, and it gets only what Codex did.
  await C.call("chat.set_engine", { chat_id: chat.id, engine: "claude-code", model: "claude-sonnet-5-5" });
  let meta = (await C.call("chat.list", {})).result.chats.find((c) => c.id === chat.id);
  t.check("the chat keeps both engines' sessions, and Claude's is the current one again", meta?.engine_session === "sess-claude-1" && meta.engine_sessions?.["claude-code"] === "sess-claude-1" && meta.engine_sessions?.codex === "thread-new-1", JSON.stringify([meta?.engine_session, meta?.engine_sessions]));
  n = mark();
  tid = await say(chat.id, "Thanks, check it.");
  log = since(n);
  const argv = log.find((e) => e.bin === "claude" && e.argv)?.argv ?? [];
  const prompt = log.find((e) => e.bin === "claude" && e.prompt)?.prompt ?? "";
  t.check("Claude Code resumes its own session", argv.includes("--resume") && argv[argv.indexOf("--resume") + 1] === "sess-claude-1");
  t.check("…and its message starts with an update of what Codex did, then the user's words", prompt.startsWith('<handoff kind="update" from="codex/gpt-fake" to="claude-code">') && /src\/cart\.test\.ts \(Codex\)/.test(prompt) && /npm test` → ok/.test(prompt) && prompt.endsWith("</handoff>\n\nThanks, check it."), prompt.slice(0, 600));
  t.check("the update leaves out what Claude already knows (goal, its own failing run)", !/Goal \(the user/.test(prompt) && !/Still failing/.test(prompt), prompt);
  t.check("the update has the user's words to Codex (Claude never saw them)", /> Continue please\./.test(prompt) && !/> Thanks, check it\./.test(prompt));
  t.check("the hand-off line says update", hoEvent(tid)?.kind === "update" && hoEvent(tid)?.via === "message");

  // 5. A new chat going Codex -> Claude: Claude starts a new session whose first message is the full pack.
  const c2 = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "codex", model: "gpt-fake" })).result.chat;
  await say(c2.id, "Plan the fix FAKE_LIST_PLAN");
  await C.call("chat.set_engine", { chat_id: c2.id, engine: "claude-code", model: "claude-haiku-5-5" });
  n = mark();
  tid = await say(c2.id, "Build it.");
  log = since(n);
  const a2 = log.find((e) => e.bin === "claude" && e.argv)?.argv ?? [];
  const p2 = log.find((e) => e.bin === "claude" && e.prompt)?.prompt ?? "";
  t.check("Codex -> Claude: a NEW Claude session (no resume)", !a2.includes("--resume"));
  t.check("…whose first message is the full pack (Codex's plan from its reply, the user's words, Codex's last reply) then the request", p2.startsWith('<handoff from="codex/gpt-fake" to="claude-code">') && /1\. \[ \] Read src\/cart\.ts/.test(p2) && /> Plan the fix FAKE_LIST_PLAN/.test(p2) && /Codex's last reply/.test(p2) && p2.endsWith("\n\nBuild it.") && !/Earlier in this conversation/.test(p2), p2.slice(0, 500));
  t.check("…and the line says 'took over', in the message", hoEvent(tid)?.kind === "full" && hoEvent(tid)?.via === "message");
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
  await rt.stop();
}

// 6. A Codex that refuses inject_items: the pack goes in front of the message instead.
rt = await startRuntime({ env: { ...env, OPSCODE_FAKE_INJECT_FAIL: "1" }, stateDir: join(base, "state2") });
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const say = async (chatId, text) => { const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result; await waitFor(() => C.find("turn.event", (p) => p.turn_id === r.turn_id && ["completed", "failed"].includes(p.type))[0]); return r.turn_id; };
  const c3 = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code" })).result.chat;
  await say(c3.id, "Hello FAKE_TOOLS");
  await C.call("chat.set_engine", { chat_id: c3.id, engine: "codex", model: "gpt-fake" });
  const n = mark();
  const tid = await say(c3.id, "Go on.");
  const ti = since(n).find((e) => e.bin === "codex" && e.turn_input)?.turn_input;
  const ho = C.find("turn.event", (p) => p.turn_id === tid && p.type === "handoff")[0]?.params?.handoff;
  t.check("inject refused: the turn still works, with the pack in front of the message", ti?.text?.startsWith('<handoff from="claude-code"') && ti.text.endsWith("</handoff>\n\nGo on.") && /> Hello FAKE_TOOLS/.test(ti.text) && ho?.via === "message", JSON.stringify(ti).slice(0, 300));
} catch (e) {
  t.check("no exception (inject refused)", false, String(e?.stack ?? e));
}
await rt.stop();
process.exit(t.finish());
