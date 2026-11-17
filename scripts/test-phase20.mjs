// Slice A3: hand-off to a fresh worker past the threshold (Conductors only), the working
// rules and project map in a Conductor worker's brief, lean-start flags for a Chief's
// workers (never for a Normal chat), and the start-up measurement.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res?.error ?? res?.result)?.slice(0, 300);
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p20-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "src", "cart"), { recursive: true });
mkdirSync(join(proj, "docs"));
mkdirSync(join(proj, "node_modules", "left-pad"), { recursive: true });
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "shop", scripts: { test: "x", build: "y" } }));
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const start = (title, extra = {}) => tool("chat_start", { title, brief: `Goal: ${title}`, quotes: [title], project_ids: [wid], engine: "claude-code", ...extra });
  const chats = async () => (await C.call("chat.list", {})).result.chats;
  const byTitle = async (title) => (await chats()).filter((c) => c.title === title);
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const idle = (id) => waitFor(async () => { const c = (await chats()).find((x) => x.id === id); return c?.usage?.context_tokens ? c : null; });
  const sendResults = () => entries().filter((e) => e.chief_tool === "chat_send").map((e) => { try { return JSON.parse(e.result); } catch { return {}; } });
  const claudeArgv = () => entries().filter((e) => e.argv && !e.argv.includes("--system-prompt"));

  // ---- a WARLORD Conductor ------------------------------------------------------------------------
  const w = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: w.id, max_parallel: 8 });
  await C.call("chief.note", { chief_id: w.id, text: `go\n${start("big", { tier: "base" }).replace('"Goal: big"', '"Goal: big FAKE_BIG_CTX"')}\n${start("small", { tier: "base" })}` });
  const big = (await waitFor(async () => (await byTitle("big"))[0]))?.id;
  const small = (await waitFor(async () => (await byTitle("small"))[0]))?.id;
  const bigMeta = await idle(big);
  await idle(small);
  t.check("the worker that grew reports more than 150k tokens of history", bigMeta?.usage?.context_tokens > 150_000, JSON.stringify(bigMeta?.usage));

  // ---- the brief: working rules and project map ---------------------------------------------------
  const prompts = () => entries().filter((e) => e.prompt && !e.prompt.includes("<board>")).map((e) => e.prompt);
  const first = prompts().find((p) => p.includes("Goal: big")) ?? "";
  t.check("a Conductor worker's brief carries the working rules", /Working rules \(they keep this chat small/.test(first) && /tail -n 60/.test(first), first.slice(0, 120));
  t.check("and a project map: folders and a few entries, package scripts; dependency folders are left out", /Project map/.test(first) && /- src\/\s+cart\//.test(first) && /- docs\//.test(first) && /npm scripts: test, build/.test(first) && !/node_modules/.test(first.slice(first.indexOf("Project map"))), first.slice(first.indexOf("Project map"), first.indexOf("Project map") + 260));
  t.check("the report format still comes last", first.indexOf("Working rules") < first.indexOf("Status: done | review | question | blocked"));

  // ---- hand-off ------------------------------------------------------------------------------------
  const before = (await chats()).length;
  await C.call("chief.note", { chief_id: w.id, text: `next\n${tool("chat_send", { chat_id: small, text: "also handle empty carts" })}\n${tool("chat_send", { chat_id: big, text: "now add the tests" })}` });
  const fresh = await waitFor(async () => sendResults().find((r) => r.delivered === "fresh_worker"));
  t.check("sending to the bloated worker starts a fresh one instead, and says so", fresh?.chat_id && fresh.chat_id !== big && /150k|\d+k tokens of history/.test(fresh.note ?? ""), JSON.stringify(sendResults()));
  t.check("a small worker still gets its message in the same chat", sendResults().some((r) => r.delivered === "now"), JSON.stringify(sendResults()));
  const all = await chats();
  t.check("exactly one new chat was made (the hand-off)", all.length === before + 1, `${before} -> ${all.length}`);
  const nu = all.find((c) => c.id === fresh?.chat_id);
  const old = all.find((c) => c.id === big);
  t.check("the fresh worker has the same title, model and effort, and belongs to the Chief", nu?.title === "big" && nu.model === old.model && nu.effort === old.effort && nu.chief?.id === w.id && nu.chief.role === "build", JSON.stringify([nu?.title, nu?.model, nu?.effort]));
  const handBrief = (await waitFor(async () => prompts().find((p) => p.includes("You are continuing work that another worker started")))) ?? "";
  t.check("its brief holds the previous report and the new instruction, plus the rules", /previous worker's last report/.test(handBrief) && /now add the tests/.test(handBrief) && /Working rules/.test(handBrief), handBrief.slice(0, 200));
  const view = (await C.call("chief.get", { chief_id: w.id })).result;
  const ics = view.items.find((i) => i.title === "big")?.chats ?? [];
  t.check("the board keeps both: the old chat is stopped and points to its successor", ics.length === 2 && ics[0].state === "stopped" && ics[0].handed_to === fresh?.chat_id && ics[1].chat_id === fresh?.chat_id, JSON.stringify(ics.map((c) => [c.chat_id.slice(0, 6), c.state, c.handed_to?.slice(0, 6)])));

  // ---- a plain Chief never hands off --------------------------------------------------------------
  const p = (await C.call("chief.create", { name: "Boss" })).result.chief;
  await C.call("chief.update", { chief_id: p.id, project_ids: [wid], max_parallel: 8 });
  await C.call("chief.note", { chief_id: p.id, text: `go\n${start("plain-big").replace('"Goal: plain-big"', '"Goal: plain-big FAKE_BIG_CTX"')}` });
  const pb = (await waitFor(async () => (await byTitle("plain-big"))[0]))?.id;
  await idle(pb);
  const beforePlain = (await chats()).length;
  const nBefore = sendResults().length;
  await C.call("chief.note", { chief_id: p.id, text: `next\n${tool("chat_send", { chat_id: pb, text: "carry on" })}` });
  await waitFor(async () => sendResults().length > nBefore);
  await sleep(600);
  t.check("a plain Chief's worker keeps its chat however big it is", sendResults().at(-1)?.delivered === "now" && (await chats()).length === beforePlain, JSON.stringify(sendResults().at(-1)));
  const plainPrompt = prompts().find((x) => x.includes("Goal: plain-big")) ?? "";
  t.check("and its brief has no Conductor extras", plainPrompt && !/Working rules|Project map/.test(plainPrompt), plainPrompt.slice(0, 80));

  // ---- lean start for a Chief's workers, never for a Normal chat ---------------------------------
  const workerFlags = () => claudeArgv().filter((e) => e.cwd.endsWith("shop") || e.cwd.includes("/shop")).map((e) => e.argv);
  t.check("by default a Chief's worker starts without skills (--disable-slash-commands)", workerFlags().some((a) => a.includes("--disable-slash-commands") && !a.includes("--setting-sources")), JSON.stringify(workerFlags().at(-1)));
  const normal = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", model: "claude-sonnet-5-5" })).result.chat;
  writeFileSync(logFile, "");
  const tid = (await C.call("turn.submit", { workspace_id: wid, chat_id: normal.id, text: "hello" })).result.turn_id;
  await waitFor(() => C.find("turn.event", (x) => x.turn_id === tid && x.type === "completed").length > 0);
  const nArgv = claudeArgv().at(-1)?.argv ?? [];
  t.check("a Normal chat gets none of it", nArgv.length > 0 && !nArgv.includes("--disable-slash-commands") && !nArgv.includes("--setting-sources") && nArgv.includes("--strict-mcp-config"), JSON.stringify(nArgv));
  let res = await C.call("engines.set", { worker_start: "leanest" });
  t.check("the setting is saved", res.result?.settings.worker_start === "leanest", why(res));
  writeFileSync(logFile, "");
  await C.call("chief.note", { chief_id: w.id, text: `go\n${start("lean-check", { tier: "fast" })}` });
  await waitFor(async () => workerFlags().length > 0);
  const lean = workerFlags().at(-1) ?? [];
  t.check("leanest also leaves out user-level settings (--setting-sources project,local)", lean.includes("--disable-slash-commands") && lean[lean.indexOf("--setting-sources") + 1] === "project,local", JSON.stringify(lean));
  await C.call("engines.set", { worker_start: "standard" });
  writeFileSync(logFile, "");
  await C.call("chief.note", { chief_id: w.id, text: `go\n${start("std-check", { tier: "fast" })}` });
  await waitFor(async () => workerFlags().length > 0);
  t.check("standard adds nothing", !(workerFlags().at(-1) ?? []).includes("--disable-slash-commands"), JSON.stringify(workerFlags().at(-1)));
  res = await C.call("engines.set", { worker_start: "bogus" });
  t.check("an unknown level is refused", !!res.error, why(res));
  await C.call("engines.set", { worker_start: "lean" });

  // ---- measure the start-up size --------------------------------------------------------------------
  res = await C.call("engines.measure_start", { workspace_id: wid });
  const r = res.result?.results ?? [];
  t.check("measure_start reports the first request's size at each level, smaller as it gets leaner (52k, 43k, 29k)", r.map((x) => x.level).join() === "standard,lean,leanest" && r[0].tokens === 52_003 && r[1].tokens === 43_003 && r[2].tokens === 29_003, JSON.stringify(res.result ?? res.error));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
