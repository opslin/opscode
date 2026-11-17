// M1: limits-aware engine choice for a Conductor's workers. The pure router (bands,
// hysteresis, which window counts, what may move), then the runtime on fake engines
// whose plan usage the test controls: soft moves chores to Codex, hard parks logic
// work without spending the daily budget, the park survives a restart, and the work
// starts once there is room again. A plain Chief is never routed.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const R = await import(join(process.cwd(), "dist/runtime/chief/route.js"));

// ---- the router, as pure functions ----------------------------------------------------------------
const now = Date.now();
const lim = (engine, windows, extra = {}) => ({ engine, state: "ok", windows, checked_at: new Date(now).toISOString(), ...extra });
const w = (id, pct, kind = "session") => ({ id, kind, label: id, used_percent: pct, resets_at: new Date(now + 3600_000).toISOString() });
const claude = (fiveH, week = 10, more = []) => lim("claude-code", [w("five_hour", fiveH), w("seven_day", week, "weekly"), ...more]);
t.check("the higher of 5-hour and weekly counts", R.usageOf(claude(20, 75), now).pct === 75);
t.check("model windows and monthly extra usage never count for the band", R.usageOf(claude(20, 30, [w("seven_day_opus", 99, "weekly"), w("extra_usage", 100, "monthly"), w("seven_day_fable", 98, "weekly")]), now).pct === 30);
t.check("a limit that already stopped work counts as full", R.usageOf(lim("claude-code", [w("five_hour", 40)], { reached: "five_hour" }), now).pct === 100);
t.check("no data, an error or an API-key sign-in: normal, never parked", R.bandOf(R.usageOf(undefined)) === "normal" && R.bandOf(R.usageOf({ engine: "claude-code", state: "unavailable", windows: [], checked_at: new Date().toISOString() })) === "normal" && R.bandOf(R.usageOf({ engine: "claude-code", state: "error", windows: [], checked_at: new Date().toISOString() })) === "normal");
const stale = lim("claude-code", [w("five_hour", 95)]);
stale.checked_at = new Date(now - 10 * 60_000).toISOString();
t.check("a reading older than 5 minutes cannot raise the band", R.bandOf(R.usageOf(stale, now)) === "normal");
const u = (pct) => ({ pct, label: "5-hour", fresh: true });
let b = "normal";
const seq = [69, 71, 69, 66, 64, 89, 91, 89, 86, 84].map((p) => (b = R.bandOf(u(p), b)));
t.check("hysteresis: soft at 70, held down to 65; hard at 90, held down to 85", JSON.stringify(seq) === JSON.stringify(["normal", "soft", "soft", "soft", "normal", "soft", "hard", "hard", "hard", "soft"]), JSON.stringify(seq));
const spec = (o) => ({ project_id: "p", title: "x", brief: "b", engine: "claude-code", role: "build", access: "edit", ...o });
const N = { band: "normal", usage: null }, S = { band: "soft", usage: u(78) }, H = { band: "hard", usage: { ...u(93), resets_at: new Date(now + 7200_000).toISOString() } };
t.check("normal: everything as the Conductor asked", R.route(spec({ kind: "chore" }), N, N).engine === "claude-code");
t.check("soft: a chore or tier fast moves to Codex; logic and reviews stay", R.route(spec({ kind: "chore" }), S, N).engine === "codex" && R.route(spec({ tier: "fast" }), S, N).rerouted_from === "claude-code" && R.route(spec({ kind: "fix", tier: "frontier" }), S, N).engine === "claude-code" && R.route(spec({ role: "review", tier: "fast" }), S, N).engine === "claude-code");
const hp = R.route(spec({ kind: "fix" }), H, N);
t.check("hard: logic parks until Claude's reset, with the reason", hp.action === "park" && hp.engine === "claude-code" && hp.until === H.usage.resets_at && /93%/.test(hp.why), JSON.stringify(hp));
t.check("hard: reviews park too (they never move engine)", R.route(spec({ role: "review" }), H, N).action === "park");
t.check("hard: a chore still runs, on Codex", R.route(spec({ kind: "chore" }), H, N).engine === "codex");
t.check("a pinned engine is never moved", R.route(spec({ kind: "chore", pin_engine: true }), S, N).engine === "claude-code" && R.route(spec({ kind: "chore", pin_engine: true }), H, N).action === "park");
t.check("both full: a chore parks on Codex instead of moving", R.route(spec({ kind: "chore" }), H, { band: "hard", usage: u(96) }).action === "park" && R.route(spec({ engine: "codex" }), N, { band: "hard", usage: u(96) }).action === "park");
t.check("API-key workers are never routed", R.route(spec({ engine: "api" }), H, H).action === "launch");
t.check("the weekly Opus window, nearly full, blocks Opus picks only", R.opusBlocked(claude(10, 10, [w("seven_day_opus", 92, "weekly")]), now) && !R.opusBlocked(claude(95, 95), now));
t.check("the Conductor's line appears only when it matters", R.limitsLine(N, N) === "" && /Claude is at 78%/.test(R.limitsLine(S, N)) && /park and start by themselves after the reset/.test(R.limitsLine(H, N)));

