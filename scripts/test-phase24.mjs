// M2: the end-to-end pipeline and the safety fixes under it. A Conductor starts a
// pipeline; stages run in order on their own modes (GODMODE's Opus for the plan inside
// a WARLORD Conductor); stage_done is refused until a stage's chats have reported; a
// gated stage waits for the person, who approves or sends it back over RPC (the
// Conductor has no tool for it, and waiting does not approve it); a restart resumes a
// cut-off stage and restarts waiting work instead of failing it; a worker waiting on
// an approval no longer holds a SHINOBI Conductor's only slot.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p24-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "src"), { recursive: true });
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "shop" }));
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile, OPSCODE_CHIEF_TICK_MS: "400" };
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
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const chats = async () => (await C.call("chat.list", {})).result.chats;
  const view = async (id) => (await C.call("chief.get", { chief_id: id })).result;
  const toolResults = (name) => entries().filter((e) => e.chief_tool === name).map((e) => ({ text: e.result, err: e.is_error }));
  const prompts = () => entries().filter((e) => e.prompt).map((e) => e.prompt);
  const note = async (chief, text) => C.call("chief.note", { chief_id: chief, text });

  // ---- a pipeline in a WARLORD Conductor ----------------------------------------------------------
  const wl = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: wl.id, max_parallel: 8 });
  await note(wl.id, `build me a grocery app with a friday fish auction\n${tool("pipeline_start", { title: "Fish market", quotes: ["build me a grocery app with a friday fish auction"], project_ids: [wid], skip: ["ui", "test", "review"] })}`);
  const started = await waitFor(async () => toolResults("pipeline_start")[0]);
  t.check("the Conductor starts a pipeline", started && !started.err && /pipeline_id/.test(started.text), started?.text?.slice(0, 160));
  const pid = JSON.parse(started?.text ?? "{}").pipeline_id;
  const first = JSON.parse(started?.text ?? "{}").first_stage ?? "";
  t.check("the first stage's instructions come back at once (spec, the person's words, the file to write)", /stage="spec"/.test(first) && /docs\/opscode\/fish-market\/spec\.md/.test(first) && /friday fish auction/.test(first), first.slice(0, 200));
  let v = await view(wl.id);
  let pl = v.pipelines.find((x) => x.id === pid);
  t.check("the board lists the pipeline: spec running, skipped stages marked", pl?.state === "running" && pl.stages[0].state === "running" && pl.stages.find((s) => s.id === "ui").state === "skipped", JSON.stringify(pl?.stages?.map((s) => s.id + ":" + s.state)));
  const specItem = v.items.find((i) => i.id === pl.stages[0].item_id);
  t.check("the spec stage has its own item, on WARLORD (the stage's mode)", specItem?.title === "Fish market · Spec" && specItem.mode === "warlord" && specItem.pipeline?.stage === "spec", JSON.stringify(specItem));

  await note(wl.id, `next\n${tool("stage_done", { pipeline_id: pid, summary: "nothing yet" })}`);
  const early = await waitFor(async () => toolResults("stage_done")[0]);
  t.check("stage_done is refused while the stage has no chats", early?.err && /no chats yet/.test(early.text), early?.text);

  const work = (ref, title, extra = {}) => tool("chat_start", { item_id: `[[${ref}]]`, title, brief: `Goal: ${title} FAKE_REPORT=done FAKE_CHECK`, quotes: ["build me a grocery app with a friday fish auction"], project_ids: [wid], engine: "claude-code", kind: "plan", ...extra });
  const stageItem = async (stage) => { const vv = await view(wl.id); const p2 = vv.pipelines.find((x) => x.id === pid); return vv.items.find((i) => i.id === p2.stages.find((s) => s.id === stage).item_id); };
  const finish = async (stage, extra) => {
    const it = await stageItem(stage);
    await note(wl.id, `go\n${work(it.ref, `${stage} work`, extra)}`);
    await waitFor(async () => { const i = await stageItem(stage); return i.chats.length && i.chats.every((c) => c.state === "idle") ? i : null; });
    const n = toolResults("stage_done").length;
    await note(wl.id, `done\n${tool("stage_done", { pipeline_id: pid, summary: `${stage} written` })}`);
    return waitFor(async () => toolResults("stage_done")[n]);
  };
  const r1 = await finish("spec");
  const next1 = r1 ? JSON.parse(r1.text).next_stage ?? "" : "";
  t.check("after the spec chat reports, stage_done moves on to the gap report", r1 && !r1.err && /stage="gap"/.test(next1), r1?.text?.slice(0, 120));
  const gapItem = await stageItem("gap");
  t.check("the gap stage runs on SHINOBI and points at spec.md", gapItem?.mode === "shinobi" && /spec\.md/.test(next1));
  const specBrief = prompts().find((x) => x.startsWith("Goal: spec work")) ?? "";
  t.check("a kind plan worker gets the planning skill", /How to write a planning document/.test(specBrief), specBrief.slice(0, 100));

  await finish("gap");
  const planItem = await stageItem("plan");
  t.check("the plan stage runs on GODMODE inside a WARLORD Conductor", planItem?.mode === "godmode", planItem?.mode);
  const r3 = await finish("plan", { tier: "opus" });
  const planChat = (await chats()).find((c) => c.title === "plan work");
  t.check("so its tier-opus planner runs on Opus at high effort (GODMODE's table)", planChat?.model === "claude-opus-5-5" && planChat.effort === "high", JSON.stringify([planChat?.model, planChat?.effort]));
  t.check("stage_done on the plan stops at the gate and says only the person can approve", r3 && !r3.err && /waits_for_the_person/.test(r3.text) && /cannot approve/.test(r3.text), r3?.text);
  pl = (await view(wl.id)).pipelines.find((x) => x.id === pid);
  t.check("the pipeline waits at the plan gate; no build stage yet", pl.state === "gate" && pl.stages.find((s) => s.id === "plan").state === "gate" && !pl.stages.find((s) => s.id === "build").item_id);
  const toolNames = entries().filter((e) => e.argv && e.bin === "claude" && e.argv.includes("--mcp-config")).length;
  await C.call("chief.update", { chief_id: wl.id, autonomy: 3 });
  await note(wl.id, "anything new?");
  await sleep(1500);
  pl = (await view(wl.id)).pipelines.find((x) => x.id === pid);
  t.check("waiting (even at autonomy 3) does not approve the gate", pl.state === "gate", pl.state);
  const again = await C.call("chief.pipeline.approve", { pipeline_id: "pl_nope" });
  t.check("approving an unknown pipeline is an error", !!again.error);

  // ---- send back, then approve ----------------------------------------------------------------------
  await C.call("chief.pipeline.reject", { pipeline_id: pid, text: "split the auction into its own milestone" });
  pl = (await view(wl.id)).pipelines.find((x) => x.id === pid);
  t.check("sending the plan back reopens the same stage", pl.state === "running" && pl.stages.find((s) => s.id === "plan").state === "running", pl.state);
  const sent = await waitFor(async () => prompts().find((x) => x.includes('sent_back="true"') && x.includes("split the auction into its own milestone")));
  t.check("the Conductor reads the person's words and that the stage was sent back", !!sent);
  const nDone = toolResults("stage_done").length;
  await note(wl.id, `redo\n${tool("stage_done", { pipeline_id: pid, summary: "plan with an auction milestone" })}`);
  await waitFor(async () => toolResults("stage_done")[nDone]);
  const ok = await C.call("chief.pipeline.approve", { pipeline_id: pid });
  t.check("the person approves over RPC", !ok.error && ok.result.pipeline.state === "running", JSON.stringify(ok.error ?? ok.result?.pipeline?.state));
  const buildItem = await waitFor(async () => stageItem("build"));
  t.check("the build stage starts by itself, on SHINOBI", buildItem?.mode === "shinobi", buildItem?.mode);
  const buildWake = await waitFor(async () => prompts().find((x) => x.includes('stage="build"') && x.includes("<pipeline_approved")));
  t.check("and the Conductor is woken with the approval and the build stage's instructions", !!buildWake);
  const m1 = await C.call("chief.pipeline.mode", { pipeline_id: pid, stage: "build", mode: "godmode" });
  t.check("the person can change a running stage's mode", m1.result?.pipeline?.stages?.find((s) => s.id === "build").mode === "godmode" && (await stageItem("build")).mode === "godmode");
  const m2 = await C.call("chief.pipeline.mode", { pipeline_id: pid, stage: "spec", mode: "godmode" });
  t.check("but not a finished one's", !!m2.error);

  // ---- a stage cut off by a restart is resumed, not failed ------------------------------------------
  const bi = await stageItem("build");
  await note(wl.id, `build\n${tool("chat_start", { item_id: `[[${bi.ref}]]`, title: "slow build", brief: "Goal: slow build FAKE_HANG", quotes: ["build me a grocery app with a friday fish auction"], project_ids: [wid], engine: "claude-code", kind: "feature" })}`);
  await waitFor(async () => (await stageItem("build")).chats.some((c) => c.state === "running"));
  const nd2 = toolResults("stage_done").length;
  await note(wl.id, `check\n${tool("stage_done", { pipeline_id: pid, summary: "too early" })}`);
  const busy = await waitFor(async () => toolResults("stage_done")[nd2]);
  t.check("stage_done is refused while a chat of the stage still runs", busy?.err && /still has chats running/.test(busy.text), busy?.text);
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  t.check("runtime restarts", rt.ready);
  C = await session(rt);
  const after = await stageItem("build");
  t.check("after the restart the build stage is not failed: queued, waiting for its Conductor", after.state === "queued" && /Conductor resumes it/.test(after.detail ?? ""), JSON.stringify([after.state, after.detail]));
  const resumed = await waitFor(async () => prompts().find((x) => x.includes('stage="build"') && x.includes('resumed="true"')));
  t.check("and the Conductor is woken to continue it, not start over", !!resumed && /do not start over/.test(resumed));

  // ---- SHINOBI: an approval wait does not hold the only slot ----------------------------------------
  const sh = (await C.call("chief.create", { mode: "shinobi", project_id: wid })).result.chief;
  t.check("SHINOBI has one slot", sh.max_parallel === 1);
  await note(sh.id, `go\n${tool("chat_start", { title: "needs ok", brief: "Goal: needs ok FAKE_WRITE", quotes: ["go"], project_ids: [wid], engine: "claude-code", access: "read" })}`);
  await waitFor(async () => (await view(sh.id)).items.find((i) => i.title === "needs ok")?.state === "needs_you");
  await note(sh.id, `more\n${tool("chat_start", { title: "next job", brief: "Goal: next job FAKE_REPORT=done FAKE_CHECK", quotes: ["more"], project_ids: [wid], engine: "claude-code" })}`);
  const next = await waitFor(async () => (await chats()).find((c) => c.title === "next job"));
  t.check("a worker waiting on the person's approval does not block the next job", !!next);

  // ---- waiting work survives a restart --------------------------------------------------------------
  const one = (await C.call("chief.create", { mode: "shinobi", project_id: wid })).result.chief;
  await note(one.id, `go\n${tool("chat_start", { title: "first", brief: "Goal: first FAKE_HANG", quotes: ["go"], project_ids: [wid, wid], engine: "claude-code" })}`);
  await waitFor(async () => { const i = (await view(one.id)).items.find((x) => x.title === "first"); return i?.pending?.length && i.chats.length === 1 ? i : null; });
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  C = await session(rt);
  const w2 = await waitFor(async () => { const i = (await view(one.id)).items.find((x) => x.title === "first"); return i && i.chats.length === 2 ? i : null; }, 10000);
  const iFirst = (await view(one.id)).items.find((x) => x.title === "first");
  t.check("an item that still had a chat waiting to start is not failed by a restart; the waiting chat starts", !!w2 && iFirst.state !== "failed", JSON.stringify([iFirst?.state, iFirst?.chats?.length, iFirst?.detail]));

  // ---- a plain Chief has no pipeline tools ----------------------------------------------------------
  const boss = (await C.call("chief.create", { name: "Boss" })).result.chief;
  await C.call("chief.update", { chief_id: boss.id, project_ids: [wid] });
  const nP = toolResults("pipeline_start").length;
  await note(boss.id, `try\n${tool("pipeline_start", { title: "x", quotes: ["try"], project_ids: [wid] })}`);
  const plainTry = await waitFor(async () => toolResults("pipeline_start")[nP]);
  t.check("a plain Chief cannot start a pipeline", !plainTry || plainTry.err || !/pipeline_id/.test(plainTry.text), plainTry?.text?.slice(0, 120));
  void toolNames;
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
