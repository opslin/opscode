// Hand-off slice H2: the task plan survives a switch in both directions. Codex plans (its own plan
// events or task_checkpoint), Claude Code continues and updates the same plan; Opscode keeps it in the
// ledger and writes <project>/.opscode/tasks/<chat>/plan.md (git-ignored) that both engines can read.
import { existsSync, mkdtempSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const L = await import(join(process.cwd(), "dist/runtime/ledger.js"));
const CL = await import(join(process.cwd(), "dist/runtime/engines/claude.js"));

// ---- pure ------------------------------------------------------------------------------------------------
t.check("plan status words from every engine map to pending / in_progress / done", L.planStatus("completed") === "done" && L.planStatus("inProgress") === "in_progress" && L.planStatus("in_progress") === "in_progress" && L.planStatus("done") === "done" && L.planStatus("pending") === "pending" && L.planStatus(undefined) === "pending");
const md = L.planMarkdown({ version: 1, chat_id: "c", goal: "Fix cart", decisions: [{ text: "Keep the API shape", by: "codex", at: "x" }], plan: { steps: [{ step: "Read", status: "done" }, { step: "Fix", status: "in_progress" }], by: "codex", at: "x" }, next: { text: "run tests", by: "codex", at: "x" }, user_messages: [], files_changed: [], files_read: [], commands: [], denied: [], turns: [], last_reply: "", updated_at: "now" });
t.check("the plan file shows goal, ticked steps, decisions and next step", /Goal: Fix cart/.test(md) && /1\. \[x\] Read/.test(md) && /2\. \[ \] Fix \(in progress\)/.test(md) && /Keep the API shape \(codex\)/.test(md) && /## Next step\nrun tests/.test(md), md);
t.check("a plan written as a list is read from the reply (numbered items, details skipped, markdown removed)", JSON.stringify(L.planFromReply("Plan:\n1. **Read** `a.ts`\n   - detail\n2. Fix [b.ts](/abs/b.ts)\n\n- aside")) === '["Read a.ts","Fix b.ts"]' && L.planFromReply("just text\n- one").length === 0);
t.check("every engine is told to keep the task state (the note is added when the tool is there)", /task_checkpoint/.test(CL.devicesNote(["task_checkpoint"])) && !/task_checkpoint/.test(CL.devicesNote(["browser_read"])));

// ---- live --------------------------------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p34-")));
writeFileSync(join(base, "package.json"), "{}");
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(60)) { const v = await fn(); if (v) return v; } return null; };
  const ended = (tid) => waitFor(() => C.find("turn.event", (p) => p.turn_id === tid && ["completed", "failed", "interrupted"].includes(p.type))[0]);
  const say = async (chatId, text) => { const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result; await ended(r.turn_id); return r.turn_id; };
  const dev = (name, args) => `FAKE_DEVICE ${name} ${JSON.stringify(args)}`;

  // 1. Codex plans in a READ-ONLY chat (planning must not need edit rights).
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "read", engine: "codex", model: "gpt-fake" })).result.chat;
  const ledger = async () => (await C.call("chat.ledger", { chat_id: chat.id })).result.ledger;
  const planFile = join(base, ".opscode", "tasks", chat.id, "plan.md");
  const t1 = await say(chat.id, ["Plan the cart fix, Codex.", dev("task_checkpoint", { plan: [{ step: "Read cart.ts", status: "done" }, { step: "Fix total()", status: "pending" }, { step: "Run npm test", status: "pending" }], decisions: ["Keep the public API of cart.ts", "API_KEY=abcdef123456 stays in .env"], next: "Fix total() in src/cart.ts" })].join("\n"));
  const r1 = entries().find((e) => e.bin === "codex" && e.device_tool === "task_checkpoint");
  t.check("Codex's task_checkpoint works in a read-only chat and says where the plan file is", r1 && !r1.is_error && /Saved plan \(3 steps\), decision, decision, next step\. Plan file: \.opscode\/tasks\//.test(r1.result), JSON.stringify(r1));
  const card = C.find("turn.event", (p) => p.turn_id === t1 && p.type === "tool_start")[0];
  t.check("its card says what was saved", /Checkpoint: plan 1\/3 done, 2 decisions, next: Fix total/.test(card?.params?.summary ?? ""), card?.params?.summary);
  let l = await ledger();
  t.check("the plan is in the ledger, signed by engine and model", l?.plan?.steps.length === 3 && l.plan.by === "codex/gpt-fake" && l.plan.steps[0].status === "done", JSON.stringify(l?.plan));
  t.check("decisions and next step are kept; a secret in a decision is hidden", l?.decisions.length === 2 && l.next?.text === "Fix total() in src/cart.ts" && !JSON.stringify(l).includes("abcdef123456"));
  t.check("plan.md is written in the project, private, inside a git-ignored folder", existsSync(planFile) && (statSync(planFile).mode & 0o777) === 0o600 && readFileSync(join(base, ".opscode", "tasks", ".gitignore"), "utf8").trim() === "*");
  t.check("plan.md has the plan Codex made", /\[x\] Read cart\.ts/.test(readFileSync(planFile, "utf8")) && /Keep the public API/.test(readFileSync(planFile, "utf8")));

  // 2. Codex's own plan events (update_plan) are picked up for free.
  await say(chat.id, "Go on FAKE_CODEX_PLAN");
  l = await ledger();
  t.check("Codex's own plan (turn/plan/updated) replaces the plan, statuses mapped", l?.plan?.steps.map((s) => s.status).join(",") === "done,in_progress,pending" && l.plan.explanation === "Codex plan", JSON.stringify(l?.plan));
  t.check("…and the decisions made earlier stay", l?.decisions.length === 2);

  // 3. Switch to Claude Code to build: it has the same tool and the same note, and updates the same plan.
  await C.call("chat.set_mode", { chat_id: chat.id, mode: "full" });
  await C.call("chat.set_engine", { chat_id: chat.id, engine: "claude-code", model: "claude-sonnet-5-5" });
  await say(chat.id, ["Build it.", dev("task_checkpoint", { plan: [{ step: "Read cart.ts", status: "done" }, { step: "Fix total()", status: "done" }, { step: "Run npm test", status: "in_progress" }], decisions: ["Keep the public API of cart.ts", "Round totals to 2 decimals"], next: "Run npm test" })].join("\n"));
  const argv = entries().filter((e) => e.bin === "claude" && e.argv).at(-1)?.argv ?? [];
  const sys = argv[argv.indexOf("--append-system-prompt") + 1] ?? "";
  t.check("Claude Code is offered task_checkpoint and told when to use it", entries().some((e) => e.bin === "claude" && e.device_tools?.includes("task_checkpoint")) && /task_checkpoint/.test(sys));
  l = await ledger();
  t.check("Claude's update moves the same plan forward, signed by Claude", l?.plan?.by === "claude-code/claude-sonnet-5-5" && l.plan.steps[1].status === "done" && l.plan.steps[2].status === "in_progress");
  t.check("a decision already made is not repeated; the new one is added by Claude", l?.decisions.length === 3 && l.decisions.at(-1).text === "Round totals to 2 decimals" && l.decisions.at(-1).by.startsWith("claude-code"), JSON.stringify(l?.decisions));
  t.check("plan.md follows", /\[x\] Fix total\(\)/.test(readFileSync(planFile, "utf8")) && /Round totals/.test(readFileSync(planFile, "utf8")));

  // 4. Claude Code's own to-do list (TodoWrite) is used when it has one.
  await say(chat.id, "Plan the API FAKE_TODO");
  l = await ledger();
  t.check("Claude Code's TodoWrite becomes the plan", l?.plan?.steps.map((s) => `${s.step}:${s.status}`).join("|") === "Plan the API:done|Write the API:in_progress", JSON.stringify(l?.plan));

  // 5. An empty checkpoint is an error the model sees.
  await say(chat.id, dev("task_checkpoint", {}));
  const bad = entries().filter((e) => e.device_tool === "task_checkpoint").at(-1);
  t.check("an empty checkpoint is refused with a reason", bad?.is_error && /nothing to save/.test(bad.result), JSON.stringify(bad));

  // 6. A model that plans in words only (no checkpoint): Opscode keeps its list as the plan, for free.
  const c2 = (await C.call("chat.create", { workspace_id: wid, mode: "read", engine: "codex", model: "gpt-fake" })).result.chat;
  await say(c2.id, "Plan it FAKE_LIST_PLAN");
  let l2 = (await C.call("chat.ledger", { chat_id: c2.id })).result.ledger;
  t.check("a plan written only in the reply becomes the plan (pending steps, marked as from the reply)", l2?.plan?.steps.map((s) => s.step).join("|") === "Read src/cart.ts|Fix total()|Run npm test" && l2.plan.by === "codex/gpt-fake (from its reply)" && existsSync(join(base, ".opscode", "tasks", c2.id, "plan.md")), JSON.stringify(l2?.plan));
  await say(c2.id, "Again FAKE_LIST_PLAN");
  await say(c2.id, dev("task_checkpoint", { plan: [{ step: "Real plan", status: "in_progress" }] }));
  await say(c2.id, "Summary FAKE_LIST_PLAN");
  l2 = (await C.call("chat.ledger", { chat_id: c2.id })).result.ledger;
  t.check("a later list in a reply never replaces a saved plan", l2?.plan?.steps.length === 1 && l2.plan.steps[0].step === "Real plan", JSON.stringify(l2?.plan));

  // 7. Deleting the chat removes its plan folder too.
  await C.call("chat.delete", { chat_id: chat.id });
  t.check("deleting the chat deletes its plan folder", !existsSync(join(base, ".opscode", "tasks", chat.id)));
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
}
const exit = await rt.stop();
t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
process.exit(t.finish());