// ---- the runtime, on fake engines -----------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p23-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "src"), { recursive: true });
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "shop" }));
const logFile = join(base, "engines.log");
const usageFile = join(base, "usage.json");
const setUsage = (o) => writeFileSync(usageFile, JSON.stringify(o));
setUsage({ claude5h: 78 });
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile, OPSCODE_FAKE_USAGE_FILE: usageFile, OPSCODE_CHIEF_TICK_MS: "400" };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const stateDir = join(base, "state");
let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const start = (title, extra = {}) => tool("chat_start", { title, brief: `Goal: ${title} FAKE_REPORT=done FAKE_CHECK`, quotes: [title], project_ids: [wid], engine: "claude-code", ...extra });
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const chats = async () => (await C.call("chat.list", {})).result.chats;
  const byTitle = async (title) => (await chats()).filter((c) => c.title === title);
  const itemOf = async (chiefId, title) => (await C.call("chief.get", { chief_id: chiefId })).result.items.find((i) => i.title === title);

  // ---- soft (78%) ---------------------------------------------------------------------------------
  const r0 = (await C.call("limits.get", { refresh: true })).result.limits;
  t.check("the fake plan reads 78% on Claude's 5-hour window", r0.find((l) => l.engine === "claude-code")?.windows.find((x) => x.id === "five_hour")?.used_percent === 78, JSON.stringify(r0.map((l) => l.state)));
  const wl = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: wl.id, max_parallel: 8 });
  await C.call("chief.note", { chief_id: wl.id, text: ["go", start("lookup", { kind: "chore", tier: "fast" }), start("logic", { kind: "fix", tier: "frontier" }), start("pinned", { kind: "chore", tier: "fast", pin_engine: true })].join("\n") });
  const lookup = await waitFor(async () => (await byTitle("lookup"))[0]);
  const logic = await waitFor(async () => (await byTitle("logic"))[0]);
  const pinned = await waitFor(async () => (await byTitle("pinned"))[0]);
  t.check("soft: the chore runs on Codex", lookup?.engine === "codex", lookup?.engine);
  t.check("soft: the logic fix stays on Claude", logic?.engine === "claude-code", logic?.engine);
  t.check("soft: a pinned chore stays on Claude", pinned?.engine === "claude-code", pinned?.engine);
  const li = await itemOf(wl.id, "lookup");
  t.check("the board records that the chore was moved", li?.chats?.[0]?.rerouted_from === "claude-code", JSON.stringify(li?.chats?.[0]));
  const prompts = () => entries().filter((e) => e.prompt).map((e) => e.prompt);
  const codexBrief = await waitFor(async () => entries().find((e) => e.bin === "codex" && JSON.stringify(e).includes("Goal: lookup")));
  t.check("the moved worker is told it was moved, and to end with the report", !!codexBrief && JSON.stringify(codexBrief).includes("Opscode moved this task to you"), JSON.stringify(codexBrief ?? {}).slice(0, 160));
  const argvs = () => entries().filter((e) => e.argv && e.bin === "claude").map((e) => e.argv.join(" "));
  await C.call("chief.note", { chief_id: wl.id, text: "status?" });
  const sawLine = await waitFor(async () => argvs().some((a) => a.includes("Claude is at 78%")));
  t.check("the Conductor reads 'Claude is at 78%' with what to prefer", !!sawLine);

  // ---- hard (93%) ---------------------------------------------------------------------------------
  setUsage({ claude5h: 93, resetInS: 6 });
  await C.call("limits.get", { refresh: true });
  const before = (await chats()).length;
  await C.call("chief.note", { chief_id: wl.id, text: ["more", start("payment", { kind: "fix" }), start("audit", { role: "review" }), start("grep", { kind: "chore", tier: "fast" })].join("\n") });
  const grep = await waitFor(async () => (await byTitle("grep"))[0]);
  t.check("hard: the chore still runs, on Codex", grep?.engine === "codex", grep?.engine);
  const pay = await waitFor(async () => { const i = await itemOf(wl.id, "payment"); return i?.parked ? i : null; });
  t.check("hard: the logic fix parks: no chat, waiting, until Claude's reset", pay && pay.state === "waiting" && pay.chats.length === 0 && pay.parked.reason === "limits" && pay.parked.engine === "claude-code" && !!pay.parked.until, JSON.stringify(pay));
  t.check("the board says why, with the percent", /93%/.test(pay?.detail ?? ""), pay?.detail);
  const audit = await itemOf(wl.id, "audit");
  t.check("hard: the review parks too", audit?.parked?.reason === "limits" && audit.chats.length === 0, JSON.stringify(audit));
  t.check("parking spends no chats from the daily budget (only the chore started)", (await chats()).length === before + 1, `${before} -> ${(await chats()).length}`);

  // ---- restart: the park holds ----------------------------------------------------------------------
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  t.check("runtime restarts", rt.ready);
  C = await session(rt);
  await sleep(1500);
  const afterRestart = await itemOf(wl.id, "payment");
  t.check("after a restart, before the reset, the parked fix is still parked (no limits known yet)", afterRestart?.state === "waiting" && afterRestart.chats.length === 0 && afterRestart.parked?.reason === "limits", JSON.stringify(afterRestart));

  // ---- room again: it starts by itself, once ------------------------------------------------------
  setUsage({ claude5h: 60 });
  const started = await waitFor(async () => { const i = await itemOf(wl.id, "payment"); return i?.chats?.length ? i : null; }, 20000);
  t.check("after the reset, with room again, the fix starts by itself on Claude", started?.chats?.length === 1 && !started.parked, JSON.stringify(started));
  const pchat = (await byTitle("payment"))[0];
  t.check("and runs on Claude Code", pchat?.engine === "claude-code", pchat?.engine);
  await sleep(1500);
  t.check("exactly once", (await byTitle("payment")).length === 1 && (await itemOf(wl.id, "payment")).chats.length === 1);
  const au = await waitFor(async () => { const i = await itemOf(wl.id, "audit"); return i?.chats?.length ? i : null; }, 10000);
  t.check("the parked review starts too", au?.chats?.length === 1);

  // ---- a plain Chief is never routed --------------------------------------------------------------
  setUsage({ claude5h: 95, resetInS: 3600 });
  await C.call("limits.get", { refresh: true });
  const boss = (await C.call("chief.create", { name: "Boss" })).result.chief;
  await C.call("chief.update", { chief_id: boss.id, project_ids: [wid], max_parallel: 8 });
  await C.call("chief.note", { chief_id: boss.id, text: `go\n${start("plain", { kind: "chore", tier: "fast" })}` });
  const plain = await waitFor(async () => (await byTitle("plain"))[0]);
  t.check("a plain Chief's chore starts on Claude whatever the limits (no mode, no routing)", plain?.engine === "claude-code", plain?.engine);
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
