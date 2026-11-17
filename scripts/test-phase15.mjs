// Automations: file format checks, templates, the simple form, runs (run/prompt/agent
// steps on engines, needs/if/decides, checks with a reviewer, retries + escalation,
// approval gates, inputs, budget, cancel), schedules, scopes and history.
// Engines are the fake Claude Code / Codex CLIs.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004, CONFLICT: -32009 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 300);
const spec = await import(pathToFileURL(join(process.cwd(), "dist/runtime/automations/spec.js")).href);

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p15-")));
const proj = join(base, "project");
mkdirSync(proj);
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const stateDir = join(base, "state");
const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const write = (name, text, scope = "project") => C.call("automation.file_write", { workspace_id: wid, scope, name, text });
  const runOf = async (id) => (await C.call("automation.run_get", { run_id: id })).result.run;
  const until = async (id, pred, ms = 15000) => { let r; await waitFor(async () => false, 1); for (const end = Date.now() + ms; Date.now() < end; await new Promise((x) => setTimeout(x, 100))) { r = await runOf(id); if (pred(r)) return r; } return r; };
  const ended = (r) => ["succeeded", "failed", "cancelled"].includes(r.status);
  const start = (name, inputs, scope = "project") => C.call("automation.run", { workspace_id: wid, scope, name, ...(inputs ? { inputs } : {}) });
  const step = (r, n) => r.steps.find((s) => s.name === n);

  // ---- checking files -----------------------------------------------------------------------------
  const bad = [
    ["not yaml", "steps: [", /not valid YAML/],
    ["unknown top key", "steps: { a: { run: ls } }\ncolor: red", /unknown key color/],
    ["two kinds", "steps:\n  a: { run: ls, prompt: hi }", /exactly one of/],
    ["needs a later step", "steps:\n  a: { prompt: x, needs: [b] }\n  b: { prompt: y }", /comes later/],
    ["if on a non-decider", "steps:\n  a: { prompt: x }\n  b: { prompt: y, if: { a: yes } }", /never decides yes/],
    ["bad schedule time", "on: { schedule: { at: \"9am\" } }\nsteps: { a: { prompt: x } }", /24-hour time/],
    ["too-frequent schedule", "on: { schedule: { every: 1m } }\nsteps: { a: { prompt: x } }", /at least 5m/],
    ["escalate without retries", "steps:\n  a: { prompt: x, escalate: frontier }", /escalate needs retries/],
    ["a multi-line command", "steps:\n  a: { run: \"ls\\nrm -rf /\" }", /one command line/],
    ["a dollar budget", "budget: { usd: 5 }\nsteps: { a: { prompt: x } }", /tokens and turns/],
  ];
  for (const [name, text, re] of bad) {
    const res = await write("broken", text);
    t.check(`a file with ${name} is reported`, res.result?.diagnostics.some((d) => re.test(d.message) && d.line >= 1), why(res));
  }
  let res = await C.call("automation.list", { workspace_id: wid });
  t.check("a broken file is listed as not ok", res.result?.automations.some((a) => a.name === "broken" && a.ok === false), why(res));
  res = await start("broken");
  t.check("a broken automation can't run", res.error?.code === E.INVALID, why(res));
  res = await C.call("automation.set_enabled", { workspace_id: wid, scope: "project", name: "broken", enabled: true });
  t.check("a broken automation can't be turned on", res.error?.code === E.INVALID, why(res));
  res = await write("Bad Name", "steps: { a: { prompt: x } }");
  t.check("file names are checked", res.error?.code === E.INVALID, why(res));

  // ---- templates and the simple form ---------------------------------------------------------------------
  res = await C.call("automation.templates");
  t.check("templates include the software agency and marketing", ["software-agency", "fix-failing-tests", "daily-digest", "launch-post"].every((id) => res.result?.templates.some((x) => x.id === id)), why(res));
  for (const tp of res.result.templates) {
    const r = spec.parseAutomation(tp.name, tp.text);
    t.check(`template ${tp.id} is a valid automation`, r.diagnostics.length === 0, JSON.stringify(r.diagnostics));
  }
  res = await C.call("automation.from_template", { workspace_id: wid, scope: "project", template: "software-agency" });
  t.check("a template is written to .opscode/automations", res.result?.name === "build-from-brief" && existsSync(join(proj, ".opscode/automations/build-from-brief.yaml")), why(res));
  res = await C.call("automation.from_template", { workspace_id: wid, scope: "project", template: "software-agency" });
  t.check("writing it twice is refused", res.error?.code === E.CONFLICT, why(res));
  res = await C.call("automation.list", { workspace_id: wid });
  const agency = res.result.automations.find((a) => a.name === "build-from-brief");
  t.check("the agency pipeline: Claude Code plans, Codex builds the UI, a reviewer checks", agency?.ok && agency.steps.find((s) => s.name === "ui")?.engine === "codex" && agency.steps.find((s) => s.name === "plan")?.approve === true && agency.steps.find((s) => s.name === "build")?.checks.includes("agent reviewer") && agency.trigger === "By hand", JSON.stringify(agency?.steps));
  res = await C.call("automation.create", { workspace_id: wid, scope: "me", title: "Nightly notes", prompt: "Summarise today's work", schedule: "weekdays", engine: "codex" });
  t.check("the simple form writes a personal automation", res.result?.name === "nightly-notes" && res.result.diagnostics.length === 0, why(res));
  const mePath = join(stateDir, "automations", wid, "nightly-notes.yaml");
  t.check("personal automations live in Opscode's data folder (0600), not the repo", existsSync(mePath) && (statSync(mePath).mode & 0o777) === 0o600 && !existsSync(join(proj, ".opscode/automations/nightly-notes.yaml")));
  res = await C.call("automation.get", { workspace_id: wid, scope: "me", name: "nightly-notes" });
  t.check("its schedule reads as Weekdays at 09:00, off until turned on", res.result?.automation.trigger === "Weekdays at 09:00" && res.result.automation.enabled === false && res.result.automation.next_run === null, why(res));
  res = await C.call("automation.set_enabled", { workspace_id: wid, scope: "me", name: "nightly-notes", enabled: true });
  const next = new Date(res.result?.automation.next_run);
  t.check("turned on, it shows the next run on a weekday at 09:00", res.result?.automation.enabled && next.getHours() === 9 && next.getMinutes() === 0 && next.getDay() >= 1 && next.getDay() <= 5 && next > new Date(), why(res));

  // ---- schedule maths --------------------------------------------------------------------------------------
  const fri = new Date(2026, 10, 13, 10, 0); // Fri 13 Nov 2026 10:00
  t.check("weekdays at 09:00 after Friday 10:00 is Monday 09:00", spec.nextFire({ at: "09:00", weekdays: [1, 2, 3, 4, 5] }, fri).toString() === new Date(2026, 10, 16, 9, 0).toString());
  t.check("daily at 09:00 after 08:00 is the same day", spec.nextFire({ at: "09:00" }, new Date(2026, 10, 13, 8, 0)).toString() === new Date(2026, 10, 13, 9, 0).toString());
  t.check("every 30m counts from the last run", spec.nextFire({ every_ms: 1800000 }, fri, fri).getTime() === fri.getTime() + 1800000);

  // ---- a run: run step, decisions, if, skip ----------------------------------------------------------------
  await write("flow", `description: decide and branch
steps:
  hello:
    run: printf 'hi from shell'
  choose:
    prompt: Pick one. FAKE_DECIDE=go
    decides: [go, stop]
  went:
    if: { choose: go }
    prompt: You chose go.
  stopped:
    if: { choose: stop }
    prompt: You chose stop.
`);
  res = await start("flow");
  t.check("a run starts", res.result?.run.status === "running", why(res));
  let run = await until(res.result.run.id, ended);
  t.check("it succeeds", run.status === "succeeded", JSON.stringify(run).slice(0, 400));
  t.check("the shell step's output is kept", step(run, "hello").status === "succeeded" && step(run, "hello").attempts[0].output === "hi from shell");
  t.check("the agent's decision is read", step(run, "choose").decision === "go");
  t.check("if: runs the matching branch and skips the other, saying why", step(run, "went").status === "succeeded" && step(run, "stopped").status === "skipped" && /did not decide stop/.test(step(run, "stopped").why));
  t.check("tokens and turns are counted", run.turns === 2 && run.tokens > 0, `${run.turns} turns, ${run.tokens} tokens`);
  const chats = (await C.call("chat.list", {})).result.chats.filter((c) => c.origin?.run_id === run.id);
  t.check("each agent step ran in its own chat, marked with the automation", chats.length === 2 && chats.every((c) => c.engine === "claude-code" && c.mode === "read" && c.title.startsWith("flow · ")), JSON.stringify(chats.map((c) => [c.title, c.engine, c.mode])));
  const choosePrompt = entries().filter((e) => e.prompt?.includes("You chose go.")).at(-1)?.prompt ?? "";
  t.check("later steps get earlier results as data", choosePrompt.includes("Results of earlier steps") && choosePrompt.includes("### choose (decided go)"));

  // ---- checks: reviewer asks for changes, the retry escalates and passes ------------------------------------
  await write("review", `steps:
  build:
    agent: builder
    prompt: Build the feature.
    checks:
      - agent: reviewer
    retries: 1
    escalate: frontier
`);
  res = await start("review");
  run = await until(res.result.run.id, ended);
  const b = step(run, "build");
  t.check("the reviewer asked for changes on attempt 1, approved attempt 2", run.status === "succeeded" && b.attempts.length === 2 && b.attempts[0].checks[0].ok === false && b.attempts[1].checks[0].ok === true, JSON.stringify(b).slice(0, 500));
  t.check("attempt 1 ran on base (Sonnet) with edit access, attempt 2 escalated to frontier (Opus)", b.attempts[0].model === "sonnet" && b.attempts[1].model === "opus");
  const retryPrompt = entries().filter((e) => e.prompt?.includes("did not pass its checks")).at(-1)?.prompt ?? "";
  t.check("the retry is told what the reviewer found", retryPrompt.includes("The reviewer asked for changes") && retryPrompt.includes("Missing the main part"));
  t.check("the builder ran with edit access (auto_edits), the reviewer read-only", (await C.call("chat.list", {})).result.chats.filter((c) => c.origin?.run_id === run.id).map((c) => `${c.origin.step}:${c.mode}`).sort().join() === "build-reviewer:read,build-reviewer:read,build:auto_edits,build:auto_edits");

  // ---- a failing command check fails the step and the run --------------------------------------------------------
  await write("strict", `steps:
  build:
    prompt: Do it.
    checks: ["exit 3"]
  after:
    prompt: Never runs.
`);
  res = await start("strict");
  run = await until(res.result.run.id, ended);
  t.check("a failing check fails the step and stops the run", run.status === "failed" && step(run, "build").status === "failed" && /exit 3/.test(step(run, "build").why) && step(run, "after").status === "cancelled", JSON.stringify(run).slice(0, 400));

  // ---- approval gate ----------------------------------------------------------------------------------------------
  await write("gated", `steps:
  plan:
    prompt: Make a plan.
    approve: true
  build:
    needs: [plan]
    prompt: Build it.
`);
  res = await start("gated");
  run = await until(res.result.run.id, (r) => r.status === "waiting");
  t.check("the run waits for you after an approve: step", run.status === "waiting" && step(run, "plan").status === "waiting_approval" && step(run, "build").status === "pending");
  res = await C.call("automation.approve", { run_id: run.id, step: "build", decision: "approve" });
  t.check("only a waiting step can be approved", res.error?.code === E.INVALID, why(res));
  await C.call("automation.approve", { run_id: run.id, step: "plan", decision: "approve" });
  run = await until(run.id, ended);
  t.check("after Approve it continues", run.status === "succeeded" && step(run, "build").status === "succeeded");
  res = await start("gated");
  run = await until(res.result.run.id, (r) => r.status === "waiting");
  await C.call("automation.approve", { run_id: run.id, step: "plan", decision: "reject" });
  run = await until(run.id, ended);
  t.check("after Reject the run fails and later steps don't run", run.status === "failed" && step(run, "plan").why === "You rejected it" && step(run, "build").status !== "succeeded");

  // ---- inputs ------------------------------------------------------------------------------------------------------------
  await write("echoer", `inputs:
  word: { description: A word, required: true }
steps:
  say:
    run: printf '%s' {{inputs.word}}
`);
  res = await start("echoer");
  t.check("a required input must be given", res.error?.code === E.INVALID && /word/.test(res.error.message), why(res));
  res = await start("echoer", { word: "x", other: "y" });
  t.check("unknown inputs are refused", res.error?.code === E.INVALID, why(res));
  res = await start("echoer", { word: "a b; touch PWNED" });
  run = await until(res.result.run.id, ended);
  t.check("inputs go into commands as one quoted argument (no injection)", step(run, "say").attempts[0].output === "a b; touch PWNED" && !existsSync(join(proj, "PWNED")), step(run, "say").attempts[0].output);

  // ---- budget ------------------------------------------------------------------------------------------------------------
  await write("thrifty", `budget: { turns: 1 }
steps:
  one: { prompt: First. }
  two: { prompt: Second. }
`);
  res = await start("thrifty");
  run = await until(res.result.run.id, ended);
  t.check("the budget stops the run", run.status === "failed" && /Budget reached: 1 of 1 turns/.test(run.error) && step(run, "two").status !== "succeeded", run.error);

  // ---- cancel ------------------------------------------------------------------------------------------------------------
  await write("slow", `steps:
  wait: { prompt: FAKE_HANG }
`);
  res = await start("slow");
  run = await until(res.result.run.id, (r) => step(r, "wait").attempts.length === 1);
  res = await start("slow");
  t.check("the same automation can't run twice at once", res.error?.code === E.INVALID && /already running/.test(res.error.message), why(res));
  await C.call("automation.run_cancel", { run_id: run.id });
  run = await until(run.id, ended);
  t.check("Cancel stops the run and its chat", run.status === "cancelled" && step(run, "wait").status === "cancelled");

  // ---- history and deleting ----------------------------------------------------------------------------------------------
  res = await C.call("automation.runs", { workspace_id: wid, name: "gated" });
  t.check("run history per automation, newest first", res.result?.runs.length === 2 && res.result.runs[0].status === "failed", why(res));
  res = await C.call("automation.delete", { workspace_id: wid, scope: "project", name: "broken" });
  t.check("delete removes the file", res.result?.deleted === true && !existsSync(join(proj, ".opscode/automations/broken.yaml")));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
