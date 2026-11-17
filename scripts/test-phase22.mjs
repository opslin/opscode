// Worker skills and the finish check: a Conductor worker's brief carries the skill
// matching its kind (fix / feature / chore) or role (review); a build worker whose
// report has no Check line is sent back once by the runtime before the Chief hears;
// a plain Chief and a Normal chat get none of it.

import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p22-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "src"), { recursive: true });
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "shop", scripts: { test: "x" } }));
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
  const prompts = () => entries().filter((e) => e.prompt).map((e) => e.prompt);
  const briefs = () => prompts().filter((p) => !p.includes("<board>"));
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };

  const w = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: w.id, max_parallel: 8 });

  // ---- skills by kind and role --------------------------------------------------------------------
  await C.call("chief.note", { chief_id: w.id, text: [
    "go",
    start("fixjob", { kind: "fix" }).replace('"Goal: fixjob"', '"Goal: fixjob FAKE_REPORT=done"'),
    start("proved", { kind: "fix" }).replace('"Goal: proved"', '"Goal: proved FAKE_REPORT=done FAKE_CHECK"'),
    start("asker", { kind: "fix" }).replace('"Goal: asker"', '"Goal: asker FAKE_REPORT=question"'),
    start("feat", { kind: "feature" }).replace('"Goal: feat"', '"Goal: feat FAKE_REPORT=done FAKE_CHECK"'),
    start("nokind", {}).replace('"Goal: nokind"', '"Goal: nokind FAKE_REPORT=done FAKE_CHECK"'),
    start("rev", { role: "review", kind: "fix" }).replace('"Goal: rev"', '"Goal: rev FAKE_REPORT=done FAKE_CHECK"'),
  ].join("\n") });

  // ---- the Conductor's own instructions carry the job-size and change-set rules -------------------
  const argvs = () => entries().filter((e) => e.argv).map((e) => e.argv.join(" "));
  await waitFor(async () => argvs().some((a) => a.includes("Job size")));
  t.check("the Conductor is told: job size first, a fix gets no plan stage", argvs().some((a) => a.includes("Job size, before anything else") && a.includes("no plan stage")), argvs().at(-1)?.slice(0, 120));
  t.check("and the change-set rule: one chat per project with a shared contract", argvs().some((a) => a.includes("change set: one build chat per project") && a.includes("shared contract")));
  t.check("and that a report without a Check line proves nothing", argvs().some((a) => a.includes("Check line is missing proves nothing")));

  const briefOf = async (title) => (await waitFor(async () => briefs().find((p) => p.includes(`Goal: ${title}`)))) ?? "";
  const fix = await briefOf("fixjob");
  t.check("a kind fix worker gets the fix skill (reproduce, first error, smallest fix)", /How to fix/.test(fix) && /Reproduce it first/.test(fix) && /first error, not the last/.test(fix), fix.slice(0, 160));
  t.check("the fix skill sits between the brief and the working rules, report format last", fix.indexOf("Goal: fixjob") < fix.indexOf("How to fix") && fix.indexOf("How to fix") < fix.indexOf("Working rules") && fix.indexOf("Working rules") < fix.indexOf("Status: done | review | question | blocked"));
  t.check("the working rules now end with the finish check", /Before you say done: run the check that proves the goal itself/.test(fix));
  const feat = await briefOf("feat");
  t.check("a kind feature worker gets the build skill (Done when, reuse first)", /How to build/.test(feat) && /Done when lines first/.test(feat) && /Copy and adapt beats new code/.test(feat), feat.slice(0, 120));
  const rev = await briefOf("rev");
  t.check("a reviewer gets the review skill, never the fix skill", /How to review/.test(rev) && /count it as passing/.test(rev) && /Change nothing/.test(rev) && !/How to fix/.test(rev), rev.slice(0, 120));
  const nokind = await briefOf("nokind");
  t.check("no kind: rules and map, but no skill", !/How to fix|How to build|How to review/.test(nokind) && /Working rules/.test(nokind), nokind.slice(0, 120));

  // ---- the finish check ---------------------------------------------------------------------------
  const nudges = () => briefs().filter((p) => p.includes("no Check line, so nothing proves the work"));
  const nudged = await waitFor(async () => nudges().find((p) => true));
  t.check("a done report with no Check line sends the worker back once", !!nudged && /run the check that proves the goal itself/i.test(nudged ?? ""), (nudged ?? "").slice(0, 140));
  const updates = () => prompts().filter((p) => p.includes("<chat_update"));
  await waitFor(async () => updates().some((p) => p.includes('title="fixjob"')));
  await sleep(800);
  t.check("the Chief hears about that worker only after the second answer", updates().some((p) => p.includes('title="fixjob"')), updates().join(" ").slice(0, 100));
  t.check("one reminder only, ever, for that chat", nudges().length === 1, String(nudges().length));
  t.check("a report that carries a Check line is never sent back", !nudges().some((p) => p.includes("proved")) && updates().some((p) => p.includes('title="proved"')));
  t.check("a question is never sent back (it has no check to run)", updates().some((p) => p.includes('title="asker"') && p.includes("question")) && !briefs().some((p) => p.includes("asker") && p.includes("no Check line")));
  const view = (await C.call("chief.get", { chief_id: w.id })).result;
  const fixItem = view.items.find((i) => i.title === "fixjob");
  t.check("the board keeps the worker's kind", fixItem?.chats?.[0]?.kind === "fix", JSON.stringify(fixItem?.chats?.[0]));

  // ---- a plain Chief stays as it was --------------------------------------------------------------
  writeFileSync(logFile, "");
  const p = (await C.call("chief.create", { name: "Boss" })).result.chief;
  await C.call("chief.update", { chief_id: p.id, project_ids: [wid], max_parallel: 8 });
  await C.call("chief.note", { chief_id: p.id, text: `go\n${start("plainjob", { kind: "fix" }).replace('"Goal: plainjob"', '"Goal: plainjob FAKE_REPORT=done"')}` });
  const plain = await briefOf("plainjob");
  t.check("a plain Chief's worker gets no skill and no working rules", plain && !/How to fix|Working rules/.test(plain), plain.slice(0, 120));
  await sleep(1200);
  t.check("and its missing Check line is not chased", !briefs().some((x) => x.includes("plainjob") && x.includes("no Check line")));

  // ---- a Normal chat is untouched -----------------------------------------------------------------
  writeFileSync(logFile, "");
  const normal = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", model: "claude-sonnet-5-5" })).result.chat;
  await C.call("turn.submit", { workspace_id: wid, chat_id: normal.id, text: "hello FAKE_REPORT=done" });
  await waitFor(async () => briefs().some((x) => x.includes("hello")));
  await sleep(1000);
  t.check("a Normal chat gets no skills, rules or reminders", briefs().every((x) => !/How to fix|Working rules|no Check line/.test(x)), briefs().join(" ").slice(0, 120));
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
