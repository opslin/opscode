// Hand-off slice H4: when Claude Code or Codex runs out of its plan limit, a Normal chat continues on the
// other engine (opt-in). During a turn: the chat moves and Opscode sends "Continue the task from where it
// stopped." with the H3 hand-off. Before a turn: an engine already at its limit is skipped. Never when the
// setting is off, never to an engine also at its limit, at most one automatic switch per message.
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const A = await import(join(process.cwd(), "dist/runtime/autoswitch.js"));

// ---- pure -----------------------------------------------------------------------------------------------------
const limitMsgs = ["Claude AI usage limit reached|1792999999", "You've hit your usage limit. Upgrade to Pro or try again at 5:00 PM.", "You've hit your limit · resets 3pm", "5-hour limit reached", "rate_limit_error: Too Many Requests", "usage_limit_reached"];
const other = ["it broke", "npm test failed (exit 1)", "Claude Code reported an error", "Codex failed", "line 429: syntax error"];
t.check("plan-limit errors are recognised", limitMsgs.every(A.isLimitError), limitMsgs.filter((m) => !A.isLimitError(m)).join(" | "));
t.check("ordinary failures are not", !other.some(A.isLimitError), other.filter(A.isLimitError).join(" | "));
const now = Date.now();
const lim = (engine, pct, reached, ageMs = 0) => ({ engine, state: "ok", windows: [{ id: engine === "codex" ? "primary" : "five_hour", kind: "session", label: "5h", used_percent: pct, window_mins: 300 }], checked_at: new Date(now - ageMs).toISOString(), ...(reached ? { reached } : {}) });
t.check("'at its limit' = a fresh reading at 100%, or the engine said a limit stopped work", A.exhausted(lim("codex", 100), now) && A.exhausted(lim("claude-code", 40, "five_hour"), now) && !A.exhausted(lim("codex", 99), now) && !A.exhausted(lim("codex", 100, undefined, 20 * 60_000), now) && !A.exhausted(undefined, now));
t.check("only Normal chats on Claude Code or Codex", A.eligible({ engine: "codex" }) && A.eligible({ engine: "claude-code" }) && !A.eligible({ engine: "api" }) && !A.eligible({ engine: "codex", chief: { id: "x", role: "build" } }) && !A.eligible({ engine: "codex", origin: { automation: "a", run_id: "r", step: "s" } }));
const sw = (o = {}) => new A.AutoSwitch({ enabled: () => o.enabled ?? true, installed: (e) => (o.installed ?? ["claude-code", "codex"]).includes(e), limits: () => o.limits ?? [] });
const cc = { engine: "claude-code" };
t.check("after a limit failure: the other engine", sw().afterFailure(cc, limitMsgs[0], false) === "codex" && sw().afterFailure({ engine: "codex" }, limitMsgs[1], false) === "claude-code");
t.check("not when the setting is off, not for other failures, not twice in a row", sw({ enabled: false }).afterFailure(cc, limitMsgs[0], false) === null && sw().afterFailure(cc, "it broke", false) === null && sw().afterFailure(cc, limitMsgs[0], true) === null);
t.check("not to an engine that is missing or also at its limit", sw({ installed: ["claude-code"] }).afterFailure(cc, limitMsgs[0], false) === null && sw({ limits: [lim("codex", 100)] }).afterFailure(cc, limitMsgs[0], false) === null);
t.check("before a turn: only when the chat's engine is at its limit now", sw({ limits: [lim("claude-code", 100)] }).beforeTurn(cc) === "codex" && sw({ limits: [lim("claude-code", 80)] }).beforeTurn(cc) === null && sw().beforeTurn(cc) === null);

// ---- live ---------------------------------------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p37-")));
mkdirSync(join(base, "src"));
writeFileSync(join(base, "src/cart.ts"), "export const total = 1;\n");
writeFileSync(join(base, "package.json"), "{}");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: join(base, "engines.log") };
const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(60)) { const v = await fn(); if (v) return v; } return null; };

let rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const ends = (tid) => waitFor(() => C.find("turn.event", (p) => p.turn_id === tid && ["completed", "failed", "interrupted"].includes(p.type))[0]?.params);
  const say = async (chatId, text) => { const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result; return { ...r, end: await ends(r.turn_id) }; };
  const meta = async (id) => (await C.call("chat.list", {})).result.chats.find((c) => c.id === id);
  const turnsOf = async (id) => (await C.call("turn.history", { chat_id: id })).result.messages;

  t.check("the setting is off by default", (await C.call("engines.list", {})).result.settings.auto_switch === false);
  // 2. Setting on: during a turn Claude runs out -> the chat moves to Codex and carries on with the hand-off.
  const set = (await C.call("engines.set", { auto_switch: true })).result.settings;
  t.check("the setting can be turned on", set.auto_switch === true);
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code", model: "claude-opus-5-5" })).result.chat;
  await say(chat.id, "Fix the cart total FAKE_TOOLS");
  const r1 = await say(chat.id, "Now finish it FAKE_LIMIT");
  t.check("the Claude turn fails on the limit", r1.end?.type === "failed" && /usage limit/.test(r1.end.error));
  const cont = await waitFor(() => C.find("turn.event", (p) => p.chat_id === chat.id && p.type === "started" && p.engine === "codex")[0]?.params);
  t.check("Opscode starts a Codex turn in the same chat by itself", !!cont);
  const end2 = cont ? await ends(cont.turn_id) : null;
  const hist = await turnsOf(chat.id);
  const contUser = hist.find((m) => m.turn_id === cont?.turn_id && m.role === "user");
  t.check("…with a runtime line 'Continue the task from where it stopped.' (not the person's words)", contUser?.text === "Continue the task from where it stopped." && contUser.event === true);
  const ho = hist.find((m) => m.turn_id === cont?.turn_id && m.role === "assistant")?.handoff;
  t.check("…and the hand-off says why (limit) and what was carried over (as Codex history)", ho?.reason === "limit" && ho.from === "claude-code/claude-opus-5-5" && ho.to === "codex" && ho.via === "inject" && ho.tokens > 50, JSON.stringify(ho));
  t.check("the continue turn finishes on Codex; the chat is now on Codex", end2?.type === "completed" && (await meta(chat.id)).engine === "codex");
  const log = (await import("node:fs")).readFileSync(env.OPSCODE_FAKE_ENGINE_LOG, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  const inj = log.filter((e) => e.method === "thread/inject_items").at(-1)?.params?.items?.[0]?.content?.[0]?.text ?? "";
  t.check("Codex is told the goal, the half-done edit and the failed turn's work", /Goal \(the user's own words\): Fix the cart total/.test(inj) && /src\/half\.ts/.test(inj) && /src\/cart\.ts/.test(inj) && /Claude Code's last turn stopped early \(Claude AI usage limit reached\)\. Check that its last step is finished\./.test(inj), inj.slice(0, 900));

  // 1. Setting off: a limit failure stays a failure.
  await C.call("engines.set", { auto_switch: false });
  const off = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code", model: "claude-opus-5-5" })).result.chat;
  const r0 = await say(off.id, "Fix it FAKE_LIMIT");
  await sleep(500);
  t.check("setting off: the turn fails with the limit message and the chat stays on Claude Code", r0.end?.type === "failed" && /usage limit/.test(r0.end.error) && (await meta(off.id)).engine === "claude-code" && (await turnsOf(off.id)).length === 2);

  await C.call("engines.set", { auto_switch: true });
  // 3. Before a turn: Claude is now known to be at its limit, so a new Claude chat's message goes straight to Codex.
  const fresh = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code" })).result.chat;
  const r3 = await say(fresh.id, "hello there");
  const started3 = C.find("turn.event", (p) => p.turn_id === r3.turn_id && p.type === "started")[0]?.params;
  const ho3 = C.find("turn.event", (p) => p.turn_id === r3.turn_id && p.type === "handoff")[0]?.params?.handoff;
  t.check("an engine already at its limit is skipped before the turn starts (no failed turn first)", started3?.engine === "codex" && r3.end?.type === "completed" && (await meta(fresh.id)).engine === "codex" && (await turnsOf(fresh.id)).length === 2, JSON.stringify(started3));
  t.check("…and the reply says so", ho3?.reason === "limit" && ho3.from === "claude-code" && ho3.to === "codex" && ho3.tokens === 0, JSON.stringify(ho3));

  // 4. Both out: Codex runs out too while Claude is still at its limit -> no switch back, the failure stays.
  const r4 = await say(fresh.id, "more FAKE_CODEX_LIMIT");
  await sleep(600);
  t.check("both engines out: the Codex failure stays, no switch back to Claude", r4.end?.type === "failed" && /usage limit/.test(r4.end.error) && (await meta(fresh.id)).engine === "codex" && !C.find("turn.event", (p) => p.chat_id === fresh.id && p.type === "started" && p.engine === "claude-code").length);
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
  await rt.stop();
}

// 5. The other way: Codex runs out (Claude has room) -> Claude Code continues.
rt = await startRuntime({ env, stateDir: join(base, "state2") });
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  await C.call("engines.set", { auto_switch: true });
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "codex", model: "gpt-fake" })).result.chat;
  const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: "Build FAKE_CODEX_LIMIT" })).result;
  const cont = await waitFor(() => C.find("turn.event", (p) => p.chat_id === chat.id && p.type === "started" && p.engine === "claude-code")[0]?.params);
  const done = cont ? await waitFor(() => C.find("turn.event", (p) => p.turn_id === cont.turn_id && ["completed", "failed"].includes(p.type))[0]?.params) : null;
  const ho = cont ? C.find("turn.event", (p) => p.turn_id === cont.turn_id && p.type === "handoff")[0]?.params?.handoff : null;
  t.check("Codex runs out -> Claude Code continues the chat, with the hand-off in its first message", !!r.turn_id && done?.type === "completed" && ho?.reason === "limit" && ho.from === "codex/gpt-fake" && ho.via === "message", JSON.stringify(ho));
} catch (e) {
  t.check("no exception (Codex -> Claude)", false, String(e?.stack ?? e));
}
await rt.stop();
process.exit(t.finish());
