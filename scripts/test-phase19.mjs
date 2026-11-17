// Modes: GODMODE / WARLORD / SHINOBI as presets on a Chief (a project Conductor).
// Exact models per tier, the review model, Codex effort, the Opus-per-day limit,
// the generated prompt section, switching modes, and a plain Chief left untouched.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res?.error ?? res?.result)?.slice(0, 300);
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p19-")));
const proj = join(base, "shop");
mkdirSync(proj);
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
  const find = async (title) => (await chats()).find((c) => c.title === title);
  const run = async (cid, titles, lines) => {
    await C.call("chief.note", { chief_id: cid, text: `go\n${lines.join("\n")}` });
    for (const end = Date.now() + 15000; Date.now() < end; await sleep(100)) if ((await Promise.all(titles.map(find))).every(Boolean)) break;
    return Object.fromEntries(await Promise.all(titles.map(async (x) => [x, await find(x)])));
  };
  const results = () => entries().filter((e) => e.chief_tool === "chat_start").map((e) => e.result);
  const prompts = () => entries().filter((e) => e.argv?.includes("--system-prompt")).map((e) => e.argv[e.argv.indexOf("--system-prompt") + 1]);

  // ---- the catalogue -----------------------------------------------------------------------------
  let res = await C.call("chief.modes", {});
  t.check("chief.modes lists the three modes with their tiers", res.result?.modes.map((m) => m.id).join() === "godmode,warlord,shinobi" && res.result.modes[0].tiers.frontier.model === "claude-opus-5-5" && res.result.modes[2].opus_per_day === 1, why(res));
  res = await C.call("chief.create", { mode: "bogus" });
  t.check("an unknown mode is refused", !!res.error, why(res));
  res = await C.call("chief.create", { mode: "warlord", project_id: "nope" });
  t.check("a Conductor needs a real project", !!res.error, why(res));

  // ---- WARLORD -----------------------------------------------------------------------------------
  res = await C.call("chief.create", { mode: "warlord", project_id: wid });
  const w = res.result?.chief;
  t.check("a WARLORD Conductor: Sonnet 5.5 medium brain, 2 at once, 30 a day, one project, no mascot", w?.mode === "warlord" && w.name === "WARLORD" && w.brain.engine === "claude-code" && w.brain.model === "claude-sonnet-5-5" && w.brain.effort === "medium" && w.max_parallel === 2 && w.daily_chats === 30 && w.project_ids.join() === wid && w.avatar === undefined && w.updates === "milestones", why(res));
  t.check("its soul holds only standing instructions (crew rules come from the mode)", /Standing instructions/.test(w.soul) && !/Crew rules/.test(w.soul), w.soul);
  await C.call("chief.update", { chief_id: w.id, max_parallel: 8 });
  const W = await run(w.id, ["w-fast", "w-base", "w-frontier", "w-opus", "w-review"], [
    start("w-fast", { tier: "fast" }), start("w-base", { tier: "base" }), start("w-frontier", { tier: "frontier" }), start("w-opus", { tier: "opus" }), start("w-review", { tier: "base", role: "review", access: "read" }),
  ]);
  const is = (c, model, effort) => c?.engine === "claude-code" && c.model === model && c.effort === effort;
  t.check("fast -> Haiku 5.5 low", is(W["w-fast"], "claude-haiku-5-5", "low"), JSON.stringify(W["w-fast"]));
  t.check("base -> Sonnet 5.5 medium", is(W["w-base"], "claude-sonnet-5-5", "medium"), JSON.stringify(W["w-base"]));
  t.check("frontier -> Sonnet 5.5 high (WARLORD keeps Opus for plans)", is(W["w-frontier"], "claude-sonnet-5-5", "high"), JSON.stringify(W["w-frontier"]));
  t.check("opus -> Opus 5.5 high", is(W["w-opus"], "claude-opus-5-5", "high"), JSON.stringify(W["w-opus"]));
  t.check("a reviewer runs on Sonnet 5.5 high whatever tier was asked", is(await find("Review: w-review"), "claude-sonnet-5-5", "high"), JSON.stringify(await find("Review: w-review")));
  const sys = prompts().at(-1) ?? "";
  t.check("the Chief's prompt carries the generated mode section", /## Mode: WARLORD/.test(sys) && /tier frontier: Sonnet 5\.5, high effort/.test(sys) && /tier opus: Opus 5\.5, high effort\. Planning a big project\. At most 4 a day/.test(sys) && /end of each milestone/.test(sys) && /Escalation: when a worker fails a task twice/.test(sys), sys.slice(sys.indexOf("## Mode"), sys.indexOf("## Mode") + 300));
  // Opus limit: WARLORD allows 4 a day; one is used, so three more fit and the fifth is downgraded.
  const more = await run(w.id, ["w-o2", "w-o3", "w-o4", "w-o5"], ["w-o2", "w-o3", "w-o4", "w-o5"].map((x) => start(x, { tier: "opus" })));
  const opusN = ["w-opus", ...Object.keys(more)].filter((k) => (k === "w-opus" ? W[k] : more[k]).model === "claude-opus-5-5").length;
  t.check("WARLORD allows 4 Opus chats a day; the 5th runs on Sonnet 5.5 high with a note", opusN === 4 && results().some((r) => /allows 4 Opus chats a day and it is used up/.test(r)), JSON.stringify({ opusN, notes: results().filter((r) => /used up/.test(r)).length }));

  // ---- SHINOBI -----------------------------------------------------------------------------------
  res = await C.call("chief.create", { mode: "shinobi", project_id: wid });
  const s = res.result?.chief;
  t.check("a SHINOBI Conductor: 1 at once, 15 a day", s?.mode === "shinobi" && s.max_parallel === 1 && s.daily_chats === 15, why(res));
  await C.call("chief.update", { chief_id: s.id, max_parallel: 8 });
  const S = await run(s.id, ["s-base", "s-frontier", "s-opus", "s-opus2", "s-review"], [
    start("s-base", { tier: "base" }), start("s-frontier", { tier: "frontier" }), start("s-opus", { tier: "opus" }), start("s-opus2", { tier: "opus" }), start("s-review", { role: "review", access: "read" }),
  ]);
  t.check("SHINOBI: base and frontier are Sonnet 5.5 medium", is(S["s-base"], "claude-sonnet-5-5", "medium") && is(S["s-frontier"], "claude-sonnet-5-5", "medium"), JSON.stringify([S["s-base"], S["s-frontier"]]));
  t.check("SHINOBI: the first Opus is Opus 5.5 medium; the second is downgraded (1 a day)", is(S["s-opus"], "claude-opus-5-5", "medium") && is(S["s-opus2"], "claude-sonnet-5-5", "medium") && results().some((r) => /allows 1 Opus chat a day/.test(r)), JSON.stringify([S["s-opus"], S["s-opus2"]]));
  t.check("SHINOBI: a reviewer is Sonnet 5.5 low", is(await find("Review: s-review"), "claude-sonnet-5-5", "low"), JSON.stringify(await find("Review: s-review")));
  const cx = await run(s.id, ["s-codex", "s-codex-f"], [start("s-codex", { engine: "codex", tier: "base" }), start("s-codex-f", { engine: "codex", tier: "frontier" })]);
  t.check("Codex gets only an effort from the mode (SHINOBI: base low, frontier medium) and keeps its own model", cx["s-codex"]?.engine === "codex" && cx["s-codex"].effort === "low" && !cx["s-codex"].model && cx["s-codex-f"].effort === "medium", JSON.stringify([cx["s-codex"], cx["s-codex-f"]]));
  // QA (testing the running app in the browser/simulator) runs on Sonnet whatever tier, and on Claude Code unless named.
  const Q = await run(s.id, ["s-qa", "s-qa-opus"], [start("s-qa", { kind: "qa", tier: "fast" }), start("s-qa-opus", { kind: "qa", tier: "opus" })]);
  t.check("SHINOBI: a qa worker runs on Claude Code Sonnet 5.5 medium even when tier fast was asked", is(Q["s-qa"], "claude-sonnet-5-5", "medium"), JSON.stringify(Q["s-qa"]));
  t.check("an explicit tier opus (escalation) still goes to Opus for qa", Q["s-qa-opus"]?.model === "claude-opus-5-5" || results().some((r) => /Opus chat a day/.test(r)), JSON.stringify(Q["s-qa-opus"]));
  t.check("the mode section tells the Conductor qa runs on Sonnet", /kind qa \(testing the running app.*Sonnet 5\.5, medium effort/.test(prompts().at(-1) ?? ""), (prompts().at(-1) ?? "").match(/.*kind qa.*/)?.[0]);

  // ---- GODMODE -----------------------------------------------------------------------------------
  res = await C.call("chief.create", { mode: "godmode", project_id: wid });
  const g = res.result?.chief;
  t.check("a GODMODE Conductor: 4 at once, 60 a day", g?.mode === "godmode" && g.max_parallel === 4 && g.daily_chats === 60, why(res));
  const G = await run(g.id, ["g-frontier", "g-o1", "g-o2", "g-o3", "g-review"], [
    start("g-frontier", { tier: "frontier" }), start("g-o1", { tier: "opus" }), start("g-o2", { tier: "opus" }), start("g-o3", { tier: "opus" }), start("g-review", { role: "review", access: "read" }),
  ]);
  t.check("GODMODE: frontier is Opus 5.5 high; Opus has no daily limit", is(G["g-frontier"], "claude-opus-5-5", "high") && ["g-o1", "g-o2", "g-o3"].every((k) => is(G[k], "claude-opus-5-5", "high")), JSON.stringify(G));
  const GQ = await run(g.id, ["g-qa"], [start("g-qa", { kind: "qa", tier: "frontier" })]);
  t.check("GODMODE: a qa worker is Sonnet 5.5 high, not Opus, at tier frontier", is(GQ["g-qa"], "claude-sonnet-5-5", "high"), JSON.stringify(GQ["g-qa"]));
  t.check("GODMODE: every behaviour-changing feature gets an Opus reviewer", is(await find("Review: g-review"), "claude-opus-5-5", "high"));

  // ---- switching ---------------------------------------------------------------------------------
  res = await C.call("chief.update", { chief_id: g.id, mode: "shinobi" });
  t.check("switching GODMODE -> SHINOBI re-applies the brain and limits and keeps the project", res.result?.chief.mode === "shinobi" && res.result.chief.max_parallel === 1 && res.result.chief.daily_chats === 15 && res.result.chief.project_ids.join() === wid, why(res));

  // ---- a plain Chief is untouched ---------------------------------------------------------------
  res = await C.call("chief.create", { name: "Boss" });
  const p = res.result?.chief;
  t.check("a plain Chief has no mode, a mascot, its crew rules and 3 at once", p && p.mode === undefined && !!p.avatar && /Crew rules/.test(p.soul) && p.max_parallel === 3 && p.updates === "results", why(res));
  await C.call("chief.update", { chief_id: p.id, project_ids: [wid], max_parallel: 8 });
  const P = await run(p.id, ["p-base", "p-front", "p-opus"], [start("p-base", { tier: "base" }), start("p-front", { tier: "frontier" }), start("p-opus", { tier: "opus" })]);
  t.check("its tiers are the plain classes (sonnet / opus aliases); tier opus counts as frontier", P["p-base"].model === "sonnet" && P["p-front"].model === "opus" && P["p-opus"].model === "opus", JSON.stringify([P["p-base"].model, P["p-front"].model, P["p-opus"].model]));
  await C.call("chief.note", { chief_id: p.id, text: "hello" });
  const own = async () => { for (let i = 0; i < 50; i++) { const x = prompts().filter((y) => y.includes(p.name) && !/## Mode: (GODMODE|WARLORD|SHINOBI)/.test(y.split("\n")[0])).at(-1); if (x) return x; await sleep(100); } return prompts().filter((y) => y.includes(p.name)).at(-1); };
  const plainPrompt = (await own()) ?? "";
  t.check("its prompt has no mode section", !!plainPrompt && !plainPrompt.includes("## Mode:"), plainPrompt.slice(0, 120));
  res = await C.call("chief.list", {});
  t.check("chief.list returns Conductors and plain Chiefs together (the app tells them apart by mode)", res.result?.chiefs.filter((c) => c.mode).length === 3 && res.result.chiefs.filter((c) => !c.mode).length === 1, why(res));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
